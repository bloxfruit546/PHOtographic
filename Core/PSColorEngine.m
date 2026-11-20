//
//  PSColorEngine.m
//  PhotographicStyles12
//
//  Unified iPhone 16 Pro Max Color Science Engine (CAColorMatrix + CIColorKernel).
//

#import "PSColorEngine.h"
#import <math.h>

static inline float PS12EngineClamp(float v, float lo, float hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static NSString *const kPS12ColorKernelSource =
@"kernel vec4 ps12StyleKernel(__sample s, vec4 uTone, vec4 uColor, vec4 uSplit, vec4 uShade, vec4 uGlow) {\n"
@"    vec4 src = unpremultiply(s);\n"
@"    vec3 c = clamp(src.rgb, 0.0, 1.0);\n"
@"\n"
@"    float exposure    = uTone.x;\n"
@"    float contrast    = uTone.y;\n"
@"    float blackLift   = uTone.z;\n"
@"    float skinProtect = uTone.w;\n"
@"\n"
@"    float sat      = uColor.x;\n"
@"    float vibrance = uColor.y;\n"
@"    float warmth   = uColor.z;\n"
@"    float tint     = uColor.w;\n"
@"\n"
@"    float splitAmt = uSplit.x;\n"
@"    float monoMix  = uSplit.y;\n"
@"    float toneBias = uSplit.z;\n"
@"\n"
@"    // Soft skin-tone mask (R > G > B, warm hue, mid-luma, moderate chroma)\n"
@"    float lum0 = dot(c, vec3(0.2126, 0.7152, 0.0722));\n"
@"    float rgDiff = smoothstep(0.01, 0.14, c.r - c.g);\n"
@"    float gbDiff = smoothstep(0.00, 0.12, c.g - c.b);\n"
@"    float lumaGate = smoothstep(0.12, 0.28, lum0) * (1.0 - smoothstep(0.82, 0.96, lum0));\n"
@"    float cMax = max(c.r, max(c.g, c.b));\n"
@"    float cMin = min(c.r, min(c.g, c.b));\n"
@"    float satEst = (cMax - cMin) / max(cMax, 0.001);\n"
@"    float chromaGate = smoothstep(0.08, 0.22, satEst) * (1.0 - smoothstep(0.65, 0.88, satEst));\n"
@"    float skinMask = clamp(rgDiff * gbDiff * lumaGate * chromaGate * skinProtect, 0.0, 0.90);\n"
@"\n"
@"    // Midtone/shadow gamma curve (preserves pure black & pure white) + contrast S-curve\n"
@"    float gammaExp = clamp(1.0 - toneBias * 0.28, 0.68, 1.38);\n"
@"    c = pow(max(c, vec3(0.0001)), vec3(gammaExp));\n"
@"    c = c + vec3(exposure * 0.55);\n"
@"    c = (c - vec3(0.5)) * contrast + vec3(0.5);\n"
@"    c = mix(c, vec3(1.0), blackLift * (1.0 - clamp(c, 0.0, 1.0)));\n"
@"    c = clamp(c, 0.0, 1.0);\n"
@"\n"
@"    // Warmth & tint attenuated on protected skin tones\n"
@"    float tempScale = 1.0 - skinMask * 0.75;\n"
@"    c.r += (warmth * 0.12 + tint * 0.04) * tempScale;\n"
@"    c.g += (-tint * 0.06) * tempScale;\n"
@"    c.b += (-warmth * 0.12 + tint * 0.04) * tempScale;\n"
@"    c = clamp(c, 0.0, 1.0);\n"
@"\n"
@"    // Saturation & selective vibrance\n"
@"    float lum1 = dot(c, vec3(0.2126, 0.7152, 0.0722));\n"
@"    float pMax = max(c.r, max(c.g, c.b));\n"
@"    float pMin = min(c.r, min(c.g, c.b));\n"
@"    float curSat = pMax - pMin;\n"
@"    float vibScale = vibrance * (1.0 - curSat) * (1.0 - skinMask * 0.70);\n"
@"    float effSat = clamp(sat + vibScale, 0.0, 2.2);\n"
@"    c = mix(vec3(lum1), c, effSat);\n"
@"    c = clamp(c, 0.0, 1.0);\n"
@"\n"
@"    // Directional shadow / highlight split-toning\n"
@"    float lum2 = dot(c, vec3(0.2126, 0.7152, 0.0722));\n"
@"    float shWeight = (1.0 - smoothstep(0.05, 0.55, lum2)) * splitAmt * 0.35 * (1.0 - skinMask * 0.65);\n"
@"    float hiWeight = smoothstep(0.45, 0.95, lum2) * splitAmt * 0.35 * (1.0 - skinMask * 0.65);\n"
@"    c = c + (uShade.rgb - vec3(0.5)) * shWeight + (uGlow.rgb - vec3(0.5)) * hiWeight;\n"
@"    c = clamp(c, 0.0, 1.0);\n"
@"\n"
@"    // Monochrome blend (STARK B&W)\n"
@"    if (monoMix > 0.001) {\n"
@"        float monoL = dot(c, vec3(0.299, 0.587, 0.114));\n"
@"        vec3 monoRGB = vec3(monoL) + (uGlow.rgb - vec3(0.5)) * smoothstep(0.35, 0.90, monoL) * 0.25;\n"
@"        c = mix(c, clamp(monoRGB, 0.0, 1.0), monoMix);\n"
@"    }\n"
@"\n"
@"    return premultiply(vec4(clamp(c, 0.0, 1.0), src.a));\n"
@"}\n";

@implementation PSColorEngine

+ (instancetype)shared {
    static PSColorEngine *s_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_instance = [[PSColorEngine alloc] init];
    });
    return s_instance;
}

