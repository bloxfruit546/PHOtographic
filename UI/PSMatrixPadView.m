//
//  PSMatrixPadView.m
//  PhotographicStyles12
//
//  11x11 Gaussian dot matrix + 4 corner radial glows + 24pt puck in CoreGraphics.
//

#import "PSMatrixPadView.h"
#import "PSColorProfile.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static const CGFloat kPS12PadCornerRadius = 22.0;
static const CGFloat kPS12PadInset        = 16.0;
static const CGFloat kPS12PuckDiameter    = 24.0;
static const NSInteger kPS12GridDimension = 11;

static inline float PS12PadClamp(float v, float lo, float hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

@interface PSMatrixPadView () <UIGestureRecognizerDelegate> {
    float _topLeftRGB[3];
    float _topRightRGB[3];
    float _bottomLeftRGB[3];
    float _bottomRightRGB[3];
    float _lastSignX;
    float _lastSignY;
}
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
@property (nonatomic, strong) UITapGestureRecognizer *doubleTapGesture;
@property (nonatomic, strong, nullable) UIImpactFeedbackGenerator *haptics;

- (void)ps12_commonInit;
- (CGPoint)ps12_puckCenterForColor:(float)color tone:(float)tone;
- (void)ps12_applyTouchLocation:(CGPoint)loc finished:(BOOL)finished;
- (void)ps12_handlePan:(UIPanGestureRecognizer *)gesture;
- (void)ps12_handleDoubleTap:(UITapGestureRecognizer *)gesture;
- (void)ps12_drawRadialCornerInContext:(CGContextRef)ctx
                                   rgb:(const float[3])rgb
                                 alpha:(CGFloat)alpha
                                center:(CGPoint)center
                                radius:(CGFloat)radius;
@end

@implementation PSMatrixPadView

- (instancetype)initWithFrame:(CGRect)frame {
    CGRect f = CGRectIsEmpty(frame) ? CGRectMake(0.0, 0.0, 136.0, 136.0) : frame;
    self = [super initWithFrame:f];
    if (self) {
        [self ps12_commonInit];
    }
    return self;
}

- (void)ps12_commonInit {
    _color = 0.0f;
    _tone = 0.0f;
    _palette = 0.5f;
    _lastSignX = 0.0f;
    _lastSignY = 0.0f;

    [self configureForPresetIndex:0];

    self.backgroundColor = [UIColor colorWithWhite:0.07 alpha:0.72];
    self.opaque = NO;
    self.exclusiveTouch = YES;
    self.contentMode = UIViewContentModeRedraw;
    self.layer.cornerRadius = kPS12PadCornerRadius;
    self.layer.masksToBounds = YES;
    self.layer.borderWidth = 1.0;
    self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;

    if (NSClassFromString(@"UIImpactFeedbackGenerator")) {
        _haptics = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [_haptics prepare];
    }

    _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(ps12_handlePan:)];
    _panGesture.minimumNumberOfTouches = 1;
    _panGesture.maximumNumberOfTouches = 1;
    _panGesture.cancelsTouchesInView = NO;
    _panGesture.delegate = self;
    [self addGestureRecognizer:_panGesture];

    _doubleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(ps12_handleDoubleTap:)];
    _doubleTapGesture.numberOfTapsRequired = 2;
    _doubleTapGesture.delegate = self;
    [self addGestureRecognizer:_doubleTapGesture];
}

- (void)configureForPresetIndex:(NSInteger)presetIndex {
    const PSPresetDefinition *def = PSGetPresetDefinition(presetIndex);
    if (!def) {
        return;
    }
    for (int i = 0; i < 3; i++) {
        _topLeftRGB[i] = def->topLeftRGB[i];
        _topRightRGB[i] = def->topRightRGB[i];
        _bottomLeftRGB[i] = def->bottomLeftRGB[i];
        _bottomRightRGB[i] = def->bottomRightRGB[i];
    }
    [self setNeedsDisplay];
}

- (void)setColor:(float)color tone:(float)tone palette:(float)palette {
    _color = PS12PadClamp(color, -1.0f, 1.0f);
    _tone = PS12PadClamp(tone, -1.0f, 1.0f);
    _palette = PS12PadClamp(palette, 0.0f, 1.0f);
    [self setNeedsDisplay];
}

