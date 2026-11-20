//
//  Tweak.xm
//  PhotographicStyles12 (v2.2.0)
//
//  Clean-room, Iris-safe Camera tweak:
//    - Zero AVCaptureSession output injection.
//    - Zero global CIContext or CALayer hooks.
//    - Zero-readback optical preview veil (PSOpticalPreviewView).
//    - Touch-passthrough CoreGraphics overlay on CAMViewfinderViewController.
//    - Serialized, Jetsam-safe JPEG + Live Photo .MOV persistence baking.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <os/lock.h>

#import "CameraUI12.h"
#import "PSState.h"
#import "PSColorProfile.h"
#import "PSPreviewFilterController.h"
#import "PSOverlayPassthroughView.h"
#import "PSCaptureCoordinator.h"
#import "PSStillImageBaker.h"
#import "PSLivePhotoVideoBaker.h"
#import "PSVideoTimelineTracker.h"
#import "PSPhotographicStyleFilter.h"
#import "PSDiagnostics.h"

static const void *kPS12OverlayAssocKey          = &kPS12OverlayAssocKey;
static const void *kPS12BakedPreviewImageKey     = &kPS12BakedPreviewImageKey;
static const void *kPS12BakedImageWellKey        = &kPS12BakedImageWellKey;
static const void *kPS12BakedPlaceholderKey      = &kPS12BakedPlaceholderKey;

static os_unfair_lock s_bakedURLsLock = OS_UNFAIR_LOCK_INIT;
static NSMutableSet<NSString *> *s_bakedURLPaths = nil;

static BOOL PS12IsURLBaked(NSURL *url) {
    if (!url || !url.path) {
        return NO;
    }
    os_unfair_lock_lock(&s_bakedURLsLock);
    BOOL contains = s_bakedURLPaths ? [s_bakedURLPaths containsObject:url.path] : NO;
    os_unfair_lock_unlock(&s_bakedURLsLock);
    return contains;
}

static void PS12MarkURLBaked(NSURL *url) {
    if (!url || !url.path) {
        return;
    }
    os_unfair_lock_lock(&s_bakedURLsLock);
    if (!s_bakedURLPaths) {
        s_bakedURLPaths = [NSMutableSet setWithCapacity:32];
    } else if (s_bakedURLPaths.count >= 64) {
        [s_bakedURLPaths removeAllObjects];
    }
    [s_bakedURLPaths addObject:url.path];
    os_unfair_lock_unlock(&s_bakedURLsLock);
}