+ (nullable CIColorKernel *)ps12_sharedKernel {
    static CIColorKernel *s_kernel = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_kernel = [CIColorKernel kernelWithString:kPS12ColorKernelSource];
    });
    return s_kernel;
}

+ (CAColorMatrix)colorMatrixForParameters:(PSResolvedParameters)params {
    if (params.isIdentity) {
        return PS12CAColorMatrixIdentity();
    }

    float contrast = PS12EngineClamp(params.contrast, 0.60f, 1.65f);
    float effSat = PS12EngineClamp(params.saturation + params.vibrance * 0.35f, 0.0f, 2.0f);
    effSat *= (1.0f - PS12EngineClamp(params.monoMix, 0.0f, 1.0f));

    float invSat = 1.0f - effSat;
    const float lumR = 0.2126f;
    const float lumG = 0.7152f;
    const float lumB = 0.0722f;

    float sr = invSat * lumR;
    float sg = invSat * lumG;
    float sb = invSat * lumB;

    float rGain = contrast * (1.0f + params.warmth * 0.14f + params.tint * 0.05f);
    float gGain = contrast * (1.0f - params.tint * 0.07f);
    float bGain = contrast * (1.0f - params.warmth * 0.14f + params.tint * 0.05f);

    float splitBiasR = ((params.shadowTintRGB[0] + params.highlightTintRGB[0]) * 0.5f - 0.5f) * params.splitStrength * 0.22f;
    float splitBiasG = ((params.shadowTintRGB[1] + params.highlightTintRGB[1]) * 0.5f - 0.5f) * params.splitStrength * 0.22f;
    float splitBiasB = ((params.shadowTintRGB[2] + params.highlightTintRGB[2]) * 0.5f - 0.5f) * params.splitStrength * 0.22f;

    float baseBias = 0.5f * (1.0f - contrast) + params.exposure * contrast + params.blackPointLift * 0.5f;

    CAColorMatrix m;
    m.m11 = rGain * (sr + effSat);
    m.m12 = rGain * sg;
    m.m13 = rGain * sb;
    m.m14 = 0.0f;
    m.m15 = PS12EngineClamp(baseBias + splitBiasR, -0.45f, 0.45f);

    m.m21 = gGain * sr;
    m.m22 = gGain * (sg + effSat);
    m.m23 = gGain * sb;
    m.m24 = 0.0f;
    m.m25 = PS12EngineClamp(baseBias + splitBiasG, -0.45f, 0.45f);

    m.m31 = bGain * sr;
    m.m32 = bGain * sg;
    m.m33 = bGain * (sb + effSat);
    m.m34 = 0.0f;
    m.m35 = PS12EngineClamp(baseBias + splitBiasB, -0.45f, 0.45f);

    m.m41 = 0.0f;
    m.m42 = 0.0f;
    m.m43 = 0.0f;
    m.m44 = 1.0f;
    m.m45 = 0.0f;

    return m;
}

- (nullable CIImage *)applyKernelToImage:(nullable CIImage *)source
                          withParameters:(PSResolvedParameters)params {
    if (!source || params.isIdentity) {
        return source;
    }

    CIColorKernel *kernel = [PSColorEngine ps12_sharedKernel];
    if (!kernel) {
        return source;
    }

    CIVector *uTone = [CIVector vectorWithX:params.exposure
                                          Y:params.contrast
                                          Z:params.blackPointLift
                                          W:params.skinProtectStrength];
    CIVector *uColor = [CIVector vectorWithX:params.saturation
                                           Y:params.vibrance
                                           Z:params.warmth
                                           W:params.tint];
    CIVector *uSplit = [CIVector vectorWithX:params.splitStrength
                                           Y:params.monoMix
                                           Z:params.toneBias
                                           W:0.0];
    CIVector *uShade = [CIVector vectorWithX:params.shadowTintRGB[0]
                                           Y:params.shadowTintRGB[1]
                                           Z:params.shadowTintRGB[2]
                                           W:0.0];
    CIVector *uGlow = [CIVector vectorWithX:params.highlightTintRGB[0]
                                          Y:params.highlightTintRGB[1]
                                          Z:params.highlightTintRGB[2]
                                          W:0.0];

    CIImage *output = [kernel applyWithExtent:source.extent
                                    arguments:@[source, uTone, uColor, uSplit, uShade, uGlow]];
    return output ?: source;
}

- (nullable CIImage *)filteredImage:(nullable CIImage *)source
                        forSnapshot:(PSRenderSnapshot)snapshot {
    PSResolvedParameters params = PSResolveParameters(snapshot);
    return [self applyKernelToImage:source withParameters:params];
}

- (nullable UIImage *)processCapturedImage:(nullable UIImage *)image
                               forSnapshot:(PSRenderSnapshot)snapshot
                              usingContext:(CIContext *)context {
    if (!image || !context) {
        return image;
    }

    PSResolvedParameters params = PSResolveParameters(snapshot);
    if (params.isIdentity) {
        return image;
    }

    CIImage *ciInput = nil;
    if (image.CGImage) {
        ciInput = [CIImage imageWithCGImage:image.CGImage];
    } else if (image.CIImage) {
        ciInput = image.CIImage;
    }
    if (!ciInput) {
        return image;
    }

    UIImage *resultImage = image;
    @autoreleasepool {
        CIImage *ciOutput = [self applyKernelToImage:ciInput withParameters:params];
        if (ciOutput) {
            CGImageRef cgOut = [context createCGImage:ciOutput fromRect:ciInput.extent];
            if (cgOut) {
                resultImage = [UIImage imageWithCGImage:cgOut
                                                  scale:image.scale
                                            orientation:image.imageOrientation];
                CGImageRelease(cgOut);
            }
        }
    }
    return resultImage ?: image;
}

@end
