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

#import <XCTest/XCTest.h>

#import "AppCheckCore/Tests/Unit/Utils/GACAppCheckProviderFake.h"
#import "AppCheckCore/Tests/Unit/Utils/GACAppCheckSettingsFake.h"
#import "AppCheckCore/Tests/Unit/Utils/GACAppCheckStorageFake.h"
#import "AppCheckCore/Tests/Unit/Utils/GACAppCheckTokenDelegateFake.h"
#import "AppCheckCore/Tests/Unit/Utils/GACAppCheckTokenRefresherFake.h"

#import "FBLPromise+Testing.h"

#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheck.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheckErrors.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheckProvider.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheckSettings.h"

#import "AppCheckCore/Sources/Core/Storage/GACAppCheckStorage.h"
#import "AppCheckCore/Sources/Core/TokenRefresh/GACAppCheckTokenRefreshResult.h"
#import "AppCheckCore/Sources/Core/TokenRefresh/GACAppCheckTokenRefresher.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheckToken.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheckTokenDelegate.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheckTokenResult.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/_GACAppCheckErrorUtil.h"

/// The placeholder token value returned when an error occurs: `{"error":"UNKNOWN_ERROR"}` encoded
/// as base64
static NSString *const kPlaceholderTokenValue = @"eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ==";

static NSString *const kResourceName = @"projects/test_project_id/apps/test_app_id";
static NSString *const kAppName = @"GACAppCheckTests";
static NSString *const kAppGroupID = @"app_group_id";

@interface GACAppCheck (Tests)

- (instancetype)initWithServiceName:(NSString *)instanceName
                   appCheckProvider:(id<GACAppCheckProvider>)appCheckProvider
                            storage:(id<GACAppCheckStorageProtocol>)storage
                     tokenRefresher:(id<GACAppCheckTokenRefresherProtocol>)tokenRefresher
                           settings:(id<GACAppCheckSettingsProtocol>)settings
                      tokenDelegate:(nullable id<GACAppCheckTokenDelegate>)tokenDelegate;

@end

@interface GACAppCheckTests : XCTestCase

@property(nonatomic) GACAppCheckStorageFake *fakeStorage;
@property(nonatomic) GACAppCheckProviderFake *fakeAppCheckProvider;
@property(nonatomic) GACAppCheckTokenRefresherFake *fakeTokenRefresher;
@property(nonatomic) GACAppCheckSettingsFake *fakeSettings;
@property(nonatomic) GACAppCheckTokenDelegateFake *fakeTokenDelegate;
@property(nonatomic) GACAppCheck *appCheck;

@end

@implementation GACAppCheckTests

- (void)setUp {
  [super setUp];

  self.fakeStorage = [[GACAppCheckStorageFake alloc] init];
  self.fakeAppCheckProvider = [[GACAppCheckProviderFake alloc] init];
  self.fakeTokenRefresher = [[GACAppCheckTokenRefresherFake alloc] init];
  self.fakeSettings = [[GACAppCheckSettingsFake alloc] init];
  self.fakeTokenDelegate = [[GACAppCheckTokenDelegateFake alloc] init];

  self.appCheck = [[GACAppCheck alloc] initWithServiceName:kAppName
                                          appCheckProvider:self.fakeAppCheckProvider
                                                   storage:self.fakeStorage
                                            tokenRefresher:self.fakeTokenRefresher
                                                  settings:self.fakeSettings
                                             tokenDelegate:self.fakeTokenDelegate];
}

- (void)tearDown {
  self.appCheck = nil;
  self.fakeAppCheckProvider = nil;
  self.fakeStorage = nil;
  self.fakeTokenRefresher = nil;
  self.fakeSettings = nil;
  self.fakeTokenDelegate = nil;

  [super tearDown];
}

#pragma mark - Public Init

#pragma mark - Public Get Token

