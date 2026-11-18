//
//  PSMatrixPadView.h
//  PhotographicStyles12
//
//  iPhone 16+ 2D Tone (Y) x Color (X) matrix pad drawn 100% with CoreGraphics.
//  Includes gesture isolation so dragging never triggers Camera mode swipes,
//  and double-tap resets (tone, color) to the active preset's defaults.
//

#ifndef PS12_MATRIX_PAD_VIEW_H
#define PS12_MATRIX_PAD_VIEW_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PSMatrixPadView;

@protocol PSMatrixPadViewDelegate <NSObject>
- (void)matrixPadView:(PSMatrixPadView *)padView
       didChangeColor:(float)color
                 tone:(float)tone
           isFinished:(BOOL)finished;
- (void)matrixPadViewDidRequestDoubleTapReset:(PSMatrixPadView *)padView;
@end

@interface PSMatrixPadView : UIView

@property (nonatomic, weak, nullable) id<PSMatrixPadViewDelegate> delegate;

@property (nonatomic, assign) float color;   // -1.0 .. +1.0 (X)
@property (nonatomic, assign) float tone;    // -1.0 .. +1.0 (Y, + is up)
@property (nonatomic, assign) float palette; //  0.0 ..  1.0

/// Updates corner radial glow colors from the active preset definition.
- (void)configureForPresetIndex:(NSInteger)presetIndex;

/// Sets both axes at once and triggers redraw.
- (void)setColor:(float)color tone:(float)tone palette:(float)palette;

@end

NS_ASSUME_NONNULL_END

#endif /* PS12_MATRIX_PAD_VIEW_H */
