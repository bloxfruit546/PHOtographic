//
//  PSPreviewBackdropView.m
//  PhotographicStyles12
//
//  Isolated CABackdropLayer overlay for 60fps viewfinder color grading
//  without mutating CAMPreviewView / AVCaptureVideoPreviewLayer.
//

#import "PSPreviewBackdropView.h"
#import <string.h>

static NSString *const kPS12BackdropFilterName = @"ps12LiveMatrix";
static NSString *const kPS12BackdropFilterKeyPath = @"filters.ps12LiveMatrix.inputColorMatrix";

@interface PSPreviewBackdropView () {
    BOOL _hasApplied;
    BOOL _lastActive;
    CAColorMatrix _lastMatrix;
}
- (nullable CAFilter *)ps12_findFilterInArray:(nullable NSArray *)filters;
- (NSValue *)ps12_boxedMatrix:(CAColorMatrix)matrix;
- (void)ps12_configureBackdropLayer:(CALayer *)layer enabled:(BOOL)enabled;
@end

@implementation PSPreviewBackdropView

+ (Class)layerClass {
    Class backdropClass = NSClassFromString(@"CABackdropLayer");
    return backdropClass ?: [CALayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.hidden = YES;
        _hasApplied = NO;
        _lastActive = NO;
        _lastMatrix = PS12CAColorMatrixIdentity();
        [self ps12_configureBackdropLayer:self.layer enabled:NO];
    }
    return self;
}

- (void)ps12_configureBackdropLayer:(CALayer *)layer enabled:(BOOL)enabled {
    if (!layer) {
        return;
    }
    @try {
        if ([layer respondsToSelector:@selector(setScale:)]) {
            [(CABackdropLayer *)layer setScale:0.5];
        }
        if ([layer respondsToSelector:@selector(setAllowsInPlaceFiltering:)]) {
            [(CABackdropLayer *)layer setAllowsInPlaceFiltering:YES];
        }
        if ([layer respondsToSelector:@selector(setEnabled:)]) {
            [(CABackdropLayer *)layer setEnabled:enabled];
        }
    } @catch (NSException *exception) {
        (void)exception;
    }
}

- (nullable CAFilter *)ps12_findFilterInArray:(nullable NSArray *)filters {
    for (id item in filters) {
        if ([item respondsToSelector:@selector(name)]) {
            @try {
                NSString *name = [item valueForKey:@"name"];
                if ([name isKindOfClass:[NSString class]] && [name isEqualToString:kPS12BackdropFilterName]) {
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

- (void)applyColorMatrix:(CAColorMatrix)matrix active:(BOOL)active {
    if (_hasApplied && _lastActive == active) {
        if (!active || memcmp(&matrix, &_lastMatrix, sizeof(CAColorMatrix)) == 0) {
            return;
        }
    }

    _hasApplied = YES;
    _lastActive = active;
    _lastMatrix = matrix;

    CALayer *layer = self.layer;
    if (!layer) {
        return;
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    if (!active) {
        self.hidden = YES;
        [self ps12_configureBackdropLayer:layer enabled:NO];
        if (layer.filters.count > 0) {
            layer.filters = nil;
        }
        [CATransaction commit];
        return;
    }

    Class caFilterClass = NSClassFromString(@"CAFilter");
    if (!caFilterClass || ![caFilterClass respondsToSelector:@selector(filterWithType:)]) {
        self.hidden = YES;
        [CATransaction commit];
        return;
    }

    self.hidden = NO;
    [self ps12_configureBackdropLayer:layer enabled:YES];

    NSValue *matrixValue = [self ps12_boxedMatrix:matrix];
    CAFilter *existing = [self ps12_findFilterInArray:layer.filters];
    if (existing) {
        @try {
            [existing setValue:@YES forKey:@"enabled"];
            [existing setValue:matrixValue forKey:@"inputColorMatrix"];
            [layer setValue:matrixValue forKeyPath:kPS12BackdropFilterKeyPath];
        } @catch (NSException *exception) {
            (void)exception;
        }
    } else {
        @try {
            CAFilter *filter = [caFilterClass filterWithType:@"colorMatrix"];
            if (filter) {
                [filter setValue:kPS12BackdropFilterName forKey:@"name"];
                [filter setValue:@YES forKey:@"enabled"];
                [filter setValue:matrixValue forKey:@"inputColorMatrix"];
                layer.filters = @[ filter ];
            }
        } @catch (NSException *exception) {
            (void)exception;
        }
    }

    [CATransaction commit];
}

@end
