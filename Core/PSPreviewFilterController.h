//
//  PSPreviewFilterController.h
//  PhotographicStyles12
//
//  Zero-readback viewfinder preview controller for Apple A7 (iOS 12).
//  Drives PSOpticalPreviewView (pure GPU-composited translucent CALayers)
//  without touching CAMPreviewView, CABackdropLayer, or CAFilter.
//

#ifndef PS12_PREVIEW_FILTER_CONTROLLER_H
#define PS12_PREVIEW_FILTER_CONTROLLER_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PSOpticalPreviewView;

@interface PSPreviewFilterController : NSObject

+ (instancetype)shared;

@property (nonatomic, weak, nullable) PSOpticalPreviewView *opticalPreviewView;

/// YES when CameraUI's native CAMEffectsFullsizeView is actively rendering
/// PSPhotographicStyleFilter 1:1, suppressing the fallback optical veil.
@property (nonatomic, assign) BOOL nativeEffectsViewActive;

/// Refreshes the optical preview view with the current PSState snapshot.
- (void)refreshOnOpticalView:(nullable PSOpticalPreviewView *)opticalView;

/// Forwards refresh to self.opticalPreviewView without touching previewView's layers.
- (void)refreshOnPreviewView:(nullable UIView *)previewView;

/// Hides the optical preview view completely.
- (void)detachFromOpticalView:(nullable PSOpticalPreviewView *)opticalView;

/// Forwards detach to self.opticalPreviewView without touching previewView's layers.
- (void)detachFromPreviewView:(nullable UIView *)previewView;

@end

NS_ASSUME_NONNULL_END

#endif /* PS12_PREVIEW_FILTER_CONTROLLER_H */
