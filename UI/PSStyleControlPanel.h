//
//  PSStyleControlPanel.h
//  PhotographicStyles12
//
//  Floating dark-glass Photographic Styles control card (304 x 252 pt)
//  designed for 4-inch 320x568 pt iPhone 5s viewfinders and larger screens.
//

#ifndef PS12_STYLE_CONTROL_PANEL_H
#define PS12_STYLE_CONTROL_PANEL_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PSStyleControlPanel;

@protocol PSStyleControlPanelDelegate <NSObject>
- (void)styleControlPanelDidChangeRenderState:(PSStyleControlPanel *)panel;
- (void)styleControlPanelDidRequestCollapse:(PSStyleControlPanel *)panel;
@end

@interface PSStyleControlPanel : UIView

@property (nonatomic, weak, nullable) id<PSStyleControlPanelDelegate> delegate;

/// Synchronizes all subviews (pad, slider, preset strip, telemetry, reset button)
/// with the current PSState.
- (void)syncWithStateAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END

#endif /* PS12_STYLE_CONTROL_PANEL_H */
