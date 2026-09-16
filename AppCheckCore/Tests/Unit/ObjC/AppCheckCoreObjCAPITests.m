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

#import <XCTest/XCTest.h>

@import AppCheckCore;

#pragma mark - Protocol Conformance Dummies

@interface GACDummyAppCheckProvider : NSObject <GACAppCheckProvider>
@end

@implementation GACDummyAppCheckProvider

- (void)getTokenWithCompletion:(void (^)(GACAppCheckToken *_Nullable token,
                                         NSError *_Nullable error))handler {
  GACAppCheckToken *token = [[GACAppCheckToken alloc] initWithToken:@"dummy_token"
                                                     expirationDate:[NSDate distantFuture]];
  handler(token, nil);
}

- (void)getLimitedUseTokenWithCompletion:(void (^)(GACAppCheckToken *_Nullable token,
                                                   NSError *_Nullable error))handler {
  GACAppCheckToken *token = [[GACAppCheckToken alloc] initWithToken:@"dummy_limited_use_token"
                                                     expirationDate:[NSDate distantFuture]];
  handler(token, nil);
}

@end

@interface GACDummyAppCheckSettings : NSObject <GACAppCheckSettingsProtocol>
@property(nonatomic, assign) BOOL isTokenAutoRefreshEnabled;
@end

@implementation GACDummyAppCheckSettings
@end

@interface GACDummyTokenDelegate : NSObject <GACAppCheckTokenDelegate>
@end

@implementation GACDummyTokenDelegate
- (void)tokenDidUpdate:(GACAppCheckToken *)token serviceName:(NSString *)serviceName {
}
@end

#pragma mark - API Build Tests

@interface AppCheckCoreObjCAPITests : XCTestCase
@end

@implementation AppCheckCoreObjCAPITests

