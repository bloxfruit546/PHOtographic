//
//  PSStyleControlPanel.m
//  PhotographicStyles12
//
//  Compact 304 x 252 pt CoreGraphics control card for iOS 12 Camera.
//

#import "PSStyleControlPanel.h"
#import "PSState.h"
#import "PSColorProfile.h"
#import "PSCaptureCoordinator.h"
#import "PSMatrixPadView.h"
#import "PSPaletteSliderView.h"
#import "PSPresetStripView.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

typedef NS_ENUM(NSInteger, PSGlyphKind) {
    PSGlyphKindReset = 0,
    PSGlyphKindChevronDown = 1
};

@interface PSGlyphButton : UIButton
@property (nonatomic, assign) PSGlyphKind glyphKind;
@end

@implementation PSGlyphButton

- (instancetype)initWithKind:(PSGlyphKind)kind {
    self = [super initWithFrame:CGRectMake(0.0, 0.0, 26.0, 24.0)];
    if (self) {
        _glyphKind = kind;
        self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
        self.layer.cornerRadius = 12.0;
        self.layer.masksToBounds = YES;
        self.exclusiveTouch = YES;
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.55 : 1.0;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) {
        return;
    }

    CGFloat cx = CGRectGetMidX(rect);
    CGFloat cy = CGRectGetMidY(rect);
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.90].CGColor);
    CGContextSetLineWidth(ctx, 1.5);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);

    if (self.glyphKind == PSGlyphKindReset) {
        CGFloat r = 5.2;
        CGContextAddArc(ctx, cx, cy, r, (CGFloat)(-M_PI * 0.75), (CGFloat)(M_PI * 0.85), 0);
        CGContextStrokePath(ctx);

        // Arrowhead at top-left of arc
        CGFloat ax = cx - r * 0.72;
        CGFloat ay = cy - r * 0.72;
        CGContextMoveToPoint(ctx, ax - 2.6, ay + 0.5);
        CGContextAddLineToPoint(ctx, ax, ay);
        CGContextAddLineToPoint(ctx, ax + 0.8, ay + 2.8);
        CGContextStrokePath(ctx);
    } else {
        CGContextMoveToPoint(ctx, cx - 4.5, cy - 1.8);
        CGContextAddLineToPoint(ctx, cx, cy + 2.4);
        CGContextAddLineToPoint(ctx, cx + 4.5, cy - 1.8);
        CGContextStrokePath(ctx);
    }
}

@end

#pragma mark - PSStyleControlPanel

@interface PSStyleControlPanel () <
    PSMatrixPadViewDelegate,
    PSPaletteSliderViewDelegate,
    PSPresetStripViewDelegate,
    UIGestureRecognizerDelegate
>
@property (nonatomic, strong) UIButton *categoryButton;
@property (nonatomic, strong) PSGlyphButton *resetButton;
@property (nonatomic, strong) UIButton *lpButton;
@property (nonatomic, strong) UIButton *powerButton;
@property (nonatomic, strong) PSGlyphButton *collapseButton;

@property (nonatomic, copy, nullable) NSString *transientBannerText;
@property (nonatomic, assign) NSUInteger transientBannerToken;

@property (nonatomic, strong) UILabel *telemetryLabel;
@property (nonatomic, strong) UILabel *toneAxisLabel;
@property (nonatomic, strong) UILabel *colorAxisLabel;
@property (nonatomic, strong) PSMatrixPadView *matrixPad;

@property (nonatomic, strong) UILabel *paletteLabel;
@property (nonatomic, strong) PSPaletteSliderView *paletteSlider;
@property (nonatomic, strong) PSPresetStripView *presetStrip;

- (void)ps12_buildSubviews;
- (void)ps12_updateTelemetryAndHeader:(PSRenderSnapshot)snap;
- (void)ps12_didTapCategory;
- (void)ps12_didTapReset;
- (void)ps12_didTapLP;
- (void)ps12_didTapPower;
- (void)ps12_didTapCollapse;
@end

@implementation PSStyleControlPanel

- (instancetype)initWithFrame:(CGRect)frame {
    CGRect f = CGRectIsEmpty(frame) ? CGRectMake(0.0, 0.0, 304.0, 252.0) : frame;
    self = [super initWithFrame:f];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.06 alpha:0.84];
        self.opaque = NO;
        self.exclusiveTouch = YES;
        self.layer.cornerRadius = 22.0;
        self.layer.masksToBounds = YES;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.16].CGColor;

        [self ps12_buildSubviews];
        [self syncWithStateAnimated:NO];
    }
    return self;
}

