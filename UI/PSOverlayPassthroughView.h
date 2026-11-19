//
//  PSOverlayPassthroughView.h
//  PhotographicStyles12
//
//  Touch-passthrough overlay container for CAMViewfinderViewController.
//  Hosts PSOpticalPreviewView (behind controls), PSTopBarButton, and lazily
//  instantiated PSStyleControlPanel.
//

#ifndef PS12_OVERLAY_PASSTHROUGH_VIEW_H
#define PS12_OVERLAY_PASSTHROUGH_VIEW_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PSOpticalPreviewView;

@interface PSOverlayPassthroughView : UIView

/// Weak reference to CAMPreviewView for optical veil frame alignment.
@property (nonatomic, weak, nullable) UIView *targetPreviewView;

/// Zero-readback optical preview veil positioned strictly behind UI controls.
@property (nonatomic, strong, readonly) PSOpticalPreviewView *opticalPreviewView;

/// Synchronizes top-bar button and control panel with PSState.
- (void)syncWithState;

@end

NS_ASSUME_NONNULL_END

#endif /* PS12_OVERLAY_PASSTHROUGH_VIEW_H */
