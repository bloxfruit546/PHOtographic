//
//  PSOpticalPreviewView.h
//  PhotographicStyles12
//
//  Zero-readback GPU-composited optical grading veil for iPhone 5s (iOS 12).
//  Uses only standard translucent CALayer / CAGradientLayer sublayers so
//  mediaserverd and backboardd stay 100% in hardware zero-copy YUV scanout.
//

#ifndef PS12_OPTICAL_PREVIEW_VIEW_H
#define PS12_OPTICAL_PREVIEW_VIEW_H

#import <UIKit/UIKit.h>
#import "PSState.h"

NS_ASSUME_NONNULL_BEGIN

@interface PSOpticalPreviewView : UIView

/// Updates the zero-readback optical veil for the given render snapshot.
/// When disabled or identity, hides the view completely (0 composited layers).
- (void)applySnapshot:(PSRenderSnapshot)snapshot;

@end

NS_ASSUME_NONNULL_END

#endif /* PS12_OPTICAL_PREVIEW_VIEW_H */
