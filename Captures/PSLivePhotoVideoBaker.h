//
//  PSLivePhotoVideoBaker.h
//  PhotographicStyles12
//
//  Iris-safe Live Photo companion .MOV baker (duration <= 6.5s).
//  Uses AVVideoComposition + PSColorEngine CIColorKernel while preserving
//  QuickTime content identifier & still-image-time metadata.
//

#ifndef PS12_LIVE_PHOTO_VIDEO_BAKER_H
#define PS12_LIVE_PHOTO_VIDEO_BAKER_H

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import "PSState.h"

NS_ASSUME_NONNULL_BEGIN

@interface PSLivePhotoVideoBaker : NSObject

/// Grades a short Live Photo companion .MOV file (0.05s < duration <= 6.5s)
/// on a background thread. Returns NO immediately on main thread, under
/// memory pressure, for identity styles, or for normal long videos (> 6.5s).
+ (BOOL)bakeLivePhotoMovieAtURL:(NSURL *)movieURL
                       snapshot:(PSRenderSnapshot)snapshot
                        context:(CIContext *)context;

@end

NS_ASSUME_NONNULL_END

#endif /* PS12_LIVE_PHOTO_VIDEO_BAKER_H */
