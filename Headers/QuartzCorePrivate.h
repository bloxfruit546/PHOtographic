//
//  QuartzCorePrivate.h
//  PhotographicStyles12
//
//  Private QuartzCore declarations for hardware-accelerated CAFilter color
//  matrix rendering on iOS 12 (arm64, Apple A7).
//

#ifndef PS12_QUARTZ_CORE_PRIVATE_H
#define PS12_QUARTZ_CORE_PRIVATE_H

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

#ifndef PS12_EXTERNAL_CACOLORMATRIX
/// 4x5 row-major color matrix applied to non-premultiplied RGBA values:
///   out.r = m11*r + m12*g + m13*b + m14*a + m15
///   out.g = m21*r + m22*g + m23*b + m24*a + m25
///   out.b = m31*r + m32*g + m33*b + m34*a + m35
///   out.a = m41*r + m42*g + m43*b + m44*a + m45
/// Declared with explicit struct tag `CAColorMatrix` so `@encode(CAColorMatrix)`
/// evaluates strictly to `{CAColorMatrix=ffffffffffffffffffff}`.
struct CAColorMatrix {
    float m11, m12, m13, m14, m15;
    float m21, m22, m23, m24, m25;
    float m31, m32, m33, m34, m35;
    float m41, m42, m43, m44, m45;
};
typedef struct CAColorMatrix CAColorMatrix;
#endif

static inline CAColorMatrix PS12CAColorMatrixIdentity(void) {
    CAColorMatrix m = {
        1.0f, 0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 1.0f, 0.0f
    };
    return m;
}

@interface NSValue (PS12CAColorMatrix)
+ (NSValue *)valueWithCAColorMatrix:(CAColorMatrix)t;
- (CAColorMatrix)CAColorMatrixValue;
@end

@interface CAFilter : NSObject <NSCopying, NSMutableCopying>

+ (nullable instancetype)filterWithType:(NSString *)type;
+ (nullable instancetype)filterWithName:(NSString *)name;

@property (nullable, copy) NSString *name;
@property (nullable, readonly, copy) NSString *type;
@property (getter=isEnabled) BOOL enabled;
@property BOOL cachesInputImage;

@end

NS_ASSUME_NONNULL_END

#endif /* PS12_QUARTZ_CORE_PRIVATE_H */
