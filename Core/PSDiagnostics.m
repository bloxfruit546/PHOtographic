//
//  PSDiagnostics.m
//  PhotographicStyles12
//
//  Thread-safe, size-capped on-device exception logger for Camera.app.
//

#import "PSDiagnostics.h"
#import <os/lock.h>

static NSString *const kPS12LogPath = @"/var/mobile/Library/Logs/PhotographicStyles12.log";
static const unsigned long long kPS12MaxLogBytes = 64ULL * 1024ULL;
static os_unfair_lock s_logLock = OS_UNFAIR_LOCK_INIT;

void PS12LogException(NSString *context, NSException *exception) {
    if (!exception) {
        return;
    }

    @try {
        NSString *safeContext = context.length > 0 ? context : @"UnknownContext";
        NSString *name = exception.name ?: @"NSException";
        NSString *reason = exception.reason ?: @"(no reason)";
        NSArray<NSString *> *stack = exception.callStackSymbols ?: @[];

        NSMutableString *entry = [NSMutableString stringWithFormat:
            @"[PS12 v2.0.2] %.3f | %@ | %@: %@\n",
            CFAbsoluteTimeGetCurrent(),
            safeContext,
            name,
            reason];

        NSUInteger maxFrames = MIN((NSUInteger)12, stack.count);
        for (NSUInteger i = 0; i < maxFrames; i++) {
            [entry appendFormat:@"  #%lu: %@\n", (unsigned long)i, stack[i]];
        }
        [entry appendString:@"\n"];

        NSData *payload = [entry dataUsingEncoding:NSUTF8StringEncoding];
        if (!payload || payload.length == 0) {
            return;
        }

        os_unfair_lock_lock(&s_logLock);
        @try {
            NSFileManager *fm = [NSFileManager defaultManager];
            NSString *dir = [kPS12LogPath stringByDeletingLastPathComponent];
            if (![fm fileExistsAtPath:dir]) {
                [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
            }

            NSDictionary *attrs = [fm attributesOfItemAtPath:kPS12LogPath error:nil];
            unsigned long long existingSize = [attrs fileSize];
            if (existingSize + payload.length > kPS12MaxLogBytes) {
                [payload writeToFile:kPS12LogPath atomically:YES];
            } else if ([fm fileExistsAtPath:kPS12LogPath]) {
                NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:kPS12LogPath];
                if (fh) {
                    [fh seekToEndOfFile];
                    [fh writeData:payload];
                    [fh closeFile];
                } else {
                    [payload writeToFile:kPS12LogPath atomically:YES];
                }
            } else {
                [payload writeToFile:kPS12LogPath atomically:YES];
            }
        } @finally {
            os_unfair_lock_unlock(&s_logLock);
        }
    } @catch (NSException *ignored) {
        (void)ignored;
    }
}