- (void)testGetToken_WhenNoCache_Success {
  // 1. Create expected token and configure expectations.
  GACAppCheckToken *expectedToken = [self validToken];

  XCTestExpectation *expectation =
      [self configuredExpectations_GetTokenWhenNoCache_withExpectedToken:expectedToken];

  // 2. Request token and verify result.
  [self.appCheck tokenForcingRefresh:NO
                          completion:^(GACAppCheckTokenResult *result) {
                            [expectation fulfill];
                            XCTAssertEqualObjects(result.token, expectedToken);
                            XCTAssertNil(result.error);
                          }];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ expectation ] timeout:0.5];

  XCTAssertEqual(self.fakeAppCheckProvider.getTokenCallCount, 1);
  XCTAssertEqualObjects(self.fakeStorage.lastSetToken, expectedToken);
  XCTAssertEqual(self.fakeTokenRefresher.updateWithRefreshResultCallCount, 1);
  XCTAssertEqualObjects(self.fakeTokenDelegate.lastToken, expectedToken);
}

- (void)testGetToken_WhenCachedTokenIsValid_Success {
  [self assertGetToken_WhenCachedTokenIsValid_Success];
}

- (void)testGetTokenForcingRefresh_WhenCachedTokenIsValid_Success {
  // 1. Create expected token and configure expectations.
  GACAppCheckToken *expectedToken = [self validToken];
  XCTestExpectation *expectation =
      [self configuredExpectations_GetTokenForcingRefreshWhenCacheIsValid_withExpectedToken:
                expectedToken];

  // 2. Request token and verify result.
  [self.appCheck tokenForcingRefresh:YES
                          completion:^(GACAppCheckTokenResult *result) {
                            [expectation fulfill];
                            XCTAssertEqualObjects(result.token, expectedToken);
                            XCTAssertNil(result.error);
                          }];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ expectation ] timeout:0.5];

  XCTAssertEqual(self.fakeAppCheckProvider.getTokenCallCount, 1);
  XCTAssertEqualObjects(self.fakeStorage.lastSetToken, expectedToken);
  XCTAssertEqual(self.fakeTokenRefresher.updateWithRefreshResultCallCount, 1);
  XCTAssertEqualObjects(self.fakeTokenDelegate.lastToken, expectedToken);
}

- (void)testGetToken_WhenCachedTokenExpired_Success {
  // 1. Create expected token and configure expectations.
  GACAppCheckToken *expectedToken = [self validToken];

  XCTestExpectation *expectation =
      [self configuredExpectations_GetTokenWhenCachedTokenExpired_withExpectedToken:expectedToken];

  // 2. Request token and verify result.
  [self.appCheck tokenForcingRefresh:NO
                          completion:^(GACAppCheckTokenResult *result) {
                            [expectation fulfill];
                            XCTAssertEqualObjects(result.token, expectedToken);
                            XCTAssertNil(result.error);
                          }];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ expectation ] timeout:0.5];

  XCTAssertEqual(self.fakeAppCheckProvider.getTokenCallCount, 1);
  XCTAssertEqualObjects(self.fakeStorage.lastSetToken, expectedToken);
  XCTAssertEqual(self.fakeTokenRefresher.updateWithRefreshResultCallCount, 1);
  XCTAssertEqualObjects(self.fakeTokenDelegate.lastToken, expectedToken);
}

- (void)testGetToken_AppCheckProviderError {
  // 1. Create expected tokens and errors and configure expectations.
  GACAppCheckToken *cachedToken = [self soonExpiringToken];
  NSError *providerError = [NSError errorWithDomain:@"GACAppCheckTests" code:-1 userInfo:nil];

  XCTestExpectation *expectation =
      [self configuredExpectations_GetTokenWhenError_withError:providerError andToken:cachedToken];

  // 2. Request token and verify result.
  [self.appCheck tokenForcingRefresh:NO
                          completion:^(GACAppCheckTokenResult *result) {
                            [expectation fulfill];
                            XCTAssertEqualObjects(result.token.token, kPlaceholderTokenValue);
                            XCTAssertNotNil(result.error);
                            XCTAssertEqualObjects(result.error, providerError);
                            // App Check Core does not wrap errors in public domain.
                            XCTAssertNotEqualObjects(result.error.domain, GACAppCheckErrorDomain);
                          }];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ expectation ] timeout:0.5];

  XCTAssertEqual(self.fakeAppCheckProvider.getTokenCallCount, 1);
  XCTAssertEqual(self.fakeTokenDelegate.tokenDidUpdateCallCount, 0);
  XCTAssertNil(self.fakeStorage.lastSetToken);
  XCTAssertEqual(self.fakeTokenRefresher.updateWithRefreshResultCallCount, 0);
}

