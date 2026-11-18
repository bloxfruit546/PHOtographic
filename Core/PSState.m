//
//  PSState.m
//  PhotographicStyles12
//
//  Thread-safe state singleton with NSUserDefaults persistence and
//  luminance-preserving 4x5 CAColorMatrix synthesis.
//

#import "PSState.h"
#import "PSColorProfile.h"
#import "PSColorEngine.h"
#import <os/lock.h>
#import <math.h>

static NSString *const kPS12KeyEnabled     = @"ps12_v2_enabled";
static NSString *const kPS12KeyPresetIndex = @"ps12_v2_presetIndex";
static NSString *const kPS12KeyTone        = @"ps12_v2_tone";
static NSString *const kPS12KeyColor       = @"ps12_v2_color";
static NSString *const kPS12KeyPalette     = @"ps12_v2_palette";

static inline float PS12ClampFloat(float v, float lo, float hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

@interface PSState () {
    os_unfair_lock _lock;
    BOOL _enabled;
    NSInteger _presetIndex;
    float _tone;
    float _color;
    float _palette;
    BOOL _saveScheduled;
}
- (void)ps12_loadFromDefaults;
- (void)ps12_scheduleSave;
@end

@implementation PSState

+ (instancetype)shared {
    static PSState *s_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_instance = [[PSState alloc] init];
    });
    return s_instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _lock = OS_UNFAIR_LOCK_INIT;
        _enabled = NO;
        _presetIndex = 0;
        _tone = 0.0f;
        _color = 0.0f;
        _palette = 0.5f;
        _saveScheduled = NO;
        [self ps12_loadFromDefaults];
    }
    return self;
}

- (void)ps12_loadFromDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    os_unfair_lock_lock(&_lock);
    if ([defaults objectForKey:kPS12KeyEnabled] != nil) {
        _enabled = [defaults boolForKey:kPS12KeyEnabled];
    }
    if ([defaults objectForKey:kPS12KeyPresetIndex] != nil) {
        NSInteger idx = [defaults integerForKey:kPS12KeyPresetIndex];
        _presetIndex = (idx >= 0 && idx < 15) ? idx : 0;
    }
    if ([defaults objectForKey:kPS12KeyTone] != nil) {
        _tone = PS12ClampFloat([defaults floatForKey:kPS12KeyTone], -1.0f, 1.0f);
    }
    if ([defaults objectForKey:kPS12KeyColor] != nil) {
        _color = PS12ClampFloat([defaults floatForKey:kPS12KeyColor], -1.0f, 1.0f);
    }
    if ([defaults objectForKey:kPS12KeyPalette] != nil) {
        _palette = PS12ClampFloat([defaults floatForKey:kPS12KeyPalette], 0.0f, 1.0f);
    }
    os_unfair_lock_unlock(&_lock);
}

- (void)ps12_scheduleSave {
    os_unfair_lock_lock(&_lock);
    BOOL alreadyScheduled = _saveScheduled;
    _saveScheduled = YES;
    os_unfair_lock_unlock(&_lock);

    if (alreadyScheduled) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf saveNow];
    });
}

- (void)saveNow {
    os_unfair_lock_lock(&_lock);
    BOOL enabled = _enabled;
    NSInteger presetIndex = _presetIndex;
    float tone = _tone;
    float color = _color;
    float palette = _palette;
    _saveScheduled = NO;
    os_unfair_lock_unlock(&_lock);

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:enabled forKey:kPS12KeyEnabled];
    [defaults setInteger:presetIndex forKey:kPS12KeyPresetIndex];
    [defaults setFloat:tone forKey:kPS12KeyTone];
    [defaults setFloat:color forKey:kPS12KeyColor];
    [defaults setFloat:palette forKey:kPS12KeyPalette];
}

#pragma mark - Thread-Safe Accessors

- (BOOL)isEnabled {
    os_unfair_lock_lock(&_lock);
    BOOL v = _enabled;
    os_unfair_lock_unlock(&_lock);
    return v;
}

- (void)setEnabled:(BOOL)enabled {
    os_unfair_lock_lock(&_lock);
    _enabled = enabled;
    os_unfair_lock_unlock(&_lock);
    [self ps12_scheduleSave];
}

- (NSInteger)presetIndex {
    os_unfair_lock_lock(&_lock);
    NSInteger v = _presetIndex;
    os_unfair_lock_unlock(&_lock);
    return v;
}

