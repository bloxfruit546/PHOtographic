//
//  PSStyleControlPanel.m
//  PhotographicStyles12
//
//  Authentic iPhone 16 Pro Max Photographic Styles floating card (296 x 252 pt)
//  tailored for iPhone 5s (320 x 568 pt) on iOS 12.
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
    PSGlyphKindChevronDown = 1,
    PSGlyphKindChevronLeft = 2,
    PSGlyphKindChevronRight = 3
};

@interface PSGlyphButton : UIButton
@property (nonatomic, assign) PSGlyphKind glyphKind;
@end

@implementation PSGlyphButton

- (instancetype)initWithKind:(PSGlyphKind)kind {
    self = [super initWithFrame:CGRectMake(0.0, 0.0, 24.0, 24.0)];
    if (self) {
        _glyphKind = kind;
        BOOL isNav = (kind == PSGlyphKindChevronLeft || kind == PSGlyphKindChevronRight);
        self.backgroundColor = isNav ? [UIColor clearColor] : [UIColor colorWithWhite:1.0 alpha:0.12];
        self.layer.cornerRadius = 12.0;
        self.layer.masksToBounds = YES;
        self.exclusiveTouch = YES;
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.50 : 1.0;
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

    CGFloat cx = CGRectGetMidX(rect);
    CGFloat cy = CGRectGetMidY(rect);
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.92].CGColor);
    CGContextSetLineWidth(ctx, 1.5);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);

    if (self.glyphKind == PSGlyphKindReset) {
        CGFloat r = 5.0;
        CGContextAddArc(ctx, cx, cy, r, (CGFloat)(-M_PI * 0.75), (CGFloat)(M_PI * 0.85), 0);
        CGContextStrokePath(ctx);

        CGFloat ax = cx - r * 0.72;
        CGFloat ay = cy - r * 0.72;
        CGContextMoveToPoint(ctx, ax - 2.4, ay + 0.5);
        CGContextAddLineToPoint(ctx, ax, ay);
        CGContextAddLineToPoint(ctx, ax + 0.8, ay + 2.6);
        CGContextStrokePath(ctx);
    } else if (self.glyphKind == PSGlyphKindChevronDown) {
        CGContextMoveToPoint(ctx, cx - 4.2, cy - 1.6);
        CGContextAddLineToPoint(ctx, cx, cy + 2.4);
        CGContextAddLineToPoint(ctx, cx + 4.2, cy - 1.6);
        CGContextStrokePath(ctx);
    } else if (self.glyphKind == PSGlyphKindChevronLeft) {
        CGContextMoveToPoint(ctx, cx + 2.0, cy - 4.0);
        CGContextAddLineToPoint(ctx, cx - 2.2, cy);
        CGContextAddLineToPoint(ctx, cx + 2.0, cy + 4.0);
        CGContextStrokePath(ctx);
    } else {
        CGContextMoveToPoint(ctx, cx - 2.0, cy - 4.0);
        CGContextAddLineToPoint(ctx, cx + 2.2, cy);
        CGContextAddLineToPoint(ctx, cx - 2.0, cy + 4.0);
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
// Zone A: Header
@property (nonatomic, strong) PSGlyphButton *resetButton;
@property (nonatomic, strong) PSGlyphButton *prevPresetButton;
@property (nonatomic, strong) UILabel *presetTitleLabel;
@property (nonatomic, strong) PSGlyphButton *nextPresetButton;
@property (nonatomic, strong) UIButton *lpButton;
@property (nonatomic, strong) PSGlyphButton *collapseButton;

@property (nonatomic, copy, nullable) NSString *transientBannerText;
@property (nonatomic, assign) NSUInteger transientBannerToken;

// Zone B: Apple Telemetry Bar
@property (nonatomic, strong) UILabel *telemetryLabel;

// Zone C: Centered 142x142 2D Pad + Left/Right Flanking Pills
@property (nonatomic, strong) UIButton *categoryButton;
@property (nonatomic, strong) UILabel *toneAxisLabel;
@property (nonatomic, strong) PSMatrixPadView *matrixPad;
@property (nonatomic, strong) UIButton *powerButton;
@property (nonatomic, strong) UILabel *colorAxisLabel;

// Zone D & E: Palette Slider + 15-Preset Strip
@property (nonatomic, strong) UILabel *paletteLabel;
@property (nonatomic, strong) PSPaletteSliderView *paletteSlider;
@property (nonatomic, strong) PSPresetStripView *presetStrip;

- (void)ps12_buildSubviews;
- (void)ps12_updateTelemetryAndHeader:(PSRenderSnapshot)snap;
- (void)ps12_didTapPrevPreset;
- (void)ps12_didTapNextPreset;
- (void)ps12_didTapCategory;
- (void)ps12_didTapReset;
- (void)ps12_didTapLP;
- (void)ps12_didTapPower;
- (void)ps12_didTapCollapse;
@end

@implementation PSStyleControlPanel

- (instancetype)initWithFrame:(CGRect)frame {
    BOOL invalid = CGRectIsEmpty(frame) ||
                   !isfinite(frame.size.width) || !isfinite(frame.size.height) ||
                   frame.size.width <= 0.0 || frame.size.height <= 0.0;
    CGRect f = invalid ? CGRectMake(0.0, 0.0, 296.0, 252.0) : frame;
    self = [super initWithFrame:f];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:14.0 / 255.0 green:14.0 / 255.0 blue:16.0 / 255.0 alpha:0.84];
        self.opaque = NO;
        self.exclusiveTouch = YES;
        self.layer.cornerRadius = 24.0;
        self.layer.masksToBounds = YES;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;

        [self ps12_buildSubviews];
        [self syncWithStateAnimated:NO];
    }
    return self;
}

