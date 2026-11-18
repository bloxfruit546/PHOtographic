//
//  PSCaptureCoordinator.m
//  PhotographicStyles12
//
//  Serialized, Jetsam-safe capture coordinator with isolated thumbnail context.
//

#import "PSCaptureCoordinator.h"
#import <os/lock.h>

static NSString *const kPS12KeyLivePhotoVideoBaking = @"ps12_v2_bakeLivePhotoMOV";
static const void *kPS12BakeQueueKey = &kPS12BakeQueueKey;

@interface PSCaptureCoordinator () {
    dispatch_queue_t _bakeQueue;
    dispatch_semaphore_t _bakeSemaphore;
    os_unfair_lock _contextLock;
    os_unfair_lock _thumbLock;
    CIContext *_lazyContext;
    CIContext *_thumbnailContext;
    CFAbsoluteTime _lastMemoryWarningTime;
    BOOL _livePhotoVideoBakingEnabled;
}
- (void)ps12_handleMemoryWarning:(NSNotification *)notification;
@end

@implementation PSCaptureCoordinator

+ (instancetype)shared {
    static PSCaptureCoordinator *s_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_instance = [[PSCaptureCoordinator alloc] init];
    });
    return s_instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_SERIAL,
            QOS_CLASS_USER_INITIATED,
            0
        );
        _bakeQueue = dispatch_queue_create("com.ps12.bake.serial", attr);
        dispatch_queue_set_specific(_bakeQueue, kPS12BakeQueueKey, (void *)kPS12BakeQueueKey, NULL);

        _bakeSemaphore = dispatch_semaphore_create(1);
        _contextLock = OS_UNFAIR_LOCK_INIT;
        _thumbLock = OS_UNFAIR_LOCK_INIT;
        _lazyContext = nil;
        _thumbnailContext = nil;
        _lastMemoryWarningTime = 0.0;

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults objectForKey:kPS12KeyLivePhotoVideoBaking] != nil) {
            _livePhotoVideoBakingEnabled = [defaults boolForKey:kPS12KeyLivePhotoVideoBaking];
        } else {
            _livePhotoVideoBakingEnabled = YES;
        }

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(ps12_handleMemoryWarning:)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (dispatch_queue_t)bakeQueue {
    return _bakeQueue;
}

- (BOOL)livePhotoVideoBakingEnabled {
    os_unfair_lock_lock(&_contextLock);
    BOOL enabled = _livePhotoVideoBakingEnabled;
    os_unfair_lock_unlock(&_contextLock);
    return enabled;
}

- (void)setLivePhotoVideoBakingEnabled:(BOOL)livePhotoVideoBakingEnabled {
    os_unfair_lock_lock(&_contextLock);
    _livePhotoVideoBakingEnabled = livePhotoVideoBakingEnabled;
    os_unfair_lock_unlock(&_contextLock);
    [[NSUserDefaults standardUserDefaults] setBool:livePhotoVideoBakingEnabled
                                            forKey:kPS12KeyLivePhotoVideoBaking];
}

- (BOOL)isUnderMemoryPressure {
    os_unfair_lock_lock(&_contextLock);
    CFAbsoluteTime last = _lastMemoryWarningTime;
    os_unfair_lock_unlock(&_contextLock);
    if (last <= 0.0) {
        return NO;
    }
    return ((CFAbsoluteTimeGetCurrent() - last) < 10.0);
}

- (CIContext *)lazyBakeContext {
    os_unfair_lock_lock(&_contextLock);
    CIContext *ctx = _lazyContext;
    if (!ctx) {
        NSDictionary *options = @{
            kCIContextCacheIntermediates : @NO,
            kCIContextPriorityRequestLow : @YES,
            kCIContextWorkingColorSpace  : [NSNull null]
        };
        ctx = [CIContext contextWithOptions:options];
        _lazyContext = ctx;
    }
    os_unfair_lock_unlock(&_contextLock);
    return ctx;
}

- (void)performSerializedBake:(void (^)(CIContext *context))bakeBlock {
    if (!bakeBlock) {
        return;
    }
    dispatch_async(_bakeQueue, ^{
        dispatch_semaphore_wait(self->_bakeSemaphore, DISPATCH_TIME_FOREVER);
        @autoreleasepool {
            CIContext *ctx = [self lazyBakeContext];
            if (ctx) {
                bakeBlock(ctx);
            }
        }
        dispatch_semaphore_signal(self->_bakeSemaphore);
    });
}

- (void)performSynchronousSerializedBake:(void (^)(CIContext *context))bakeBlock {
    if (!bakeBlock) {
        return;
    }

    if ([NSThread isMainThread]) {
        [self performThumbnailBake:bakeBlock];
        return;
    }

    if (dispatch_get_specific(kPS12BakeQueueKey) == kPS12BakeQueueKey) {
        @autoreleasepool {
            CIContext *ctx = [self lazyBakeContext];
            if (ctx) {
                bakeBlock(ctx);
            }
        }
        return;
    }

    dispatch_semaphore_wait(_bakeSemaphore, DISPATCH_TIME_FOREVER);
    @autoreleasepool {
        CIContext *ctx = [self lazyBakeContext];
        if (ctx) {
            bakeBlock(ctx);
        }
    }
    dispatch_semaphore_signal(_bakeSemaphore);
}

- (void)performThumbnailBake:(void (^)(CIContext *context))bakeBlock {
    if (!bakeBlock) {
        return;
    }
    os_unfair_lock_lock(&_thumbLock);
    @autoreleasepool {
        if (!_thumbnailContext) {
            NSDictionary *options = @{
                kCIContextCacheIntermediates : @NO,
                kCIContextWorkingColorSpace  : [NSNull null]
            };
            _thumbnailContext = [CIContext contextWithOptions:options];
        }
        if (_thumbnailContext) {
            bakeBlock(_thumbnailContext);
        }
    }
    os_unfair_lock_unlock(&_thumbLock);
}

- (void)releaseCachedContext {
    os_unfair_lock_lock(&_contextLock);
    _lazyContext = nil;
    os_unfair_lock_unlock(&_contextLock);

    os_unfair_lock_lock(&_thumbLock);
    _thumbnailContext = nil;
    os_unfair_lock_unlock(&_thumbLock);
}

- (void)ps12_handleMemoryWarning:(NSNotification *)notification {
    (void)notification;
    os_unfair_lock_lock(&_contextLock);
    _lastMemoryWarningTime = CFAbsoluteTimeGetCurrent();
    _lazyContext = nil;
    os_unfair_lock_unlock(&_contextLock);

    os_unfair_lock_lock(&_thumbLock);
    _thumbnailContext = nil;
    os_unfair_lock_unlock(&_thumbLock);
}

@end