#pragma mark - Token refresher

- (void)testTokenRefreshTriggeredAndRefreshSuccess {
  // 1. Expect token to be requested from storage.
  self.fakeStorage.getTokenPromise = [FBLPromise resolvedWith:nil];

  // 2. Expect token requested from app check provider.
  NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceNow:10000];
  GACAppCheckToken *tokenToReturn = [[GACAppCheckToken alloc] initWithToken:@"valid"
                                                             expirationDate:expirationDate];
  self.fakeAppCheckProvider.tokenToReturn = tokenToReturn;

  // 3. Expect new token to be stored.
  self.fakeStorage.setTokenPromise = [FBLPromise resolvedWith:tokenToReturn];

  // 4. Trigger refresh and expect the result.
  if (self.fakeTokenRefresher.tokenRefreshHandler == nil) {
    XCTFail(@"`tokenRefreshHandler` must be not `nil`.");
    return;
  }

  XCTestExpectation *completionExpectation = [self expectationWithDescription:@"completion"];
  self.fakeTokenRefresher.tokenRefreshHandler(^(GACAppCheckTokenRefreshResult *refreshResult) {
    [completionExpectation fulfill];
    XCTAssertEqualObjects(refreshResult.tokenExpirationDate, expirationDate);
    XCTAssertEqual(refreshResult.status, GACAppCheckTokenRefreshStatusSuccess);
  });

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];

  XCTAssertEqual(self.fakeAppCheckProvider.getTokenCallCount, 1);
  XCTAssertEqualObjects(self.fakeStorage.lastSetToken, tokenToReturn);
  XCTAssertEqual(self.fakeTokenRefresher.updateWithRefreshResultCallCount, 1);
  XCTAssertEqual(self.fakeTokenDelegate.tokenDidUpdateCallCount, 1);
  XCTAssertEqualObjects(self.fakeTokenDelegate.lastToken, tokenToReturn);
}

- (void)testTokenRefreshTriggeredAndRefreshError {
  // 1. Expect token to be requested from storage.
  self.fakeStorage.getTokenPromise = [FBLPromise resolvedWith:nil];

  // 2. Expect token requested from app check provider.
  NSError *providerError = [self internalError];
  self.fakeAppCheckProvider.errorToReturn = providerError;

  // 5. Trigger refresh and expect the result.
  if (self.fakeTokenRefresher.tokenRefreshHandler == nil) {
    XCTFail(@"`tokenRefreshHandler` must be not `nil`.");
    return;
  }

  XCTestExpectation *completionExpectation = [self expectationWithDescription:@"completion"];
  self.fakeTokenRefresher.tokenRefreshHandler(^(GACAppCheckTokenRefreshResult *refreshResult) {
    [completionExpectation fulfill];
    XCTAssertEqual(refreshResult.status, GACAppCheckTokenRefreshStatusFailure);
    XCTAssertNil(refreshResult.tokenExpirationDate);
    XCTAssertNil(refreshResult.tokenReceivedAtDate);
  });

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];

  XCTAssertEqual(self.fakeAppCheckProvider.getTokenCallCount, 1);
  XCTAssertEqual(self.fakeTokenDelegate.tokenDidUpdateCallCount, 0);
  XCTAssertNil(self.fakeStorage.lastSetToken);
  XCTAssertEqual(self.fakeTokenRefresher.updateWithRefreshResultCallCount, 0);
}

