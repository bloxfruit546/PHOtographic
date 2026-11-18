//
//  PSPresetStripView.h
//  PhotographicStyles12
//
//  Horizontal 15-preset capsule carousel with CoreGraphics dual-tone swatches,
//  category divider (UNDERTONES | MOOD), and Camera mode-swipe isolation.
//

#ifndef PS12_PRESET_STRIP_VIEW_H
#define PS12_PRESET_STRIP_VIEW_H

#import <UIKit/UIKit.h>
#import "PSColorProfile.h"

NS_ASSUME_NONNULL_BEGIN

@class PSPresetStripView;

@protocol PSPresetStripViewDelegate <NSObject>
- (void)presetStripView:(PSPresetStripView *)stripView didSelectPresetAtIndex:(NSInteger)presetIndex;
@end

@interface PSPresetStripView : UIView

@property (nonatomic, weak, nullable) id<PSPresetStripViewDelegate> delegate;
@property (nonatomic, assign) NSInteger selectedPresetIndex;

- (void)setSelectedPresetIndex:(NSInteger)selectedPresetIndex animated:(BOOL)animated;
- (void)scrollToCategory:(PSStyleCategory)category animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END

#endif /* PS12_PRESET_STRIP_VIEW_H */
