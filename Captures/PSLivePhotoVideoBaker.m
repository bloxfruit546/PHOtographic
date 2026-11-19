//
//  PSLivePhotoVideoBaker.m
//  PhotographicStyles12
//
//  AVFoundation + CoreImage Live Photo .MOV baker with Jetsam & metadata guards.
//

#import "PSLivePhotoVideoBaker.h"
#import "PSCaptureCoordinator.h"
#import "PSColorProfile.h"
#import "PSColorEngine.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

static const double kPS12MinLivePhotoDuration = 0.05;
static const double kPS12MaxLivePhotoDuration = 6.50;
static const double kPS12MaxVideoDuration = 90.0;
static const double kPS12ExportTimeoutSeconds = 12.0;
static const double kPS12VideoExportTimeoutSeconds = 25.0;

@implementation PSLivePhotoVideoBaker

+ (BOOL)bakeLivePhotoMovieAtURL:(NSURL *)movieURL
                       snapshot:(PSRenderSnapshot)snapshot
                        context:(CIContext *)context {
    if (!movieURL || ![movieURL isFileURL] || !context) {
        return NO;
    }

    // Never block the main thread on AVAssetExportSession.
    if ([NSThread isMainThread]) {
        return NO;
    }

    PSCaptureCoordinator *coordinator = [PSCaptureCoordinator shared];
    if (![coordinator livePhotoVideoBakingEnabled] || [coordinator isUnderMemoryPressure]) {
        return NO;
    }

    PSResolvedParameters params = PSResolveParameters(snapshot);
    if (params.isIdentity) {
        return NO;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:movieURL.path]) {
        return NO;
    }

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:movieURL
                                            options:@{ AVURLAssetPreferPreciseDurationAndTimingKey : @NO }];
    if (!asset) {
        return NO;
    }

    double durationSec = CMTimeGetSeconds(asset.duration);
    if (!isfinite(durationSec) || durationSec <= kPS12MinLivePhotoDuration || durationSec > kPS12MaxVideoDuration) {
        return NO;
    }

    if ([asset tracksWithMediaType:AVMediaTypeVideo].count == 0) {
        return NO;
    }

    AVVideoComposition *composition = [AVVideoComposition videoCompositionWithAsset:asset
                                                       applyingCIFiltersWithHandler:^(AVAsynchronousCIImageFilteringRequest *request) {
        @autoreleasepool {
            CIImage *src = request.sourceImage;
            if (!src) {
                [request finishWithError:[NSError errorWithDomain:@"com.ps12.videobaker"
                                                             code:-1
                                                         userInfo:nil]];
                return;
            }
            CIImage *clamped = [src imageByClampingToExtent];
            CIImage *graded = [[PSColorEngine shared] applyKernelToImage:clamped withParameters:params];
            CIImage *cropped = [(graded ?: src) imageByCroppingToRect:src.extent];
            [request finishWithImage:cropped context:context];
        }
    }];

    if (!composition) {
        return NO;
    }

    NSString *tempName = [NSString stringWithFormat:@"ps12_lp_%@.mov", [[NSUUID UUID] UUIDString]];
    NSURL *tempURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:tempName]];
    [fm removeItemAtURL:tempURL error:nil];

    BOOL isShortLivePhoto = (durationSec <= kPS12MaxLivePhotoDuration);
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset
                                                                           presetName:AVAssetExportPreset1280x720];
    if (!exportSession) {
        NSString *fallbackPreset = isShortLivePhoto ? AVAssetExportPresetHighestQuality : AVAssetExportPresetMediumQuality;
        exportSession = [[AVAssetExportSession alloc] initWithAsset:asset
                                                         presetName:fallbackPreset];
    }
    if (!exportSession) {
        return NO;
    }

    exportSession.outputURL = tempURL;
    exportSession.outputFileType = AVFileTypeQuickTimeMovie;
    exportSession.videoComposition = composition;
    exportSession.shouldOptimizeForNetworkUse = NO;
    if (asset.metadata.count > 0) {
        exportSession.metadata = asset.metadata;
    }

    dispatch_semaphore_t doneSem = dispatch_semaphore_create(0);
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        dispatch_semaphore_signal(doneSem);
    }];

    double timeoutSec = (durationSec <= kPS12MaxLivePhotoDuration) ? kPS12ExportTimeoutSeconds : kPS12VideoExportTimeoutSeconds;
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeoutSec * NSEC_PER_SEC));
    long waitResult = dispatch_semaphore_wait(doneSem, timeout);

    if (waitResult != 0) {
        [exportSession cancelExport];
        [fm removeItemAtURL:tempURL error:nil];
        return NO;
    }

    BOOL success = NO;
    if (exportSession.status == AVAssetExportSessionStatusCompleted && [fm fileExistsAtPath:tempURL.path]) {
        NSError *replaceErr = nil;
        if ([fm replaceItemAtURL:movieURL
                   withItemAtURL:tempURL
                  backupItemName:nil
                         options:0
                resultingItemURL:nil
                           error:&replaceErr]) {
            success = YES;
        } else {
            [fm removeItemAtURL:movieURL error:nil];
            if ([fm moveItemAtURL:tempURL toURL:movieURL error:&replaceErr]) {
                success = YES;
            }
        }
    }

    [fm removeItemAtURL:tempURL error:nil];
    return success;
}

@end
