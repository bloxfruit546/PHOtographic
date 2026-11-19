//
//  PSPreviewBackdropView.h
//  PhotographicStyles12
//
//  Isolated CABackdropLayer overlay for 60fps viewfinder color grading
//  without mutating CAMPreviewView / AVCaptureVideoPreviewLayer.
//

#ifndef PS12_PREVIEW_BACKDROP_VIEW_H
#define PS12_PREVIEW_BACKDROP_VIEW_H

#import <UIKit/UIKit.h>
#import "QuartzCorePrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface PSPreviewBackdropView : UIView

/// Applies a 4x5 CAColorMatrix to the isolated CABackdropLayer.
/// When active is NO, hides the view, disables the backdrop layer, and clears
/// its filters so idle RAM/GPU cost is zero.
- (void)applyColorMatrix:(CAColorMatrix)matrix active:(BOOL)active;

@end

NS_ASSUME_NONNULL_END

#endif /* PS12_PREVIEW_BACKDROP_VIEW_H */
