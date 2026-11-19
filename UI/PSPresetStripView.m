//
//  PSPresetStripView.m
//  PhotographicStyles12
//
//  15-preset capsule carousel with CoreGraphics dual-tone dot swatches.
//

#import "PSPresetStripView.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

@interface PSPresetSwatchView : UIView {
    float _shadowRGB[3];
    float _highlightRGB[3];
}
- (void)setShadowRGB:(const float[3])shadow highlightRGB:(const float[3])highlight;
@end

@implementation PSPresetSwatchView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (void)setShadowRGB:(const float[3])shadow highlightRGB:(const float[3])highlight {
    for (int i = 0; i < 3; i++) {
        _shadowRGB[i] = shadow[i];
        _highlightRGB[i] = highlight[i];
    }
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) {
        return;
    }

    CGRect circle = CGRectInset(rect, 0.5, 0.5);
    CGContextSaveGState(ctx);
    CGContextAddEllipseInRect(ctx, circle);
    CGContextClip(ctx);

    CGContextSetRGBFillColor(ctx, _shadowRGB[0], _shadowRGB[1], _shadowRGB[2], 1.0);
    CGContextFillRect(ctx, CGRectMake(0.0, 0.0, CGRectGetWidth(rect) * 0.5, CGRectGetHeight(rect)));

    CGContextSetRGBFillColor(ctx, _highlightRGB[0], _highlightRGB[1], _highlightRGB[2], 1.0);
    CGContextFillRect(ctx, CGRectMake(CGRectGetWidth(rect) * 0.5, 0.0, CGRectGetWidth(rect) * 0.5, CGRectGetHeight(rect)));

    CGContextRestoreGState(ctx);
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.35].CGColor);
    CGContextSetLineWidth(ctx, 0.75);
    CGContextStrokeEllipseInRect(ctx, circle);
}

@end

#pragma mark - PSPresetStripView

@interface PSPresetStripView () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *dividerView;
@property (nonatomic, strong) NSMutableArray<UIButton *> *chipButtons;

- (void)ps12_buildChips;
- (void)ps12_layoutChips;
- (void)ps12_updateSelectionAppearance;
- (void)ps12_scrollChipToCenter:(NSInteger)index animated:(BOOL)animated;
- (void)ps12_chipTapped:(UIButton *)sender;
@end

@implementation PSPresetStripView

- (instancetype)initWithFrame:(CGRect)frame {
    BOOL invalidFrame = CGRectIsEmpty(frame) ||
                        !isfinite(frame.size.width) || !isfinite(frame.size.height) ||
                        frame.size.width <= 0.0 || frame.size.height <= 0.0;
    CGRect f = invalidFrame ? CGRectMake(0.0, 0.0, 290.0, 34.0) : frame;
    self = [super initWithFrame:f];
    if (self) {
        _selectedPresetIndex = 0;
        _chipButtons = [NSMutableArray arrayWithCapacity:PSColorPresetCount];
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.exclusiveTouch = YES;

        _scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.decelerationRate = UIScrollViewDecelerationRateFast;
        _scrollView.alwaysBounceHorizontal = YES;
        _scrollView.exclusiveTouch = YES;
        [self addSubview:_scrollView];

        _dividerView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 1.0, 16.0)];
        _dividerView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.22];
        [_scrollView addSubview:_dividerView];

        [self ps12_buildChips];
        [self ps12_updateSelectionAppearance];
    }
    return self;
}

- (void)ps12_buildChips {
    for (NSInteger i = 0; i < PSColorPresetCount; i++) {
        const PSPresetDefinition *def = PSGetPresetDefinition(i);
        NSString *title = PSPresetDisplayName(i);

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = i;
        btn.layer.cornerRadius = 13.0;
        btn.layer.masksToBounds = YES;
        btn.layer.borderWidth = 1.0;
        btn.exclusiveTouch = YES;
        btn.contentEdgeInsets = UIEdgeInsetsMake(0.0, 22.0, 0.0, 10.0);

        UIFont *chipFont = [UIFont systemFontOfSize:10.0 weight:UIFontWeightBold] ?: [UIFont boldSystemFontOfSize:10.0];
        NSAttributedString *attrTitle = [[NSAttributedString alloc]
            initWithString:(title ?: @"")
                attributes:@{
                    NSFontAttributeName : chipFont,
                    NSKernAttributeName : @0.5,
                    NSForegroundColorAttributeName : [UIColor colorWithWhite:0.95 alpha:0.90]
                }];
        [btn setAttributedTitle:attrTitle forState:UIControlStateNormal];

        PSPresetSwatchView *swatch = [[PSPresetSwatchView alloc] initWithFrame:CGRectMake(7.0, 7.0, 12.0, 12.0)];
        if (def) {
            [swatch setShadowRGB:def->shadowTintRGB highlightRGB:def->highlightTintRGB];
        }
        [btn addSubview:swatch];

        [btn addTarget:self
                action:@selector(ps12_chipTapped:)
      forControlEvents:UIControlEventTouchUpInside];

        [_scrollView addSubview:btn];
        [_chipButtons addObject:btn];
    }
}

