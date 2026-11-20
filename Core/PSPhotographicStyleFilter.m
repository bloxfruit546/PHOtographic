//
//  PSPhotographicStyleFilter.m
//  PhotographicStyles12
//
//  Custom CIFilter wrapping PSColorEngine's exact CIColorKernel.
//

#import "PSPhotographicStyleFilter.h"
#import "PSState.h"
#import "PSColorProfile.h"
#import "PSColorEngine.h"

@implementation PSPhotographicStyleFilter

@synthesize inputImage = _inputImage;

- (id)copyWithZone:(nullable NSZone *)zone {
    PSPhotographicStyleFilter *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        copy.inputImage = self.inputImage;
    }
    return copy;
}

- (nullable CIImage *)outputImage {
    CIImage *src = self.inputImage;
    if (!src) {
        return nil;
    }

    PSRenderSnapshot snap = [[PSState shared] snapshot];
    PSResolvedParameters params = PSResolveParameters(snap);
    if (params.isIdentity) {
        return src;
    }

    CIImage *clamped = [src imageByClampingToExtent];
    CIImage *graded = [[PSColorEngine shared] applyKernelToImage:clamped withParameters:params];
    if (!graded) {
        return src;
    }
    return [graded imageByCroppingToRect:src.extent];
}

@end
