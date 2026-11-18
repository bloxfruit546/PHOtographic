//
//  PSColorProfile.h
//  PhotographicStyles12
//
//  15 iPhone 16 Pro Max Photographic Styles presets (UNDERTONES 0..5, MOOD 6..14)
//  and the authoritative C parameter resolver shared by both the 60fps
//  CAColorMatrix viewfinder path and the full-precision CIColorKernel capture path.
//

#ifndef PS12_COLOR_PROFILE_H
#define PS12_COLOR_PROFILE_H

#import <Foundation/Foundation.h>
#import "PSState.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PSStyleCategory) {
    PSStyleCategoryUndertones = 0,
    PSStyleCategoryMood       = 1
};

FOUNDATION_EXPORT NSInteger const PSColorPresetCount;
FOUNDATION_EXPORT NSInteger const PSColorUndertoneCount;

typedef struct PSPresetDefinition {
    NSInteger presetIndex;
    const char *name;
    PSStyleCategory category;
    float defaultTone;
    float defaultColor;
    float defaultPalette;
    float baseExposure;
    float baseContrast;
    float baseSaturation;
    float baseWarmth;
    float baseTint;
    float baseVibrance;
    float splitStrength;
    float monoMix;
    float shadowTintRGB[3];
    float highlightTintRGB[3];
    float blackPointLift;
    float skinProtectStrength;
    float topLeftRGB[3];
    float topRightRGB[3];
    float bottomLeftRGB[3];
    float bottomRightRGB[3];
} PSPresetDefinition;

typedef struct PSResolvedParameters {
    BOOL isIdentity;
    NSInteger presetIndex;
    float exposure;
    float contrast;
    float saturation;
    float warmth;
    float tint;
    float vibrance;
    float splitStrength;
    float monoMix;
    float shadowTintRGB[3];
    float highlightTintRGB[3];
    float blackPointLift;
    float skinProtectStrength;
} PSResolvedParameters;

/// Returns the immutable definition for presetIndex (clamped to 0..14).
FOUNDATION_EXPORT const PSPresetDefinition *PSGetPresetDefinition(NSInteger presetIndex);

/// Returns the uppercase display name for presetIndex (e.g. @"VIBRANT").
FOUNDATION_EXPORT NSString *PSPresetDisplayName(NSInteger presetIndex);

/// Returns the category (Undertones or Mood) for presetIndex.
FOUNDATION_EXPORT PSStyleCategory PSPresetCategory(NSInteger presetIndex);

/// Resolves a PSRenderSnapshot into unified rendering parameters.
/// Guarantees isIdentity == YES when disabled or at STANDARD (0, 0).
FOUNDATION_EXPORT PSResolvedParameters PSResolveParameters(PSRenderSnapshot snapshot);

NS_ASSUME_NONNULL_END

#endif /* PS12_COLOR_PROFILE_H */
