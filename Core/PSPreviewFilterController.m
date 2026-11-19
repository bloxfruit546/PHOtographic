//
//  PSPreviewFilterController.m
//  PhotographicStyles12
//
//  Zero-mediaserverd-intrusion viewfinder preview controller.
//  Drives PSPreviewBackdropView (CABackdropLayer) with strict dirty-checking.
//

#import "PSPreviewFilterController.h"
#import "PSPreviewBackdropView.h"
#import "PSState.h"
#import "PSColorProfile.h"
#import "QuartzCorePrivate.h"
#import <string.h>

@interface PSPreviewFilterController () {
    BOOL _hasCachedState;
    BOOL _lastActive;
    CAColorMatrix _lastAppliedMatrix;
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
        _hasCachedState = NO;
        _lastActive = NO;
        _lastAppliedMatrix = PS12CAColorMatrixIdentity();
    }
    return self;
}

- (void)refreshOnBackdropView:(nullable PSPreviewBackdropView *)backdropView {
    PSPreviewBackdropView *target = backdropView ?: self.backdropView;
    if (!target) {
        return;
    }
    if (backdropView && self.backdropView != backdropView) {
        self.backdropView = backdropView;
    }

    PSState *state = [PSState shared];
    PSRenderSnapshot snap = [state snapshot];
    PSResolvedParameters params = PSResolveParameters(snap);
    BOOL active = snap.enabled && !params.isIdentity;
    CAColorMatrix newMatrix = active ? [state previewMatrixForSnapshot:snap] : PS12CAColorMatrixIdentity();

    if (_hasCachedState && _lastActive == active) {
        if (!active || memcmp(&newMatrix, &_lastAppliedMatrix, sizeof(CAColorMatrix)) == 0) {
            return;
        }
    }

    _hasCachedState = YES;
    _lastActive = active;
    _lastAppliedMatrix = newMatrix;
    [target applyColorMatrix:newMatrix active:active];
}

- (void)refreshOnPreviewView:(nullable UIView *)previewView {
    (void)previewView;
    [self refreshOnBackdropView:self.backdropView];
}

- (void)detachFromBackdropView:(nullable PSPreviewBackdropView *)backdropView {
    PSPreviewBackdropView *target = backdropView ?: self.backdropView;
    if (!target) {
        return;
    }
    _hasCachedState = YES;
    _lastActive = NO;
    _lastAppliedMatrix = PS12CAColorMatrixIdentity();
    [target applyColorMatrix:_lastAppliedMatrix active:NO];
}

- (void)detachFromPreviewView:(nullable UIView *)previewView {
    (void)previewView;
    [self detachFromBackdropView:self.backdropView];
}

@end
