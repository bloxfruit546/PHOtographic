//
//  CameraUI12.h
//  PhotographicStyles12
//
//  Minimal, defensive CameraUI.framework declarations for iOS 12.0 - 12.5.8.
//  All private accessors must be guarded at runtime with -respondsToSelector:
//  and KVC calls wrapped in @try / @catch.
//

#ifndef PS12_CAMERA_UI_12_H
#define PS12_CAMERA_UI_12_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

@class AVCaptureVideoPreviewLayer;

@interface CAMPreviewView : UIView

@property (nullable, nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;
@property (nullable, nonatomic, strong) CALayer *previewLayer;

- (CGRect)previewBounds;

@end

@interface CAMViewfinderViewController : UIViewController

- (void)viewDidLoad;
- (void)viewDidLayoutSubviews;

@end

/// Safely retrieves the preview view from CAMViewfinderViewController via KVC.
static inline CAMPreviewView * _Nullable PS12SafePreviewViewFromViewfinder(id _Nullable viewfinderVC) {
    if (!viewfinderVC) {
        return nil;
    }
    @try {
        id candidate = [viewfinderVC valueForKey:@"_previewView"];
        if ([candidate isKindOfClass:[UIView class]]) {
            return (CAMPreviewView *)candidate;
        }
    } @catch (NSException *exception) {
        (void)exception;
    }
    return nil;
}

#pragma mark - Phase 4 Capture & Persistence Declarations (iOS 12.4)

@interface CAMCaptureResponse : NSObject

@property (nonatomic, assign) long long uniqueIdentifier;
@property (nullable, nonatomic, strong) NSDate *captureDate;

@end

@interface CAMStillImageCaptureResponse : CAMCaptureResponse

@property (nullable, nonatomic, strong) UIImage *previewImage;
@property (nullable, nonatomic, strong) UIImage *imageWellImage;
@property (nullable, nonatomic, strong) UIImage *placeholderImage;
@property (nullable, nonatomic, copy) NSString *persistenceUUID;
@property (nullable, nonatomic, strong) NSDictionary *stillImageMetadata;

@end

@interface CAMStillImageLocalPersistenceResult : NSObject

@property (nullable, nonatomic, copy) NSURL *localDestinationURL;
@property (nullable, nonatomic, copy) NSURL *linkedDestinationURL;
@property (nullable, nonatomic, copy) NSString *localPersistenceUUID;
@property (nullable, nonatomic, copy) NSString *uniformTypeIdentifier;
@property (nullable, nonatomic, copy) NSDictionary *metadata;

@end

@interface CAMVideoLocalPersistenceResult : NSObject

@property (nullable, nonatomic, copy) NSURL *localDestinationURL;
@property (nullable, nonatomic, copy) NSURL *filteredLocalDestinationURL;
@property (nullable, nonatomic, copy) NSURL *linkedDestinationURL;
@property (nullable, nonatomic, copy) NSString *stillPersistenceUUID;
@property (nonatomic, assign) CMTime duration;
@property (nonatomic, assign) CMTime stillDisplayTime;

@end

@interface CAMPersistenceController : NSObject

@property (nullable, nonatomic, readonly) dispatch_queue_t _localPersistenceQueue;

- (BOOL)_writeJPEGToURL:(NSURL *)url
               withData:(NSData *)data
              thumbnail:(nullable UIImage *)thumbnail
             properties:(nullable NSDictionary *)properties
            duringBurst:(BOOL)duringBurst
                  error:(NSError * _Nullable * _Nullable)error;

- (void)_locallyPersistStillImageResult:(id)result
                             forRequest:(id)request
                  withCompletionHandler:(nullable void (^)(id _Nullable localResult))completionHandler;

- (void)_locallyPersistVideoCaptureResult:(id)result
                               forRequest:(id)request
                    withCompletionHandler:(nullable void (^)(id _Nullable localResult))completionHandler;

@end

NS_ASSUME_NONNULL_END

#endif /* PS12_CAMERA_UI_12_H */