- (void)ps12_buildSubviews {
    _categoryButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _categoryButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    _categoryButton.layer.cornerRadius = 11.0;
    _categoryButton.layer.masksToBounds = YES;
    _categoryButton.titleLabel.font = [UIFont systemFontOfSize:10.0 weight:UIFontWeightBold];
    [_categoryButton setTitleColor:[UIColor colorWithWhite:0.94 alpha:0.90] forState:UIControlStateNormal];
    [_categoryButton addTarget:self action:@selector(ps12_didTapCategory) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_categoryButton];

    _resetButton = [[PSGlyphButton alloc] initWithKind:PSGlyphKindReset];
    [_resetButton addTarget:self action:@selector(ps12_didTapReset) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_resetButton];

    _lpButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _lpButton.layer.cornerRadius = 11.0;
    _lpButton.layer.masksToBounds = YES;
    _lpButton.layer.borderWidth = 1.0;
    _lpButton.exclusiveTouch = YES;
    _lpButton.titleLabel.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightBold];
    [_lpButton setTitle:@"LP" forState:UIControlStateNormal];
    [_lpButton addTarget:self action:@selector(ps12_didTapLP) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_lpButton];

    _powerButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _powerButton.layer.cornerRadius = 11.0;
    _powerButton.layer.masksToBounds = YES;
    _powerButton.layer.borderWidth = 1.0;
    _powerButton.titleLabel.font = [UIFont systemFontOfSize:10.0 weight:UIFontWeightBold];
    [_powerButton addTarget:self action:@selector(ps12_didTapPower) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_powerButton];

    _collapseButton = [[PSGlyphButton alloc] initWithKind:PSGlyphKindChevronDown];
    [_collapseButton addTarget:self action:@selector(ps12_didTapCollapse) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_collapseButton];

    _telemetryLabel = [[UILabel alloc] init];
    _telemetryLabel.textAlignment = NSTextAlignmentCenter;
    _telemetryLabel.font = [UIFont monospacedDigitSystemFontOfSize:10.0 weight:UIFontWeightSemibold];
    _telemetryLabel.textColor = [UIColor colorWithWhite:0.92 alpha:0.86];
    [self addSubview:_telemetryLabel];

    _toneAxisLabel = [[UILabel alloc] init];
    _toneAxisLabel.text = @"TONE";
    _toneAxisLabel.textAlignment = NSTextAlignmentCenter;
    _toneAxisLabel.font = [UIFont systemFontOfSize:9.0 weight:UIFontWeightBold];
    _toneAxisLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.42];
    [self addSubview:_toneAxisLabel];

    _colorAxisLabel = [[UILabel alloc] init];
    _colorAxisLabel.text = @"COLOR";
    _colorAxisLabel.textAlignment = NSTextAlignmentCenter;
    _colorAxisLabel.font = [UIFont systemFontOfSize:9.0 weight:UIFontWeightBold];
    _colorAxisLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.42];
    [self addSubview:_colorAxisLabel];

    _matrixPad = [[PSMatrixPadView alloc] initWithFrame:CGRectMake(0.0, 0.0, 132.0, 132.0)];
    _matrixPad.delegate = self;
    [self addSubview:_matrixPad];

    _paletteLabel = [[UILabel alloc] init];
    _paletteLabel.text = @"PALETTE";
    _paletteLabel.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightBold];
    _paletteLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.58];
    [self addSubview:_paletteLabel];

    _paletteSlider = [[PSPaletteSliderView alloc] initWithFrame:CGRectMake(0.0, 0.0, 210.0, 26.0)];
    _paletteSlider.delegate = self;
    [self addSubview:_paletteSlider];

    _presetStrip = [[PSPresetStripView alloc] initWithFrame:CGRectMake(0.0, 0.0, 288.0, 34.0)];
    _presetStrip.delegate = self;
    [self addSubview:_presetStrip];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat w = CGRectGetWidth(self.bounds);
    CGFloat padX = 10.0;
    CGFloat y = 8.0;

    // Row 1: Header (26 pt)
    self.categoryButton.frame = CGRectMake(padX, y, 88.0, 24.0);
    self.collapseButton.frame = CGRectMake(w - padX - 26.0, y, 26.0, 24.0);
    self.powerButton.frame = CGRectMake(CGRectGetMinX(self.collapseButton.frame) - 5.0 - 38.0, y, 38.0, 24.0);
    self.lpButton.frame = CGRectMake(CGRectGetMinX(self.powerButton.frame) - 5.0 - 30.0, y, 30.0, 24.0);
    self.resetButton.frame = CGRectMake(CGRectGetMinX(self.lpButton.frame) - 5.0 - 26.0, y, 26.0, 24.0);
    y += 28.0;

    // Row 2: Live Readout (18 pt)
    self.telemetryLabel.frame = CGRectMake(padX, y, w - padX * 2.0, 16.0);
    y += 18.0;

    // Row 3: 2D Matrix Pad (132 pt)
    CGFloat padSize = 132.0;
    CGFloat padFrameX = (w - padSize) * 0.5;
    self.matrixPad.frame = CGRectMake(padFrameX, y, padSize, padSize);
    self.toneAxisLabel.frame = CGRectMake(padX, y + (padSize - 14.0) * 0.5, padFrameX - padX - 4.0, 14.0);
    self.colorAxisLabel.frame = CGRectMake(CGRectGetMaxX(self.matrixPad.frame) + 4.0,
                                           y + (padSize - 14.0) * 0.5,
                                           w - padX - CGRectGetMaxX(self.matrixPad.frame) - 4.0,
                                           14.0);
    y += padSize + 6.0;

    // Row 4: Palette Slider (26 pt)
    self.paletteLabel.frame = CGRectMake(padX + 2.0, y + 6.0, 52.0, 14.0);
    CGFloat sliderX = CGRectGetMaxX(self.paletteLabel.frame) + 4.0;
    self.paletteSlider.frame = CGRectMake(sliderX, y, w - padX - sliderX, 26.0);
    y += 28.0;

    // Row 5: 15-Preset Carousel (34 pt)
    self.presetStrip.frame = CGRectMake(6.0, y, w - 12.0, 34.0);
}