- (void)testLimitedUseTokenWithSuccess {
  // 1. Expect token requested from app check provider.
  GACAppCheckToken *expectedToken = [self validToken];
  self.fakeAppCheckProvider.limitedUseTokenToReturn = expectedToken;

  // 5. Expect token request to be completed.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];

  [self.appCheck limitedUseTokenWithCompletion:^(GACAppCheckTokenResult *result) {
    [getTokenExpectation fulfill];
    XCTAssertEqualObjects(result.token, expectedToken);
    XCTAssertNil(result.error);
  }];
  [self waitForExpectations:@[ getTokenExpectation ] timeout:0.5];

  XCTAssertEqual(self.fakeAppCheckProvider.getLimitedUseTokenCallCount, 1);
  XCTAssertEqualObjects(self.fakeStorage.lastSetToken, nil);
  XCTAssertEqual(self.fakeTokenDelegate.tokenDidUpdateCallCount, 0);
}

- (void)testLimitedUseToken_WhenTokenGenerationErrors {
  // 2. Expect error when requesting token from app check provider.
  NSError *providerError = [_GACAppCheckErrorUtil keychainErrorWithError:[self internalError]];
  self.fakeAppCheckProvider.limitedUseErrorToReturn = providerError;

  // 5. Expect token request to be completed.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];

  [self.appCheck limitedUseTokenWithCompletion:^(GACAppCheckTokenResult *result) {
    [getTokenExpectation fulfill];
    XCTAssertEqualObjects(result.token.token, kPlaceholderTokenValue);
    XCTAssertNotNil(result.error);
    XCTAssertEqualObjects(result.error, providerError);
    XCTAssertEqualObjects(result.error.domain, GACAppCheckErrorDomain);
  }];

  [self waitForExpectations:@[ getTokenExpectation ] timeout:0.5];

  XCTAssertEqual(self.fakeAppCheckProvider.getLimitedUseTokenCallCount, 1);
  XCTAssertEqual(self.fakeAppCheckProvider.getTokenCallCount, 0);
  XCTAssertNil(self.fakeStorage.lastSetToken);
  XCTAssertEqual(self.fakeTokenDelegate.tokenDidUpdateCallCount, 0);
  XCTAssertEqual(self.fakeTokenRefresher.updateWithRefreshResultCallCount, 0);
}

#pragma mark - Merging multiple get token requests

- (void)testGetToken_WhenCalledSeveralTimesSuccess_ThenThereIsOnlyOneOperation {
  // 1. Expect a token to be requested and stored.
  NSArray * /*[expectedToken, storeTokenPromise]*/ expectedTokenAndPromise =
      [self expectTokenRequestFromAppCheckProvider];
  GACAppCheckToken *expectedToken = expectedTokenAndPromise.firstObject;
  FBLPromise *storeTokenPromise = expectedTokenAndPromise.lastObject;

  // 3. Request token several times.
  NSInteger getTokenCallsCount = 10;
  NSMutableArray *getTokenCompletionExpectations =
      [NSMutableArray arrayWithCapacity:getTokenCallsCount];

  for (NSInteger i = 0; i < getTokenCallsCount; i++) {
    // 3.1. Expect a completion to be called for each method call.
    XCTestExpectation *getTokenExpectation =
        [self expectationWithDescription:[NSString stringWithFormat:@"getToken%@", @(i)]];
    [getTokenCompletionExpectations addObject:getTokenExpectation];

    // 3.2. Request token and verify result.
    [self.appCheck tokenForcingRefresh:NO
                            completion:^(GACAppCheckTokenResult *result) {
                              [getTokenExpectation fulfill];
                              XCTAssertEqualObjects(result.token, expectedToken);
                              XCTAssertNil(result.error);
                            }];
  }

  // 3.3. Fulfill the pending promise to finish the get token operation.
  [storeTokenPromise fulfill:expectedToken];

  // 4. Wait for expectations and validate mocks.
  [self waitForExpectations:getTokenCompletionExpectations timeout:0.5];

  XCTAssertEqual(self.fakeAppCheckProvider.getTokenCallCount, 1);
  XCTAssertEqual(self.fakeTokenRefresher.updateWithRefreshResultCallCount, 1);
  XCTAssertEqual(self.fakeTokenDelegate.tokenDidUpdateCallCount, 1);

  // 5. Check a get token call after.
  [self assertGetToken_WhenCachedTokenIsValid_Success];
}

