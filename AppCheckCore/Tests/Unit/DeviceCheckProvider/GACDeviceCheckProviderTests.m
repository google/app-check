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

#import <FirebaseCoreExtension/FirebaseCoreInternal.h>
#import <OCMock/OCMock.h>
#import "FBLPromise+Testing.h"

#import "AppCheckCore/Sources/DeviceCheckProvider/API/GACDeviceCheckAPIService.h"
#import "AppCheckCore/Sources/DeviceCheckProvider/GACDeviceCheckTokenGenerator.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheckToken.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/GACDeviceCheckProvider.h"

#import "AppCheckCore/Tests/Utils/AppCheckBackoffWrapperFake/GACAppCheckBackoffWrapperFake.h"

#if GAC_DEVICE_CHECK_SUPPORTED_TARGETS

GAC_DEVICE_CHECK_PROVIDER_AVAILABILITY
@interface GACDeviceCheckProvider (Tests)

- (instancetype)initWithAPIService:(id<GACDeviceCheckAPIServiceProtocol>)APIService
              deviceTokenGenerator:(id<GACDeviceCheckTokenGenerator>)deviceTokenGenerator
                    backoffWrapper:(id<GACAppCheckBackoffWrapperProtocol>)backoffWrapper;

@end

GAC_DEVICE_CHECK_PROVIDER_AVAILABILITY
@interface GACDeviceCheckProviderTests : XCTestCase

@property(nonatomic) GACDeviceCheckProvider *provider;
@property(nonatomic) id fakeAPIService;
@property(nonatomic) id fakeTokenGenerator;
@property(nonatomic) GACAppCheckBackoffWrapperFake *fakeBackoffWrapper;

@end

@implementation GACDeviceCheckProviderTests

- (void)setUp {
  [super setUp];

  self.fakeAPIService = OCMProtocolMock(@protocol(GACDeviceCheckAPIServiceProtocol));
  self.fakeTokenGenerator = OCMProtocolMock(@protocol(GACDeviceCheckTokenGenerator));

  self.fakeBackoffWrapper = [[GACAppCheckBackoffWrapperFake alloc] init];
  // Don't backoff by default.
  self.fakeBackoffWrapper.isNextOperationAllowed = YES;

  self.provider = [[GACDeviceCheckProvider alloc] initWithAPIService:self.fakeAPIService
                                                deviceTokenGenerator:self.fakeTokenGenerator
                                                      backoffWrapper:self.fakeBackoffWrapper];
}

- (void)tearDown {
  self.provider = nil;
  self.fakeAPIService = nil;
  self.fakeTokenGenerator = nil;
  self.fakeBackoffWrapper = nil;
}

- (void)testInitWithValidApp {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"app_id" GCMSenderID:@"sender_id"];
  options.APIKey = @"api_key";
  options.projectID = @"project_id";
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:@"testInitWithValidApp" options:options];

  XCTAssertNotNil([[GACDeviceCheckProvider alloc]
      initWithServiceName:app.name
             resourceName:[GACDeviceCheckProviderTests resourceNameFromApp:app]
                   APIKey:app.options.APIKey
             requestHooks:nil]);
}

- (void)testGetTokenSuccess {
  // 1. Expect device token to be generated.
  NSData *deviceToken = [NSData data];
  id generateTokenArg = [OCMArg invokeBlockWithArgs:deviceToken, [NSNull null], nil];
  OCMExpect([self.fakeTokenGenerator generateTokenWithCompletionHandler:generateTokenArg]);

  // 2. Expect FAA token to be requested.
  GACAppCheckToken *validToken = [[GACAppCheckToken alloc] initWithToken:@"valid_token"
                                                          expirationDate:[NSDate distantFuture]
                                                          receivedAtDate:[NSDate date]];
  OCMExpect([self.fakeAPIService appCheckTokenWithDeviceToken:deviceToken])
      .andReturn([FBLPromise resolvedWith:validToken]);

  // 3. Expect backoff wrapper to be used.
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 4. Call getToken and validate the result.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];
        XCTAssertEqualObjects(token.token, validToken.token);
        XCTAssertEqualObjects(token.expirationDate, validToken.expirationDate);
        XCTAssertEqualObjects(token.receivedAtDate, validToken.receivedAtDate);
        XCTAssertNil(error);
      }];

  [self waitForExpectations:@[ self.fakeBackoffWrapper.backoffExpectation, completionExpectation ]
                    timeout:0.5
               enforceOrder:YES];

  // 5. Verify.
  XCTAssertNil(self.fakeBackoffWrapper.operationError);
  GACAppCheckToken *wrapperResult =
      [self.fakeBackoffWrapper.operationResult isKindOfClass:[GACAppCheckToken class]]
          ? self.fakeBackoffWrapper.operationResult
          : nil;
  XCTAssertEqualObjects(wrapperResult.token, validToken.token);

  OCMVerifyAll(self.fakeAPIService);
  OCMVerifyAll(self.fakeTokenGenerator);
}

