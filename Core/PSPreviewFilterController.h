//
//  PSPreviewFilterController.h
//  PhotographicStyles12
//
//  Zero-mediaserverd-intrusion viewfinder preview controller.
//  Drives an isolated CABackdropLayer view (PSPreviewBackdropView) without
//  ever mutating CAMPreviewView or AVCaptureVideoPreviewLayer.
//

#ifndef PS12_PREVIEW_FILTER_CONTROLLER_H
#define PS12_PREVIEW_FILTER_CONTROLLER_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PSPreviewBackdropView;

@interface PSPreviewFilterController : NSObject

+ (instancetype)shared;

@property (nonatomic, weak, nullable) PSPreviewBackdropView *backdropView;

/// Refreshes the active style matrix on the given backdrop view (or self.backdropView).
- (void)refreshOnBackdropView:(nullable PSPreviewBackdropView *)backdropView;

/// Forwards refresh to self.backdropView without touching previewView's layers.
- (void)refreshOnPreviewView:(nullable UIView *)previewView;

/// Disables and clears the filter on the given backdrop view.
- (void)detachFromBackdropView:(nullable PSPreviewBackdropView *)backdropView;

/// Forwards detach to self.backdropView without touching previewView's layers.
- (void)detachFromPreviewView:(nullable UIView *)previewView;

@end

NS_ASSUME_NONNULL_END

#endif /* PS12_PREVIEW_FILTER_CONTROLLER_H */
