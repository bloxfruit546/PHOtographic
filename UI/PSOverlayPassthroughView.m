//
//  PSOverlayPassthroughView.m
//  PhotographicStyles12
//
//  Ergonomic 320x568-compatible overlay hosting PSTopBarButton and
//  PSStyleControlPanel with strict passthrough -hitTest:withEvent:.
//

#import "PSOverlayPassthroughView.h"
#import "PSPreviewBackdropView.h"
#import "PSTopBarButton.h"
#import "PSStyleControlPanel.h"
#import "PSState.h"
#import "PSPreviewFilterController.h"
#import "PSDiagnostics.h"
#import <math.h>

static const CGFloat kPS12TopButtonW = 40.0;
static const CGFloat kPS12TopButtonH = 32.0;
static const CGFloat kPS12PanelMaxW  = 304.0;
static const CGFloat kPS12PanelH     = 252.0;

@interface PSOverlayPassthroughView () <PSTopBarButtonDelegate, PSStyleControlPanelDelegate>
@property (nonatomic, strong, readwrite) PSPreviewBackdropView *backdropView;
@property (nonatomic, strong) PSTopBarButton *topBarButton;
@property (nonatomic, strong, nullable) PSStyleControlPanel *controlPanel;
@property (nonatomic, assign) BOOL panelVisible;

- (CGRect)ps12_panelFrameForBounds:(CGRect)bounds;
- (nullable PSStyleControlPanel *)ps12_ensureControlPanelLoaded;
- (void)ps12_setPanelVisible:(BOOL)visible animated:(BOOL)animated;
@end

@implementation PSOverlayPassthroughView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        _backdropView = [[PSPreviewBackdropView alloc] initWithFrame:self.bounds];
        [self insertSubview:_backdropView atIndex:0];
        [PSPreviewFilterController shared].backdropView = _backdropView;

        _topBarButton = [[PSTopBarButton alloc] initWithFrame:CGRectMake(0.0, 0.0, kPS12TopButtonW, kPS12TopButtonH)];
        _topBarButton.delegate = self;
        [self addSubview:_topBarButton];

        _controlPanel = nil;
        _panelVisible = NO;
        [self syncWithState];
    }
    return self;
}

- (CGRect)ps12_panelFrameForBounds:(CGRect)bounds {
    CGFloat w = CGRectGetWidth(bounds);
    CGFloat h = CGRectGetHeight(bounds);
    if (!isfinite(w) || w <= 0.0 || !isfinite(h) || h <= 0.0) {
        return CGRectMake(8.0, 100.0, kPS12PanelMaxW, kPS12PanelH);
    }

    CGFloat bottomSafe = 0.0;
    if (@available(iOS 11.0, *)) {
        bottomSafe = self.safeAreaInsets.bottom;
    }

    CGFloat panelW = MIN(kPS12PanelMaxW, MAX(260.0, w - 16.0));
    CGFloat panelX = (w - panelW) * 0.5;
    CGFloat bottomBarReserve = 138.0 + bottomSafe;
    CGFloat panelY = h - bottomBarReserve - kPS12PanelH;
    CGFloat minTopY = CGRectGetMaxY(self.topBarButton.frame) + 8.0;
    if (panelY < minTopY) {
        panelY = minTopY;
    }
    return CGRectMake(panelX, panelY, panelW, kPS12PanelH);
}