- (void)ps12_layoutChips {
    CGFloat w = CGRectGetWidth(self.bounds);
    CGFloat h = CGRectGetHeight(self.bounds);
    if (!isfinite(w) || w <= 0.0 || !isfinite(h) || h <= 0.0) {
        return;
    }
    CGFloat chipH = 26.0;
    CGFloat chipY = (h - chipH) * 0.5;
    CGFloat x = 4.0;
    CGFloat spacing = 6.0;

    for (NSInteger i = 0; i < (NSInteger)self.chipButtons.count; i++) {
        if (i == PSColorUndertoneCount) {
            self.dividerView.frame = CGRectMake(x + 1.0, (h - 16.0) * 0.5, 1.0, 16.0);
            x += 9.0;
        }
        UIButton *btn = self.chipButtons[(NSUInteger)i];
        [btn sizeToFit];
        CGFloat chipW = MAX(62.0, CGRectGetWidth(btn.bounds));
        btn.frame = CGRectMake(x, chipY, chipW, chipH);
        x += chipW + spacing;
    }

    self.scrollView.frame = self.bounds;
    self.scrollView.contentSize = CGSizeMake(x + 4.0, h);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self ps12_layoutChips];
}

- (void)setSelectedPresetIndex:(NSInteger)selectedPresetIndex {
    [self setSelectedPresetIndex:selectedPresetIndex animated:NO];
}

- (void)setSelectedPresetIndex:(NSInteger)selectedPresetIndex animated:(BOOL)animated {
    NSInteger clamped = (selectedPresetIndex < 0) ? 0 : (selectedPresetIndex >= PSColorPresetCount ? PSColorPresetCount - 1 : selectedPresetIndex);
    _selectedPresetIndex = clamped;
    [self ps12_updateSelectionAppearance];
    [self ps12_scrollChipToCenter:clamped animated:animated];
}

- (void)scrollToCategory:(PSStyleCategory)category animated:(BOOL)animated {
    NSInteger targetIndex = (category == PSStyleCategoryUndertones) ? 0 : PSColorUndertoneCount;
    [self ps12_scrollChipToCenter:targetIndex animated:animated];
}

- (void)ps12_updateSelectionAppearance {
    UIColor *yellow = [UIColor colorWithRed:1.0 green:0.84 blue:0.04 alpha:1.0];
    UIColor *normalText = [UIColor colorWithWhite:0.92 alpha:0.85];

    for (NSInteger i = 0; i < (NSInteger)self.chipButtons.count; i++) {
        UIButton *btn = self.chipButtons[(NSUInteger)i];
        BOOL selected = (i == _selectedPresetIndex);

        btn.backgroundColor = selected
            ? [UIColor colorWithRed:1.0 green:0.84 blue:0.04 alpha:0.16]
            : [UIColor colorWithWhite:1.0 alpha:0.08];
        btn.layer.borderColor = selected
            ? yellow.CGColor
            : [UIColor colorWithWhite:1.0 alpha:0.14].CGColor;

        UIFont *chipFont = [UIFont systemFontOfSize:10.0 weight:UIFontWeightBold] ?: [UIFont boldSystemFontOfSize:10.0];
        NSAttributedString *attrTitle = [[NSAttributedString alloc]
            initWithString:(PSPresetDisplayName(i) ?: @"")
                attributes:@{
                    NSFontAttributeName : chipFont,
                    NSKernAttributeName : @0.5,
                    NSForegroundColorAttributeName : selected ? yellow : normalText
                }];
        [btn setAttributedTitle:attrTitle forState:UIControlStateNormal];
    }
}

- (void)ps12_scrollChipToCenter:(NSInteger)index animated:(BOOL)animated {
    if (index < 0 || index >= (NSInteger)self.chipButtons.count) {
        return;
    }
    [self layoutIfNeeded];
    UIButton *btn = self.chipButtons[(NSUInteger)index];
    CGFloat viewW = CGRectGetWidth(self.scrollView.bounds);
    CGFloat contentW = self.scrollView.contentSize.width;
    if (contentW <= viewW || viewW <= 0.0) {
        return;
    }

    CGFloat targetX = CGRectGetMidX(btn.frame) - viewW * 0.5;
    CGFloat maxX = contentW - viewW;
    if (targetX < 0.0) targetX = 0.0;
    if (targetX > maxX) targetX = maxX;
    [self.scrollView setContentOffset:CGPointMake(targetX, 0.0) animated:animated];
}

- (void)ps12_chipTapped:(UIButton *)sender {
    NSInteger idx = sender.tag;
    [self setSelectedPresetIndex:idx animated:YES];
    [self.delegate presetStripView:self didSelectPresetAtIndex:idx];
}

#pragma mark - Gesture Isolation

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return (gestureRecognizer == self.scrollView.panGestureRecognizer);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    (void)gestureRecognizer;
    (void)otherGestureRecognizer;
    return NO;
}

@end
