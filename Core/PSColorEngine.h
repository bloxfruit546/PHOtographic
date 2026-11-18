//
//  PSColorEngine.h
//  PhotographicStyles12
//
//  Unified iPhone 16 Pro Max Color Science Engine:
//    - 60fps 4x5 CAColorMatrix synthesis for QuartzCore viewfinder preview.
//    - Full-precision CIColorKernel (CIKL) with parametric tone, vibrance,
//      split-toning, monochrome blend, and smoothstep skin-tone protection.
//

#ifndef PS12_COLOR_ENGINE_H
#define PS12_COLOR_ENGINE_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreImage/CoreImage.h>
#import "QuartzCorePrivate.h"
#import "PSColorProfile.h"

NS_ASSUME_NONNULL_BEGIN

@interface PSColorEngine : NSObject

+ (instancetype)shared;

/// Synthesizes a 4x5 QuartzCore CAColorMatrix from resolved parameters
/// for zero-copy 60fps viewfinder preview.
+ (CAColorMatrix)colorMatrixForParameters:(PSResolvedParameters)params;

/// Applies the full-precision CIColorKernel pipeline to a CIImage.
/// Returns `source` untouched when params.isIdentity is YES.
- (nullable CIImage *)applyKernelToImage:(nullable CIImage *)source
                          withParameters:(PSResolvedParameters)params;

/// Convenience helper resolving `snapshot` and applying the kernel.
- (nullable CIImage *)filteredImage:(nullable CIImage *)source
                        forSnapshot:(PSRenderSnapshot)snapshot;

/// Bakes the active style into a captured UIImage using the supplied CIContext,
/// preserving exact scale and UIImageOrientation.
- (nullable UIImage *)processCapturedImage:(nullable UIImage *)image
                               forSnapshot:(PSRenderSnapshot)snapshot
                              usingContext:(CIContext *)context;

@end

NS_ASSUME_NONNULL_END

#endif /* PS12_COLOR_ENGINE_H */