- (nullable PSStyleControlPanel *)ps12_ensureControlPanelLoaded {
    if (_controlPanel) {
        return _controlPanel;
    }
    @try {
        CGRect panelFrame = [self ps12_panelFrameForBounds:self.bounds];
        PSStyleControlPanel *panel = [[PSStyleControlPanel alloc] initWithFrame:panelFrame];
        panel.delegate = self;
        panel.hidden = YES;
        panel.alpha = 0.0;
        [self addSubview:panel];
        _controlPanel = panel;
        return _controlPanel;
    } @catch (NSException *exception) {
        PS12LogException(@"PSOverlayPassthroughView.ensureControlPanelLoaded", exception);
        return nil;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat w = CGRectGetWidth(self.bounds);
    CGFloat h = CGRectGetHeight(self.bounds);
    if (!isfinite(w) || w <= 0.0 || !isfinite(h) || h <= 0.0) {
        return;
    }

    CGRect backdropFrame = self.bounds;
    UIView *preview = self.targetPreviewView;
    if (preview && preview.window && self.window && preview.window == self.window) {
        CGRect converted = [self convertRect:preview.bounds fromView:preview];
        if (!CGRectIsEmpty(converted) &&
            isfinite(converted.origin.x) && isfinite(converted.origin.y) &&
            isfinite(converted.size.width) && isfinite(converted.size.height) &&
            converted.size.width > 0.0 && converted.size.height > 0.0) {
            backdropFrame = converted;
        }
    }
    self.backdropView.frame = backdropFrame;
    if (self.backdropView.superview == self) {
        [self sendSubviewToBack:self.backdropView];
    }

    CGFloat topSafe = 0.0;
    CGFloat rightSafe = 0.0;
    if (@available(iOS 11.0, *)) {
        topSafe = self.safeAreaInsets.top;
        rightSafe = self.safeAreaInsets.right;
    }

    // Top-right safe area, sitting cleanly below stock top flash/HDR bar
    CGFloat btnX = w - kPS12TopButtonW - MAX(rightSafe, 12.0);
    CGFloat btnY = MAX(topSafe, 6.0) + 46.0;
    if (btnX < 8.0) btnX = 8.0;
    self.topBarButton.frame = CGRectMake(btnX, btnY, kPS12TopButtonW, kPS12TopButtonH);

    if (self.controlPanel) {
        self.controlPanel.frame = [self ps12_panelFrameForBounds:self.bounds];
    }
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self) {
        return nil;
    }
    return hit;
}

- (void)syncWithState {
    [self.topBarButton syncWithState];
    if (self.controlPanel && !self.controlPanel.hidden) {
        [self.controlPanel syncWithStateAnimated:NO];
    }
}

- (void)ps12_setPanelVisible:(BOOL)visible animated:(BOOL)animated {
    if (visible) {
        PSStyleControlPanel *panel = [self ps12_ensureControlPanelLoaded];
        if (!panel) {
            _panelVisible = NO;
            self.topBarButton.panelOpen = NO;
            return;
        }
        _panelVisible = YES;
        self.topBarButton.panelOpen = YES;
        [panel syncWithStateAnimated:NO];
        panel.hidden = NO;
        if (animated) {
            panel.alpha = 0.0;
            panel.transform = CGAffineTransformMakeTranslation(0.0, 14.0);
            [UIView animateWithDuration:0.22
                                  delay:0.0
                 usingSpringWithDamping:0.86
                  initialSpringVelocity:0.4
                                options:UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                panel.alpha = 1.0;
                panel.transform = CGAffineTransformIdentity;
            } completion:nil];
        } else {
            panel.alpha = 1.0;
            panel.transform = CGAffineTransformIdentity;
        }
    } else {
        _panelVisible = NO;
        self.topBarButton.panelOpen = NO;
        PSStyleControlPanel *panel = self.controlPanel;
        if (!panel) {
            return;
        }
        if (animated) {
            [UIView animateWithDuration:0.16 animations:^{
                panel.alpha = 0.0;
                panel.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
            } completion:^(BOOL finished) {
                (void)finished;
                if (!self.panelVisible) {
                    panel.hidden = YES;
                    panel.transform = CGAffineTransformIdentity;
                }
            }];
        } else {
            panel.alpha = 0.0;
            panel.hidden = YES;
            panel.transform = CGAffineTransformIdentity;
        }
    }
}

#pragma mark - PSTopBarButtonDelegate

- (void)topBarButtonDidTap:(PSTopBarButton *)button {
    (void)button;
    [self ps12_setPanelVisible:!self.panelVisible animated:YES];
}

- (void)topBarButtonDidLongPressToggle:(PSTopBarButton *)button {
    (void)button;
    PSState *state = [PSState shared];
    BOOL nextEnabled = ![state isEnabled];
    if (nextEnabled && state.presetIndex == 0 && fabsf(state.tone) < 1e-5f && fabsf(state.color) < 1e-5f) {
        [state selectPresetAtIndex:1 resetToPresetDefaults:YES];
    } else {
        state.enabled = nextEnabled;
    }
    [state saveNow];

    [self syncWithState];
    [[PSPreviewFilterController shared] refreshOnBackdropView:self.backdropView];
}

#pragma mark - PSStyleControlPanelDelegate

- (void)styleControlPanelDidChangeRenderState:(PSStyleControlPanel *)panel {
    (void)panel;
    [self.topBarButton syncWithState];
    [[PSPreviewFilterController shared] refreshOnBackdropView:self.backdropView];
}

- (void)styleControlPanelDidRequestCollapse:(PSStyleControlPanel *)panel {
    (void)panel;
    [self ps12_setPanelVisible:NO animated:YES];
}

@end
