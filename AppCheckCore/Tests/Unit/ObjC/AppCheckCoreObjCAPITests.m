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
#if SWIFT_PACKAGE && (TARGET_OS_IOS || TARGET_OS_VISION) && !TARGET_OS_MACCATALYST
@import AppCheckRecaptchaProvider;
#endif

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

@interface GACAppCheckMockURLProtocol : NSURLProtocol
@end
@implementation GACAppCheckMockURLProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
  return YES;
}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
  return request;
}
- (void)startLoading {
  [self.client URLProtocol:self
          didFailWithError:[NSError errorWithDomain:@"test" code:-1 userInfo:nil]];
}
- (void)stopLoading {
}
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
  GACAppCheckMessageCode msgInvalidRequestHook = GACAppCheckMessageCodeInvalidRequestHook;
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
  XCTAssertEqual(msgInvalidRequestHook, 3002);
  XCTAssertEqual(msgLocalToken, 4001);
  XCTAssertEqual(msgEnvToken, 4002);
  XCTAssertEqual(msgFirebaseEnv, 4003);
  XCTAssertEqual(msgFailedExchange, 4004);
  XCTAssertEqual(msgAttestNotSupported, 7001);
  XCTAssertEqual(msgAttestationRejected, 7002);
  XCTAssertEqual(msgAssertionRejected, 7003);
}

/// The error domain must remain reachable from Objective-C and must keep its
/// v11 string value; shipped apps compare against it when handling errors.
- (void)testErrorDomainIsAvailableToObjectiveCAndUnchanged {
  XCTAssertEqualObjects(GACAppCheckErrors.errorDomain, @"com.google.app_check_core");
}

/// Builds a session that never touches the network.
- (NSURLSession *)stubSession {
  NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
  config.protocolClasses = @[ [GACAppCheckMockURLProtocol class] ];
  return [NSURLSession sessionWithConfiguration:config];
}

/// Drives a request with a non-empty array of Objective-C blocks.
///
/// Elsewhere this file passes `requestHooks:nil`, which never builds an
/// `NSArray` and so never crosses the bridge, and the Swift tests pass Swift
/// closures, which never bridge either. Neither performs the motion Firebase
/// actually performs.
///
/// Constructing the service is not enough to catch a bridging regression:
/// `NSArray` to `Array` bridging is lazy, so the element cast is forced on
/// first access, which happens while building a request.
///
/// The hook is shaped like `FIRHeartbeatLogger`'s App Check request hook, the
/// only non-nil hook Firebase passes in production. Asserting that its header
/// survives is stronger than asserting it ran: it shows the recovered block
/// was invoked with the correct ABI and handed a usable request, not merely
/// that control reached it.
- (void)testRequestHooksBridging {
  XCTestExpectation *hookExpectation = [self expectationWithDescription:@"request hook called"];
  XCTestExpectation *completionExpectation = [self expectationWithDescription:@"completion called"];

  __block NSMutableURLRequest *capturedRequest = nil;
  void (^heartbeatHook)(NSMutableURLRequest *) = ^(NSMutableURLRequest *request) {
    [request setValue:@"test-heartbeat" forHTTPHeaderField:@"X-firebase-client"];
    capturedRequest = request;
    [hookExpectation fulfill];
  };

  _GACAppCheckAPIService *apiService =
      [[_GACAppCheckAPIService alloc] initWithURLSession:[self stubSession]
                                                 baseURL:nil
                                                  APIKey:@"key"
                                            requestHooks:@[ heartbeatHook ]];

  [apiService sendRequestWithURL:[NSURL URLWithString:@"https://test.local"]
                      httpMethod:@"GET"
                            body:nil
               additionalHeaders:nil
               completionHandler:^(id response, NSError *_Nullable error) {
                 [completionExpectation fulfill];
               }];

  [self waitForExpectations:@[ hookExpectation, completionExpectation ] timeout:2.0];

  XCTAssertTrue([capturedRequest isKindOfClass:[NSMutableURLRequest class]]);
  XCTAssertEqualObjects([capturedRequest valueForHTTPHeaderField:@"X-firebase-client"],
                        @"test-heartbeat");
}

/// Objects that are not blocks must be ignored rather than reinterpreted.
///
/// `NSBlockOperation` is the case that matters, and the only one that tells
/// the two candidate filters apart. A class-name substring check admits it,
/// because "NSBlockOperation" contains "Block", and then bit-casts an
/// `NSOperation` into a callable; invoking that exits the process with
/// SIGSEGV. An `NSBlock` ancestry check rejects it. A non-block that is also
/// not named "...Block...", such as an `NSString`, is rejected by both and so
/// pins neither.
///
/// The valid hook is last so that rejecting an element cannot be mistaken for
/// abandoning the rest of the array.
- (void)testNonBlockRequestHooksAreIgnored {
  XCTestExpectation *hookExpectation = [self expectationWithDescription:@"request hook called"];
  XCTestExpectation *completionExpectation = [self expectationWithDescription:@"completion called"];

  void (^hook)(NSMutableURLRequest *) = ^(NSMutableURLRequest *request) {
    [hookExpectation fulfill];
  };

  NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
    XCTFail(@"A non-block request hook must never be invoked.");
  }];

  _GACAppCheckAPIService *apiService =
      [[_GACAppCheckAPIService alloc] initWithURLSession:[self stubSession]
                                                 baseURL:nil
                                                  APIKey:@"key"
                                            requestHooks:@[ blockOperation, @"not a block", hook ]];

  [apiService sendRequestWithURL:[NSURL URLWithString:@"https://test.local"]
                      httpMethod:@"GET"
                            body:nil
               additionalHeaders:nil
               completionHandler:^(id response, NSError *_Nullable error) {
                 [completionExpectation fulfill];
               }];

  [self waitForExpectations:@[ hookExpectation, completionExpectation ] timeout:2.0];
}

#if (TARGET_OS_IOS || TARGET_OS_VISION) && !TARGET_OS_MACCATALYST
- (void)testRecaptchaProviderRequestHooksBridging {
  if (@available(iOS 15.0, visionOS 1.0, *)) {
    void (^hook)(NSMutableURLRequest *) = ^(NSMutableURLRequest *r) {
    };
    (void)[[GACRecaptchaProvider alloc] initWithSiteKey:@"key"
                                           resourceName:@"projects/p/apps/a"
                                                 APIKey:@"key"
                                           requestHooks:@[ hook ]];
  }
}
#endif

@end