- (void)testGetToken_WhenCalledSeveralTimesError_ThenThereIsOnlyOneOperation {
  // 1. Expect a token to be requested and stored.
  NSArray * /*[expectedToken, storeTokenPromise]*/ expectedTokenAndPromise =
      [self expectTokenRequestFromAppCheckProvider];
  FBLPromise *storeTokenPromise = expectedTokenAndPromise.lastObject;

  // 1.1. Create an expected error to be reject the store token promise with later.
  NSError *storageError = [NSError errorWithDomain:self.name code:0 userInfo:nil];

  // 3. Request token several times.
  NSInteger getTokenCallsCount = 10;
  NSMutableArray *getTokenCompletionExpectations =
      [NSMutableArray arrayWithCapacity:getTokenCallsCount];

  for (NSInteger i = 0; i < getTokenCallsCount; i++) {
    // 3.1. Expect a completion to be called for each method call.
    XCTestExpectation *getTokenExpectation =
        [self expectationWithDescription:[NSString stringWithFormat:@"getToken%@", @(i)]];
    [getTokenCompletionExpectations addObject:getTokenExpectation];

    // 3.2. Request token and verify result.
    [self.appCheck tokenForcingRefresh:NO
                            completion:^(GACAppCheckTokenResult *result) {
                              [getTokenExpectation fulfill];
                              XCTAssertEqualObjects(result.token.token, kPlaceholderTokenValue);
                              XCTAssertNotNil(result.error);
                              XCTAssertNotNil(result.error);
                              XCTAssertEqualObjects(result.error, storageError);
                            }];
  }

  // 3.3. Reject the pending promise to finish the get token operation.
  [storeTokenPromise reject:storageError];

  // 4. Wait for expectations and validate mocks.
  [self waitForExpectations:getTokenCompletionExpectations timeout:0.5];

  // After the first token generation fails and caches the result, the call count will be 1
  XCTAssertEqual(self.fakeAppCheckProvider.getTokenCallCount, 1);
  XCTAssertEqual(self.fakeTokenDelegate.tokenDidUpdateCallCount, 0);  // No updates on error
  XCTAssertEqualObjects(self.fakeStorage.lastSetToken, expectedTokenAndPromise.firstObject);
  XCTAssertEqual(self.fakeTokenRefresher.updateWithRefreshResultCallCount, 0);

  // 5. Check a get token call after.
  [self assertGetToken_WhenCachedTokenIsValid_Success];
}

#pragma mark - Helpers

- (NSError *)internalError {
  return [NSError errorWithDomain:@"com.internal.error" code:-1 userInfo:nil];
}

- (GACAppCheckToken *)validToken {
  return [[GACAppCheckToken alloc] initWithToken:[NSUUID UUID].UUIDString
                                  expirationDate:[NSDate distantFuture]];
}

- (GACAppCheckToken *)soonExpiringToken {
  NSDate *soonExpiringTokenDate = [NSDate dateWithTimeIntervalSinceNow:4.5 * 60];
  return [[GACAppCheckToken alloc] initWithToken:@"valid" expirationDate:soonExpiringTokenDate];
}

- (void)assertGetToken_WhenCachedTokenIsValid_Success {
  NSInteger initialCallCount = self.fakeAppCheckProvider.getTokenCallCount;

  // 1. Create expected token and configure expectations.
  GACAppCheckToken *cachedToken = [self validToken];

  XCTestExpectation *expectation =
      [self configuredExpectation_GetTokenWhenCacheTokenIsValid_withExpectedToken:cachedToken];

  // 2. Request token and verify result.
  [self.appCheck tokenForcingRefresh:NO
                          completion:^(GACAppCheckTokenResult *result) {
                            [expectation fulfill];
                            XCTAssertEqualObjects(result.token, cachedToken);
                            XCTAssertNil(result.error);
                          }];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ expectation ] timeout:0.5];

  XCTAssertEqual(self.fakeAppCheckProvider.getTokenCallCount, initialCallCount);
}

