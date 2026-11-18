//
//  PSOverlayPassthroughView.m
//  PhotographicStyles12
//
//  Ergonomic 320x568-compatible overlay hosting PSTopBarButton and
//  PSStyleControlPanel with strict passthrough -hitTest:withEvent:.
//

#import "PSOverlayPassthroughView.h"
#import "PSTopBarButton.h"
#import "PSStyleControlPanel.h"
#import "PSState.h"
#import "PSPreviewFilterController.h"
#import <math.h>

static const CGFloat kPS12TopButtonW = 40.0;
static const CGFloat kPS12TopButtonH = 32.0;
static const CGFloat kPS12PanelMaxW  = 304.0;
static const CGFloat kPS12PanelH     = 252.0;

@interface PSOverlayPassthroughView () <PSTopBarButtonDelegate, PSStyleControlPanelDelegate>
@property (nonatomic, strong) PSTopBarButton *topBarButton;
@property (nonatomic, strong) PSStyleControlPanel *controlPanel;
@property (nonatomic, assign) BOOL panelVisible;

- (void)ps12_setPanelVisible:(BOOL)visible animated:(BOOL)animated;
@end

@implementation PSOverlayPassthroughView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        _topBarButton = [[PSTopBarButton alloc] initWithFrame:CGRectMake(0.0, 0.0, kPS12TopButtonW, kPS12TopButtonH)];
        _topBarButton.delegate = self;
        [self addSubview:_topBarButton];

        _controlPanel = [[PSStyleControlPanel alloc] initWithFrame:CGRectMake(0.0, 0.0, kPS12PanelMaxW, kPS12PanelH)];
        _controlPanel.delegate = self;
        _controlPanel.hidden = YES;
        _controlPanel.alpha = 0.0;
        [self addSubview:_controlPanel];

        _panelVisible = NO;
        [self syncWithState];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat w = CGRectGetWidth(self.bounds);
    CGFloat h = CGRectGetHeight(self.bounds);

    CGFloat topSafe = 0.0;
    CGFloat bottomSafe = 0.0;
    CGFloat rightSafe = 0.0;
    if (@available(iOS 11.0, *)) {
        topSafe = self.safeAreaInsets.top;
        bottomSafe = self.safeAreaInsets.bottom;
        rightSafe = self.safeAreaInsets.right;
    }

    // Top-right safe area, sitting cleanly below stock top flash/HDR bar
    CGFloat btnX = w - kPS12TopButtonW - MAX(rightSafe, 12.0);
    CGFloat btnY = MAX(topSafe, 6.0) + 46.0;
    if (btnX < 8.0) btnX = 8.0;
    self.topBarButton.frame = CGRectMake(btnX, btnY, kPS12TopButtonW, kPS12TopButtonH);

    // Control panel centered horizontally, sitting cleanly above bottom shutter/mode bar (~138pt)
    CGFloat panelW = MIN(kPS12PanelMaxW, MAX(260.0, w - 16.0));
    CGFloat panelX = (w - panelW) * 0.5;
    CGFloat bottomBarReserve = 138.0 + bottomSafe;
    CGFloat panelY = h - bottomBarReserve - kPS12PanelH;
    CGFloat minTopY = CGRectGetMaxY(self.topBarButton.frame) + 8.0;
    if (panelY < minTopY) {
        panelY = minTopY;
    }

    self.controlPanel.frame = CGRectMake(panelX, panelY, panelW, kPS12PanelH);
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
    if (!self.controlPanel.hidden) {
        [self.controlPanel syncWithStateAnimated:NO];
    }
}

- (void)ps12_setPanelVisible:(BOOL)visible animated:(BOOL)animated {
    _panelVisible = visible;
    self.topBarButton.panelOpen = visible;

    if (visible) {
        [self.controlPanel syncWithStateAnimated:NO];
        self.controlPanel.hidden = NO;
        if (animated) {
            self.controlPanel.alpha = 0.0;
            self.controlPanel.transform = CGAffineTransformMakeTranslation(0.0, 14.0);
            [UIView animateWithDuration:0.22
                                  delay:0.0
                 usingSpringWithDamping:0.86
                  initialSpringVelocity:0.4
                                options:UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                self.controlPanel.alpha = 1.0;
                self.controlPanel.transform = CGAffineTransformIdentity;
            } completion:nil];
        } else {
            self.controlPanel.alpha = 1.0;
            self.controlPanel.transform = CGAffineTransformIdentity;
        }
    } else {
        if (animated) {
            [UIView animateWithDuration:0.16 animations:^{
                self.controlPanel.alpha = 0.0;
                self.controlPanel.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
            } completion:^(BOOL finished) {
                (void)finished;
                if (!self.panelVisible) {
                    self.controlPanel.hidden = YES;
                    self.controlPanel.transform = CGAffineTransformIdentity;
                }
            }];
        } else {
            self.controlPanel.alpha = 0.0;
            self.controlPanel.hidden = YES;
            self.controlPanel.transform = CGAffineTransformIdentity;
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
    [[PSPreviewFilterController shared] refreshOnPreviewView:self.targetPreviewView];
}

#pragma mark - PSStyleControlPanelDelegate

- (void)styleControlPanelDidChangeRenderState:(PSStyleControlPanel *)panel {
    (void)panel;
    [self.topBarButton syncWithState];
    [[PSPreviewFilterController shared] refreshOnPreviewView:self.targetPreviewView];
}

- (void)styleControlPanelDidRequestCollapse:(PSStyleControlPanel *)panel {
    (void)panel;
    [self ps12_setPanelVisible:NO animated:YES];
}

@end
