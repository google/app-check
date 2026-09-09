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

  // 5. Check a get token call after returns the cached token without re-fetching.
  XCTestExpectation *afterExpectation = [self expectationWithDescription:@"getTokenAfter"];
  [self.appCheck tokenForcingRefresh:NO
                          completion:^(GACAppCheckTokenResult *result) {
                            [afterExpectation fulfill];
                            XCTAssertEqualObjects(result.token, expectedToken);
                            XCTAssertNil(result.error);
                          }];
  [self waitForExpectations:@[ afterExpectation ] timeout:0.5];
  XCTAssertEqual(self.fakeAppCheckProvider.getTokenCallCount, 1);
}

- (void)testGetToken_WhenCalledSeveralTimesError_ThenThereIsOnlyOneOperation {
  // 1. Expect a token to be requested from storage, kept pending to merge multiple calls.
  FBLPromise<GACAppCheckToken *> *storageGetPromise = [FBLPromise pendingPromise];
  self.fakeStorage.getTokenPromise = storageGetPromise;

  // 1.1. Create an expected error to reject the provider request with later.
  NSError *providerError = [self internalError];
  self.fakeAppCheckProvider.errorToReturn = providerError;

  // 2. Request token several times.
  NSInteger getTokenCallsCount = 10;
  NSMutableArray *getTokenCompletionExpectations =
      [NSMutableArray arrayWithCapacity:getTokenCallsCount];

  for (NSInteger i = 0; i < getTokenCallsCount; i++) {
    // 2.1. Expect a completion to be called for each method call.
    XCTestExpectation *getTokenExpectation =
        [self expectationWithDescription:[NSString stringWithFormat:@"getToken%@", @(i)]];
    [getTokenCompletionExpectations addObject:getTokenExpectation];

    // 2.2. Request token and verify result.
    [self.appCheck tokenForcingRefresh:NO
                            completion:^(GACAppCheckTokenResult *result) {
                              [getTokenExpectation fulfill];
                              XCTAssertEqualObjects(result.token.token, kPlaceholderTokenValue);
                              XCTAssertNotNil(result.error);
                              XCTAssertEqualObjects(result.error, providerError);
                            }];
  }

  // 2.3. Finish storage get with nil so it proceeds to refresh with provider.
  [storageGetPromise fulfill:nil];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:getTokenCompletionExpectations timeout:0.5];

  // After the first token generation fails, call count will be 1
  XCTAssertEqual(self.fakeAppCheckProvider.getTokenCallCount, 1);
  XCTAssertEqual(self.fakeTokenDelegate.tokenDidUpdateCallCount, 0);  // No updates on error
  XCTAssertNil(self.fakeStorage.lastSetToken);
  XCTAssertEqual(self.fakeTokenRefresher.updateWithRefreshResultCallCount, 0);

  // 4. Check a get token call after.
  [self assertGetToken_WhenCachedTokenIsValid_Success];
}

