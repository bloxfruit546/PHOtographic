//
//  PSOpticalPreviewView.m
//  PhotographicStyles12
//
//  Zero-readback GPU-composited optical grading veil for iPhone 5s (iOS 12).
//  Pure translucent CALayer/CAGradientLayer compositing, zero mediaserverd RAM impact.
//

#import "PSOpticalPreviewView.h"
#import "PSColorProfile.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import <string.h>

static inline float PS12OpticalClamp(float v, float lo, float hi) {
    if (!isfinite(v)) return lo;
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

@interface PSOpticalPreviewView () {
    BOOL _hasApplied;
    PSRenderSnapshot _lastSnapshot;
}
@property (nonatomic, strong) CAGradientLayer *tintGradientLayer;
@property (nonatomic, strong) CALayer *toneVeilLayer;
@property (nonatomic, strong) UILabel *monoBadgeLabel;
@end

@implementation PSOpticalPreviewView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.hidden = YES;
        self.alpha = 0.0;
        self.clipsToBounds = YES;

        _hasApplied = NO;
        memset(&_lastSnapshot, 0, sizeof(_lastSnapshot));

        _tintGradientLayer = [CAGradientLayer layer];
        _tintGradientLayer.startPoint = CGPointMake(0.5, 0.0);
        _tintGradientLayer.endPoint = CGPointMake(0.5, 1.0);
        _tintGradientLayer.actions = @{
            @"colors" : [NSNull null],
            @"opacity" : [NSNull null],
            @"bounds" : [NSNull null],
            @"position" : [NSNull null]
        };
        [self.layer addSublayer:_tintGradientLayer];

        _toneVeilLayer = [CALayer layer];
        _toneVeilLayer.actions = @{
            @"backgroundColor" : [NSNull null],
            @"opacity" : [NSNull null],
            @"bounds" : [NSNull null],
            @"position" : [NSNull null]
        };
        [self.layer addSublayer:_toneVeilLayer];

        _monoBadgeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _monoBadgeLabel.text = @"STARK B&W";
        _monoBadgeLabel.textAlignment = NSTextAlignmentCenter;
        _monoBadgeLabel.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightBold] ?: [UIFont boldSystemFontOfSize:9.5];
        _monoBadgeLabel.textColor = [UIColor colorWithWhite:0.96 alpha:0.94];
        _monoBadgeLabel.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.62];
        _monoBadgeLabel.layer.cornerRadius = 9.0;
        _monoBadgeLabel.layer.masksToBounds = YES;
        _monoBadgeLabel.layer.borderWidth = 0.75;
        _monoBadgeLabel.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.30].CGColor;
        _monoBadgeLabel.hidden = YES;
        [self addSubview:_monoBadgeLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat w = CGRectGetWidth(self.bounds);
    CGFloat h = CGRectGetHeight(self.bounds);
    if (!isfinite(w) || w <= 0.0 || !isfinite(h) || h <= 0.0) {
        return;
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.tintGradientLayer.frame = self.bounds;
    self.toneVeilLayer.frame = self.bounds;
    [CATransaction commit];

    CGFloat badgeW = 78.0;
    CGFloat badgeH = 18.0;
    self.monoBadgeLabel.frame = CGRectMake((w - badgeW) * 0.5, 56.0, badgeW, badgeH);
}

- (void)applySnapshot:(PSRenderSnapshot)snapshot {
    if (_hasApplied && memcmp(&snapshot, &_lastSnapshot, sizeof(PSRenderSnapshot)) == 0) {
        return;
    }
    _hasApplied = YES;
    _lastSnapshot = snapshot;

    PSResolvedParameters params = PSResolveParameters(snapshot);
    if (!snapshot.enabled || params.isIdentity) {
        self.hidden = YES;
        self.alpha = 0.0;
        self.monoBadgeLabel.hidden = YES;
        return;
    }

    const PSPresetDefinition *def = PSGetPresetDefinition(snapshot.presetIndex);
    float hiR = def ? def->highlightTintRGB[0] : 0.5f;
    float hiG = def ? def->highlightTintRGB[1] : 0.5f;
    float hiB = def ? def->highlightTintRGB[2] : 0.5f;
    float shR = def ? def->shadowTintRGB[0] : 0.5f;
    float shG = def ? def->shadowTintRGB[1] : 0.5f;
    float shB = def ? def->shadowTintRGB[2] : 0.5f;

    // Nudge tint subtly with warmth & tint parameters
    float warmShift = PS12OpticalClamp(params.warmth * 0.25f, -0.20f, 0.20f);
    float tintShift = PS12OpticalClamp(params.tint * 0.20f, -0.15f, 0.15f);

    float topR = PS12OpticalClamp(hiR + warmShift + tintShift, 0.0f, 1.0f);
    float topG = PS12OpticalClamp(hiG - tintShift * 0.6f, 0.0f, 1.0f);
    float topB = PS12OpticalClamp(hiB - warmShift + tintShift, 0.0f, 1.0f);

    float botR = PS12OpticalClamp(shR + warmShift * 0.7f, 0.0f, 1.0f);
    float botG = PS12OpticalClamp(shG - tintShift * 0.4f, 0.0f, 1.0f);
    float botB = PS12OpticalClamp(shB - warmShift * 0.7f, 0.0f, 1.0f);

    BOOL isMono = (params.monoMix > 0.5f);
    float paletteScale = 0.25f + 0.75f * PS12OpticalClamp(snapshot.palette, 0.0f, 1.0f);

    CGFloat topAlpha = 0.0;
    CGFloat botAlpha = 0.0;
    if (isMono) {
        // Subtle silver-grey optical veil + monochrome badge
        topR = 0.72f; topG = 0.73f; topB = 0.75f;
        botR = 0.18f; botG = 0.19f; botB = 0.21f;
        topAlpha = 0.10;
        botAlpha = 0.16;
    } else {
        float colorEnergy = fabsf(params.warmth) * 0.45f + fabsf(params.tint) * 0.35f + params.splitStrength * 0.30f + fabsf(snapshot.color) * 0.18f;
        CGFloat veilAlpha = (CGFloat)PS12OpticalClamp(colorEnergy * paletteScale * 0.28f, 0.03f, 0.22f);
        topAlpha = veilAlpha;
        botAlpha = veilAlpha * 0.85;
    }

    UIColor *topColor = [UIColor colorWithRed:topR green:topG blue:topB alpha:topAlpha];
    UIColor *botColor = [UIColor colorWithRed:botR green:botG blue:botB alpha:botAlpha];

    // Tone veil: negative tone -> moody shadow depth; positive tone -> airy luminous lift
    float toneNorm = PS12OpticalClamp(snapshot.tone + params.exposure * 0.8f, -1.0f, 1.0f);
    UIColor *toneColor = [UIColor clearColor];
    if (toneNorm < -0.02f) {
        CGFloat darkAlpha = (CGFloat)PS12OpticalClamp(fabsf(toneNorm) * 0.22f, 0.0f, 0.22f);
        toneColor = [UIColor colorWithWhite:0.0 alpha:darkAlpha];
    } else if (toneNorm > 0.02f) {
        CGFloat liftAlpha = (CGFloat)PS12OpticalClamp(toneNorm * 0.16f, 0.0f, 0.16f);
        toneColor = [UIColor colorWithWhite:1.0 alpha:liftAlpha];
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.hidden = NO;
    self.alpha = 1.0;
    self.tintGradientLayer.colors = @[
        (__bridge id)topColor.CGColor,
        (__bridge id)botColor.CGColor
    ];
    self.toneVeilLayer.backgroundColor = toneColor.CGColor;
    self.monoBadgeLabel.hidden = !isMono;
    [CATransaction commit];
}

@end
