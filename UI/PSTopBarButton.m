//
//  PSTopBarButton.m
//  PhotographicStyles12
//
//  Pure CoreGraphics Photographic Styles glyph button (iOS 12 compatible).
//

#import "PSTopBarButton.h"
#import "PSState.h"
#import "PSColorProfile.h"
#import <math.h>

@interface PSTopBarButton ()
@property (nonatomic, assign) BOOL styleEngaged;
- (void)ps12_handleTap;
- (void)ps12_handleLongPress:(UILongPressGestureRecognizer *)gesture;
@end

@implementation PSTopBarButton

- (instancetype)initWithFrame:(CGRect)frame {
    CGRect f = CGRectIsEmpty(frame) ? CGRectMake(0.0, 0.0, 40.0, 32.0) : frame;
    self = [super initWithFrame:f];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.exclusiveTouch = YES;
        self.contentMode = UIViewContentModeRedraw;

        [self addTarget:self
                 action:@selector(ps12_handleTap)
       forControlEvents:UIControlEventTouchUpInside];

        UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(ps12_handleLongPress:)];
        lp.minimumPressDuration = 0.45;
        [self addGestureRecognizer:lp];

        [self syncWithState];
    }
    return self;
}

- (void)setPanelOpen:(BOOL)panelOpen {
    if (_panelOpen != panelOpen) {
        _panelOpen = panelOpen;
        [self setNeedsDisplay];
    }
}

- (void)syncWithState {
    PSRenderSnapshot snap = [[PSState shared] snapshot];
    PSResolvedParameters params = PSResolveParameters(snap);
    BOOL engaged = snap.enabled && !params.isIdentity;
    if (_styleEngaged != engaged) {
        _styleEngaged = engaged;
    }
    [self setNeedsDisplay];
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.68 : 1.0;
}

- (void)ps12_handleTap {
    [self.delegate topBarButtonDidTap:self];
}

- (void)ps12_handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) {
        return;
    }

    [UIView animateWithDuration:0.10 animations:^{
        self.transform = CGAffineTransformMakeScale(0.88, 0.88);
    } completion:^(BOOL finished) {
        (void)finished;
        [UIView animateWithDuration:0.14 animations:^{
            self.transform = CGAffineTransformIdentity;
        }];
    }];

    [self.delegate topBarButtonDidLongPressToggle:self];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) {
        return;
    }
    CGFloat rw = CGRectGetWidth(rect);
    CGFloat rh = CGRectGetHeight(rect);
    if (!isfinite(rw) || rw <= 2.0 || !isfinite(rh) || rh <= 2.0) {
        return;
    }

    CGRect bounds = CGRectInset(rect, 0.5, 0.5);
    CGFloat radius = CGRectGetHeight(bounds) * 0.5;

    UIColor *accent = self.styleEngaged
        ? [UIColor colorWithRed:1.0 green:0.84 blue:0.04 alpha:1.0]
        : [UIColor colorWithWhite:1.0 alpha:0.92];

    UIBezierPath *bgPath = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:radius];
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.06 alpha:self.panelOpen ? 0.80 : 0.55].CGColor);
    CGContextAddPath(ctx, bgPath.CGPath);
    CGContextFillPath(ctx);

    UIColor *borderColor = self.styleEngaged
        ? [UIColor colorWithRed:1.0 green:0.84 blue:0.04 alpha:0.65]
        : [UIColor colorWithWhite:1.0 alpha:self.panelOpen ? 0.45 : 0.22];
    CGContextSetStrokeColorWithColor(ctx, borderColor.CGColor);
    CGContextSetLineWidth(ctx, 1.0);
    CGContextAddPath(ctx, bgPath.CGPath);
    CGContextStrokePath(ctx);

    // Signature iPhone 16 Photographic Styles glyph: rounded square frame + 3x3 dot grid + center puck
    CGFloat glyphSize = 16.0;
    CGRect glyphRect = CGRectMake(
        CGRectGetMidX(rect) - glyphSize * 0.5,
        CGRectGetMidY(rect) - glyphSize * 0.5,
        glyphSize,
        glyphSize
    );
    UIBezierPath *framePath = [UIBezierPath bezierPathWithRoundedRect:glyphRect cornerRadius:4.0];
    CGContextSetStrokeColorWithColor(ctx, accent.CGColor);
    CGContextSetLineWidth(ctx, 1.25);
    CGContextAddPath(ctx, framePath.CGPath);
    CGContextStrokePath(ctx);

    CGContextSetFillColorWithColor(ctx, accent.CGColor);
    CGFloat step = 3.8;
    CGFloat cx = CGRectGetMidX(glyphRect);
    CGFloat cy = CGRectGetMidY(glyphRect);
    for (NSInteger row = -1; row <= 1; row++) {
        for (NSInteger col = -1; col <= 1; col++) {
            CGFloat px = cx + (CGFloat)col * step;
            CGFloat py = cy + (CGFloat)row * step;
            CGFloat r = (row == 0 && col == 0) ? 1.75 : 0.90;
            CGContextFillEllipseInRect(ctx, CGRectMake(px - r, py - r, r * 2.0, r * 2.0));
        }
    }
}

@end