- (void)syncWithStateAnimated:(BOOL)animated {
    PSRenderSnapshot snap = [[PSState shared] snapshot];
    [self.matrixPad configureForPresetIndex:snap.presetIndex];
    [self.matrixPad setColor:snap.color tone:snap.tone palette:snap.palette];
    [self.paletteSlider configureForPresetIndex:snap.presetIndex];
    self.paletteSlider.palette = snap.palette;
    [self.presetStrip setSelectedPresetIndex:snap.presetIndex animated:animated];
    [self ps12_updateTelemetryAndHeader:snap];
}

- (void)ps12_updateTelemetryAndHeader:(PSRenderSnapshot)snap {
    PSStyleCategory cat = PSPresetCategory(snap.presetIndex);
    NSString *catTitle = (cat == PSStyleCategoryUndertones) ? @"UNDERTONES" : @"MOOD";
    [self.categoryButton setTitle:catTitle forState:UIControlStateNormal];

    BOOL modified = [[PSState shared] isCurrentPresetModifiedFromDefaults];
    self.resetButton.hidden = !modified;

    BOOL lpEnabled = [[PSCaptureCoordinator shared] livePhotoVideoBakingEnabled];
    UIColor *yellow = [UIColor colorWithRed:1.0 green:0.84 blue:0.04 alpha:1.0];

    if (lpEnabled) {
        [self.lpButton setTitleColor:yellow forState:UIControlStateNormal];
        self.lpButton.backgroundColor = [UIColor colorWithRed:1.0 green:0.84 blue:0.04 alpha:0.14];
        self.lpButton.layer.borderColor = [UIColor colorWithRed:1.0 green:0.84 blue:0.04 alpha:0.55].CGColor;
    } else {
        [self.lpButton setTitleColor:[UIColor colorWithWhite:0.75 alpha:0.60] forState:UIControlStateNormal];
        self.lpButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.06];
        self.lpButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.14].CGColor;
    }

    if (snap.enabled) {
        [self.powerButton setTitle:@"ON" forState:UIControlStateNormal];
        [self.powerButton setTitleColor:yellow forState:UIControlStateNormal];
        self.powerButton.backgroundColor = [UIColor colorWithRed:1.0 green:0.84 blue:0.04 alpha:0.16];
        self.powerButton.layer.borderColor = yellow.CGColor;
    } else {
        [self.powerButton setTitle:@"OFF" forState:UIControlStateNormal];
        [self.powerButton setTitleColor:[UIColor colorWithWhite:0.85 alpha:0.75] forState:UIControlStateNormal];
        self.powerButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
        self.powerButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.20].CGColor;
    }

    if (self.transientBannerText.length > 0) {
        self.telemetryLabel.text = self.transientBannerText;
    } else {
        NSInteger tVal = (NSInteger)llroundf(snap.tone * 100.0f);
        NSInteger cVal = (NSInteger)llroundf(snap.color * 100.0f);
        NSInteger pVal = (NSInteger)llroundf(snap.palette * 100.0f);

        NSString *name = PSPresetDisplayName(snap.presetIndex);
        self.telemetryLabel.text = [NSString stringWithFormat:@"%@  ·  T %+ld  C %+ld  P %ld",
                                    name, (long)tVal, (long)cVal, (long)pVal];
    }
}

