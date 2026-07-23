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

#import "FBLPromise+Testing.h"

#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheck.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheckToken.h"

#import "AppCheckCore/Sources/DebugProvider/API/GACAppCheckDebugProviderAPIService.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/_GACAppCheckAPIService.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/_GACAppCheckErrorUtil.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/_GACURLSessionDataResponse.h"

#import "AppCheckCore/Tests/Unit/Utils/GACAppCheckAPIServiceFake.h"
#import "AppCheckCore/Tests/Unit/Utils/GACURLSessionFake.h"

static NSString *const kResourceName = @"projects/test_project_id/apps/test_app_id";

@interface GACAppCheckDebugProviderAPIServiceTests : XCTestCase
@property(nonatomic) GACAppCheckDebugProviderAPIService *debugAPIService;

@property(nonatomic) GACAppCheckAPIServiceFake *mockAPIService;
@end

@implementation GACAppCheckDebugProviderAPIServiceTests

- (void)setUp {
  [super setUp];

  self.mockAPIService = [[GACAppCheckAPIServiceFake alloc] init];
  self.mockAPIService.baseURL = @"https://test.appcheck.url.com/alpha";

  self.debugAPIService =
      [[GACAppCheckDebugProviderAPIService alloc] initWithAPIService:self.mockAPIService
                                                        resourceName:kResourceName];
}

- (void)tearDown {
  self.debugAPIService = nil;
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
  NSData *fakeResponseData = [@"fake response" dataUsingEncoding:NSUTF8StringEncoding];
  NSHTTPURLResponse *HTTPResponse = [GACURLSessionFake HTTPResponseWithCode:200];
  _GACURLSessionDataResponse *APIResponse =
      [[_GACURLSessionDataResponse alloc] initWithResponse:HTTPResponse HTTPBody:fakeResponseData];

  self.mockAPIService.sendRequestPromise = [FBLPromise resolvedWith:APIResponse];

  // 1.2. Stub response parsing.
  self.mockAPIService.appCheckTokenPromise = [FBLPromise resolvedWith:expectedResult];

  // 2. Send request.
  __auto_type tokenPromise = [self.debugAPIService appCheckTokenWithDebugToken:debugToken
                                                                    limitedUse:limitedUse];

  // 3. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(tokenPromise.isFulfilled);
  XCTAssertNil(tokenPromise.error);

  XCTAssertEqualObjects(tokenPromise.value.token, expectedResult.token);
  XCTAssertEqualObjects(tokenPromise.value.expirationDate, expectedResult.expirationDate);

  XCTAssertEqualObjects(tokenPromise.value.token, expectedResult.token);
  XCTAssertEqualObjects(tokenPromise.value.expirationDate, expectedResult.expirationDate);

  XCTAssertEqualObjects(self.mockAPIService.passedRequestURL.absoluteString, expectedRequestURL);
  XCTAssertEqualObjects(self.mockAPIService.passedHTTPMethod, @"POST");
  XCTAssertEqualObjects(self.mockAPIService.passedAdditionalHeaders[@"Content-Type"],
                        @"application/json");
  [self assertHTTPBody:self.mockAPIService.passedBody debugToken:debugToken limitedUse:limitedUse];
  XCTAssertEqualObjects(self.mockAPIService.passedAPIResponse, APIResponse);
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
  NSData *fakeResponseData = [@"fake response" dataUsingEncoding:NSUTF8StringEncoding];
  NSHTTPURLResponse *HTTPResponse = [GACURLSessionFake HTTPResponseWithCode:200];
  _GACURLSessionDataResponse *APIResponse =
      [[_GACURLSessionDataResponse alloc] initWithResponse:HTTPResponse HTTPBody:fakeResponseData];

  self.mockAPIService.sendRequestPromise = [FBLPromise resolvedWith:APIResponse];

  // 1.2. Stub response parsing.
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  [rejectedPromise reject:parsingError];
  self.mockAPIService.appCheckTokenPromise = rejectedPromise;

  // 2. Send request.
  __auto_type tokenPromise = [self.debugAPIService appCheckTokenWithDebugToken:debugToken
                                                                    limitedUse:NO];

  // 3. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(tokenPromise.isRejected);
  XCTAssertEqualObjects(tokenPromise.error, parsingError);
  XCTAssertNil(tokenPromise.value);

  XCTAssertEqualObjects(self.mockAPIService.passedRequestURL.absoluteString, expectedRequestURL);
  XCTAssertEqualObjects(self.mockAPIService.passedHTTPMethod, @"POST");
  XCTAssertEqualObjects(self.mockAPIService.passedAdditionalHeaders[@"Content-Type"],
                        @"application/json");
  [self assertHTTPBody:self.mockAPIService.passedBody debugToken:debugToken limitedUse:NO];
  XCTAssertEqualObjects(self.mockAPIService.passedAPIResponse, APIResponse);
}

- (void)testAppCheckTokenNetworkError {
  NSString *debugToken = [NSUUID UUID].UUIDString;
  NSError *APIError = [NSError errorWithDomain:@"testAppCheckTokenNetworkError"
                                          code:-1
                                      userInfo:nil];

  // 1. Stub API service.
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  [rejectedPromise reject:APIError];

  self.mockAPIService.sendRequestPromise = rejectedPromise;

  // 2. Send request.
  __auto_type tokenPromise = [self.debugAPIService appCheckTokenWithDebugToken:debugToken
                                                                    limitedUse:NO];

  // 3. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(tokenPromise.isRejected);
  XCTAssertNil(tokenPromise.value);
  XCTAssertEqualObjects(tokenPromise.error, APIError);

  [self assertHTTPBody:self.mockAPIService.passedBody debugToken:debugToken limitedUse:NO];
}

#pragma mark - Helpores

- (void)assertHTTPBody:(NSData *)body
            debugToken:(NSString *)debugToken
            limitedUse:(BOOL)limitedUse {
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
}

@end
