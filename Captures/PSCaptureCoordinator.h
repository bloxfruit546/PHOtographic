//
//  PSCaptureCoordinator.h
//  PhotographicStyles12
//
//  Serialized, low-memory capture baking coordinator for Apple A7 (1 GB RAM).
//  Uses a dedicated serial queue + semaphore(1) + lazy CIContext with
//  kCIContextCacheIntermediates = NO to prevent Jetsam memory spikes during
//  Live Photo / burst captures, plus an isolated lightweight thumbnail context.
//

#ifndef PS12_CAPTURE_COORDINATOR_H
#define PS12_CAPTURE_COORDINATOR_H

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PSCaptureCoordinator : NSObject

+ (instancetype)shared;

/// Dedicated serial queue for still-image baking.
@property (nonatomic, readonly) dispatch_queue_t bakeQueue;

/// Enables/disables Live Photo companion .MOV grading (default YES).
@property (nonatomic, assign) BOOL livePhotoVideoBakingEnabled;

/// Returns YES if a memory warning occurred within the last 10 seconds.
- (BOOL)isUnderMemoryPressure;

/// Returns the lazily created, low-memory CIContext for full-res capture baking.
- (CIContext *)lazyBakeContext;

/// Executes a baking block asynchronously on bakeQueue under the semaphore.
- (void)performSerializedBake:(void (^)(CIContext *context))bakeBlock;

/// Executes a baking block synchronously on the caller's background thread
/// under the Jetsam-capping semaphore. Never blocks the main thread.
- (void)performSynchronousSerializedBake:(void (^)(CIContext *context))bakeBlock;

/// Executes a fast thumbnail bake using an isolated CIContext guarded by its
/// own lock, completely decoupled from _bakeSemaphore to avoid main-thread stalls.
- (void)performThumbnailBake:(void (^)(CIContext *context))bakeBlock;

/// Releases cached CIContexts under memory pressure.
- (void)releaseCachedContext;

@end

NS_ASSUME_NONNULL_END

#endif /* PS12_CAPTURE_COORDINATOR_H */