- (XCTestExpectation *)configuredExpectations_GetTokenWhenNoCache_withExpectedToken:
    (GACAppCheckToken *)expectedToken {
  // 1. Expect token to be requested from storage.
  self.fakeStorage.getTokenPromise = [FBLPromise resolvedWith:nil];

  // 2. Expect token requested from app check provider.
  self.fakeAppCheckProvider.tokenToReturn = expectedToken;

  // 3. Expect new token to be stored.
  self.fakeStorage.setTokenPromise = [FBLPromise resolvedWith:expectedToken];

  // 5. Expect token request to be completed.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];

  return getTokenExpectation;
}

- (XCTestExpectation *)configuredExpectation_GetTokenWhenCacheTokenIsValid_withExpectedToken:
    (GACAppCheckToken *)expectedToken {
  // 1. Expect token to be requested from storage.
  self.fakeStorage.getTokenPromise = [FBLPromise resolvedWith:expectedToken];

  // 4. Expect token request to be completed.
  return [self expectationWithDescription:@"getToken"];
}

- (XCTestExpectation *)
    configuredExpectations_GetTokenForcingRefreshWhenCacheIsValid_withExpectedToken:
        (GACAppCheckToken *)expectedToken {
  // 2. Expect token requested from app check provider.
  self.fakeAppCheckProvider.tokenToReturn = expectedToken;

  // 3. Expect new token to be stored.
  self.fakeStorage.setTokenPromise = [FBLPromise resolvedWith:expectedToken];

  // 5. Expect token request to be completed.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];

  return getTokenExpectation;
}

- (XCTestExpectation *)configuredExpectations_GetTokenWhenCachedTokenExpired_withExpectedToken:
    (GACAppCheckToken *)expectedToken {
  // 1. Expect token to be requested from storage.
  GACAppCheckToken *cachedToken = [[GACAppCheckToken alloc] initWithToken:@"expired"
                                                           expirationDate:[NSDate date]];
  self.fakeStorage.getTokenPromise = [FBLPromise resolvedWith:cachedToken];

  // 2. Expect token requested from app check provider.
  self.fakeAppCheckProvider.tokenToReturn = expectedToken;

  // 3. Expect new token to be stored.
  self.fakeStorage.setTokenPromise = [FBLPromise resolvedWith:expectedToken];

  // 5. Expect token request to be completed.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];

  return getTokenExpectation;
}

- (XCTestExpectation *)
    configuredExpectations_GetTokenWhenError_withError:(NSError *_Nonnull)error
                                              andToken:(GACAppCheckToken *_Nullable)token {
  // 1. Expect token to be requested from storage.
  self.fakeStorage.getTokenPromise = [FBLPromise resolvedWith:token];

  // 2. Expect token requested from app check provider.
  self.fakeAppCheckProvider.errorToReturn = error;

  // 5. Expect token request to be completed.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];

  return getTokenExpectation;
}

- (NSArray *)expectTokenRequestFromAppCheckProvider {
  // 1. Expect token to be requested from storage.
  self.fakeStorage.getTokenPromise = [FBLPromise resolvedWith:nil];

  // 2. Expect token requested from app check provider.
  GACAppCheckToken *expectedToken = [self validToken];
  self.fakeAppCheckProvider.tokenToReturn = expectedToken;

  // 3. Expect new token to be stored.
  // 3.1. Create a pending promise to resolve later.
  FBLPromise<GACAppCheckToken *> *storeTokenPromise = [FBLPromise pendingPromise];
  // 3.2. Stub storage set token method.
  self.fakeStorage.setTokenPromise = storeTokenPromise;

  return @[ expectedToken, storeTokenPromise ];
}

@end
