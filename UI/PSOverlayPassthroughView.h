//
//  PSOverlayPassthroughView.h
//  PhotographicStyles12
//
//  Touch-passthrough overlay container for CAMViewfinderViewController.
//  Hosts PSTopBarButton and PSStyleControlPanel; all other touches pass
//  through untouched to stock Camera and Iris Live Photo gestures.
//

#ifndef PS12_OVERLAY_PASSTHROUGH_VIEW_H
#define PS12_OVERLAY_PASSTHROUGH_VIEW_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PSPreviewBackdropView;

@interface PSOverlayPassthroughView : UIView

/// Weak reference to CAMPreviewView for backdrop coordinate alignment.
@property (nonatomic, weak, nullable) UIView *targetPreviewView;

/// Isolated CABackdropLayer view positioned behind UI controls.
@property (nonatomic, strong, readonly) PSPreviewBackdropView *backdropView;

/// Synchronizes top-bar button and control panel with PSState.
- (void)syncWithState;

@end

NS_ASSUME_NONNULL_END

#endif /* PS12_OVERLAY_PASSTHROUGH_VIEW_H */
