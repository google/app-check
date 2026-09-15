// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

#if !defined(SWIFT_RUNTIME_NAME)
#if __has_attribute(objc_runtime_name)
#define SWIFT_RUNTIME_NAME(X) __attribute__((objc_runtime_name(X)))
#else
#define SWIFT_RUNTIME_NAME(X)
#endif
#endif

#if !defined(SWIFT_COMPILE_NAME)
#if __has_attribute(swift_name)
#define SWIFT_COMPILE_NAME(X) __attribute__((swift_name(X)))
#else
#define SWIFT_COMPILE_NAME(X)
#endif
#endif

#if !defined(SWIFT_CLASS_EXTRA)
#define SWIFT_CLASS_EXTRA
#endif

// Allow Objective-C subclassing of open classes such as GACAppCheckSettings.
#if !defined(SWIFT_CLASS)
#define SWIFT_CLASS(SWIFT_NAME) SWIFT_RUNTIME_NAME(SWIFT_NAME) SWIFT_CLASS_EXTRA
#define SWIFT_CLASS_NAMED(SWIFT_NAME) SWIFT_COMPILE_NAME(SWIFT_NAME) SWIFT_CLASS_EXTRA
#endif

#if __has_include(<AppCheckCore/AppCheckCore-Swift.h>)
#import <AppCheckCore/AppCheckCore-Swift.h>
#elif __has_include("AppCheckCore-Swift.h")
#import "AppCheckCore-Swift.h"
#else
// Fallback for Swift package manager which auto-generates the bridging header
#endif

NS_ASSUME_NONNULL_BEGIN

/// Error domain for App Check errors.
static NSString *const GACAppCheckErrorDomain = @"com.google.app_check_core";

/// A block to be called before sending API requests.
typedef void (^GACAppCheckAPIRequestHook)(NSMutableURLRequest *request);

/// Backward compatibility enum aliases for message codes from v11.
typedef NS_ENUM(NSInteger, GACLoggerAppCheckMessageCode) {
  GACLoggerAppCheckMessageCodeUnknown = GACAppCheckMessageCodeUnknown,
  GACLoggerAppCheckMessageCodeProviderIsMissing = GACAppCheckMessageCodeProviderIsMissing,
  GACLoggerAppCheckMessageCodeStagingModeEnabled = GACAppCheckMessageCodeStagingModeEnabled,
  GACLoggerAppCheckMessageCodeUnexpectedHTTPCode = GACAppCheckMessageCodeUnexpectedHTTPCode,
  GACLoggerAppCheckMessageLocalDebugToken = GACAppCheckMessageCodeLocalDebugToken,
  GACLoggerAppCheckMessageEnvironmentVariableDebugToken =
      GACAppCheckMessageCodeEnvironmentVariableDebugToken,
  GACLoggerAppCheckMessageDebugProviderFirebaseEnvironmentVariable =
      GACAppCheckMessageCodeDebugProviderFirebaseEnvironmentVariable,
  GACLoggerAppCheckMessageDebugProviderFailedExchange =
      GACAppCheckMessageCodeDebugProviderFailedExchange,
  GACLoggerAppCheckMessageCodeAppAttestNotSupported = GACAppCheckMessageCodeAppAttestNotSupported,
  GACLoggerAppCheckMessageCodeAttestationRejected = GACAppCheckMessageCodeAttestationRejected,
  GACLoggerAppCheckMessageCodeAssertionRejected = GACAppCheckMessageCodeAssertionRejected
};

NS_ASSUME_NONNULL_END
