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
#import "FBLPromise+Testing.h"

#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheck.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheckToken.h"

#import <GoogleUtilities/GULURLSessionDataResponse.h>

#import "AppCheckCore/Sources/Core/APIService/GACAppCheckAPIService.h"
#import "AppCheckCore/Sources/Core/Errors/GACAppCheckErrorUtil.h"
#import "AppCheckCore/Sources/DebugProvider/API/GACAppCheckDebugProviderAPIService.h"

#import "AppCheckCore/Tests/Utils/URLSession/GACURLSessionOCMockStub.h"

static NSString *const kResourceName = @"projects/test_project_id/apps/test_app_id";

@interface GACAppCheckDebugProviderAPIServiceTests : XCTestCase
@property(nonatomic) GACAppCheckDebugProviderAPIService *debugAPIService;

@property(nonatomic) id mockAPIService;
@end

@implementation GACAppCheckDebugProviderAPIServiceTests

- (void)setUp {
  [super setUp];

  self.mockAPIService = OCMProtocolMock(@protocol(GACAppCheckAPIServiceProtocol));
  OCMStub([self.mockAPIService baseURL]).andReturn(@"https://test.appcheck.url.com/alpha");

  self.debugAPIService =
      [[GACAppCheckDebugProviderAPIService alloc] initWithAPIService:self.mockAPIService
                                                        resourceName:kResourceName];
}

- (void)tearDown {
  self.debugAPIService = nil;
  [self.mockAPIService stopMocking];
  self.mockAPIService = nil;
  [super tearDown];
}

- (void)testAppCheckTokenSuccess {
  [self testAppCheckTokenSuccessWithLimitedUse:NO];
}

- (void)testAppCheckTokenSuccessWithLimitedUse {
  [self testAppCheckTokenSuccessWithLimitedUse:YES];
}

- (void)testAppCheckTokenSuccessWithLimitedUse:(BOOL)limitedUse {
  NSString *debugToken = [NSUUID UUID].UUIDString;
  GACAppCheckToken *expectedResult = [[GACAppCheckToken alloc] initWithToken:@"app_check_token"
                                                              expirationDate:[NSDate date]];

  // 1. Stub API service.
  // 1.1. Stub API response.
  NSString *expectedRequestURL =
      [NSString stringWithFormat:@"%@%@", [self.mockAPIService baseURL],
                                 @"/projects/test_project_id/apps/test_app_id:exchangeDebugToken"];
  id URLValidationArg = [OCMArg checkWithBlock:^BOOL(NSURL *URL) {
    XCTAssertEqualObjects(URL.absoluteString, expectedRequestURL);
    return YES;
  }];

  id HTTPBodyValidationArg = [self HTTPBodyValidationArgWithDebugToken:debugToken
                                                            limitedUse:limitedUse];
  NSData *fakeResponseData = [@"fake response" dataUsingEncoding:NSUTF8StringEncoding];
  NSHTTPURLResponse *HTTPResponse = [GACURLSessionOCMockStub HTTPResponseWithCode:200];
  GULURLSessionDataResponse *APIResponse =
      [[GULURLSessionDataResponse alloc] initWithResponse:HTTPResponse HTTPBody:fakeResponseData];

  OCMExpect([self.mockAPIService sendRequestWithURL:URLValidationArg
                                         HTTPMethod:@"POST"
                                               body:HTTPBodyValidationArg
                                  additionalHeaders:@{@"Content-Type" : @"application/json"}])
      .andReturn([FBLPromise resolvedWith:APIResponse]);

  // 1.2. Stub response parsing.
  OCMExpect([self.mockAPIService appCheckTokenWithAPIResponse:APIResponse])
      .andReturn([FBLPromise resolvedWith:expectedResult]);

  // 2. Send request.
  __auto_type tokenPromise = [self.debugAPIService appCheckTokenWithDebugToken:debugToken
                                                                    limitedUse:limitedUse];

  // 3. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(tokenPromise.isFulfilled);
  XCTAssertNil(tokenPromise.error);

  XCTAssertEqualObjects(tokenPromise.value.token, expectedResult.token);
  XCTAssertEqualObjects(tokenPromise.value.expirationDate, expectedResult.expirationDate);

  OCMVerifyAll(self.mockAPIService);
}

