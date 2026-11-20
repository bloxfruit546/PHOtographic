//
//  PSPreviewFilterController.m
//  PhotographicStyles12
//
//  Zero-readback viewfinder preview controller for Apple A7 (iOS 12).
//  Drives PSOpticalPreviewView with zero CAMPreviewView layer mutation.
//

#import "PSPreviewFilterController.h"
#import "PSOpticalPreviewView.h"
#import "PSVideoTimelineTracker.h"
#import "PSState.h"
#import <string.h>

@interface PSPreviewFilterController () {
    BOOL _hasCachedSnapshot;
    BOOL _lastNativeActive;
    PSRenderSnapshot _lastSnapshot;
}
@end

@implementation PSPreviewFilterController

+ (instancetype)shared {
    static PSPreviewFilterController *s_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_instance = [[PSPreviewFilterController alloc] init];
    });
    return s_instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _hasCachedSnapshot = NO;
        memset(&_lastSnapshot, 0, sizeof(_lastSnapshot));
    }
    return self;
}

- (void)refreshOnOpticalView:(nullable PSOpticalPreviewView *)opticalView {
    PSOpticalPreviewView *target = opticalView ?: self.opticalPreviewView;
    if (!target) {
        return;
    }
    if (opticalView && self.opticalPreviewView != opticalView) {
        self.opticalPreviewView = opticalView;
    }

    PSRenderSnapshot snap = [[PSState shared] snapshot];
    [[PSVideoTimelineTracker shared] recordSnapshotChange:snap];

    BOOL nativeActive = self.nativeEffectsViewActive;
    if (_hasCachedSnapshot &&
        _lastNativeActive == nativeActive &&
        memcmp(&snap, &_lastSnapshot, sizeof(PSRenderSnapshot)) == 0) {
        return;
    }

    _hasCachedSnapshot = YES;
    _lastNativeActive = nativeActive;
    _lastSnapshot = snap;

    if (nativeActive) {
        PSRenderSnapshot hiddenSnap;
        memset(&hiddenSnap, 0, sizeof(hiddenSnap));
        hiddenSnap.enabled = NO;
        [target applySnapshot:hiddenSnap];
    } else {
        [target applySnapshot:snap];
    }
}

- (void)refreshOnPreviewView:(nullable UIView *)previewView {
    (void)previewView;
    [self refreshOnOpticalView:self.opticalPreviewView];
}

- (void)detachFromOpticalView:(nullable PSOpticalPreviewView *)opticalView {
    PSOpticalPreviewView *target = opticalView ?: self.opticalPreviewView;
    if (!target) {
        return;
    }
    PSRenderSnapshot offSnap;
    memset(&offSnap, 0, sizeof(offSnap));
    offSnap.enabled = NO;
    _hasCachedSnapshot = YES;
    _lastSnapshot = offSnap;
    [target applySnapshot:offSnap];
}

- (void)detachFromPreviewView:(nullable UIView *)previewView {
    (void)previewView;
    [self detachFromOpticalView:self.opticalPreviewView];
}

@end
