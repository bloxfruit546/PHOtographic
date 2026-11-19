//
//  PSDiagnostics.h
//  PhotographicStyles12
//
//  Thread-safe, size-capped on-device exception logger for Camera.app.
//

#ifndef PS12_DIAGNOSTICS_H
#define PS12_DIAGNOSTICS_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Appends a timestamped exception report (name, reason, callStackSymbols)
/// to /var/mobile/Library/Logs/PhotographicStyles12.log (capped at 64 KB).
void PS12LogException(NSString *context, NSException *exception);

NS_ASSUME_NONNULL_END

#endif /* PS12_DIAGNOSTICS_H */
