/*
 * Copyright 2021 Google LLC
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

#import "AppCheckCore/Sources/AppAttestProvider/API/GACAppAttestAPIService.h"
#import "AppCheckCore/Sources/AppAttestProvider/API/GACAppAttestAttestationResponse.h"
#import "AppCheckCore/Sources/Core/Errors/GACAppCheckHTTPError.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheckErrors.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheckToken.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/_GACAppCheckAPIService.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/_GACAppCheckErrorUtil.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/_GACURLSessionDataResponse.h"

#import "AppCheckCore/Tests/Unit/Utils/GACAppCheckAPIServiceFake.h"
#import "AppCheckCore/Tests/Unit/Utils/GACFixtureLoader.h"
#import "AppCheckCore/Tests/Unit/Utils/GACURLSessionFake.h"
#import "AppCheckCore/Tests/Utils/Date/GACDateTestUtils.h"

static NSString *const kBaseURL = @"https://test.appcheck.url.com/beta";
static NSString *const kResourceName = @"projects/project_id/apps/app_id";

@interface GACAppAttestAPIServiceTests : XCTestCase

@property(nonatomic) GACAppAttestAPIService *appAttestAPIService;

@property(nonatomic) GACAppCheckAPIServiceFake *fakeAPIService;

@end

@implementation GACAppAttestAPIServiceTests

- (void)setUp {
  [super setUp];

  self.fakeAPIService = [[GACAppCheckAPIServiceFake alloc] init];
  self.fakeAPIService.baseURL = kBaseURL;

  self.appAttestAPIService = [[GACAppAttestAPIService alloc] initWithAPIService:self.fakeAPIService
                                                                   resourceName:kResourceName];
}

- (void)tearDown {
  [super tearDown];

  self.appAttestAPIService = nil;
  self.fakeAPIService = nil;
}

#pragma mark - Random challenge request

- (void)testGetRandomChallengeWhenAPIResponseValid {
  // 1. Prepare API response.
  NSData *responseBody = [GACFixtureLoader loadFixtureNamed:@"AppAttestResponseSuccess.json"];
  _GACURLSessionDataResponse *validAPIResponse = [self APIResponseWithCode:200
                                                              responseBody:responseBody];
  // 2. Stub API Service Request to return prepared API response.
  [self stubMockAPIServiceRequestForChallengeRequestWithResponse:validAPIResponse];

  // 3. Request the random challenge and verify results.
  __auto_type *promise = [self.appAttestAPIService getRandomChallenge];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssert(promise.isFulfilled);
  XCTAssertNotNil(promise.value);
  XCTAssertNil(promise.error);

  NSString *challengeString = [[NSString alloc] initWithData:promise.value
                                                    encoding:NSUTF8StringEncoding];
  // The challenge stored in `AppAttestResponseSuccess.json` is a valid base64 encoding of
  // the string "random_challenge".
  XCTAssert([challengeString isEqualToString:@"random_challenge"]);

  NSString *expectedRequestURL =
      [NSString stringWithFormat:@"%@/%@:%@", [self.fakeAPIService baseURL], kResourceName,
                                 @"generateAppAttestChallenge"];
  XCTAssertEqualObjects(self.fakeAPIService.passedRequestURL.absoluteString, expectedRequestURL);
  XCTAssertEqualObjects(self.fakeAPIService.passedHTTPMethod, @"POST");
}

- (void)testGetRandomChallengeWhenAPIError {
  // 1. Prepare API response.
  NSString *responseBodyString = @"Generate challenge failed with invalid format.";
  NSData *responseBody = [responseBodyString dataUsingEncoding:NSUTF8StringEncoding];
  _GACURLSessionDataResponse *invalidAPIResponse = [self APIResponseWithCode:300
                                                                responseBody:responseBody];
  GACAppCheckHTTPError *APIError =
      [_GACAppCheckErrorUtil APIErrorWithHTTPResponse:invalidAPIResponse.HTTPResponse
                                                 data:invalidAPIResponse.HTTPBody];
  // 2. Stub API Service Request to return prepared API response.
  [self stubMockAPIServiceRequestForChallengeRequestWithResponse:APIError];

  // 3. Request the random challenge and verify results.
  __auto_type *promise = [self.appAttestAPIService getRandomChallenge];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssert(promise.isRejected);
  XCTAssertNotNil(promise.error);
  XCTAssertNil(promise.value);

  // Assert error is as expected.
  XCTAssertEqualObjects(promise.error.domain, GACAppCheckErrorDomain);
  XCTAssertEqual(promise.error.code, GACAppCheckErrorCodeUnknown);

  // Expect response body and HTTP status code to be included in the error.
  NSString *failureReason = promise.error.userInfo[NSLocalizedFailureReasonErrorKey];
  XCTAssertTrue([failureReason containsString:@"300"]);
  XCTAssertTrue([failureReason containsString:responseBodyString]);

  NSString *expectedRequestURL =
      [NSString stringWithFormat:@"%@/%@:%@", [self.fakeAPIService baseURL], kResourceName,
                                 @"generateAppAttestChallenge"];
  XCTAssertEqualObjects(self.fakeAPIService.passedRequestURL.absoluteString, expectedRequestURL);
  XCTAssertEqualObjects(self.fakeAPIService.passedHTTPMethod, @"POST");
}

- (void)testGetRandomChallengeWhenAPIResponseEmpty {
  // 1. Prepare API response.
  NSData *responseBody = [NSData data];
  _GACURLSessionDataResponse *emptyAPIResponse = [self APIResponseWithCode:200
                                                              responseBody:responseBody];
  // 2. Stub API Service Request to return prepared API response.
  [self stubMockAPIServiceRequestForChallengeRequestWithResponse:emptyAPIResponse];

  // 3. Request the random challenge and verify results.
  __auto_type *promise = [self.appAttestAPIService getRandomChallenge];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssert(promise.isRejected);
  XCTAssertNotNil(promise.error);
  XCTAssertNil(promise.value);

  // Expect response body and HTTP status code to be included in the error.
  NSString *failureReason = promise.error.userInfo[NSLocalizedFailureReasonErrorKey];
  XCTAssertEqualObjects(failureReason, @"Empty server response body.");

  NSString *expectedRequestURL =
      [NSString stringWithFormat:@"%@/%@:%@", [self.fakeAPIService baseURL], kResourceName,
                                 @"generateAppAttestChallenge"];
  XCTAssertEqualObjects(self.fakeAPIService.passedRequestURL.absoluteString, expectedRequestURL);
  XCTAssertEqualObjects(self.fakeAPIService.passedHTTPMethod, @"POST");
}

- (void)testGetRandomChallengeWhenAPIResponseInvalidFormat {
  // 1. Prepare API response.
  NSString *responseBodyString = @"Generate challenge failed with invalid format.";
  NSData *responseBody = [responseBodyString dataUsingEncoding:NSUTF8StringEncoding];
  _GACURLSessionDataResponse *validAPIResponse = [self APIResponseWithCode:200
                                                              responseBody:responseBody];
  // 2. Stub API Service Request to return prepared API response.
  [self stubMockAPIServiceRequestForChallengeRequestWithResponse:validAPIResponse];

  // 3. Request the random challenge and verify results.
  __auto_type *promise = [self.appAttestAPIService getRandomChallenge];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssert(promise.isRejected);
  XCTAssertNotNil(promise.error);
  XCTAssertNil(promise.value);

  // Expect response body and HTTP status code to be included in the error.
  NSString *failureReason = promise.error.userInfo[NSLocalizedFailureReasonErrorKey];
  XCTAssertEqualObjects(failureReason, @"JSON serialization error.");

  NSString *expectedRequestURL =
      [NSString stringWithFormat:@"%@/%@:%@", [self.fakeAPIService baseURL], kResourceName,
                                 @"generateAppAttestChallenge"];
  XCTAssertEqualObjects(self.fakeAPIService.passedRequestURL.absoluteString, expectedRequestURL);
  XCTAssertEqualObjects(self.fakeAPIService.passedHTTPMethod, @"POST");
}

- (void)testGetRandomChallengeWhenResponseMissingField {
  [self assertMissingFieldErrorWithFixture:@"AppAttestResponseMissingChallenge.json"
                              missingField:@"challenge"];
}

- (void)assertMissingFieldErrorWithFixture:(NSString *)fixtureName
                              missingField:(NSString *)fieldName {
  // 1. Prepare API response.
  NSData *missingFieldBody = [GACFixtureLoader loadFixtureNamed:fixtureName];
  _GACURLSessionDataResponse *incompleteAPIResponse = [self APIResponseWithCode:200
                                                                   responseBody:missingFieldBody];
  // 2. Stub API Service Request to return prepared API response.
  [self stubMockAPIServiceRequestForChallengeRequestWithResponse:incompleteAPIResponse];

  // 3. Request the random challenge and verify results.
  __auto_type *promise = [self.appAttestAPIService getRandomChallenge];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssert(promise.isRejected);
  XCTAssertNotNil(promise.error);
  XCTAssertNil(promise.value);

  // Assert error is as expected.
  XCTAssertEqualObjects(promise.error.domain, GACAppCheckErrorDomain);
  XCTAssertEqual(promise.error.code, GACAppCheckErrorCodeUnknown);

  // Expect missing field name to be included in the error.
  NSString *failureReason = promise.error.userInfo[NSLocalizedFailureReasonErrorKey];
  NSString *fieldNameString = [NSString stringWithFormat:@"`%@`", fieldName];
  XCTAssertTrue([failureReason containsString:fieldNameString],
                @"Fixture `%@`: expected missing field %@ error not found", fixtureName,
                fieldNameString);
}

#pragma mark - Assertion request

- (void)testGetAppCheckTokenSuccess {
  [self testGetAppCheckTokenSuccessWithLimitedUse:NO];
}

- (void)testGetAppCheckTokenSuccessWithLimitedUse {
  [self testGetAppCheckTokenSuccessWithLimitedUse:YES];
}

- (void)testGetAppCheckTokenSuccessWithLimitedUse:(BOOL)limitedUse {
  NSData *artifact = [self generateRandomData];
  NSData *challenge = [self generateRandomData];
  NSData *assertion = [self generateRandomData];

  // 1. Prepare response.
  NSData *responseBody =
      [GACFixtureLoader loadFixtureNamed:@"FACTokenExchangeResponseSuccess.json"];
  _GACURLSessionDataResponse *validAPIResponse = [self APIResponseWithCode:200
                                                              responseBody:responseBody];

  // 2. Stub API Service
  // 2.1. Return prepared response.
  [self expectTokenAPIRequestWithArtifact:artifact
                                challenge:challenge
                                assertion:assertion
                               limitedUse:limitedUse
                                 response:validAPIResponse
                                    error:nil];
  // 2.2. Return token from parsed response.
  GACAppCheckToken *expectedToken = [[GACAppCheckToken alloc] initWithToken:@"app_check_token"
                                                             expirationDate:[NSDate date]
                                                             receivedAtDate:[NSDate date]];
  [self expectTokenWithAPIReponse:validAPIResponse toReturnToken:expectedToken];

  // 3. Send request.
  __auto_type promise = [self.appAttestAPIService getAppCheckTokenWithArtifact:artifact
                                                                     challenge:challenge
                                                                     assertion:assertion
                                                                    limitedUse:limitedUse];
  // 4. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(promise.isFulfilled);
  XCTAssertNil(promise.error);

  XCTAssertEqualObjects(promise.value, expectedToken);
  XCTAssertEqualObjects(promise.value.token, expectedToken.token);
  XCTAssertEqualObjects(promise.value.expirationDate, expectedToken.expirationDate);
  XCTAssertEqualObjects(promise.value.receivedAtDate, expectedToken.receivedAtDate);

  NSString *expectedRequestURL =
      [NSString stringWithFormat:@"%@/%@:%@", [self.fakeAPIService baseURL], kResourceName,
                                 @"exchangeAppAttestAssertion"];
  XCTAssertEqualObjects(self.fakeAPIService.passedRequestURL.absoluteString, expectedRequestURL);
  XCTAssertEqualObjects(self.fakeAPIService.passedHTTPMethod, @"POST");
  XCTAssertEqualObjects(self.fakeAPIService.passedAdditionalHeaders[@"Content-Type"],
                        @"application/json");
  [self assertTokenExchangeBody:self.fakeAPIService.passedBody
                       artifact:artifact
                      challenge:challenge
                      assertion:assertion
                     limitedUse:limitedUse];
}

- (void)testGetAppCheckTokenNetworkError {
  NSData *artifact = [self generateRandomData];
  NSData *challenge = [self generateRandomData];
  NSData *assertion = [self generateRandomData];

  // 1. Prepare response.
  NSData *responseBody =
      [GACFixtureLoader loadFixtureNamed:@"FACTokenExchangeResponseSuccess.json"];
  _GACURLSessionDataResponse *validAPIResponse = [self APIResponseWithCode:200
                                                              responseBody:responseBody];

  // 2. Stub API Service
  // 2.1. Return prepared response.
  NSError *networkError = [NSError errorWithDomain:self.name code:0 userInfo:nil];
  [self expectTokenAPIRequestWithArtifact:artifact
                                challenge:challenge
                                assertion:assertion
                               limitedUse:NO
                                 response:validAPIResponse
                                    error:networkError];

  // 3. Send request.
  __auto_type promise = [self.appAttestAPIService getAppCheckTokenWithArtifact:artifact
                                                                     challenge:challenge
                                                                     assertion:assertion
                                                                    limitedUse:NO];
  // 4. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(promise.isRejected);
  XCTAssertNil(promise.value);
  XCTAssertEqualObjects(promise.error, networkError);

  NSString *expectedRequestURL =
      [NSString stringWithFormat:@"%@/%@:%@", [self.fakeAPIService baseURL], kResourceName,
                                 @"exchangeAppAttestAssertion"];
  XCTAssertEqualObjects(self.fakeAPIService.passedRequestURL.absoluteString, expectedRequestURL);
  XCTAssertEqualObjects(self.fakeAPIService.passedHTTPMethod, @"POST");
  XCTAssertEqualObjects(self.fakeAPIService.passedAdditionalHeaders[@"Content-Type"],
                        @"application/json");
  [self assertTokenExchangeBody:self.fakeAPIService.passedBody
                       artifact:artifact
                      challenge:challenge
                      assertion:assertion
                     limitedUse:NO];
}

- (void)testGetAppCheckTokenUnexpectedResponse {
  NSData *artifact = [self generateRandomData];
  NSData *challenge = [self generateRandomData];
  NSData *assertion = [self generateRandomData];

  // 1. Prepare response.
  NSData *responseBody =
      [GACFixtureLoader loadFixtureNamed:@"DeviceCheckResponseMissingToken.json"];
  _GACURLSessionDataResponse *validAPIResponse = [self APIResponseWithCode:200
                                                              responseBody:responseBody];

  // 2. Stub API Service
  // 2.1. Return prepared response.
  [self expectTokenAPIRequestWithArtifact:artifact
                                challenge:challenge
                                assertion:assertion
                               limitedUse:NO
                                 response:validAPIResponse
                                    error:nil];
  // 2.2. Return token from parsed response.
  [self expectTokenWithAPIReponse:validAPIResponse toReturnToken:nil];

  // 3. Send request.
  __auto_type promise = [self.appAttestAPIService getAppCheckTokenWithArtifact:artifact
                                                                     challenge:challenge
                                                                     assertion:assertion
                                                                    limitedUse:NO];
  // 4. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(promise.isRejected);
  XCTAssertNil(promise.value);
  XCTAssertNotNil(promise.error);

  NSString *expectedRequestURL =
      [NSString stringWithFormat:@"%@/%@:%@", [self.fakeAPIService baseURL], kResourceName,
                                 @"exchangeAppAttestAssertion"];
  XCTAssertEqualObjects(self.fakeAPIService.passedRequestURL.absoluteString, expectedRequestURL);
  XCTAssertEqualObjects(self.fakeAPIService.passedHTTPMethod, @"POST");
  XCTAssertEqualObjects(self.fakeAPIService.passedAdditionalHeaders[@"Content-Type"],
                        @"application/json");
  [self assertTokenExchangeBody:self.fakeAPIService.passedBody
                       artifact:artifact
                      challenge:challenge
                      assertion:assertion
                     limitedUse:NO];
}

#pragma mark - Attestation request

- (void)testAttestKeySuccess {
  [self testAttestKeySuccessWithLimitedUse:NO];
}

- (void)testAttestKeySuccessWithLimitedUse {
  [self testAttestKeySuccessWithLimitedUse:YES];
}

- (void)testAttestKeySuccessWithLimitedUse:(BOOL)limitedUse {
  NSData *attestation = [self generateRandomData];
  NSData *challenge = [self generateRandomData];
  NSString *keyID = [NSUUID UUID].UUIDString;

  // 1. Prepare response.
  NSData *responseBody =
      [GACFixtureLoader loadFixtureNamed:@"AppAttestAttestationResponseSuccess.json"];
  _GACURLSessionDataResponse *validAPIResponse = [self APIResponseWithCode:200
                                                              responseBody:responseBody];

  // 2. Stub API Service
  // 2.1. Return prepared response.
  [self expectAttestAPIRequestWithAttestation:attestation
                                        keyID:keyID
                                    challenge:challenge
                                   limitedUse:limitedUse
                                     response:validAPIResponse
                                        error:nil];

  // 3. Send request.
  __auto_type promise = [self.appAttestAPIService attestKeyWithAttestation:attestation
                                                                     keyID:keyID
                                                                 challenge:challenge
                                                                limitedUse:limitedUse];

  // 4. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(promise.isFulfilled);
  XCTAssertNil(promise.error);

  NSData *expectedArtifact =
      [@"valid Firebase app attest artifact" dataUsingEncoding:NSUTF8StringEncoding];

  XCTAssertEqualObjects(promise.value.artifact, expectedArtifact);
  XCTAssertEqualObjects(promise.value.token.token, @"valid_app_check_token");
  XCTAssertTrue([GACDateTestUtils isDate:promise.value.token.expirationDate
      approximatelyEqualCurrentPlusTimeInterval:1800
                                      precision:10]);

  NSString *expectedRequestURL =
      [NSString stringWithFormat:@"%@/%@:%@", [self.fakeAPIService baseURL], kResourceName,
                                 @"exchangeAppAttestAttestation"];
  XCTAssertEqualObjects(self.fakeAPIService.passedRequestURL.absoluteString, expectedRequestURL);
  XCTAssertEqualObjects(self.fakeAPIService.passedHTTPMethod, @"POST");
  XCTAssertEqualObjects(self.fakeAPIService.passedAdditionalHeaders[@"Content-Type"],
                        @"application/json");
  [self assertAttestKeyBody:self.fakeAPIService.passedBody
                attestation:attestation
                  challenge:challenge
                      keyID:keyID
                 limitedUse:limitedUse];
}

- (void)testAttestKeyNetworkError {
  NSData *attestation = [self generateRandomData];
  NSData *challenge = [self generateRandomData];
  NSString *keyID = [NSUUID UUID].UUIDString;

  // 1. Stub API Service
  // 1.1. Return prepared response.
  NSError *networkError = [NSError errorWithDomain:self.name code:0 userInfo:nil];
  [self expectAttestAPIRequestWithAttestation:attestation
                                        keyID:keyID
                                    challenge:challenge
                                   limitedUse:NO
                                     response:nil
                                        error:networkError];

  // 2. Send request.
  __auto_type promise = [self.appAttestAPIService attestKeyWithAttestation:attestation
                                                                     keyID:keyID
                                                                 challenge:challenge
                                                                limitedUse:NO];

  // 3. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(promise.isRejected);
  XCTAssertNil(promise.value);
  XCTAssertEqualObjects(promise.error, networkError);

  NSString *expectedRequestURL =
      [NSString stringWithFormat:@"%@/%@:%@", [self.fakeAPIService baseURL], kResourceName,
                                 @"exchangeAppAttestAttestation"];
  XCTAssertEqualObjects(self.fakeAPIService.passedRequestURL.absoluteString, expectedRequestURL);
  XCTAssertEqualObjects(self.fakeAPIService.passedHTTPMethod, @"POST");
  XCTAssertEqualObjects(self.fakeAPIService.passedAdditionalHeaders[@"Content-Type"],
                        @"application/json");
  [self assertAttestKeyBody:self.fakeAPIService.passedBody
                attestation:attestation
                  challenge:challenge
                      keyID:keyID
                 limitedUse:NO];
}

- (void)testAttestKeyUnexpectedResponse {
  NSData *attestation = [self generateRandomData];
  NSData *challenge = [self generateRandomData];
  NSString *keyID = [NSUUID UUID].UUIDString;

  // 1. Prepare unexpected response.
  NSData *responseBody =
      [GACFixtureLoader loadFixtureNamed:@"FACTokenExchangeResponseSuccess.json"];
  _GACURLSessionDataResponse *validAPIResponse = [self APIResponseWithCode:200
                                                              responseBody:responseBody];

  // 2. Stub API Service
  // 2.1. Return prepared response.
  [self expectAttestAPIRequestWithAttestation:attestation
                                        keyID:keyID
                                    challenge:challenge
                                   limitedUse:NO
                                     response:validAPIResponse
                                        error:nil];

  // 3. Send request.
  __auto_type promise = [self.appAttestAPIService attestKeyWithAttestation:attestation
                                                                     keyID:keyID
                                                                 challenge:challenge
                                                                limitedUse:NO];

  // 4. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(promise.isRejected);
  XCTAssertNil(promise.value);
  XCTAssertNotNil(promise.error);

  NSString *expectedRequestURL =
      [NSString stringWithFormat:@"%@/%@:%@", [self.fakeAPIService baseURL], kResourceName,
                                 @"exchangeAppAttestAttestation"];
  XCTAssertEqualObjects(self.fakeAPIService.passedRequestURL.absoluteString, expectedRequestURL);
  XCTAssertEqualObjects(self.fakeAPIService.passedHTTPMethod, @"POST");
  XCTAssertEqualObjects(self.fakeAPIService.passedAdditionalHeaders[@"Content-Type"],
                        @"application/json");
  [self assertAttestKeyBody:self.fakeAPIService.passedBody
                attestation:attestation
                  challenge:challenge
                      keyID:keyID
                 limitedUse:NO];
}

#pragma mark - Helpers

- (_GACURLSessionDataResponse *)APIResponseWithCode:(NSInteger)code
                                       responseBody:(NSData *)responseBody {
  XCTAssertNotNil(responseBody);
  NSHTTPURLResponse *HTTPResponse = [GACURLSessionFake HTTPResponseWithCode:code];
  _GACURLSessionDataResponse *APIResponse =
      [[_GACURLSessionDataResponse alloc] initWithResponse:HTTPResponse HTTPBody:responseBody];
  return APIResponse;
}

- (void)stubMockAPIServiceRequestForChallengeRequestWithResponse:(id)response {
  FBLPromise *resultPromise = [FBLPromise pendingPromise];
  if ([response isKindOfClass:[NSError class]]) {
    [resultPromise reject:response];
  } else {
    [resultPromise fulfill:response];
  }
  self.fakeAPIService.sendRequestPromise = resultPromise;
  self.fakeAPIService.requestValidationBlock = ^{
    XCTAssertFalse([NSThread isMainThread], @"Network requests must not be made on the main thread.");
  };
}

- (void)expectTokenAPIRequestWithArtifact:(NSData *)attestation
                                challenge:(NSData *)challenge
                                assertion:(NSData *)assertion
                               limitedUse:(BOOL)limitedUse
                                 response:(nullable _GACURLSessionDataResponse *)response
                                    error:(nullable NSError *)error {
  FBLPromise *responsePromise = [FBLPromise pendingPromise];
  if (error) {
    [responsePromise reject:error];
  } else {
    [responsePromise fulfill:response];
  }
  self.fakeAPIService.sendRequestPromise = responsePromise;
}

- (void)assertTokenExchangeBody:(NSData *)requestBody
                       artifact:(NSData *)attestation
                      challenge:(NSData *)challenge
                      assertion:(NSData *)assertion
                     limitedUse:(BOOL)limitedUse {
  NSDictionary<NSString *, id> *decodedData = [NSJSONSerialization JSONObjectWithData:requestBody
                                                                              options:0
                                                                                error:nil];

  XCTAssert([decodedData isKindOfClass:[NSDictionary class]]);

  // Validate artifact field.
  NSString *base64EncodedArtifact = decodedData[@"artifact"];
  XCTAssert([base64EncodedArtifact isKindOfClass:[NSString class]]);

  NSData *decodedAttestation = [[NSData alloc] initWithBase64EncodedString:base64EncodedArtifact
                                                                   options:0];
  XCTAssertEqualObjects(decodedAttestation, attestation);

  // Validate challenge field.
  NSString *base64EncodedChallenge = decodedData[@"challenge"];
  XCTAssert([base64EncodedChallenge isKindOfClass:[NSString class]]);

  NSData *decodedChallenge = [[NSData alloc] initWithBase64EncodedString:base64EncodedChallenge
                                                                 options:0];
  XCTAssertEqualObjects(decodedChallenge, challenge);

  // Validate assertion field.
  NSString *base64EncodedAssertion = decodedData[@"assertion"];
  XCTAssert([base64EncodedAssertion isKindOfClass:[NSString class]]);

  // Validate limited-use field.
  NSNumber *decodedLimitedUse = decodedData[@"limited_use"];
  XCTAssertNotNil(decodedLimitedUse);
  XCTAssertEqualObjects(decodedLimitedUse, @(limitedUse));

  NSData *decodedAssertion = [[NSData alloc] initWithBase64EncodedString:base64EncodedAssertion
                                                                 options:0];
  XCTAssertEqualObjects(decodedAssertion, assertion);
}

- (void)expectTokenWithAPIReponse:(nonnull _GACURLSessionDataResponse *)response
                    toReturnToken:(nullable GACAppCheckToken *)token {
  FBLPromise *tokenPromise = [FBLPromise pendingPromise];
  if (token) {
    [tokenPromise fulfill:token];
  } else {
    NSError *tokenError = [NSError errorWithDomain:self.name code:0 userInfo:nil];
    [tokenPromise reject:tokenError];
  }
  self.fakeAPIService.appCheckTokenPromise = tokenPromise;
}

- (void)expectAttestAPIRequestWithAttestation:(NSData *)attestation
                                        keyID:(NSString *)keyID
                                    challenge:(NSData *)challenge
                                   limitedUse:(BOOL)limitedUse
                                     response:(nullable _GACURLSessionDataResponse *)response
                                        error:(nullable NSError *)error {
  FBLPromise *resultPromise = [FBLPromise pendingPromise];
  if (error) {
    [resultPromise reject:error];
  } else {
    [resultPromise fulfill:response];
  }

  self.fakeAPIService.sendRequestPromise = resultPromise;
}

- (void)assertAttestKeyBody:(NSData *)requestBody
                attestation:(NSData *)attestation
                  challenge:(NSData *)challenge
                      keyID:(NSString *)keyID
                 limitedUse:(BOOL)limitedUse {
  NSDictionary<NSString *, id> *decodedData = [NSJSONSerialization JSONObjectWithData:requestBody
                                                                              options:0
                                                                                error:nil];

  XCTAssert([decodedData isKindOfClass:[NSDictionary class]]);

  // Validate attestation field.
  NSString *base64EncodedAttestation = decodedData[@"attestation_statement"];
  XCTAssert([base64EncodedAttestation isKindOfClass:[NSString class]]);

  NSData *decodedAttestation = [[NSData alloc] initWithBase64EncodedString:base64EncodedAttestation
                                                                   options:0];
  XCTAssertEqualObjects(decodedAttestation, attestation);

  // Validate challenge field.
  NSString *base64EncodedChallenge = decodedData[@"challenge"];
  XCTAssert([base64EncodedChallenge isKindOfClass:[NSString class]]);

  NSData *decodedChallenge = [[NSData alloc] initWithBase64EncodedString:base64EncodedChallenge
                                                                 options:0];
  XCTAssertEqualObjects(decodedChallenge, challenge);

  // Validate key ID field.
  NSString *keyIDField = decodedData[@"key_id"];
  XCTAssert([keyIDField isKindOfClass:[NSString class]]);

  // Validate limited-use field.
  NSNumber *decodedLimitedUse = decodedData[@"limited_use"];
  XCTAssertNotNil(decodedLimitedUse);
  XCTAssertEqualObjects(decodedLimitedUse, @(limitedUse));

  XCTAssertEqualObjects(keyIDField, keyID);
}

- (NSData *)generateRandomData {
  return [[NSUUID UUID].UUIDString dataUsingEncoding:NSUTF8StringEncoding];
}

@end
