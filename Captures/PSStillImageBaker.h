//
//  PSStillImageBaker.h
//  PhotographicStyles12
//
//  Metadata-preserving ImageIO JPEG & preview UIImage baker.
//  Preserves 100% of {Exif}, {TIFF}, {GPS}, Orientation, and {MakerApple}
//  (including key 17 ContentIdentifier used by Iris Live Photo pairing).
//

#ifndef PS12_STILL_IMAGE_BAKER_H
#define PS12_STILL_IMAGE_BAKER_H

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <UIKit/UIKit.h>
#import "PSState.h"

NS_ASSUME_NONNULL_BEGIN

@interface PSStillImageBaker : NSObject

/// Bakes the active style into JPEG data while preserving all ImageIO metadata
/// dictionaries ({MakerApple}, {Exif}, {TIFF}, {GPS}, Orientation).
+ (nullable NSData *)bakedJPEGDataFromJPEGData:(NSData *)sourceData
                                      snapshot:(PSRenderSnapshot)snapshot
                                       context:(CIContext *)context;

/// Reads a JPEG file with memory mapping, bakes it, and writes it back atomically.
+ (BOOL)bakeJPEGFileAtURL:(NSURL *)fileURL
                 snapshot:(PSRenderSnapshot)snapshot
                  context:(CIContext *)context;

/// Bakes a UIImage thumbnail / image-well preview preserving scale and orientation.
+ (nullable UIImage *)bakedPreviewImage:(nullable UIImage *)previewImage
                               snapshot:(PSRenderSnapshot)snapshot
                                context:(CIContext *)context;

/// Thread-safe fast-path for CAMStillImageCaptureResponse thumbnails:
/// downsamples images exceeding 360px and renders on the coordinator's
/// isolated thumbnail CIContext (never blocks on _bakeSemaphore).
+ (nullable UIImage *)bakedFastThumbnailImage:(nullable UIImage *)previewImage
                                   snapshot:(PSRenderSnapshot)snapshot;

@end

NS_ASSUME_NONNULL_END

#endif /* PS12_STILL_IMAGE_BAKER_H */
