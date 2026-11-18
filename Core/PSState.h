//
//  PSState.h
//  PhotographicStyles12
//
//  Thread-safe state singleton for PhotographicStyles12 v2.
//  All property reads/writes are guarded by os_unfair_lock so UI gestures on
//  the main thread and background capture baking never observe torn state.
//

#ifndef PS12_STATE_H
#define PS12_STATE_H

#import <Foundation/Foundation.h>
#import "QuartzCorePrivate.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct PSRenderSnapshot {
    BOOL enabled;
    NSInteger presetIndex;
    float tone;
    float color;
    float palette;
} PSRenderSnapshot;

@interface PSState : NSObject

+ (instancetype)shared;

@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
@property (nonatomic, assign) NSInteger presetIndex;
@property (nonatomic, assign) float tone;
@property (nonatomic, assign) float color;
@property (nonatomic, assign) float palette;

/// Atomically returns a value-type snapshot of the current style state.
- (PSRenderSnapshot)snapshot;

/// Atomically updates both tone (-1..1) and color (-1..1) under lock for 60fps drag.
- (void)setTone:(float)tone color:(float)color;

/// Selects a preset (0..14), optionally snapping tone/color/palette to its defaults,
/// and enables styling.
- (void)selectPresetAtIndex:(NSInteger)presetIndex resetToPresetDefaults:(BOOL)resetDefaults;

/// Snaps tone, color, and palette back to the active preset's defaults.
- (void)resetCurrentPresetToDefaults;

/// Returns YES if tone, color, or palette differs from the active preset's defaults.
- (BOOL)isCurrentPresetModifiedFromDefaults;

/// Computes the 4x5 QuartzCore color matrix for the current state.
/// Returns identity when disabled or when tone == 0 and color == 0.
- (CAColorMatrix)previewMatrixForCurrentState;

/// Computes the 4x5 QuartzCore color matrix for an arbitrary snapshot.
+ (CAColorMatrix)previewMatrixForSnapshot:(PSRenderSnapshot)snapshot;

/// Persists current state to NSUserDefaults immediately.
- (void)saveNow;

@end

NS_ASSUME_NONNULL_END

#endif /* PS12_STATE_H */
