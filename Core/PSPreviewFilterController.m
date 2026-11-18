//
//  PSPreviewFilterController.m
//  PhotographicStyles12
//
//  Hardware-accelerated 60fps CAFilter controller for CAMPreviewView.
//

#import "PSPreviewFilterController.h"
#import "PSState.h"
#import "CameraUI12.h"
#import "QuartzCorePrivate.h"
#import <objc/runtime.h>

// Alphanumeric name without dots so CALayer KVC keypath
// `filters.ps12LiveMatrix.inputColorMatrix` resolves cleanly on iOS 12.
static NSString *const kPS12LiveFilterName = @"ps12LiveMatrix";
static NSString *const kPS12LiveFilterKeyPath = @"filters.ps12LiveMatrix.inputColorMatrix";

@interface PSPreviewFilterController ()
- (nullable CALayer *)ps12_targetLayerForPreviewView:(nullable UIView *)previewView;
- (nullable CAFilter *)ps12_findExistingFilterInArray:(nullable NSArray *)filters;
- (NSValue *)ps12_boxedMatrix:(CAColorMatrix)matrix;
@end

@implementation PSPreviewFilterController

+ (instancetype)shared {
    static PSPreviewFilterController *s_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_instance = [[PSPreviewFilterController alloc] init];
    });
    return s_instance;
}

- (nullable CALayer *)ps12_targetLayerForPreviewView:(nullable UIView *)previewView {
    if (!previewView) {
        return nil;
    }

    if ([previewView respondsToSelector:@selector(videoPreviewLayer)]) {
        @try {
            id layer = [(CAMPreviewView *)previewView videoPreviewLayer];
            if ([layer isKindOfClass:[CALayer class]]) {
                return (CALayer *)layer;
            }
        } @catch (NSException *exception) {
            (void)exception;
        }
    }

    if ([previewView respondsToSelector:@selector(previewLayer)]) {
        @try {
            id layer = [(CAMPreviewView *)previewView previewLayer];
            if ([layer isKindOfClass:[CALayer class]]) {
                return (CALayer *)layer;
            }
        } @catch (NSException *exception) {
            (void)exception;
        }
    }

    return previewView.layer;
}

- (nullable CAFilter *)ps12_findExistingFilterInArray:(nullable NSArray *)filters {
    for (id item in filters) {
        if ([item respondsToSelector:@selector(name)]) {
            @try {
                NSString *name = [item valueForKey:@"name"];
                if ([name isKindOfClass:[NSString class]] && [name isEqualToString:kPS12LiveFilterName]) {
                    return (CAFilter *)item;
                }
            } @catch (NSException *exception) {
                (void)exception;
            }
        }
    }
    return nil;
}

- (NSValue *)ps12_boxedMatrix:(CAColorMatrix)matrix {
    if ([NSValue respondsToSelector:@selector(valueWithCAColorMatrix:)]) {
        return [NSValue valueWithCAColorMatrix:matrix];
    }
    return [NSValue valueWithBytes:&matrix objCType:@encode(CAColorMatrix)];
}

- (void)refreshOnPreviewView:(nullable UIView *)previewView {
    CALayer *targetLayer = [self ps12_targetLayerForPreviewView:previewView];
    if (!targetLayer) {
        return;
    }

    PSState *state = [PSState shared];
    if (![state isEnabled]) {
        [self detachFromPreviewView:previewView];
        return;
    }

    Class caFilterClass = NSClassFromString(@"CAFilter");
    if (!caFilterClass || ![caFilterClass respondsToSelector:@selector(filterWithType:)]) {
        return;
    }

    CAColorMatrix matrix = [state previewMatrixForCurrentState];
    NSValue *matrixValue = [self ps12_boxedMatrix:matrix];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    NSArray *existingFilters = targetLayer.filters;
    CAFilter *existing = [self ps12_findExistingFilterInArray:existingFilters];

    if (existing) {
        @try {
            [existing setValue:@YES forKey:@"enabled"];
            [existing setValue:matrixValue forKey:@"inputColorMatrix"];
            [targetLayer setValue:matrixValue forKeyPath:kPS12LiveFilterKeyPath];
        } @catch (NSException *exception) {
            (void)exception;
        }
    } else {
        @try {
            CAFilter *filter = [caFilterClass filterWithType:@"colorMatrix"];
            if (filter) {
                [filter setValue:kPS12LiveFilterName forKey:@"name"];
                [filter setValue:@YES forKey:@"enabled"];
                [filter setValue:matrixValue forKey:@"inputColorMatrix"];

                NSMutableArray *updated = existingFilters ? [existingFilters mutableCopy] : [NSMutableArray arrayWithCapacity:1];
                [updated addObject:filter];
                targetLayer.filters = [updated copy];
            }
        } @catch (NSException *exception) {
            (void)exception;
        }
    }

    [CATransaction commit];
}

- (void)detachFromPreviewView:(nullable UIView *)previewView {
    CALayer *targetLayer = [self ps12_targetLayerForPreviewView:previewView];
    if (!targetLayer) {
        return;
    }

    NSArray *existingFilters = targetLayer.filters;
    if (!existingFilters || existingFilters.count == 0) {
        return;
    }

    NSMutableArray *preserved = [NSMutableArray arrayWithCapacity:existingFilters.count];
    BOOL removedAny = NO;

    for (id item in existingFilters) {
        BOOL isOurs = NO;
        if ([item respondsToSelector:@selector(name)]) {
            @try {
                NSString *name = [item valueForKey:@"name"];
                if ([name isKindOfClass:[NSString class]] && [name isEqualToString:kPS12LiveFilterName]) {
                    isOurs = YES;
                }
            } @catch (NSException *exception) {
                (void)exception;
            }
        }
        if (isOurs) {
            removedAny = YES;
        } else {
            [preserved addObject:item];
        }
    }

    if (!removedAny) {
        return;
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    targetLayer.filters = (preserved.count > 0) ? [preserved copy] : nil;
    [CATransaction commit];
}

@end