- (CGPoint)ps12_puckCenterForColor:(float)color tone:(float)tone {
    CGFloat w = CGRectGetWidth(self.bounds);
    CGFloat h = CGRectGetHeight(self.bounds);
    CGFloat usableW = MAX(1.0, w - kPS12PadInset * 2.0);
    CGFloat usableH = MAX(1.0, h - kPS12PadInset * 2.0);

    CGFloat nx = (CGFloat)((PS12PadClamp(color, -1.0f, 1.0f) + 1.0f) * 0.5f);
    CGFloat ny = (CGFloat)((1.0f - PS12PadClamp(tone, -1.0f, 1.0f)) * 0.5f);

    return CGPointMake(kPS12PadInset + nx * usableW, kPS12PadInset + ny * usableH);
}

- (void)ps12_applyTouchLocation:(CGPoint)loc finished:(BOOL)finished {
    CGFloat w = CGRectGetWidth(self.bounds);
    CGFloat h = CGRectGetHeight(self.bounds);
    CGFloat usableW = MAX(1.0, w - kPS12PadInset * 2.0);
    CGFloat usableH = MAX(1.0, h - kPS12PadInset * 2.0);

    float nx = (float)((loc.x - kPS12PadInset) / usableW);
    float ny = (float)((loc.y - kPS12PadInset) / usableH);
    nx = PS12PadClamp(nx, 0.0f, 1.0f);
    ny = PS12PadClamp(ny, 0.0f, 1.0f);

    float newColor = nx * 2.0f - 1.0f;
    float newTone = 1.0f - ny * 2.0f;

    // Subtle magnetic detent near zero-crossings
    if (fabsf(newColor) < 0.03f) newColor = 0.0f;
    if (fabsf(newTone) < 0.03f) newTone = 0.0f;

    float sx = (newColor > 0.0f) ? 1.0f : (newColor < 0.0f ? -1.0f : 0.0f);
    float sy = (newTone > 0.0f) ? 1.0f : (newTone < 0.0f ? -1.0f : 0.0f);
    if (_haptics && ((sx == 0.0f && _lastSignX != 0.0f) || (sy == 0.0f && _lastSignY != 0.0f))) {
        [_haptics impactOccurred];
    }
    _lastSignX = sx;
    _lastSignY = sy;

    _color = newColor;
    _tone = newTone;
    [self setNeedsDisplay];

    [self.delegate matrixPadView:self
                  didChangeColor:_color
                            tone:_tone
                      isFinished:finished];
}

#pragma mark - Gesture Isolation

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.panGesture || gestureRecognizer == self.doubleTapGesture) {
        return YES;
    }
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    (void)gestureRecognizer;
    (void)otherGestureRecognizer;
    return NO;
}

- (void)ps12_handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint loc = [gesture locationInView:self];
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged:
            [self ps12_applyTouchLocation:loc finished:NO];
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            [self ps12_applyTouchLocation:loc finished:YES];
            break;
        default:
            break;
    }
}