static UIImage *PS12BakeResponseImage(id response, UIImage *orig, const void *assocKey) {
    if (!orig) {
        return nil;
    }
    @try {
        UIImage *cached = objc_getAssociatedObject(response, assocKey);
        if (cached) {
            return cached;
        }

        PSRenderSnapshot snap = [[PSState shared] snapshot];
        if (PSResolveParameters(snap).isIdentity) {
            return orig;
        }

        UIImage *processed = [PSStillImageBaker bakedFastThumbnailImage:orig snapshot:snap];
        if (processed && processed != orig) {
            objc_setAssociatedObject(response, assocKey, processed, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return processed;
        }
    } @catch (NSException *exception) {
        PS12LogException(@"PS12BakeResponseImage", exception);
    }
    return orig;
}

%group PS12CameraHooks

#pragma mark - Viewfinder & Overlay Hooks

%hook CAMViewfinderViewController

- (void)viewDidLoad {
    %orig;

    @try {
        CAMPreviewView *previewView = PS12SafePreviewViewFromViewfinder(self);
        PSOverlayPassthroughView *overlay = objc_getAssociatedObject(self, kPS12OverlayAssocKey);

        if (!overlay && [self isViewLoaded] && self.view) {
            overlay = [[PSOverlayPassthroughView alloc] initWithFrame:self.view.bounds];
            overlay.targetPreviewView = previewView;

            if (previewView && previewView.superview == self.view) {
                [self.view insertSubview:overlay aboveSubview:previewView];
            } else {
                [self.view addSubview:overlay];
            }
            objc_setAssociatedObject(self, kPS12OverlayAssocKey, overlay, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }

        if (overlay) {
            [[PSPreviewFilterController shared] refreshOnOpticalView:overlay.opticalPreviewView];
        }
    } @catch (NSException *exception) {
        PS12LogException(@"CAMViewfinderViewController.viewDidLoad", exception);
    }
}

- (void)viewDidLayoutSubviews {
    %orig;

    @try {
        CAMPreviewView *previewView = PS12SafePreviewViewFromViewfinder(self);
        PSOverlayPassthroughView *overlay = objc_getAssociatedObject(self, kPS12OverlayAssocKey);

        if (overlay && self.view) {
            if (!CGRectEqualToRect(overlay.frame, self.view.bounds)) {
                overlay.frame = self.view.bounds;
            }
            if (overlay.targetPreviewView != previewView) {
                overlay.targetPreviewView = previewView;
            }
            [[PSPreviewFilterController shared] refreshOnOpticalView:overlay.opticalPreviewView];
        }
    } @catch (NSException *exception) {
        PS12LogException(@"CAMViewfinderViewController.viewDidLayoutSubviews", exception);
    }
}

%end

#pragma mark - Native CameraUI 1:1 CIFilter Preview & Video Timeline Hooks

%hook CAMFilterUtilities

+ (NSArray *)filtersForFilterType:(NSInteger)filterType
                     lightingType:(NSInteger)lightingType
                applyDepthEffect:(BOOL)applyDepthEffect
{
    NSArray *orig = %orig(filterType, lightingType, applyDepthEffect);
    @try {
        PSRenderSnapshot snap = [[PSState shared] snapshot];
        if (!PSResolveParameters(snap).isIdentity) {
            PSPhotographicStyleFilter *styleFilter = [[PSPhotographicStyleFilter alloc] init];
            if (styleFilter) {
                NSMutableArray *updated = orig ? [orig mutableCopy] : [NSMutableArray arrayWithCapacity:1];
                [updated addObject:styleFilter];
                return [updated copy];
            }
        }
    } @catch (NSException *exception) {
        PS12LogException(@"CAMFilterUtilities.filtersForFilterType", exception);
    }
    return orig;
}

%end

%hook CAMEffectsFullsizeView

- (void)setHidden:(BOOL)hidden {
    %orig;
    @try {
        UIView *view = (UIView *)(id)self;
        BOOL active = (!hidden && view.window != nil);
        PSPreviewFilterController *ctrl = [PSPreviewFilterController shared];
        ctrl.nativeEffectsViewActive = active;
        [ctrl refreshOnOpticalView:nil];
    } @catch (NSException *exception) {
        PS12LogException(@"CAMEffectsFullsizeView.setHidden", exception);
    }
}

- (void)didMoveToWindow {
    %orig;
    @try {
        UIView *view = (UIView *)(id)self;
        BOOL active = (!view.hidden && view.window != nil);
        PSPreviewFilterController *ctrl = [PSPreviewFilterController shared];
        ctrl.nativeEffectsViewActive = active;
        [ctrl refreshOnOpticalView:nil];
    } @catch (NSException *exception) {
        PS12LogException(@"CAMEffectsFullsizeView.didMoveToWindow", exception);
    }
}

%end

%hook CUCaptureController

- (void)startCapturingVideoWithRequest:(id)request {
    @try {
        PSRenderSnapshot snap = [[PSState shared] snapshot];
        [[PSVideoTimelineTracker shared] beginRecordingSessionWithInitialSnapshot:snap];
    } @catch (NSException *exception) {
        PS12LogException(@"CUCaptureController.startCapturingVideo", exception);
    }
    %orig;
}

- (void)stopCapturingVideo {
    @try {
        [[PSVideoTimelineTracker shared] endRecordingSession];
    } @catch (NSException *exception) {
        PS12LogException(@"CUCaptureController.stopCapturingVideo", exception);
    }
    %orig;
}

%end

#pragma mark - Still Capture Response Thumbnails

%hook CAMStillImageCaptureResponse

- (UIImage *)previewImage {
    return PS12BakeResponseImage(self, %orig, kPS12BakedPreviewImageKey);
}

- (UIImage *)imageWellImage {
    return PS12BakeResponseImage(self, %orig, kPS12BakedImageWellKey);
}

- (UIImage *)placeholderImage {
    return PS12BakeResponseImage(self, %orig, kPS12BakedPlaceholderKey);
}

%end

#pragma mark - Persistence Hooks (Still JPEG + Iris Live Photo .MOV)

%hook CAMPersistenceController

- (BOOL)_writeJPEGToURL:(NSURL *)url
               withData:(NSData *)data
              thumbnail:(UIImage *)thumbnail
             properties:(NSDictionary *)properties
            duringBurst:(BOOL)duringBurst
                  error:(NSError **)error
{
    if (duringBurst || !data || data.length == 0 || !thumbnail) {
        return %orig(url, data, thumbnail, properties, duringBurst, error);
    }

    // Never block CameraUI's capture/write thread with 8MP JPEG baking (prevents 1s rear-cam blackout).
    // Only fast-bake the tiny thumbnail (<= 360px) here; full 8MP bake runs asynchronously below.
    UIImage *bakedThumb = thumbnail;
    @try {
        PSRenderSnapshot snap = [[PSState shared] snapshot];
        if (!PSResolveParameters(snap).isIdentity) {
            bakedThumb = [PSStillImageBaker bakedFastThumbnailImage:thumbnail snapshot:snap] ?: thumbnail;
        }
    } @catch (NSException *exception) {
        PS12LogException(@"CAMPersistenceController._writeJPEGToURL", exception);
    }

    return %orig(url, data, bakedThumb, properties, duringBurst, error);
}

- (void)_locallyPersistStillImageResult:(id)result
                             forRequest:(id)request
                  withCompletionHandler:(void (^)(id localResult))completionHandler
{
    BOOL isBurst = NO;
    @try {
        if (request && [request respondsToSelector:@selector(burstIdentifier)]) {
            id (*msgBurst)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
            if (msgBurst(request, @selector(burstIdentifier)) != nil) {
                isBurst = YES;
            }
        }
    } @catch (NSException *exception) {
        (void)exception;
        isBurst = NO;
    }

    PSRenderSnapshot snap = [[PSState shared] snapshot];
    if (isBurst || PSResolveParameters(snap).isIdentity) {
        %orig(result, request, completionHandler);
        return;
    }

    void (^wrappedHandler)(id) = ^(id localResult) {
        NSURL *destURL = nil;
        NSURL *linkedURL = nil;
        @try {
            if (localResult) {
                if ([localResult respondsToSelector:@selector(localDestinationURL)]) {
                    destURL = [localResult localDestinationURL];
                }
                if ([localResult respondsToSelector:@selector(linkedDestinationURL)]) {
                    linkedURL = [localResult linkedDestinationURL];
                }
            }
        } @catch (NSException *exception) {
            PS12LogException(@"CAMPersistenceController.stillResultURLs", exception);
            destURL = nil;
            linkedURL = nil;
        }

        BOOL needsDest = (destURL && [destURL isFileURL] && !PS12IsURLBaked(destURL));
        BOOL needsLinked = (linkedURL && [linkedURL isFileURL] && ![linkedURL isEqual:destURL] && !PS12IsURLBaked(linkedURL));

        if (needsDest || needsLinked) {
            // Asynchronous non-blocking 8MP bake on serial queue: frees rear ISP immediately!
            [[PSCaptureCoordinator shared] performSerializedBake:^(CIContext *context) {
                @try {
                    if (needsDest && !PS12IsURLBaked(destURL)) {
                        if ([PSStillImageBaker bakeJPEGFileAtURL:destURL snapshot:snap context:context]) {
                            PS12MarkURLBaked(destURL);
                        }
                    }
                    if (needsLinked && !PS12IsURLBaked(linkedURL)) {
                        if ([PSStillImageBaker bakeJPEGFileAtURL:linkedURL snapshot:snap context:context]) {
                            PS12MarkURLBaked(linkedURL);
                        }
                    }
                } @catch (NSException *exception) {
                    PS12LogException(@"CAMPersistenceController.asyncStillBake", exception);
                }
                if (completionHandler) {
                    completionHandler(localResult);
                }
            }];
            return;
        }

        if (completionHandler) {
            completionHandler(localResult);
        }
    };

    %orig(result, request, wrappedHandler);
}

- (void)_locallyPersistVideoCaptureResult:(id)result
                               forRequest:(id)request
                    withCompletionHandler:(void (^)(id localResult))completionHandler
{
    PSRenderSnapshot snap = [[PSState shared] snapshot];
    PSCaptureCoordinator *coordinator = [PSCaptureCoordinator shared];
    if (PSResolveParameters(snap).isIdentity ||
        ![coordinator livePhotoVideoBakingEnabled] ||
        [coordinator isUnderMemoryPressure]) {
        %orig(result, request, completionHandler);
        return;
    }

    NSURL *sourceURL = nil;
    @try {
        if (result && [result respondsToSelector:@selector(localDestinationURL)]) {
            sourceURL = [result localDestinationURL];
        }
        if (!sourceURL && result && [result respondsToSelector:@selector(filteredLocalDestinationURL)]) {
            sourceURL = [result filteredLocalDestinationURL];
        }
    } @catch (NSException *exception) {
        (void)exception;
        sourceURL = nil;
    }

    if (sourceURL && [sourceURL isFileURL] && !PS12IsURLBaked(sourceURL) && ![NSThread isMainThread]) {
        [coordinator performSynchronousSerializedBake:^(CIContext *context) {
            if ([PSLivePhotoVideoBaker bakeLivePhotoMovieAtURL:sourceURL snapshot:snap context:context]) {
                PS12MarkURLBaked(sourceURL);
            }
        }];
    }

    void (^wrappedHandler)(id) = ^(id localResult) {
        @try {
            if (localResult && ![NSThread isMainThread]) {
                NSURL *finalURL = nil;
                @try {
                    if ([localResult respondsToSelector:@selector(localDestinationURL)]) {
                        finalURL = [localResult localDestinationURL];
                    }
                    if (!finalURL && [localResult respondsToSelector:@selector(filteredLocalDestinationURL)]) {
                        finalURL = [localResult filteredLocalDestinationURL];
                    }
                } @catch (NSException *exception) {
                    PS12LogException(@"CAMPersistenceController.videoResultURLs", exception);
                    finalURL = nil;
                }
                if (finalURL && [finalURL isFileURL] && !PS12IsURLBaked(finalURL) &&
                    (!sourceURL || !PS12IsURLBaked(sourceURL))) {
                    [coordinator performSynchronousSerializedBake:^(CIContext *context) {
                        if ([PSLivePhotoVideoBaker bakeLivePhotoMovieAtURL:finalURL snapshot:snap context:context]) {
                            PS12MarkURLBaked(finalURL);
                        }
                    }];
                }
            }
        } @catch (NSException *exception) {
            PS12LogException(@"CAMPersistenceController.videoHandler", exception);
        }
        if (completionHandler) {
            completionHandler(localResult);
        }
    };

    %orig(result, request, wrappedHandler);
}

%end

#pragma mark - Iris Live Photo Photos.framework Commit Hook (Front + Rear)

%hook PHAssetCreationRequest

- (void)addResourceWithType:(NSInteger)type fileURL:(NSURL *)fileURL options:(id)options {
    @try {
        if (fileURL && [fileURL isFileURL] && !PS12IsURLBaked(fileURL) && ![NSThread isMainThread]) {
            PSRenderSnapshot snap = [[PSState shared] snapshot];
            if (!PSResolveParameters(snap).isIdentity) {
                PSCaptureCoordinator *coordinator = [PSCaptureCoordinator shared];
                // PHAssetResourceTypePhoto = 1
                if (type == 1) {
                    [coordinator performSynchronousSerializedBake:^(CIContext *context) {
                        if ([PSStillImageBaker bakeJPEGFileAtURL:fileURL snapshot:snap context:context]) {
                            PS12MarkURLBaked(fileURL);
                        }
                    }];
                }
                // PHAssetResourceTypeVideo = 2, PHAssetResourceTypePairedVideo = 9 (Iris Live Photo .MOV)
                else if ((type == 9 || type == 2) &&
                         [coordinator livePhotoVideoBakingEnabled] &&
                         ![coordinator isUnderMemoryPressure]) {
                    [coordinator performSynchronousSerializedBake:^(CIContext *context) {
                        if ([PSLivePhotoVideoBaker bakeLivePhotoMovieAtURL:fileURL snapshot:snap context:context]) {
                            PS12MarkURLBaked(fileURL);
                        }
                    }];
                }
            }
        }
    } @catch (NSException *exception) {
        PS12LogException(@"PHAssetCreationRequest.addResourceFileURL", exception);
    }
    %orig(type, fileURL, options);
}

- (void)addResourceWithType:(NSInteger)type data:(NSData *)data options:(id)options {
    NSData *payload = data;
    @try {
        // PHAssetResourceTypePhoto = 1
        if (type == 1 && data && data.length > 512 && ![NSThread isMainThread]) {
            PSRenderSnapshot snap = [[PSState shared] snapshot];
            if (!PSResolveParameters(snap).isIdentity) {
                __block NSData *bakedData = nil;
                [[PSCaptureCoordinator shared] performSynchronousSerializedBake:^(CIContext *context) {
                    bakedData = [PSStillImageBaker bakedJPEGDataFromJPEGData:data snapshot:snap context:context];
                }];
                if (bakedData && bakedData.length > 512) {
                    payload = bakedData;
                }
            }
        }
    } @catch (NSException *exception) {
        PS12LogException(@"PHAssetCreationRequest.addResourceData", exception);
    }
    %orig(type, payload, options);
}

%end

%end /* PS12CameraHooks */

%ctor {
    @autoreleasepool {
        NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
        if (![bundleID isEqualToString:@"com.apple.camera"]) {
            return;
        }
        %init(PS12CameraHooks);
    }
}
