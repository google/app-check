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

#import <OCMock/OCMock.h>
#import <GoogleUtilities/GULUserDefaults.h>
#import "FBLPromise+Testing.h"

#import "AppCheckCore/Sources/DebugProvider/API/GACAppCheckDebugProviderAPIService.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheckDebugProvider.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheckToken.h"

static NSString *const kDebugTokenEnvKey = @"AppCheckDebugToken";
static NSString *const kFirebaseDebugTokenEnvKey = @"FIRAAppCheckDebugToken";
static NSString *const kDebugTokenUserDefaultsKey = @"GACAppCheckDebugToken";

@interface GACAppCheckDebugProvider (Tests)

- (instancetype)initWithAPIService:(id<GACAppCheckDebugProviderAPIServiceProtocol>)APIService;

@end

@interface GACAppCheckDebugProviderTests : XCTestCase

@property(nonatomic) GACAppCheckDebugProvider *provider;
@property(nonatomic) id processInfoMock;
@property(nonatomic) id fakeAPIService;

@end

typedef void (^GACAppCheckTokenValidationBlock)(GACAppCheckToken *_Nullable token,
                                                NSError *_Nullable error);

@implementation GACAppCheckDebugProviderTests

- (void)setUp {
  self.processInfoMock = OCMPartialMock([NSProcessInfo processInfo]);

  self.fakeAPIService = OCMProtocolMock(@protocol(GACAppCheckDebugProviderAPIServiceProtocol));
  self.provider = [[GACAppCheckDebugProvider alloc] initWithAPIService:self.fakeAPIService];
}

- (void)tearDown {
  self.provider = nil;
  [self.processInfoMock stopMocking];
  self.processInfoMock = nil;
  [[GULUserDefaults standardUserDefaults] removeObjectForKey:kDebugTokenUserDefaultsKey];
}

#pragma mark - Debug token generating/storing

- (void)testCurrentTokenWhenEnvironmentVariableSetAndTokenStored {
  [[GULUserDefaults standardUserDefaults] setObject:@"stored token"
                                            forKey:kDebugTokenUserDefaultsKey];
  NSString *envToken = @"env token";
  OCMExpect([self.processInfoMock processInfo]).andReturn(self.processInfoMock);
  OCMExpect([self.processInfoMock environment]).andReturn(@{kDebugTokenEnvKey : envToken});
  self.provider = [[GACAppCheckDebugProvider alloc] initWithAPIService:self.fakeAPIService];

  XCTAssertEqualObjects([self.provider currentDebugToken], envToken);
}

- (void)testCurrentTokenWhenFirebaseAndCoreEnvironmentVariablesSetAndTokenStored {
  [[GULUserDefaults standardUserDefaults] setObject:@"stored token"
                                            forKey:kDebugTokenUserDefaultsKey];
  NSString *envToken = @"env token";
  OCMExpect([self.processInfoMock processInfo]).andReturn(self.processInfoMock);
  OCMExpect([self.processInfoMock environment])
      .andReturn(
          (@{kDebugTokenEnvKey : envToken, kFirebaseDebugTokenEnvKey : @"firebase env token"}));
  self.provider = [[GACAppCheckDebugProvider alloc] initWithAPIService:self.fakeAPIService];

  XCTAssertEqualObjects([self.provider currentDebugToken], envToken);
}

- (void)testCurrentTokenWhenFirebaseEnvironmentVariableSetAndTokenStored {
  [[GULUserDefaults standardUserDefaults] setObject:@"stored token"
                                            forKey:kDebugTokenUserDefaultsKey];
  NSString *envToken = @"env token";
  OCMExpect([self.processInfoMock processInfo]).andReturn(self.processInfoMock);
  OCMExpect([self.processInfoMock environment]).andReturn((@{
    kFirebaseDebugTokenEnvKey : envToken
  }));
  self.provider = [[GACAppCheckDebugProvider alloc] initWithAPIService:self.fakeAPIService];

  XCTAssertEqualObjects([self.provider currentDebugToken], envToken);
}

- (void)testCurrentTokenWhenFirebaseAndCoreEnvironmentVariablesSet {
  NSString *envToken = @"env token";
  OCMExpect([self.processInfoMock processInfo]).andReturn(self.processInfoMock);
  OCMExpect([self.processInfoMock environment])
      .andReturn(
          (@{kDebugTokenEnvKey : envToken, kFirebaseDebugTokenEnvKey : @"firebase env token"}));
  self.provider = [[GACAppCheckDebugProvider alloc] initWithAPIService:self.fakeAPIService];

  XCTAssertEqualObjects([self.provider currentDebugToken], envToken);
}

- (void)testCurrentTokenWhenNoEnvironmentVariableAndTokenStored {
  NSString *storedToken = @"stored token";
  [[GULUserDefaults standardUserDefaults] setObject:storedToken forKey:kDebugTokenUserDefaultsKey];

  XCTAssertNil(NSProcessInfo.processInfo.environment[kDebugTokenEnvKey]);

  XCTAssertEqualObjects([self.provider currentDebugToken], storedToken);
}

