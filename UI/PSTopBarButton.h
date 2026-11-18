//
//  PSTopBarButton.h
//  PhotographicStyles12
//
//  Compact top-bar CoreGraphics toggle pill (40 x 32 pt) for iOS 12 Camera.
//  Single tap toggles the style control panel; 0.45s long-press toggles
//  PSState.enabled with a quick visual pulse.
//

#ifndef PS12_TOP_BAR_BUTTON_H
#define PS12_TOP_BAR_BUTTON_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PSTopBarButton;

@protocol PSTopBarButtonDelegate <NSObject>
- (void)topBarButtonDidTap:(PSTopBarButton *)button;
- (void)topBarButtonDidLongPressToggle:(PSTopBarButton *)button;
@end

@interface PSTopBarButton : UIControl

@property (nonatomic, weak, nullable) id<PSTopBarButtonDelegate> delegate;
@property (nonatomic, assign, getter=isPanelOpen) BOOL panelOpen;

/// Updates visual state (Camera Yellow when active, crisp white when off/standard).
- (void)syncWithState;

@end

NS_ASSUME_NONNULL_END

#endif /* PS12_TOP_BAR_BUTTON_H */
