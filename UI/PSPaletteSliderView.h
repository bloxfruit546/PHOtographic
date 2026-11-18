//
//  PSPaletteSliderView.h
//  PhotographicStyles12
//
//  Slim horizontal capsule slider (28pt height, 8pt track, 20pt thumb)
//  controlling Palette intensity (0.0 .. 1.0) with gesture isolation.
//

#ifndef PS12_PALETTE_SLIDER_VIEW_H
#define PS12_PALETTE_SLIDER_VIEW_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PSPaletteSliderView;

@protocol PSPaletteSliderViewDelegate <NSObject>
- (void)paletteSliderView:(PSPaletteSliderView *)sliderView
         didChangePalette:(float)palette
               isFinished:(BOOL)finished;
@end

@interface PSPaletteSliderView : UIView

@property (nonatomic, weak, nullable) id<PSPaletteSliderViewDelegate> delegate;
@property (nonatomic, assign) float palette; // 0.0 .. 1.0

/// Updates track gradient tint from the active preset definition.
- (void)configureForPresetIndex:(NSInteger)presetIndex;

@end

NS_ASSUME_NONNULL_END

#endif /* PS12_PALETTE_SLIDER_VIEW_H */