- (void)testPublicAPICompileAndLink {
  NSString *serviceName = @"test_service";
  NSString *resourceName = @"projects/test/apps/test";
  NSString *apiKey = @"test_api_key";
  NSString *keychainGroup = @"test_group";

  // MARK: - GACAppCheckToken
  NSDate *expirationDate = [NSDate distantFuture];
  NSDate *receivedAtDate = [NSDate date];
  GACAppCheckToken *token = [[GACAppCheckToken alloc] initWithToken:@"test_token"
                                                     expirationDate:expirationDate];
  XCTAssertNotNil(token);
  XCTAssertEqualObjects(token.token, @"test_token");
  XCTAssertEqualObjects(token.expirationDate, expirationDate);
  XCTAssertNotNil(token.receivedAtDate);

  GACAppCheckToken *tokenWithReceivedAt = [[GACAppCheckToken alloc] initWithToken:@"test_token"
                                                                   expirationDate:expirationDate
                                                                   receivedAtDate:receivedAtDate];
  XCTAssertEqualObjects(tokenWithReceivedAt.receivedAtDate, receivedAtDate);

  // MARK: - GACAppCheckTokenResult
  NSError *testError = [NSError errorWithDomain:@"test_domain" code:100 userInfo:nil];
  GACAppCheckTokenResult *successResult = [[GACAppCheckTokenResult alloc] initWithToken:token];
  XCTAssertEqualObjects(successResult.token, token);
  XCTAssertNil(successResult.error);

  GACAppCheckTokenResult *failureResult = [[GACAppCheckTokenResult alloc] initWithError:testError];
  XCTAssertNotNil(failureResult.token);
  XCTAssertEqualObjects(failureResult.error, testError);

  GACAppCheckTokenResult *designatedResult =
      [[GACAppCheckTokenResult alloc] initWithToken:token error:testError];
  XCTAssertEqualObjects(designatedResult.token, token);
  XCTAssertEqualObjects(designatedResult.error, testError);

  // MARK: - GACAppCheckSettings
  GACAppCheckSettings *settings = [[GACAppCheckSettings alloc] init];
  settings.isTokenAutoRefreshEnabled = YES;
  XCTAssertTrue(settings.isTokenAutoRefreshEnabled);

  GACDummyAppCheckSettings *customSettings = [[GACDummyAppCheckSettings alloc] init];
  customSettings.isTokenAutoRefreshEnabled = NO;
  XCTAssertFalse(customSettings.isTokenAutoRefreshEnabled);

  // MARK: - GACAppCheckProvider & Delegate
  id<GACAppCheckProvider> provider = [[GACDummyAppCheckProvider alloc] init];
  id<GACAppCheckTokenDelegate> tokenDelegate = [[GACDummyTokenDelegate alloc] init];

  // MARK: - GACAppCheck & GACAppCheckProtocol
  GACAppCheck *appCheck = [[GACAppCheck alloc] initWithServiceName:serviceName
                                                      resourceName:resourceName
                                                  appCheckProvider:provider
                                                          settings:settings
                                                     tokenDelegate:tokenDelegate
                                               keychainAccessGroup:keychainGroup];
  XCTAssertNotNil(appCheck);

  id<GACAppCheckProtocol> appCheckProtocol = appCheck;
  XCTAssertNotNil(appCheckProtocol);

  [appCheck tokenForcingRefresh:NO
                     completion:^(GACAppCheckTokenResult *result) {
                       XCTAssertNotNil(result);
                     }];

  [appCheck limitedUseTokenWithCompletion:^(GACAppCheckTokenResult *result) {
    XCTAssertNotNil(result);
  }];

  // MARK: - GACAppCheckDebugProvider
  GACAppCheckDebugProvider *debugProvider =
      [[GACAppCheckDebugProvider alloc] initWithServiceName:serviceName
                                               resourceName:resourceName
                                                    baseURL:nil
                                                     APIKey:apiKey
                                               requestHooks:nil];
  XCTAssertNotNil(debugProvider);
  XCTAssertNotNil([debugProvider localDebugToken]);
  XCTAssertNotNil([debugProvider currentDebugToken]);

  [debugProvider getTokenWithCompletion:^(GACAppCheckToken *debugToken, NSError *error){
  }];
  [debugProvider getLimitedUseTokenWithCompletion:^(GACAppCheckToken *debugToken, NSError *error){
  }];

  // MARK: - GACDeviceCheckProvider
#if !TARGET_OS_WATCH
  GACDeviceCheckProvider *deviceCheckProvider =
      [[GACDeviceCheckProvider alloc] initWithServiceName:serviceName
                                             resourceName:resourceName
                                                   APIKey:apiKey
                                             requestHooks:nil];
  XCTAssertNotNil(deviceCheckProvider);
  [deviceCheckProvider getTokenWithCompletion:^(GACAppCheckToken *dToken, NSError *error){
  }];
  [deviceCheckProvider getLimitedUseTokenWithCompletion:^(GACAppCheckToken *dToken, NSError *error){
  }];
#endif

  // MARK: - GACAppAttestProvider
  if (@available(iOS 14.0, macOS 11.0, tvOS 15.0, watchOS 9.0, *)) {
    GACAppAttestProvider *appAttestProvider =
        [[GACAppAttestProvider alloc] initWithServiceName:serviceName
                                             resourceName:resourceName
                                                  baseURL:nil
                                                   APIKey:apiKey
                                      keychainAccessGroup:keychainGroup
                                             requestHooks:nil];
    XCTAssertNotNil(appAttestProvider);
    [appAttestProvider getTokenWithCompletion:^(GACAppCheckToken *aToken, NSError *error){
    }];
    [appAttestProvider getLimitedUseTokenWithCompletion:^(GACAppCheckToken *aToken, NSError *error){
    }];
  }

  // MARK: - GACAppCheckLogger
  GACAppCheckLogger.logLevel = GACAppCheckLogLevelDebug;
  XCTAssertEqual(GACAppCheckLogger.logLevel, GACAppCheckLogLevelDebug);
  GACAppCheckLogger.logLevel = GACAppCheckLogLevelInfo;
  GACAppCheckLogger.logLevel = GACAppCheckLogLevelWarning;
  GACAppCheckLogger.logLevel = GACAppCheckLogLevelError;
  GACAppCheckLogger.logLevel = GACAppCheckLogLevelFault;

  // MARK: - GACAppCheckErrorCode
  GACAppCheckErrorCode unknownCode = GACAppCheckErrorCodeUnknown;
  GACAppCheckErrorCode serverUnreachableCode = GACAppCheckErrorCodeServerUnreachable;
  GACAppCheckErrorCode invalidConfigurationCode = GACAppCheckErrorCodeInvalidConfiguration;
  GACAppCheckErrorCode keychainCode = GACAppCheckErrorCodeKeychain;
  GACAppCheckErrorCode unsupportedCode = GACAppCheckErrorCodeUnsupported;
  XCTAssertEqual(unknownCode, 0);
  XCTAssertEqual(serverUnreachableCode, 1);
  XCTAssertEqual(invalidConfigurationCode, 2);
  XCTAssertEqual(keychainCode, 3);
  XCTAssertEqual(unsupportedCode, 4);

  // MARK: - GACAppCheckMessageCode
  GACAppCheckMessageCode msgUnknown = GACAppCheckMessageCodeUnknown;
  GACAppCheckMessageCode msgProviderMissing = GACAppCheckMessageCodeProviderIsMissing;
  GACAppCheckMessageCode msgStaging = GACAppCheckMessageCodeStagingModeEnabled;
  GACAppCheckMessageCode msgHTTP = GACAppCheckMessageCodeUnexpectedHTTPCode;
  GACAppCheckMessageCode msgLocalToken = GACAppCheckMessageCodeLocalDebugToken;
  GACAppCheckMessageCode msgEnvToken = GACAppCheckMessageCodeEnvironmentVariableDebugToken;
  GACAppCheckMessageCode msgFirebaseEnv =
      GACAppCheckMessageCodeDebugProviderFirebaseEnvironmentVariable;
  GACAppCheckMessageCode msgFailedExchange = GACAppCheckMessageCodeDebugProviderFailedExchange;
  GACAppCheckMessageCode msgAttestNotSupported = GACAppCheckMessageCodeAppAttestNotSupported;
  GACAppCheckMessageCode msgAttestationRejected = GACAppCheckMessageCodeAttestationRejected;
  GACAppCheckMessageCode msgAssertionRejected = GACAppCheckMessageCodeAssertionRejected;
  XCTAssertEqual(msgUnknown, 1001);
  XCTAssertEqual(msgProviderMissing, 2002);
  XCTAssertEqual(msgStaging, 2003);
  XCTAssertEqual(msgHTTP, 3001);
  XCTAssertEqual(msgLocalToken, 4001);
  XCTAssertEqual(msgEnvToken, 4002);
  XCTAssertEqual(msgFirebaseEnv, 4003);
  XCTAssertEqual(msgFailedExchange, 4004);
  XCTAssertEqual(msgAttestNotSupported, 7001);
  XCTAssertEqual(msgAttestationRejected, 7002);
  XCTAssertEqual(msgAssertionRejected, 7003);
}

@end