- (void)testGetToken_WhenStorageFails_ThenTokenReturnedAndCachedInMemory {
  // 1. Expect token to be requested from storage (cache miss) and provider to return a valid token.
  self.fakeStorage.getTokenPromise = [FBLPromise resolvedWith:nil];

  GACAppCheckToken *expectedToken = [self validToken];
  self.fakeAppCheckProvider.tokenToReturn = expectedToken;

  // 2. Make storage setToken fail with a keychain error.
  NSError *storageError = [_GACAppCheckErrorUtil keychainErrorWithError:[self internalError]];
  FBLPromise<GACAppCheckToken *> *rejectedStoragePromise = [FBLPromise pendingPromise];
  [rejectedStoragePromise reject:storageError];
  self.fakeStorage.setTokenPromise = rejectedStoragePromise;

  // 3. Request token and verify it succeeds with the valid token despite storage failure.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];
  [self.appCheck tokenForcingRefresh:NO
                          completion:^(GACAppCheckTokenResult *result) {
                            [getTokenExpectation fulfill];
                            XCTAssertEqualObjects(result.token, expectedToken);
                            XCTAssertNil(result.error);
                          }];

  [self waitForExpectations:@[ getTokenExpectation ] timeout:0.5];

  XCTAssertEqual(self.fakeAppCheckProvider.getTokenCallCount, 1);
  XCTAssertEqualObjects(self.fakeStorage.lastSetToken, expectedToken);
  XCTAssertEqual(self.fakeTokenRefresher.updateWithRefreshResultCallCount, 1);
  XCTAssertEqual(self.fakeTokenDelegate.tokenDidUpdateCallCount, 1);

  // 4. Request token again: should be retrieved from in-memory cache without hitting provider or
  // storage.
  self.fakeStorage.getTokenPromise = [FBLPromise resolvedWith:nil];
  XCTestExpectation *cachedExpectation = [self expectationWithDescription:@"getCachedToken"];
  [self.appCheck tokenForcingRefresh:NO
                          completion:^(GACAppCheckTokenResult *result) {
                            [cachedExpectation fulfill];
                            XCTAssertEqualObjects(result.token, expectedToken);
                            XCTAssertNil(result.error);
                          }];

  [self waitForExpectations:@[ cachedExpectation ] timeout:0.5];

  // Provider call count should remain 1.
  XCTAssertEqual(self.fakeAppCheckProvider.getTokenCallCount, 1);
}

- (void)testGetToken_WhenForcingRefresh_ThenInMemoryCacheIsBypassed {
  // 1. Prime the in-memory cache with an initial token.
  self.fakeStorage.getTokenPromise = [FBLPromise resolvedWith:nil];
  GACAppCheckToken *token1 = [self validToken];
  self.fakeAppCheckProvider.tokenToReturn = token1;
  self.fakeStorage.setTokenPromise = [FBLPromise resolvedWith:token1];

  XCTestExpectation *expectation1 = [self expectationWithDescription:@"getToken1"];
  [self.appCheck tokenForcingRefresh:NO
                          completion:^(GACAppCheckTokenResult *result) {
                            [expectation1 fulfill];
                            XCTAssertEqualObjects(result.token, token1);
                            XCTAssertNil(result.error);
                          }];
  [self waitForExpectations:@[ expectation1 ] timeout:0.5];
  XCTAssertEqual(self.fakeAppCheckProvider.getTokenCallCount, 1);

  // 2. Request token with forcingRefresh:YES; should bypass in-memory cache and fetch new token.
  GACAppCheckToken *token2 = [self validToken];
  self.fakeAppCheckProvider.tokenToReturn = token2;
  self.fakeStorage.setTokenPromise = [FBLPromise resolvedWith:token2];

  XCTestExpectation *expectation2 = [self expectationWithDescription:@"getToken2"];
  [self.appCheck tokenForcingRefresh:YES
                          completion:^(GACAppCheckTokenResult *result) {
                            [expectation2 fulfill];
                            XCTAssertEqualObjects(result.token, token2);
                            XCTAssertNil(result.error);
                          }];
  [self waitForExpectations:@[ expectation2 ] timeout:0.5];

  // Provider call count should now be 2.
  XCTAssertEqual(self.fakeAppCheckProvider.getTokenCallCount, 2);

  // 3. Subsequent call with forcingRefresh:NO should return token2 from in-memory cache without
  // calling provider again.
  XCTestExpectation *expectation3 = [self expectationWithDescription:@"getToken3"];
  [self.appCheck tokenForcingRefresh:NO
                          completion:^(GACAppCheckTokenResult *result) {
                            [expectation3 fulfill];
                            XCTAssertEqualObjects(result.token, token2);
                            XCTAssertNil(result.error);
                          }];
  [self waitForExpectations:@[ expectation3 ] timeout:0.5];
  XCTAssertEqual(self.fakeAppCheckProvider.getTokenCallCount, 2);
}

