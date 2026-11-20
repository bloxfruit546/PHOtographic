//
//  PSVideoTimelineTracker.h
//  PhotographicStyles12
//
//  Thread-safe per-timestamp keyframe tracker for live style adjustments
//  during video recording on iOS 12.
//

#ifndef PS12_VIDEO_TIMELINE_TRACKER_H
#define PS12_VIDEO_TIMELINE_TRACKER_H

#import <Foundation/Foundation.h>
#import "PSState.h"

NS_ASSUME_NONNULL_BEGIN

@interface PSVideoTimelineTracker : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly, getter=isRecording) BOOL recording;

/// Starts a new video recording timeline with the initial style snapshot.
- (void)beginRecordingSessionWithInitialSnapshot:(PSRenderSnapshot)snapshot;

/// Records a style keyframe if a recording session is active.
- (void)recordSnapshotChange:(PSRenderSnapshot)snapshot;

/// Marks the active recording session as finished while retaining keyframes
/// for post-capture AVVideoComposition grading.
- (void)endRecordingSession;

/// Resolves the style snapshot active at the given video timestamp (seconds).
- (PSRenderSnapshot)snapshotForVideoTimeSeconds:(double)elapsedSeconds
                                       fallback:(PSRenderSnapshot)fallback;

/// Clears retained keyframes once video baking completes.
- (void)clearTimeline;

@end

NS_ASSUME_NONNULL_END

#endif /* PS12_VIDEO_TIMELINE_TRACKER_H */
