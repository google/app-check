#import <Foundation/Foundation.h>

#if __has_include(<AppCheckCore/AppCheckCore-Swift.h>)
#import <AppCheckCore/AppCheckCore-Swift.h>
#elif __has_include("AppCheckCore-Swift.h")
#import "AppCheckCore-Swift.h"
#else
// Fallback for Swift package manager which auto-generates the bridging header
#endif
