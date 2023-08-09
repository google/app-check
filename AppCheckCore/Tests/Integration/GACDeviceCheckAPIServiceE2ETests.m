/*
 * Copyright 2020 Google LLC
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

#import <TargetConditionals.h>

// Tests that use the Keychain require a host app and Swift Package Manager
// does not support adding a host app to test targets.
#if !SWIFT_PACKAGE

// Skip keychain tests on Catalyst and macOS. Tests are skipped because they
// involve interactions with the keychain that require a provisioning profile.
// See go/firebase-macos-keychain-popups for more details.
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX

#import <XCTest/XCTest.h>

#import "FBLPromise+Testing.h"

#import "AppCheckCore/Sources/Core/APIService/GACAppCheckAPIService.h"
#import "AppCheckCore/Sources/DeviceCheckProvider/API/GACDeviceCheckAPIService.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheckToken.h"

// TODO: Replace with real resource name to run on CI
static NSString *const kResourceName = @"projects/test-project-id/google-app-id";

@interface GACDeviceCheckAPIServiceE2ETests : XCTestCase
@property(nonatomic) GACDeviceCheckAPIService *deviceCheckAPIService;
@property(nonatomic) GACAppCheckAPIService *APIService;
@property(nonatomic) NSURLSession *URLSession;
@end

// TODO(ncooke3): Fix these tests up and get them running on CI.

@implementation GACDeviceCheckAPIServiceE2ETests

- (void)setUp {
  self.URLSession = [NSURLSession
      sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];

  self.APIService = [[GACAppCheckAPIService alloc] initWithURLSession:self.URLSession
                                                              baseURL:nil
                                                               APIKey:nil
                                                         requestHooks:nil];
  self.deviceCheckAPIService = [[GACDeviceCheckAPIService alloc] initWithAPIService:self.APIService
                                                                       resourceName:kResourceName];
}

- (void)tearDown {
  self.deviceCheckAPIService = nil;
  self.APIService = nil;
  self.URLSession = nil;
}

// TODO: Re-enable the test once secret with "GoogleService-Info.plist" is configured.
- (void)temporaryDisabled_testAppCheckTokenSuccess {
  __auto_type appCheckPromise =
      [self.deviceCheckAPIService appCheckTokenWithDeviceToken:[NSData data]];

  XCTAssert(FBLWaitForPromisesWithTimeout(20));

  XCTAssertNil(appCheckPromise.error);
  XCTAssertNotNil(appCheckPromise.value);

  XCTAssertNotNil(appCheckPromise.value.token);
  XCTAssertNotNil(appCheckPromise.value.expirationDate);
}

@end

#endif  // !TARGET_OS_MACCATALYST && !TARGET_OS_OSX

#endif  // !SWIFT_PACKAGE