- (void)testCurrentTokenWhenNoEnvironmentVariableAndNoTokenStored {
  [[GULUserDefaults standardUserDefaults] removeObjectForKey:kDebugTokenUserDefaultsKey];
  XCTAssertNil(NSProcessInfo.processInfo.environment[kDebugTokenEnvKey]);
  XCTAssertNil([[GULUserDefaults standardUserDefaults] stringForKey:kDebugTokenUserDefaultsKey]);

  NSString *generatedToken = [self.provider currentDebugToken];
  XCTAssertNotNil(generatedToken);

  // Check if the generated token is stored to the user defaults.
  XCTAssertEqualObjects(
      [[GULUserDefaults standardUserDefaults] stringForKey:kDebugTokenUserDefaultsKey],
      generatedToken);

  // Check if the same token is used once generated.
  XCTAssertEqualObjects([self.provider currentDebugToken], generatedToken);
}

#pragma mark - Debug token to FAC token exchange

- (void)testGetTokenSuccess {
  // 1. Stub API service.
  NSString *expectedDebugToken = [self.provider currentDebugToken];
  GACAppCheckToken *validToken = [[GACAppCheckToken alloc] initWithToken:@"valid_token"
                                                          expirationDate:[NSDate date]
                                                          receivedAtDate:[NSDate date]];
  OCMExpect([self.fakeAPIService appCheckTokenWithDebugToken:expectedDebugToken limitedUse:NO])
      .andReturn([FBLPromise resolvedWith:validToken]);
  OCMReject([self.fakeAPIService appCheckTokenWithDebugToken:OCMOCK_ANY limitedUse:YES]);

  // 2. Validate get token.
  [self validateGetToken:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(token.token, validToken.token);
    XCTAssertEqualObjects(token.expirationDate, validToken.expirationDate);
    XCTAssertEqualObjects(token.receivedAtDate, validToken.receivedAtDate);
  }];

  // 3. Verify fakes.
  OCMVerifyAll(self.fakeAPIService);
}

- (void)testGetTokenAPIError {
  // 1. Stub API service.
  NSString *expectedDebugToken = [self.provider currentDebugToken];
  NSError *APIError = [NSError errorWithDomain:@"testGetTokenAPIError" code:-1 userInfo:nil];
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  [rejectedPromise reject:APIError];
  OCMExpect([self.fakeAPIService appCheckTokenWithDebugToken:expectedDebugToken limitedUse:NO])
      .andReturn(rejectedPromise);
  OCMReject([self.fakeAPIService appCheckTokenWithDebugToken:OCMOCK_ANY limitedUse:YES]);

  // 2. Validate get token.
  [self validateGetToken:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
    XCTAssertEqualObjects(error, APIError);
    XCTAssertNil(token);
  }];

  // 3. Verify fakes.
  OCMVerifyAll(self.fakeAPIService);
}

- (void)testGetLimitedUseTokenSuccess {
  // 1. Stub API service.
  NSString *expectedDebugToken = [self.provider currentDebugToken];
  GACAppCheckToken *validToken = [[GACAppCheckToken alloc] initWithToken:@"valid_token"
                                                          expirationDate:[NSDate date]
                                                          receivedAtDate:[NSDate date]];
  OCMExpect([self.fakeAPIService appCheckTokenWithDebugToken:expectedDebugToken limitedUse:YES])
      .andReturn([FBLPromise resolvedWith:validToken]);
  OCMReject([self.fakeAPIService appCheckTokenWithDebugToken:OCMOCK_ANY limitedUse:NO]);

  // 2. Validate get limited-use token.
  [self validateGetLimitedUseToken:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(token.token, validToken.token);
    XCTAssertEqualObjects(token.expirationDate, validToken.expirationDate);
    XCTAssertEqualObjects(token.receivedAtDate, validToken.receivedAtDate);
  }];

  // 3. Verify fakes.
  OCMVerifyAll(self.fakeAPIService);
}

- (void)testGetLimitedUseTokenAPIError {
  // 1. Stub API service.
  NSString *expectedDebugToken = [self.provider currentDebugToken];
  NSError *APIError = [NSError errorWithDomain:@"testGetLimitedUseTokenAPIError"
                                          code:-1
                                      userInfo:nil];
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  [rejectedPromise reject:APIError];
  OCMExpect([self.fakeAPIService appCheckTokenWithDebugToken:expectedDebugToken limitedUse:YES])
      .andReturn(rejectedPromise);
  OCMReject([self.fakeAPIService appCheckTokenWithDebugToken:OCMOCK_ANY limitedUse:NO]);

  // 2. Validate get limited-use token.
  [self validateGetLimitedUseToken:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
    XCTAssertEqualObjects(error, APIError);
    XCTAssertNil(token);
  }];

  // 3. Verify fakes.
  OCMVerifyAll(self.fakeAPIService);
}

#pragma mark - Helpers

- (void)validateGetToken:(GACAppCheckTokenValidationBlock)validationBlock {
  XCTestExpectation *expectation = [self expectationWithDescription:@"getToken"];
  [self.provider
      getTokenWithCompletion:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
        validationBlock(token, error);
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:0.5];
}

- (void)validateGetLimitedUseToken:(GACAppCheckTokenValidationBlock)validationBlock {
  XCTestExpectation *expectation = [self expectationWithDescription:@"getLimitedUseToken"];
  [self.provider getLimitedUseTokenWithCompletion:^(GACAppCheckToken *_Nullable token,
                                                    NSError *_Nullable error) {
    validationBlock(token, error);
    [expectation fulfill];
  }];

  [self waitForExpectations:@[ expectation ] timeout:0.5];
}

@end