- (void)testAppCheckTokenResponseParsingError {
  NSString *debugToken = [NSUUID UUID].UUIDString;
  NSError *parsingError = [NSError errorWithDomain:@"testAppCheckTokenResponseParsingError"
                                              code:-1
                                          userInfo:nil];

  // 1. Stub API service.
  // 1.1. Stub API response.
  NSString *expectedRequestURL =
      [NSString stringWithFormat:@"%@%@", [self.mockAPIService baseURL],
                                 @"/projects/test_project_id/apps/test_app_id:exchangeDebugToken"];
  id URLValidationArg = [OCMArg checkWithBlock:^BOOL(NSURL *URL) {
    XCTAssertEqualObjects(URL.absoluteString, expectedRequestURL);
    return YES;
  }];

  id HTTPBodyValidationArg = [self HTTPBodyValidationArgWithDebugToken:debugToken limitedUse:NO];
  NSData *fakeResponseData = [@"fake response" dataUsingEncoding:NSUTF8StringEncoding];
  NSHTTPURLResponse *HTTPResponse = [GACURLSessionOCMockStub HTTPResponseWithCode:200];
  GULURLSessionDataResponse *APIResponse =
      [[GULURLSessionDataResponse alloc] initWithResponse:HTTPResponse HTTPBody:fakeResponseData];

  OCMExpect([self.mockAPIService sendRequestWithURL:URLValidationArg
                                         HTTPMethod:@"POST"
                                               body:HTTPBodyValidationArg
                                  additionalHeaders:@{@"Content-Type" : @"application/json"}])
      .andReturn([FBLPromise resolvedWith:APIResponse]);

  // 1.2. Stub response parsing.
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  [rejectedPromise reject:parsingError];
  OCMExpect([self.mockAPIService appCheckTokenWithAPIResponse:APIResponse])
      .andReturn(rejectedPromise);

  // 2. Send request.
  __auto_type tokenPromise = [self.debugAPIService appCheckTokenWithDebugToken:debugToken
                                                                    limitedUse:NO];

  // 3. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(tokenPromise.isRejected);
  XCTAssertEqualObjects(tokenPromise.error, parsingError);
  XCTAssertNil(tokenPromise.value);

  OCMVerifyAll(self.mockAPIService);
}

- (void)testAppCheckTokenNetworkError {
  NSString *debugToken = [NSUUID UUID].UUIDString;
  NSError *APIError = [NSError errorWithDomain:@"testAppCheckTokenNetworkError"
                                          code:-1
                                      userInfo:nil];

  // 1. Stub API service.
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  [rejectedPromise reject:APIError];

  id HTTPBodyValidationArg = [self HTTPBodyValidationArgWithDebugToken:debugToken limitedUse:NO];
  OCMExpect([self.mockAPIService sendRequestWithURL:[OCMArg any]
                                         HTTPMethod:@"POST"
                                               body:HTTPBodyValidationArg
                                  additionalHeaders:@{@"Content-Type" : @"application/json"}])
      .andReturn(rejectedPromise);

  // 2. Send request.
  __auto_type tokenPromise = [self.debugAPIService appCheckTokenWithDebugToken:debugToken
                                                                    limitedUse:NO];

  // 3. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(tokenPromise.isRejected);
  XCTAssertNil(tokenPromise.value);
  XCTAssertEqualObjects(tokenPromise.error, APIError);

  OCMVerifyAll(self.mockAPIService);
}

#pragma mark - Helpores

- (id)HTTPBodyValidationArgWithDebugToken:(NSString *)debugToken limitedUse:(BOOL)limitedUse {
  return [OCMArg checkWithBlock:^BOOL(NSData *body) {
    NSDictionary<NSString *, id> *decodedData = [NSJSONSerialization JSONObjectWithData:body
                                                                                options:0
                                                                                  error:nil];
    XCTAssert([decodedData isKindOfClass:[NSDictionary class]]);

    NSString *decodeDebugToken = decodedData[@"debug_token"];
    XCTAssertNotNil(decodeDebugToken);
    XCTAssertEqualObjects(decodeDebugToken, debugToken);
    NSNumber *decodedLimitedUse = decodedData[@"limited_use"];
    XCTAssertNotNil(decodedLimitedUse);
    XCTAssertEqualObjects(decodedLimitedUse, @(limitedUse));
    return YES;
  }];
}

@end
