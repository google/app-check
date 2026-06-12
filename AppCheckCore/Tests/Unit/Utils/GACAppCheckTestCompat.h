/*
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Foundation/Foundation.h>

#pragma mark - Availability Macros

#ifndef GAC_DEVICE_CHECK_PROVIDER_AVAILABILITY
#define GAC_DEVICE_CHECK_PROVIDER_AVAILABILITY \
  API_AVAILABLE(ios(11.0), macos(10.15), macCatalyst(13.0), tvos(11.0), watchos(9.0))
#endif

#ifndef GAC_APP_ATTEST_PROVIDER_AVAILABILITY
#define GAC_APP_ATTEST_PROVIDER_AVAILABILITY \
  API_AVAILABLE(ios(14.0), macos(11.3), macCatalyst(14.5), tvos(15.0), watchos(9.0))
#endif

@protocol GACAppCheckTimerProtocol;
@class GACAppCheckTokenRefreshResult;

typedef id<GACAppCheckTimerProtocol> _Nullable (^GACTimerProvider)(NSDate *_Nonnull fireDate,
                                                                   dispatch_queue_t _Nonnull queue,
                                                                   dispatch_block_t _Nonnull block);
typedef void (^GACAppCheckTokenRefreshCompletion)(
    GACAppCheckTokenRefreshResult *_Nonnull refreshResult);
typedef void (^GACAppCheckTokenRefreshBlock)(
    void (^_Nonnull completion)(GACAppCheckTokenRefreshResult *_Nonnull refreshResult));

@class FBLPromise;
typedef FBLPromise *_Nonnull (^GACAppCheckBackoffOperationProvider)(void);
typedef NSInteger (^GACAppCheckBackoffErrorHandler)(NSError *_Nonnull error);
typedef void (^GACAppCheckAPIRequestHook)(NSMutableURLRequest *_Nonnull request);

#ifndef GACAppCheckErrorDomain
#define GACAppCheckErrorDomain @"com.google.app_check_core"
#endif

// reCAPTCHA missing error message constant for tests
#ifndef kGACAppCheckMissingRecaptchaSDKMessage
#define kGACAppCheckMissingRecaptchaSDKMessage        \
  @"The reCAPTCHA Enterprise SDK is not linked. See " \
  @"https://cloud.google.com/recaptcha/docs/instrument-ios-apps#prepare-environment"
#endif
