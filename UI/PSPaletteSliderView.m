//
//  PSPaletteSliderView.m
//  PhotographicStyles12
//
//  CoreGraphics + CAGradientLayer palette slider with gesture isolation.
//

#import "PSPaletteSliderView.h"
#import "PSColorProfile.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static const CGFloat kPS12TrackHeight  = 8.0;
static const CGFloat kPS12ThumbSize    = 20.0;
static const CGFloat kPS12ThumbInset   = 10.0;

static inline float PS12SliderClamp(float v, float lo, float hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

@interface PSPaletteSliderView () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) CAGradientLayer *trackGradientLayer;
@property (nonatomic, strong) CAShapeLayer *thumbLayer;
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;

- (void)ps12_commonInit;
- (void)ps12_updateThumbFrame;
- (void)ps12_applyTouchX:(CGFloat)x finished:(BOOL)finished;
- (void)ps12_handlePan:(UIPanGestureRecognizer *)gesture;
@end

@implementation PSPaletteSliderView

- (instancetype)initWithFrame:(CGRect)frame {
    CGRect f = CGRectIsEmpty(frame) ? CGRectMake(0.0, 0.0, 200.0, 28.0) : frame;
    self = [super initWithFrame:f];
    if (self) {
        [self ps12_commonInit];
    }
    return self;
}

- (void)ps12_commonInit {
    _palette = 0.5f;
    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO;
    self.exclusiveTouch = YES;

    _trackGradientLayer = [CAGradientLayer layer];
    _trackGradientLayer.startPoint = CGPointMake(0.0, 0.5);
    _trackGradientLayer.endPoint = CGPointMake(1.0, 0.5);
    _trackGradientLayer.cornerRadius = kPS12TrackHeight * 0.5;
    _trackGradientLayer.masksToBounds = YES;
    _trackGradientLayer.borderWidth = 0.75;
    _trackGradientLayer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.20].CGColor;
    [self.layer addSublayer:_trackGradientLayer];

    _thumbLayer = [CAShapeLayer layer];
    _thumbLayer.bounds = CGRectMake(0.0, 0.0, kPS12ThumbSize, kPS12ThumbSize);
    _thumbLayer.path = [UIBezierPath bezierPathWithOvalInRect:_thumbLayer.bounds].CGPath;
    _thumbLayer.fillColor = [UIColor whiteColor].CGColor;
    _thumbLayer.strokeColor = [UIColor colorWithWhite:0.0 alpha:0.28].CGColor;
    _thumbLayer.lineWidth = 1.0;
    [self.layer addSublayer:_thumbLayer];

    [self configureForPresetIndex:0];

    _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(ps12_handlePan:)];
    _panGesture.minimumNumberOfTouches = 1;
    _panGesture.maximumNumberOfTouches = 1;
    _panGesture.cancelsTouchesInView = NO;
    _panGesture.delegate = self;
    [self addGestureRecognizer:_panGesture];
}

- (void)setPalette:(float)palette {
    _palette = PS12SliderClamp(palette, 0.0f, 1.0f);
    [self ps12_updateThumbFrame];
}

- (void)configureForPresetIndex:(NSInteger)presetIndex {
    const PSPresetDefinition *def = PSGetPresetDefinition(presetIndex);
    if (!def) {
        return;
    }

    UIColor *leftColor = [UIColor colorWithWhite:0.30 alpha:0.85];
    UIColor *rightColor = [UIColor colorWithRed:(CGFloat)def->topRightRGB[0]
                                          green:(CGFloat)def->topRightRGB[1]
                                           blue:(CGFloat)def->topRightRGB[2]
                                          alpha:0.95];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.trackGradientLayer.colors = @[
        (__bridge id)leftColor.CGColor,
        (__bridge id)rightColor.CGColor
    ];
    [CATransaction commit];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat w = CGRectGetWidth(self.bounds);
    CGFloat h = CGRectGetHeight(self.bounds);
    CGFloat trackW = MAX(1.0, w - kPS12ThumbInset * 2.0);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.trackGradientLayer.frame = CGRectMake(
        kPS12ThumbInset,
        (h - kPS12TrackHeight) * 0.5,
        trackW,
        kPS12TrackHeight
    );
    [CATransaction commit];

    [self ps12_updateThumbFrame];
}

- (void)ps12_updateThumbFrame {
    CGFloat w = CGRectGetWidth(self.bounds);
    CGFloat h = CGRectGetHeight(self.bounds);
    CGFloat usableW = MAX(1.0, w - kPS12ThumbInset * 2.0);
    CGFloat x = kPS12ThumbInset + (CGFloat)_palette * usableW;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.thumbLayer.position = CGPointMake(x, h * 0.5);
    [CATransaction commit];
}

- (void)ps12_applyTouchX:(CGFloat)x finished:(BOOL)finished {
    CGFloat w = CGRectGetWidth(self.bounds);
    CGFloat usableW = MAX(1.0, w - kPS12ThumbInset * 2.0);
    float norm = PS12SliderClamp((float)((x - kPS12ThumbInset) / usableW), 0.0f, 1.0f);

    _palette = norm;
    [self ps12_updateThumbFrame];

    [self.delegate paletteSliderView:self
                    didChangePalette:_palette
                          isFinished:finished];
}

#pragma mark - Gesture Isolation

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return (gestureRecognizer == self.panGesture);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    (void)gestureRecognizer;
    (void)otherGestureRecognizer;
    return NO;
}

- (void)ps12_handlePan:(UIPanGestureRecognizer *)gesture {
    CGFloat x = [gesture locationInView:self].x;
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged:
            [self ps12_applyTouchX:x finished:NO];
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            [self ps12_applyTouchX:x finished:YES];
            break;
        default:
            break;
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    UITouch *touch = [touches anyObject];
    if (touch) {
        [self ps12_applyTouchX:[touch locationInView:self].x finished:NO];
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    UITouch *touch = [touches anyObject];
    if (touch) {
        [self ps12_applyTouchX:[touch locationInView:self].x finished:NO];
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    UITouch *touch = [touches anyObject];
    if (touch) {
        [self ps12_applyTouchX:[touch locationInView:self].x finished:YES];
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    UITouch *touch = [touches anyObject];
    if (touch) {
        [self ps12_applyTouchX:[touch locationInView:self].x finished:YES];
    }
}

@end