- (void)ps12_handleDoubleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) {
        if (_haptics) {
            [_haptics impactOccurred];
        }
        [self.delegate matrixPadViewDidRequestDoubleTapReset:self];
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    UITouch *touch = [touches anyObject];
    if (touch) {
        [self ps12_applyTouchLocation:[touch locationInView:self] finished:NO];
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    UITouch *touch = [touches anyObject];
    if (touch) {
        [self ps12_applyTouchLocation:[touch locationInView:self] finished:NO];
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    UITouch *touch = [touches anyObject];
    if (touch) {
        [self ps12_applyTouchLocation:[touch locationInView:self] finished:YES];
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    UITouch *touch = [touches anyObject];
    if (touch) {
        [self ps12_applyTouchLocation:[touch locationInView:self] finished:YES];
    }
}

#pragma mark - CoreGraphics Rendering

- (void)ps12_drawRadialCornerInContext:(CGContextRef)ctx
                                   rgb:(const float[3])rgb
                                 alpha:(CGFloat)alpha
                                center:(CGPoint)center
                                radius:(CGFloat)radius {
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    if (!cs) {
        return;
    }
    CGFloat components[8] = {
        rgb[0], rgb[1], rgb[2], alpha,
        rgb[0], rgb[1], rgb[2], 0.0
    };
    CGFloat locations[2] = { 0.0, 1.0 };
    CGGradientRef grad = CGGradientCreateWithColorComponents(cs, components, locations, 2);
    if (grad) {
        CGContextDrawRadialGradient(ctx, grad, center, 0.0, center, radius, kCGGradientDrawsAfterEndLocation);
        CGGradientRelease(grad);
    }
    CGColorSpaceRelease(cs);
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) {
        return;
    }

    CGFloat w = CGRectGetWidth(rect);
    CGFloat h = CGRectGetHeight(rect);
    CGFloat glowRadius = MAX(w, h) * 0.72;
    CGFloat glowAlpha = (CGFloat)(0.35f + 0.65f * _palette) * 0.42;

    [self ps12_drawRadialCornerInContext:ctx rgb:_topLeftRGB alpha:glowAlpha center:CGPointMake(0.0, 0.0) radius:glowRadius];
    [self ps12_drawRadialCornerInContext:ctx rgb:_topRightRGB alpha:glowAlpha center:CGPointMake(w, 0.0) radius:glowRadius];
    [self ps12_drawRadialCornerInContext:ctx rgb:_bottomLeftRGB alpha:glowAlpha center:CGPointMake(0.0, h) radius:glowRadius];
    [self ps12_drawRadialCornerInContext:ctx rgb:_bottomRightRGB alpha:glowAlpha center:CGPointMake(w, h) radius:glowRadius];

    // Subtle center crosshair lines
    CGFloat midX = w * 0.5;
    CGFloat midY = h * 0.5;
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.10].CGColor);
    CGContextSetLineWidth(ctx, 0.75);
    CGContextMoveToPoint(ctx, kPS12PadInset, midY);
    CGContextAddLineToPoint(ctx, w - kPS12PadInset, midY);
    CGContextMoveToPoint(ctx, midX, kPS12PadInset);
    CGContextAddLineToPoint(ctx, midX, h - kPS12PadInset);
    CGContextStrokePath(ctx);

    // 11 x 11 dot lattice with Gaussian proximity glow around puck
    CGPoint puck = [self ps12_puckCenterForColor:_color tone:_tone];
    CGFloat usableW = MAX(1.0, w - kPS12PadInset * 2.0);
    CGFloat usableH = MAX(1.0, h - kPS12PadInset * 2.0);
    CGFloat sigmaSq = 2.0 * 22.0 * 22.0;

    for (NSInteger row = 0; row < kPS12GridDimension; row++) {
        CGFloat ty = (CGFloat)row / (CGFloat)(kPS12GridDimension - 1);
        CGFloat py = kPS12PadInset + ty * usableH;
        for (NSInteger col = 0; col < kPS12GridDimension; col++) {
            CGFloat tx = (CGFloat)col / (CGFloat)(kPS12GridDimension - 1);
            CGFloat px = kPS12PadInset + tx * usableW;

            CGFloat dx = px - puck.x;
            CGFloat dy = py - puck.y;
            CGFloat distSq = dx * dx + dy * dy;
            CGFloat gauss = exp(-distSq / sigmaSq);

            CGFloat dotRadius = 0.85 + gauss * 1.15;
            CGFloat dotAlpha = 0.24 + gauss * 0.66;

            CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:dotAlpha].CGColor);
            CGContextFillEllipseInRect(ctx, CGRectMake(px - dotRadius, py - dotRadius, dotRadius * 2.0, dotRadius * 2.0));
        }
    }

    // 24 x 24 pt puck
    CGRect puckRect = CGRectMake(
        puck.x - kPS12PuckDiameter * 0.5,
        puck.y - kPS12PuckDiameter * 0.5,
        kPS12PuckDiameter,
        kPS12PuckDiameter
    );
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.22].CGColor);
    CGContextFillEllipseInRect(ctx, puckRect);

    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.96].CGColor);
    CGContextSetLineWidth(ctx, 2.0);
    CGContextStrokeEllipseInRect(ctx, CGRectInset(puckRect, 1.0, 1.0));

    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextFillEllipseInRect(ctx, CGRectMake(puck.x - 2.0, puck.y - 2.0, 4.0, 4.0));
}

@end