- (void)testGetTokenWhenDeviceTokenFails {
  NSError *deviceTokenError = [NSError errorWithDomain:@"GACDeviceCheckProviderTests"
                                                  code:-1
                                              userInfo:nil];

  // 0.1. Expect backoff wrapper to be used.
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 0.2. Expect default error handler to be used.
  XCTestExpectation *errorHandlerExpectation = [self expectationWithDescription:@"Error handler"];
  self.fakeBackoffWrapper.defaultErrorHandler = ^GACAppCheckBackoffType(NSError *_Nonnull error) {
    XCTAssertEqualObjects(error, deviceTokenError);
    [errorHandlerExpectation fulfill];
    return GACAppCheckBackoffType1Day;
  };

  // 1. Expect device token to be generated.
  id generateTokenArg = [OCMArg invokeBlockWithArgs:[NSNull null], deviceTokenError, nil];
  OCMExpect([self.fakeTokenGenerator generateTokenWithCompletionHandler:generateTokenArg]);

  // 2. Don't expect FAA token to be requested.
  OCMReject([self.fakeAPIService appCheckTokenWithDeviceToken:[OCMArg any]]);

  // 3. Call getToken and validate the result.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];
        XCTAssertNil(token);
        XCTAssertEqualObjects(error, deviceTokenError);
      }];

  [self waitForExpectations:@[
    self.fakeBackoffWrapper.backoffExpectation, errorHandlerExpectation, completionExpectation
  ]
                    timeout:0.5
               enforceOrder:YES];

  // 4. Verify.
  OCMVerifyAll(self.fakeAPIService);
  OCMVerifyAll(self.fakeTokenGenerator);

  XCTAssertEqualObjects(self.fakeBackoffWrapper.operationError, deviceTokenError);
  XCTAssertNil(self.fakeBackoffWrapper.operationResult);
}

- (void)testGetTokenWhenAPIServiceFails {
  NSError *APIServiceError = [NSError errorWithDomain:@"GACDeviceCheckProviderTests"
                                                 code:-1
                                             userInfo:nil];

  // 0.1. Expect backoff wrapper to be used.
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 0.2. Expect default error handler to be used.
  XCTestExpectation *errorHandlerExpectation = [self expectationWithDescription:@"Error handler"];
  self.fakeBackoffWrapper.defaultErrorHandler = ^GACAppCheckBackoffType(NSError *_Nonnull error) {
    XCTAssertEqualObjects(error, APIServiceError);
    [errorHandlerExpectation fulfill];
    return GACAppCheckBackoffType1Day;
  };

  // 1. Expect device token to be generated.
  NSData *deviceToken = [NSData data];
  id generateTokenArg = [OCMArg invokeBlockWithArgs:deviceToken, [NSNull null], nil];
  OCMExpect([self.fakeTokenGenerator generateTokenWithCompletionHandler:generateTokenArg]);

  // 2. Expect FAA token to be requested.
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  [rejectedPromise reject:APIServiceError];
  OCMExpect([self.fakeAPIService appCheckTokenWithDeviceToken:deviceToken])
      .andReturn(rejectedPromise);

  // 3. Call getToken and validate the result.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];
        XCTAssertNil(token);
        XCTAssertEqualObjects(error, APIServiceError);
      }];

  [self waitForExpectations:@[
    self.fakeBackoffWrapper.backoffExpectation, errorHandlerExpectation, completionExpectation
  ]
                    timeout:0.5
               enforceOrder:YES];

  // 4. Verify.
  OCMVerifyAll(self.fakeAPIService);
  OCMVerifyAll(self.fakeTokenGenerator);

  XCTAssertEqualObjects(self.fakeBackoffWrapper.operationError, APIServiceError);
  XCTAssertNil(self.fakeBackoffWrapper.operationResult);
}

#pragma mark - Backoff tests

- (void)testGetTokenBackoff {
  // 1. Configure backoff.
  self.fakeBackoffWrapper.isNextOperationAllowed = NO;
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 2. Don't expect any operations.
  OCMReject([self.fakeAPIService appCheckTokenWithDeviceToken:[OCMArg any]]);
  OCMReject([self.fakeTokenGenerator generateTokenWithCompletionHandler:OCMOCK_ANY]);

  // 3. Call getToken and validate the result.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];
        XCTAssertNil(token);
        XCTAssertEqualObjects(error, self.fakeBackoffWrapper.backoffError);
      }];

  [self waitForExpectations:@[ self.fakeBackoffWrapper.backoffExpectation, completionExpectation ]
                    timeout:0.5
               enforceOrder:YES];

  // 4. Verify.
  OCMVerifyAll(self.fakeAPIService);
  OCMVerifyAll(self.fakeTokenGenerator);
}

#pragma mark - Helpers

// TODO(andrewheard): Remove from generic App Check SDK.
// FIREBASE_APP_CHECK_ONLY_BEGIN

+ (NSString *)resourceNameFromApp:(FIRApp *)app {
  return [NSString
      stringWithFormat:@"projects/%@/apps/%@", app.options.projectID, app.options.googleAppID];
}

// FIREBASE_APP_CHECK_ONLY_END

@end

#endif  // GAC_DEVICE_CHECK_SUPPORTED_TARGETS
