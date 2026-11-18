//
//  PSStillImageBaker.m
//  PhotographicStyles12
//
//  ImageIO-backed still JPEG baker with full MakerNotes / EXIF preservation.
//

#import "PSStillImageBaker.h"
#import "PSCaptureCoordinator.h"
#import "PSColorProfile.h"
#import "PSColorEngine.h"
#import <ImageIO/ImageIO.h>
#import <math.h>

@implementation PSStillImageBaker

+ (nullable NSData *)bakedJPEGDataFromJPEGData:(NSData *)sourceData
                                      snapshot:(PSRenderSnapshot)snapshot
                                       context:(CIContext *)context {
    if (!sourceData || sourceData.length == 0 || !context) {
        return sourceData;
    }

    PSResolvedParameters params = PSResolveParameters(snapshot);
    if (params.isIdentity) {
        return sourceData;
    }

    NSData *resultData = sourceData;
    @autoreleasepool {
        CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)sourceData, NULL);
        if (!source) {
            return sourceData;
        }

        CFDictionaryRef props = CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
        // Keep native sensor orientation so it continues to match the preserved EXIF Orientation tag.
        CIImage *ciInput = [CIImage imageWithData:sourceData
                                          options:@{ kCIImageApplyOrientationProperty : @NO }];
        if (!ciInput) {
            if (props) CFRelease(props);
            CFRelease(source);
            return sourceData;
        }

        CIImage *ciOutput = [[PSColorEngine shared] applyKernelToImage:ciInput withParameters:params];
        if (!ciOutput) {
            if (props) CFRelease(props);
            CFRelease(source);
            return sourceData;
        }

        CGImageRef cgOut = [context createCGImage:ciOutput fromRect:ciInput.extent];
        if (!cgOut) {
            if (props) CFRelease(props);
            CFRelease(source);
            return sourceData;
        }

        NSMutableData *destData = [NSMutableData dataWithCapacity:sourceData.length];
        CGImageDestinationRef dest = CGImageDestinationCreateWithData(
            (__bridge CFMutableDataRef)destData,
            CFSTR("public.jpeg"),
            1,
            NULL
        );

        if (dest) {
            NSMutableDictionary *mergedProps = props
                ? [(__bridge NSDictionary *)props mutableCopy]
                : [NSMutableDictionary dictionaryWithCapacity:1];
            mergedProps[(__bridge NSString *)kCGImageDestinationLossyCompressionQuality] = @(0.93f);

            CGImageDestinationAddImage(dest, cgOut, (__bridge CFDictionaryRef)mergedProps);
            if (CGImageDestinationFinalize(dest) && destData.length > 512) {
                resultData = [destData copy];
            }
            CFRelease(dest);
        }

        CGImageRelease(cgOut);
        if (props) CFRelease(props);
        CFRelease(source);
    }
    return resultData;
}

+ (BOOL)bakeJPEGFileAtURL:(NSURL *)fileURL
                 snapshot:(PSRenderSnapshot)snapshot
                  context:(CIContext *)context {
    if (!fileURL || ![fileURL isFileURL] || !context) {
        return NO;
    }

    PSResolvedParameters params = PSResolveParameters(snapshot);
    if (params.isIdentity) {
        return NO;
    }

    NSError *readErr = nil;
    NSData *sourceData = [NSData dataWithContentsOfURL:fileURL
                                               options:NSDataReadingMappedIfSafe
                                                 error:&readErr];
    if (!sourceData || readErr || sourceData.length == 0) {
        return NO;
    }

    NSData *bakedData = [self bakedJPEGDataFromJPEGData:sourceData snapshot:snapshot context:context];
    if (!bakedData || bakedData == sourceData || bakedData.length <= 512) {
        return NO;
    }

    NSError *writeErr = nil;
    BOOL ok = [bakedData writeToURL:fileURL options:NSDataWritingAtomic error:&writeErr];
    return ok && (writeErr == nil);
}

+ (nullable UIImage *)bakedPreviewImage:(nullable UIImage *)previewImage
                               snapshot:(PSRenderSnapshot)snapshot
                                context:(CIContext *)context {
    if (!previewImage || !context) {
        return previewImage;
    }
    return [[PSColorEngine shared] processCapturedImage:previewImage
                                            forSnapshot:snapshot
                                           usingContext:context];
}

+ (nullable UIImage *)bakedFastThumbnailImage:(nullable UIImage *)previewImage
                                   snapshot:(PSRenderSnapshot)snapshot {
    if (!previewImage) {
        return nil;
    }
    if (PSResolveParameters(snapshot).isIdentity) {
        return previewImage;
    }

    UIImage *workImage = previewImage;
    CGFloat maxDim = 360.0;
    CGFloat pixelW = previewImage.size.width * previewImage.scale;
    CGFloat pixelH = previewImage.size.height * previewImage.scale;
    CGFloat longest = MAX(pixelW, pixelH);

    if (longest > maxDim && pixelW > 0.0 && pixelH > 0.0) {
        CGFloat ratio = maxDim / longest;
        CGSize targetSize = CGSizeMake(floor(pixelW * ratio), floor(pixelH * ratio));
        if (targetSize.width >= 1.0 && targetSize.height >= 1.0) {
            UIGraphicsBeginImageContextWithOptions(targetSize, NO, 1.0);
            [previewImage drawInRect:CGRectMake(0.0, 0.0, targetSize.width, targetSize.height)];
            UIImage *downsampled = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            if (downsampled) {
                workImage = downsampled;
            }
        }
    }

    __block UIImage *result = workImage;
    [[PSCaptureCoordinator shared] performThumbnailBake:^(CIContext *thumbContext) {
        UIImage *styled = [[PSColorEngine shared] processCapturedImage:workImage
                                                           forSnapshot:snapshot
                                                          usingContext:thumbContext];
        if (styled) {
            result = styled;
        }
    }];
    return result ?: previewImage;
}

@end