- (void)setPresetIndex:(NSInteger)presetIndex {
    NSInteger clamped = (presetIndex < 0) ? 0 : (presetIndex > 14 ? 14 : presetIndex);
    os_unfair_lock_lock(&_lock);
    _presetIndex = clamped;
    os_unfair_lock_unlock(&_lock);
    [self ps12_scheduleSave];
}

- (float)tone {
    os_unfair_lock_lock(&_lock);
    float v = _tone;
    os_unfair_lock_unlock(&_lock);
    return v;
}

- (void)setTone:(float)tone {
    float clamped = PS12ClampFloat(tone, -1.0f, 1.0f);
    os_unfair_lock_lock(&_lock);
    _tone = clamped;
    os_unfair_lock_unlock(&_lock);
    [self ps12_scheduleSave];
}

- (float)color {
    os_unfair_lock_lock(&_lock);
    float v = _color;
    os_unfair_lock_unlock(&_lock);
    return v;
}

- (void)setColor:(float)color {
    float clamped = PS12ClampFloat(color, -1.0f, 1.0f);
    os_unfair_lock_lock(&_lock);
    _color = clamped;
    os_unfair_lock_unlock(&_lock);
    [self ps12_scheduleSave];
}

- (float)palette {
    os_unfair_lock_lock(&_lock);
    float v = _palette;
    os_unfair_lock_unlock(&_lock);
    return v;
}

- (void)setPalette:(float)palette {
    float clamped = PS12ClampFloat(palette, 0.0f, 1.0f);
    os_unfair_lock_lock(&_lock);
    _palette = clamped;
    os_unfair_lock_unlock(&_lock);
    [self ps12_scheduleSave];
}

- (PSRenderSnapshot)snapshot {
    os_unfair_lock_lock(&_lock);
    PSRenderSnapshot snap;
    snap.enabled = _enabled;
    snap.presetIndex = _presetIndex;
    snap.tone = _tone;
    snap.color = _color;
    snap.palette = _palette;
    os_unfair_lock_unlock(&_lock);
    return snap;
}

- (void)setTone:(float)tone color:(float)color {
    float clampedTone = PS12ClampFloat(tone, -1.0f, 1.0f);
    float clampedColor = PS12ClampFloat(color, -1.0f, 1.0f);
    os_unfair_lock_lock(&_lock);
    _tone = clampedTone;
    _color = clampedColor;
    os_unfair_lock_unlock(&_lock);
    [self ps12_scheduleSave];
}

- (void)selectPresetAtIndex:(NSInteger)presetIndex resetToPresetDefaults:(BOOL)resetDefaults {
    NSInteger clamped = (presetIndex < 0) ? 0 : (presetIndex >= PSColorPresetCount ? PSColorPresetCount - 1 : presetIndex);
    const PSPresetDefinition *def = PSGetPresetDefinition(clamped);

    os_unfair_lock_lock(&_lock);
    _presetIndex = clamped;
    _enabled = YES;
    if (resetDefaults && def) {
        _tone = def->defaultTone;
        _color = def->defaultColor;
        _palette = def->defaultPalette;
    }
    os_unfair_lock_unlock(&_lock);
    [self ps12_scheduleSave];
}

- (void)resetCurrentPresetToDefaults {
    os_unfair_lock_lock(&_lock);
    const PSPresetDefinition *def = PSGetPresetDefinition(_presetIndex);
    if (def) {
        _tone = def->defaultTone;
        _color = def->defaultColor;
        _palette = def->defaultPalette;
    }
    os_unfair_lock_unlock(&_lock);
    [self ps12_scheduleSave];
}

- (BOOL)isCurrentPresetModifiedFromDefaults {
    PSRenderSnapshot snap = [self snapshot];
    const PSPresetDefinition *def = PSGetPresetDefinition(snap.presetIndex);
    if (!def) {
        return NO;
    }
    return (fabsf(snap.tone - def->defaultTone) > 0.015f ||
            fabsf(snap.color - def->defaultColor) > 0.015f ||
            fabsf(snap.palette - def->defaultPalette) > 0.015f);
}

#pragma mark - Unified Matrix Synthesis

+ (CAColorMatrix)previewMatrixForSnapshot:(PSRenderSnapshot)snapshot {
    PSResolvedParameters params = PSResolveParameters(snapshot);
    return [PSColorEngine colorMatrixForParameters:params];
}

- (CAColorMatrix)previewMatrixForCurrentState {
    return [PSState previewMatrixForSnapshot:[self snapshot]];
}

@end
