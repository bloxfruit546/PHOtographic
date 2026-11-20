//
//  PSPhotographicStyleFilter.h
//  PhotographicStyles12
//
//  Custom CIFilter wrapping PSColorEngine's exact CIColorKernel for 1:1
//  pixel-accurate live viewfinder preview inside CameraUI's native effect pipeline.
//

#ifndef PS12_PHOTOGRAPHIC_STYLE_FILTER_H
#define PS12_PHOTOGRAPHIC_STYLE_FILTER_H

#import <CoreImage/CoreImage.h>

NS_ASSUME_NONNULL_BEGIN

@interface PSPhotographicStyleFilter : CIFilter

@property (nonatomic, strong, nullable) CIImage *inputImage;

@end

NS_ASSUME_NONNULL_END

#endif /* PS12_PHOTOGRAPHIC_STYLE_FILTER_H */