- (void)testGetToken_WhenForcingRefresh_ThenInMemoryTokenIsInvalidated {
  // 1. Prime the in-memory cache with an initial token.
  self.fakeStorage.getTokenPromise = [FBLPromise resolvedWith:nil];
  GACAppCheckToken *token1 = [self validToken];
  self.fakeAppCheckProvider.tokenToReturn = token1;
  self.fakeStorage.setTokenPromise = [FBLPromise resolvedWith:token1];

  XCTestExpectation *expectation1 = [self expectationWithDescription:@"getToken1"];
  [self.appCheck tokenForcingRefresh:NO
                          completion:^(GACAppCheckTokenResult *result) {
                            [expectation1 fulfill];
                            XCTAssertEqualObjects(result.token, token1);
                          }];
  [self waitForExpectations:@[ expectation1 ] timeout:0.5];
  XCTAssertEqual(self.fakeAppCheckProvider.getTokenCallCount, 1);

  // 2. Force refresh with provider failure.
  NSError *providerError = [self internalError];
  self.fakeAppCheckProvider.errorToReturn = providerError;
  self.fakeAppCheckProvider.tokenToReturn = nil;

  XCTestExpectation *expectation2 = [self expectationWithDescription:@"getToken2"];
  [self.appCheck tokenForcingRefresh:YES
                          completion:^(GACAppCheckTokenResult *result) {
                            [expectation2 fulfill];
                            XCTAssertEqualObjects(result.error, providerError);
                          }];
  [self waitForExpectations:@[ expectation2 ] timeout:0.5];
  XCTAssertEqual(self.fakeAppCheckProvider.getTokenCallCount, 2);

  // 3. Now request token with forcingRefresh:NO; since token1 was invalidated, it should NOT return
  // token1. Provider will be called again (or fail).
  XCTestExpectation *expectation3 = [self expectationWithDescription:@"getToken3"];
  [self.appCheck tokenForcingRefresh:NO
                          completion:^(GACAppCheckTokenResult *result) {
                            [expectation3 fulfill];
                            XCTAssertEqualObjects(result.error, providerError);
                          }];
  [self waitForExpectations:@[ expectation3 ] timeout:0.5];
  XCTAssertEqual(self.fakeAppCheckProvider.getTokenCallCount, 3);
}

- (void)testGetToken_WhenInMemoryTokenExpires_ThenRefreshesWithProvider {
  // 1. Prime the in-memory cache with a soon-expiring token.
  self.fakeStorage.getTokenPromise = [FBLPromise resolvedWith:nil];
  GACAppCheckToken *expiringToken = [self soonExpiringToken];
  self.fakeAppCheckProvider.tokenToReturn = expiringToken;
  self.fakeStorage.setTokenPromise = [FBLPromise resolvedWith:expiringToken];

  XCTestExpectation *expectation1 = [self expectationWithDescription:@"getToken1"];
  [self.appCheck tokenForcingRefresh:NO
                          completion:^(GACAppCheckTokenResult *result) {
                            [expectation1 fulfill];
                            XCTAssertEqualObjects(result.token, expiringToken);
                          }];
  [self waitForExpectations:@[ expectation1 ] timeout:0.5];
  XCTAssertEqual(self.fakeAppCheckProvider.getTokenCallCount, 1);

  // 2. Next call with forcingRefresh:NO detects in-memory token expires soon and refreshes.
  GACAppCheckToken *newToken = [self validToken];
  self.fakeAppCheckProvider.tokenToReturn = newToken;
  self.fakeStorage.setTokenPromise = [FBLPromise resolvedWith:newToken];

  XCTestExpectation *expectation2 = [self expectationWithDescription:@"getToken2"];
  [self.appCheck tokenForcingRefresh:NO
                          completion:^(GACAppCheckTokenResult *result) {
                            [expectation2 fulfill];
                            XCTAssertEqualObjects(result.token, newToken);
                          }];
  [self waitForExpectations:@[ expectation2 ] timeout:0.5];
  XCTAssertEqual(self.fakeAppCheckProvider.getTokenCallCount, 2);
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
