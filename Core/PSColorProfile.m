//
//  PSColorProfile.m
//  PhotographicStyles12
//
//  15 iPhone 16 Pro Max Photographic Styles preset definitions and
//  unified parameter resolution.
//

#import "PSColorProfile.h"
#import <math.h>

NSInteger const PSColorPresetCount    = 15;
NSInteger const PSColorUndertoneCount = 6;

static inline float PS12ProfileClamp(float v, float lo, float hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static const PSPresetDefinition kPS12Presets[15] = {
    // -------------------------------------------------------------------------
    // UNDERTONES (0..5) - skinProtectStrength = 0.85
    // -------------------------------------------------------------------------
    // 0: STANDARD (Identity at tone=0, color=0)
    {
        0, "STANDARD", PSStyleCategoryUndertones,
        0.00f, 0.00f, 0.50f,
        0.00f, 0.00f, 0.00f, 0.00f, 0.00f, 0.00f, 0.00f, 0.00f,
        {0.50f, 0.50f, 0.50f}, {0.50f, 0.50f, 0.50f}, 0.00f, 0.85f,
        {0.72f, 0.72f, 0.72f}, {0.82f, 0.82f, 0.82f},
        {0.35f, 0.35f, 0.35f}, {0.55f, 0.55f, 0.55f}
    },
    // 1: AMBER
    {
        1, "AMBER", PSStyleCategoryUndertones,
        0.20f, -0.10f, 0.60f,
        0.02f, 0.12f, 0.06f, 0.28f, -0.02f, 0.10f, 0.40f, 0.00f,
        {0.42f, 0.30f, 0.16f}, {0.66f, 0.52f, 0.30f}, 0.00f, 0.85f,
        {0.92f, 0.66f, 0.32f}, {0.98f, 0.76f, 0.36f},
        {0.44f, 0.26f, 0.14f}, {0.72f, 0.48f, 0.22f}
    },
    // 2: GOLD
    {
        2, "GOLD", PSStyleCategoryUndertones,
        0.10f, -0.30f, 0.70f,
        0.03f, 0.06f, 0.08f, 0.36f, -0.03f, 0.16f, 0.45f, 0.00f,
        {0.45f, 0.34f, 0.14f}, {0.74f, 0.60f, 0.26f}, 0.00f, 0.85f,
        {0.94f, 0.78f, 0.34f}, {1.00f, 0.84f, 0.38f},
        {0.46f, 0.34f, 0.16f}, {0.76f, 0.60f, 0.24f}
    },
    // 3: ROSE GOLD
    {
        3, "ROSE GOLD", PSStyleCategoryUndertones,
        0.20f, -0.10f, 0.65f,
        0.02f, 0.05f, 0.06f, 0.20f, 0.12f, 0.10f, 0.42f, 0.00f,
        {0.52f, 0.34f, 0.34f}, {0.74f, 0.52f, 0.46f}, 0.00f, 0.85f,
        {0.94f, 0.66f, 0.62f}, {0.98f, 0.74f, 0.66f},
        {0.50f, 0.30f, 0.32f}, {0.76f, 0.48f, 0.46f}
    },
    // 4: NEUTRAL
    {
        4, "NEUTRAL", PSStyleCategoryUndertones,
        -0.05f, -0.10f, 0.35f,
        0.00f, 0.04f, -0.05f, -0.06f, 0.00f, 0.00f, 0.18f, 0.00f,
        {0.46f, 0.48f, 0.52f}, {0.52f, 0.53f, 0.55f}, 0.00f, 0.85f,
        {0.70f, 0.72f, 0.76f}, {0.80f, 0.82f, 0.84f},
        {0.34f, 0.36f, 0.40f}, {0.54f, 0.56f, 0.58f}
    },
    // 5: COOL ROSE
    {
        5, "COOL ROSE", PSStyleCategoryUndertones,
        -0.05f, -0.10f, 0.45f,
        0.00f, 0.02f, 0.04f, -0.20f, 0.16f, 0.06f, 0.40f, 0.00f,
        {0.36f, 0.36f, 0.48f}, {0.64f, 0.56f, 0.68f}, 0.00f, 0.85f,
        {0.80f, 0.66f, 0.86f}, {0.90f, 0.72f, 0.90f},
        {0.36f, 0.32f, 0.46f}, {0.64f, 0.52f, 0.68f}
    },

    // -------------------------------------------------------------------------
    // MOOD (6..14) - skinProtectStrength = 0.55 (0.00 for STARK B&W)
    // -------------------------------------------------------------------------
    // 6: VIBRANT
    {
        6, "VIBRANT", PSStyleCategoryMood,
        0.05f, 1.00f, 0.87f,
        0.01f, 0.10f, 0.16f, 0.10f, 0.02f, 0.52f, 0.65f, 0.00f,
        {0.30f, 0.22f, 0.46f}, {0.84f, 0.56f, 0.28f}, 0.00f, 0.55f,
        {0.58f, 0.42f, 0.90f}, {0.98f, 0.62f, 0.28f},
        {0.24f, 0.18f, 0.44f}, {0.72f, 0.42f, 0.22f}
    },
    // 7: BRIGHT
    {
        7, "BRIGHT", PSStyleCategoryMood,
        -0.10f, 0.85f, 0.80f,
        0.05f, 0.24f, 0.18f, 0.18f, -0.02f, 0.34f, 0.52f, 0.00f,
        {0.36f, 0.18f, 0.12f}, {0.82f, 0.66f, 0.34f}, 0.01f, 0.55f,
        {0.96f, 0.78f, 0.34f}, {1.00f, 0.86f, 0.42f},
        {0.38f, 0.22f, 0.16f}, {0.76f, 0.52f, 0.24f}
    },
    // 8: NATURAL
    {
        8, "NATURAL", PSStyleCategoryMood,
        0.00f, 0.00f, 0.40f,
        0.00f, -0.04f, 0.03f, 0.02f, 0.00f, 0.06f, 0.22f, 0.00f,
        {0.46f, 0.47f, 0.47f}, {0.56f, 0.55f, 0.53f}, 0.00f, 0.55f,
        {0.66f, 0.76f, 0.68f}, {0.80f, 0.84f, 0.74f},
        {0.34f, 0.38f, 0.36f}, {0.56f, 0.60f, 0.54f}
    },
    // 9: LUMINOUS
    {
        9, "LUMINOUS", PSStyleCategoryMood,
        0.40f, -0.20f, 0.55f,
        0.12f, -0.02f, 0.04f, 0.04f, 0.02f, 0.10f, 0.36f, 0.00f,
        {0.50f, 0.50f, 0.54f}, {0.72f, 0.68f, 0.62f}, 0.02f, 0.55f,
        {0.88f, 0.88f, 0.94f}, {0.98f, 0.94f, 0.86f},
        {0.46f, 0.46f, 0.50f}, {0.70f, 0.66f, 0.60f}
    },
    // 10: DRAMATIC
    {
        10, "DRAMATIC", PSStyleCategoryMood,
        0.65f, -0.55f, 0.70f,
        -0.08f, 0.38f, 0.08f, -0.02f, 0.00f, 0.14f, 0.54f, 0.00f,
        {0.16f, 0.18f, 0.28f}, {0.64f, 0.54f, 0.38f}, 0.00f, 0.55f,
        {0.34f, 0.42f, 0.58f}, {0.84f, 0.66f, 0.42f},
        {0.12f, 0.14f, 0.22f}, {0.52f, 0.40f, 0.26f}
    },
    // 11: QUIET
    {
        11, "QUIET", PSStyleCategoryMood,
        0.10f, -0.60f, 0.30f,
        0.02f, -0.10f, -0.24f, 0.00f, 0.00f, 0.00f, 0.30f, 0.00f,
        {0.42f, 0.42f, 0.40f}, {0.58f, 0.57f, 0.54f}, 0.03f, 0.55f,
        {0.62f, 0.64f, 0.62f}, {0.72f, 0.72f, 0.68f},
        {0.34f, 0.34f, 0.32f}, {0.52f, 0.52f, 0.48f}
    },
    // 12: COZY
    {
        12, "COZY", PSStyleCategoryMood,
        0.25f, -0.25f, 0.65f,
        0.04f, -0.06f, 0.05f, 0.26f, -0.02f, 0.10f, 0.44f, 0.00f,
        {0.44f, 0.30f, 0.18f}, {0.74f, 0.56f, 0.34f}, 0.02f, 0.55f,
        {0.88f, 0.64f, 0.38f}, {0.96f, 0.72f, 0.42f},
        {0.40f, 0.26f, 0.16f}, {0.72f, 0.50f, 0.28f}
    },
    // 13: ETHEREAL
    {
        13, "ETHEREAL", PSStyleCategoryMood,
        0.35f, -0.15f, 0.60f,
        0.10f, -0.08f, 0.02f, -0.06f, 0.14f, 0.14f, 0.48f, 0.00f,
        {0.46f, 0.42f, 0.56f}, {0.78f, 0.72f, 0.84f}, 0.03f, 0.55f,
        {0.84f, 0.78f, 0.96f}, {0.96f, 0.86f, 0.92f},
        {0.44f, 0.42f, 0.58f}, {0.76f, 0.66f, 0.80f}
    },
    // 14: STARK B&W
    {
        14, "STARK B&W", PSStyleCategoryMood,
        -0.15f, 0.00f, 0.50f,
        -0.02f, 0.42f, 0.00f, 0.00f, 0.00f, 0.00f, 0.35f, 1.00f,
        {0.46f, 0.48f, 0.52f}, {0.54f, 0.52f, 0.48f}, 0.00f, 0.00f,
        {0.72f, 0.72f, 0.74f}, {0.82f, 0.80f, 0.76f},
        {0.18f, 0.18f, 0.20f}, {0.36f, 0.36f, 0.36f}
    }
};

const PSPresetDefinition *PSGetPresetDefinition(NSInteger presetIndex) {
    NSInteger idx = presetIndex;
    if (idx < 0) idx = 0;
    if (idx >= PSColorPresetCount) idx = PSColorPresetCount - 1;
    return &kPS12Presets[idx];
}

NSString *PSPresetDisplayName(NSInteger presetIndex) {
    const PSPresetDefinition *def = PSGetPresetDefinition(presetIndex);
    return [NSString stringWithUTF8String:def->name];
}

PSStyleCategory PSPresetCategory(NSInteger presetIndex) {
    const PSPresetDefinition *def = PSGetPresetDefinition(presetIndex);
    return def->category;
}

PSResolvedParameters PSResolveParameters(PSRenderSnapshot snapshot) {
    PSResolvedParameters out;
    memset(&out, 0, sizeof(out));

    NSInteger idx = snapshot.presetIndex;
    if (idx < 0) idx = 0;
    if (idx >= PSColorPresetCount) idx = PSColorPresetCount - 1;
    out.presetIndex = idx;

    float tone = PS12ProfileClamp(snapshot.tone, -1.0f, 1.0f);
    float color = PS12ProfileClamp(snapshot.color, -1.0f, 1.0f);
    float palette = PS12ProfileClamp(snapshot.palette, 0.0f, 1.0f);

    if (!snapshot.enabled || (idx == 0 && fabsf(tone) < 1e-5f && fabsf(color) < 1e-5f)) {
        out.isIdentity = YES;
        out.contrast = 1.0f;
        out.saturation = 1.0f;
        out.shadowTintRGB[0] = 0.5f;
        out.shadowTintRGB[1] = 0.5f;
        out.shadowTintRGB[2] = 0.5f;
        out.highlightTintRGB[0] = 0.5f;
        out.highlightTintRGB[1] = 0.5f;
        out.highlightTintRGB[2] = 0.5f;
        return out;
    }

    const PSPresetDefinition *def = &kPS12Presets[idx];
    float paletteScale = 0.25f + 0.75f * palette;

    out.isIdentity = NO;
    out.exposure = PS12ProfileClamp(def->baseExposure * paletteScale + tone * 0.12f, -0.45f, 0.45f);
    out.contrast = PS12ProfileClamp(1.0f + def->baseContrast * paletteScale - tone * 0.18f, 0.60f, 1.65f);
    out.saturation = PS12ProfileClamp(1.0f + def->baseSaturation * paletteScale + color * 0.36f, 0.0f, 1.85f);
    out.warmth = PS12ProfileClamp(def->baseWarmth * paletteScale + color * 0.08f * paletteScale, -0.60f, 0.60f);
    out.tint = PS12ProfileClamp(def->baseTint * paletteScale, -0.45f, 0.45f);
    out.vibrance = PS12ProfileClamp(def->baseVibrance * paletteScale + color * 0.30f, -0.50f, 1.00f);
    out.splitStrength = PS12ProfileClamp(def->splitStrength * paletteScale, 0.0f, 1.00f);
    out.monoMix = def->monoMix;
    out.blackPointLift = PS12ProfileClamp(def->blackPointLift * paletteScale + fmaxf(tone, 0.0f) * 0.025f, 0.0f, 0.08f);
    out.skinProtectStrength = def->skinProtectStrength;

    for (int i = 0; i < 3; i++) {
        out.shadowTintRGB[i] = def->shadowTintRGB[i];
        out.highlightTintRGB[i] = def->highlightTintRGB[i];
    }

    // For STARK B&W, palette shifts the silver split-tone from cool selenium (0) to warm sepia (1).
    if (def->monoMix > 0.5f) {
        float warmShift = (palette - 0.5f) * 0.16f;
        out.highlightTintRGB[0] = PS12ProfileClamp(0.50f + warmShift, 0.30f, 0.75f);
        out.highlightTintRGB[1] = 0.50f;
        out.highlightTintRGB[2] = PS12ProfileClamp(0.50f - warmShift, 0.30f, 0.75f);
    }

    return out;
}
