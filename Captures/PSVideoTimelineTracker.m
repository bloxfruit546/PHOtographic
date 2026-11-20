//
//  PSVideoTimelineTracker.m
//  PhotographicStyles12
//
//  Thread-safe per-timestamp keyframe tracker for live style adjustments
//  during video recording.
//

#import "PSVideoTimelineTracker.h"
#import <os/lock.h>
#import <math.h>

static const NSUInteger kPS12MaxTimelineKeyframes = 256;

typedef struct {
    double elapsedSeconds;
    PSRenderSnapshot snapshot;
} PS12TimelineKeyframe;

@interface PSVideoTimelineTracker () {
    os_unfair_lock _lock;
    BOOL _recording;
    CFAbsoluteTime _sessionStartTime;
    PS12TimelineKeyframe _keyframes[kPS12MaxTimelineKeyframes];
    NSUInteger _keyframeCount;
}
@end

@implementation PSVideoTimelineTracker

+ (instancetype)shared {
    static PSVideoTimelineTracker *s_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_instance = [[PSVideoTimelineTracker alloc] init];
    });
    return s_instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _lock = OS_UNFAIR_LOCK_INIT;
        _recording = NO;
        _sessionStartTime = 0.0;
        _keyframeCount = 0;
    }
    return self;
}

- (BOOL)isRecording {
    os_unfair_lock_lock(&_lock);
    BOOL rec = _recording;
    os_unfair_lock_unlock(&_lock);
    return rec;
}

- (void)beginRecordingSessionWithInitialSnapshot:(PSRenderSnapshot)snapshot {
    os_unfair_lock_lock(&_lock);
    _recording = YES;
    _sessionStartTime = CFAbsoluteTimeGetCurrent();
    _keyframeCount = 1;
    _keyframes[0].elapsedSeconds = 0.0;
    _keyframes[0].snapshot = snapshot;
    os_unfair_lock_unlock(&_lock);
}

- (void)recordSnapshotChange:(PSRenderSnapshot)snapshot {
    os_unfair_lock_lock(&_lock);
    if (_recording && _keyframeCount < kPS12MaxTimelineKeyframes) {
        double dt = CFAbsoluteTimeGetCurrent() - _sessionStartTime;
        if (!isfinite(dt) || dt < 0.0) {
            dt = 0.0;
        }
        _keyframes[_keyframeCount].elapsedSeconds = dt;
        _keyframes[_keyframeCount].snapshot = snapshot;
        _keyframeCount += 1;
    }
    os_unfair_lock_unlock(&_lock);
}

- (void)endRecordingSession {
    os_unfair_lock_lock(&_lock);
    _recording = NO;
    os_unfair_lock_unlock(&_lock);
}

- (PSRenderSnapshot)snapshotForVideoTimeSeconds:(double)elapsedSeconds
                                       fallback:(PSRenderSnapshot)fallback {
    os_unfair_lock_lock(&_lock);
    if (_keyframeCount == 0 || !isfinite(elapsedSeconds) || elapsedSeconds < 0.0) {
        os_unfair_lock_unlock(&_lock);
        return fallback;
    }

    PSRenderSnapshot chosen = _keyframes[0].snapshot;
    for (NSUInteger i = 1; i < _keyframeCount; i++) {
        if (_keyframes[i].elapsedSeconds <= elapsedSeconds) {
            chosen = _keyframes[i].snapshot;
        } else {
            break;
        }
    }
    os_unfair_lock_unlock(&_lock);
    return chosen;
}

- (void)clearTimeline {
    os_unfair_lock_lock(&_lock);
    _recording = NO;
    _keyframeCount = 0;
    os_unfair_lock_unlock(&_lock);
}

@end