- (void)ps12_buildSubviews {
    // Zone A: Header
    _resetButton = [[PSGlyphButton alloc] initWithKind:PSGlyphKindReset];
    [_resetButton addTarget:self action:@selector(ps12_didTapReset) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_resetButton];

    _prevPresetButton = [[PSGlyphButton alloc] initWithKind:PSGlyphKindChevronLeft];
    [_prevPresetButton addTarget:self action:@selector(ps12_didTapPrevPreset) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_prevPresetButton];

    _presetTitleLabel = [[UILabel alloc] init];
    _presetTitleLabel.textAlignment = NSTextAlignmentCenter;
    _presetTitleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold] ?: [UIFont boldSystemFontOfSize:11.5];
    _presetTitleLabel.textColor = [UIColor whiteColor];
    [self addSubview:_presetTitleLabel];

    _nextPresetButton = [[PSGlyphButton alloc] initWithKind:PSGlyphKindChevronRight];
    [_nextPresetButton addTarget:self action:@selector(ps12_didTapNextPreset) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_nextPresetButton];

    _lpButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _lpButton.layer.cornerRadius = 10.0;
    _lpButton.layer.masksToBounds = YES;
    _lpButton.layer.borderWidth = 1.0;
    _lpButton.exclusiveTouch = YES;
    _lpButton.titleLabel.font = [UIFont systemFontOfSize:9.0 weight:UIFontWeightBold] ?: [UIFont boldSystemFontOfSize:9.0];
    [_lpButton setTitle:@"LP" forState:UIControlStateNormal];
    [_lpButton addTarget:self action:@selector(ps12_didTapLP) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_lpButton];

    _collapseButton = [[PSGlyphButton alloc] initWithKind:PSGlyphKindChevronDown];
    [_collapseButton addTarget:self action:@selector(ps12_didTapCollapse) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_collapseButton];

    // Zone B: Apple Telemetry Bar
    _telemetryLabel = [[UILabel alloc] init];
    _telemetryLabel.textAlignment = NSTextAlignmentCenter;
    _telemetryLabel.adjustsFontSizeToFitWidth = YES;
    _telemetryLabel.minimumScaleFactor = 0.85;
    [self addSubview:_telemetryLabel];

    // Zone C: Flanking controls + 142x142 2D Pad
    _categoryButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _categoryButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    _categoryButton.layer.cornerRadius = 11.0;
    _categoryButton.layer.masksToBounds = YES;
    _categoryButton.layer.borderWidth = 0.75;
    _categoryButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.16].CGColor;
    _categoryButton.exclusiveTouch = YES;
    _categoryButton.titleLabel.font = [UIFont systemFontOfSize:8.5 weight:UIFontWeightBold] ?: [UIFont boldSystemFontOfSize:8.5];
    [_categoryButton setTitleColor:[UIColor colorWithWhite:0.94 alpha:0.92] forState:UIControlStateNormal];
    [_categoryButton addTarget:self action:@selector(ps12_didTapCategory) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_categoryButton];

    _toneAxisLabel = [[UILabel alloc] init];
    _toneAxisLabel.text = @"TONE";
    _toneAxisLabel.textAlignment = NSTextAlignmentCenter;
    _toneAxisLabel.font = [UIFont systemFontOfSize:8.5 weight:UIFontWeightSemibold] ?: [UIFont systemFontOfSize:8.5];
    _toneAxisLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.42];
    [self addSubview:_toneAxisLabel];

    _matrixPad = [[PSMatrixPadView alloc] initWithFrame:CGRectMake(0.0, 0.0, 142.0, 142.0)];
    _matrixPad.delegate = self;
    [self addSubview:_matrixPad];

    _powerButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _powerButton.layer.cornerRadius = 11.0;
    _powerButton.layer.masksToBounds = YES;
    _powerButton.layer.borderWidth = 1.0;
    _powerButton.exclusiveTouch = YES;
    _powerButton.titleLabel.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightBold] ?: [UIFont boldSystemFontOfSize:9.5];
    [_powerButton addTarget:self action:@selector(ps12_didTapPower) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_powerButton];

    _colorAxisLabel = [[UILabel alloc] init];
    _colorAxisLabel.text = @"COLOR";
    _colorAxisLabel.textAlignment = NSTextAlignmentCenter;
    _colorAxisLabel.font = [UIFont systemFontOfSize:8.5 weight:UIFontWeightSemibold] ?: [UIFont systemFontOfSize:8.5];
    _colorAxisLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.42];
    [self addSubview:_colorAxisLabel];

    // Zone D & E: Palette Slider + 15-Preset Strip
    _paletteLabel = [[UILabel alloc] init];
    _paletteLabel.text = @"PALETTE";
    _paletteLabel.font = [UIFont systemFontOfSize:9.0 weight:UIFontWeightBold] ?: [UIFont boldSystemFontOfSize:9.0];
    _paletteLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.58];
    [self addSubview:_paletteLabel];

    _paletteSlider = [[PSPaletteSliderView alloc] initWithFrame:CGRectMake(0.0, 0.0, 210.0, 22.0)];
    _paletteSlider.delegate = self;
    [self addSubview:_paletteSlider];

    _presetStrip = [[PSPresetStripView alloc] initWithFrame:CGRectMake(0.0, 0.0, 284.0, 30.0)];
    _presetStrip.delegate = self;
    [self addSubview:_presetStrip];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat w = CGRectGetWidth(self.bounds);
    CGFloat h = CGRectGetHeight(self.bounds);
    if (!isfinite(w) || w <= 0.0 || !isfinite(h) || h <= 0.0) {
        return;
    }

    CGFloat padX = 10.0;
    CGFloat y = 8.0;

    // Zone A: Header (24 pt) — [Reset 24]   [< 20][Title][> 20]   [LP 26][Close 24]
    self.resetButton.frame = CGRectMake(padX, y, 24.0, 24.0);
    self.collapseButton.frame = CGRectMake(w - padX - 24.0, y, 24.0, 24.0);
    self.lpButton.frame = CGRectMake(CGRectGetMinX(self.collapseButton.frame) - 5.0 - 26.0, y + 2.0, 26.0, 20.0);

    CGFloat navLeftBound = CGRectGetMaxX(self.resetButton.frame) + 6.0;
    CGFloat navRightBound = CGRectGetMinX(self.lpButton.frame) - 6.0;
    CGFloat navW = MAX(80.0, navRightBound - navLeftBound);
    CGFloat arrowW = 20.0;
    self.prevPresetButton.frame = CGRectMake(navLeftBound, y, arrowW, 24.0);
    self.nextPresetButton.frame = CGRectMake(navLeftBound + navW - arrowW, y, arrowW, 24.0);
    self.presetTitleLabel.frame = CGRectMake(navLeftBound + arrowW, y, MAX(1.0, navW - arrowW * 2.0), 24.0);
    y += 26.0;

    // Zone B: Apple Telemetry Bar (18 pt)
    self.telemetryLabel.frame = CGRectMake(padX, y, MAX(1.0, w - padX * 2.0), 16.0);
    y += 18.0;

    // Zone C: Centered 142 x 142 pt 2D Pad + Left/Right Flanking Pills
    CGFloat padSize = 142.0;
    CGFloat padFrameX = (w - padSize) * 0.5;
    self.matrixPad.frame = CGRectMake(padFrameX, y, padSize, padSize);

    CGFloat leftColW = MAX(44.0, padFrameX - padX - 6.0);
    CGFloat rightColX = CGRectGetMaxX(self.matrixPad.frame) + 6.0;
    CGFloat rightColW = MAX(44.0, w - padX - rightColX);
    CGFloat midY = y + padSize * 0.5;

    self.categoryButton.frame = CGRectMake(padX, midY - 22.0, leftColW, 22.0);
    self.toneAxisLabel.frame = CGRectMake(padX, midY + 6.0, leftColW, 14.0);

    self.powerButton.frame = CGRectMake(rightColX, midY - 22.0, rightColW, 22.0);
    self.colorAxisLabel.frame = CGRectMake(rightColX, midY + 6.0, rightColW, 14.0);
    y += padSize + 4.0;

    // Zone D: Palette Slider (22 pt)
    self.paletteLabel.frame = CGRectMake(padX + 2.0, y + 4.0, 48.0, 14.0);
    CGFloat sliderX = CGRectGetMaxX(self.paletteLabel.frame) + 4.0;
    CGFloat sliderW = MAX(1.0, w - padX - sliderX);
    self.paletteSlider.frame = CGRectMake(sliderX, y, sliderW, 22.0);
    y += 24.0;

    // Zone E: 15-Preset Strip (30 pt)
    self.presetStrip.frame = CGRectMake(6.0, y, MAX(1.0, w - 12.0), 30.0);
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
    NSString *presetName = PSPresetDisplayName(snap.presetIndex) ?: @"STANDARD";
    self.presetTitleLabel.text = presetName;

    PSStyleCategory cat = PSPresetCategory(snap.presetIndex);
    NSString *catTitle = (cat == PSStyleCategoryUndertones) ? @"UNDERTONE" : @"MOOD";
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

    UIFont *labelFont = [UIFont systemFontOfSize:9.5 weight:UIFontWeightMedium] ?: [UIFont systemFontOfSize:9.5];
    UIFont *valueFont = [UIFont monospacedDigitSystemFontOfSize:10.5 weight:UIFontWeightBold] ?: [UIFont boldSystemFontOfSize:10.5];
    UIColor *labelColor = [UIColor colorWithWhite:1.0 alpha:0.62];
    UIColor *valueColor = [UIColor whiteColor];

    if (self.transientBannerText.length > 0) {
        self.telemetryLabel.attributedText = [[NSAttributedString alloc]
            initWithString:self.transientBannerText
                attributes:@{
                    NSFontAttributeName : valueFont,
                    NSForegroundColorAttributeName : yellow
                }];
        return;
    }

    NSInteger tVal = (NSInteger)llroundf(snap.tone * 100.0f);
    NSInteger cVal = (NSInteger)llroundf(snap.color * 100.0f);
    NSInteger pVal = (NSInteger)llroundf(snap.palette * 100.0f);

    NSDictionary *lblAttrs = @{ NSFontAttributeName : labelFont, NSForegroundColorAttributeName : labelColor };
    NSDictionary *valAttrs = @{ NSFontAttributeName : valueFont, NSForegroundColorAttributeName : valueColor };

    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] init];
    [attr appendAttributedString:[[NSAttributedString alloc] initWithString:@"TONE " attributes:lblAttrs]];
    [attr appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%+ld", (long)tVal] attributes:valAttrs]];
    [attr appendAttributedString:[[NSAttributedString alloc] initWithString:@"  ·  COLOR " attributes:lblAttrs]];
    [attr appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%+ld", (long)cVal] attributes:valAttrs]];
    [attr appendAttributedString:[[NSAttributedString alloc] initWithString:@"  ·  PALETTE " attributes:lblAttrs]];
    [attr appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%ld", (long)pVal] attributes:valAttrs]];

    self.telemetryLabel.attributedText = attr;
}

#pragma mark - Actions

- (void)ps12_didTapPrevPreset {
    PSState *state = [PSState shared];
    NSInteger nextIdx = (state.presetIndex - 1 + PSColorPresetCount) % PSColorPresetCount;
    [state selectPresetAtIndex:nextIdx resetToPresetDefaults:YES];
    [state saveNow];
    [self syncWithStateAnimated:YES];
    [self.delegate styleControlPanelDidChangeRenderState:self];
}

- (void)ps12_didTapNextPreset {
    PSState *state = [PSState shared];
    NSInteger nextIdx = (state.presetIndex + 1) % PSColorPresetCount;
    [state selectPresetAtIndex:nextIdx resetToPresetDefaults:YES];
    [state saveNow];
    [self syncWithStateAnimated:YES];
    [self.delegate styleControlPanelDidChangeRenderState:self];
}

- (void)ps12_didTapCategory {
    PSRenderSnapshot snap = [[PSState shared] snapshot];
    PSStyleCategory currentCat = PSPresetCategory(snap.presetIndex);
    PSStyleCategory nextCat = (currentCat == PSStyleCategoryUndertones) ? PSStyleCategoryMood : PSStyleCategoryUndertones;
    NSInteger targetIdx = (nextCat == PSStyleCategoryUndertones) ? 1 : PSColorUndertoneCount;

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