#pragma mark - Actions

- (void)ps12_didTapCategory {
    PSRenderSnapshot snap = [[PSState shared] snapshot];
    PSStyleCategory currentCat = PSPresetCategory(snap.presetIndex);
    PSStyleCategory nextCat = (currentCat == PSStyleCategoryUndertones) ? PSStyleCategoryMood : PSStyleCategoryUndertones;
    NSInteger targetIdx = (nextCat == PSStyleCategoryUndertones) ? 1 : PSColorUndertoneCount; // AMBER or VIBRANT

    [[PSState shared] selectPresetAtIndex:targetIdx resetToPresetDefaults:YES];
    [self syncWithStateAnimated:YES];
    [self.presetStrip scrollToCategory:nextCat animated:YES];
    [self.delegate styleControlPanelDidChangeRenderState:self];
}

- (void)ps12_didTapReset {
    [[PSState shared] resetCurrentPresetToDefaults];
    [[PSState shared] saveNow];
    [self syncWithStateAnimated:YES];
    [self.delegate styleControlPanelDidChangeRenderState:self];
}

- (void)ps12_didTapLP {
    PSCaptureCoordinator *coordinator = [PSCaptureCoordinator shared];
    BOOL nextLP = ![coordinator livePhotoVideoBakingEnabled];
    coordinator.livePhotoVideoBakingEnabled = nextLP;

    self.transientBannerToken += 1;
    NSUInteger token = self.transientBannerToken;
    self.transientBannerText = nextLP ? @"LIVE PHOTO VIDEO: GRADED" : @"LIVE PHOTO VIDEO: FAST SKIP";
    [self ps12_updateTelemetryAndHeader:[[PSState shared] snapshot]];

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.transientBannerToken != token) {
            return;
        }
        strongSelf.transientBannerText = nil;
        [strongSelf ps12_updateTelemetryAndHeader:[[PSState shared] snapshot]];
    });
}

- (void)ps12_didTapPower {
    PSState *state = [PSState shared];
    state.enabled = ![state isEnabled];
    [state saveNow];
    [self syncWithStateAnimated:NO];
    [self.delegate styleControlPanelDidChangeRenderState:self];
}

- (void)ps12_didTapCollapse {
    [self.delegate styleControlPanelDidRequestCollapse:self];
}

#pragma mark - Child Delegates

- (void)matrixPadView:(PSMatrixPadView *)padView
       didChangeColor:(float)color
                 tone:(float)tone
           isFinished:(BOOL)finished {
    (void)padView;
    PSState *state = [PSState shared];
    if (![state isEnabled]) {
        state.enabled = YES;
    }
    [state setTone:tone color:color];
    if (finished) {
        [state saveNow];
    }
    [self ps12_updateTelemetryAndHeader:[state snapshot]];
    [self.delegate styleControlPanelDidChangeRenderState:self];
}

- (void)matrixPadViewDidRequestDoubleTapReset:(PSMatrixPadView *)padView {
    (void)padView;
    PSState *state = [PSState shared];
    const PSPresetDefinition *def = PSGetPresetDefinition([state presetIndex]);
    if (def) {
        [state setTone:def->defaultTone color:def->defaultColor];
        [state saveNow];
    }
    [self syncWithStateAnimated:NO];
    [self.delegate styleControlPanelDidChangeRenderState:self];
}

- (void)paletteSliderView:(PSPaletteSliderView *)sliderView
         didChangePalette:(float)palette
               isFinished:(BOOL)finished {
    (void)sliderView;
    PSState *state = [PSState shared];
    if (![state isEnabled]) {
        state.enabled = YES;
    }
    state.palette = palette;
    self.matrixPad.palette = palette;
    [self.matrixPad setNeedsDisplay];
    if (finished) {
        [state saveNow];
    }
    [self ps12_updateTelemetryAndHeader:[state snapshot]];
    [self.delegate styleControlPanelDidChangeRenderState:self];
}

- (void)presetStripView:(PSPresetStripView *)stripView didSelectPresetAtIndex:(NSInteger)presetIndex {
    (void)stripView;
    [[PSState shared] selectPresetAtIndex:presetIndex resetToPresetDefaults:YES];
    [[PSState shared] saveNow];
    [self syncWithStateAnimated:YES];
    [self.delegate styleControlPanelDidChangeRenderState:self];
}

@end
