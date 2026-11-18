//
//  PSPreviewFilterController.h
//  PhotographicStyles12
//
//  Zero-session-intrusion viewfinder preview controller.
//  Attaches and updates a named QuartzCore CAFilter ("colorMatrix") on
//  CAMPreviewView's video layer without touching AVCaptureSession or CIContext.
//

#ifndef PS12_PREVIEW_FILTER_CONTROLLER_H
#define PS12_PREVIEW_FILTER_CONTROLLER_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PSPreviewFilterController : NSObject

+ (instancetype)shared;

/// Attaches or updates the named CAFilter on the preview view's target layer
/// while preserving any existing filters (e.g., mode-switch blur or Iris FX).
- (void)refreshOnPreviewView:(nullable UIView *)previewView;

/// Removes our named CAFilter from the preview view's target layer while
/// preserving all other filters.
- (void)detachFromPreviewView:(nullable UIView *)previewView;

@end

NS_ASSUME_NONNULL_END

#endif /* PS12_PREVIEW_FILTER_CONTROLLER_H */
