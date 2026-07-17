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

#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppAttestProvider.h"

#import <DeviceCheck/DeviceCheck.h>
#import <XCTest/XCTest.h>

#import "FBLPromise+Testing.h"

#import "AppCheckCore/Sources/AppAttestProvider/API/GACAppAttestAPIService.h"
#import "AppCheckCore/Sources/AppAttestProvider/API/GACAppAttestAttestationResponse.h"
#import "AppCheckCore/Sources/AppAttestProvider/GACAppAttestService.h"
#import "AppCheckCore/Sources/AppAttestProvider/Storage/GACAppAttestArtifactStorage.h"
#import "AppCheckCore/Sources/AppAttestProvider/Storage/GACAppAttestKeyIDStorage.h"
#import "AppCheckCore/Sources/Core/Utils/GACAppCheckCryptoUtils.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheckToken.h"

#import "AppCheckCore/Sources/AppAttestProvider/Errors/GACAppAttestRejectionError.h"
#import "AppCheckCore/Sources/Core/Errors/GACAppCheckHTTPError.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/_GACAppCheckErrorUtil.h"

#import "AppCheckCore/Tests/Utils/AppCheckBackoffWrapperFake/GACAppCheckBackoffWrapperFake.h"

#import "AppCheckCore/Tests/Unit/Utils/GACAppAttestAPIServiceFake.h"
#import "AppCheckCore/Tests/Unit/Utils/GACAppAttestArtifactStorageFake.h"
#import "AppCheckCore/Tests/Unit/Utils/GACAppAttestKeyIDStorageFake.h"
#import "AppCheckCore/Tests/Unit/Utils/GACAppAttestServiceFake.h"

GAC_APP_ATTEST_PROVIDER_AVAILABILITY
@interface GACAppAttestProvider (Tests)
- (instancetype)initWithAppAttestService:(id<GACAppAttestService>)appAttestService
                              APIService:(id<GACAppAttestAPIServiceProtocol>)APIService
                            keyIDStorage:(id<GACAppAttestKeyIDStorageProtocol>)keyIDStorage
                         artifactStorage:(id<GACAppAttestArtifactStorageProtocol>)artifactStorage
                          backoffWrapper:(id<_GACAppCheckBackoffWrapperProtocol>)backoffWrapper;
@end

GAC_APP_ATTEST_PROVIDER_AVAILABILITY
@interface GACAppAttestProviderTests : XCTestCase

@property(nonatomic) GACAppAttestProvider *provider;

@property(nonatomic) GACAppAttestServiceFake *fakeAppAttestService;
@property(nonatomic) GACAppAttestAPIServiceFake *fakeAPIService;
@property(nonatomic) GACAppAttestKeyIDStorageFake *fakeStorage;
@property(nonatomic) GACAppAttestArtifactStorageFake *fakeArtifactStorage;

@property(nonatomic) NSData *randomChallenge;
@property(nonatomic) NSData *randomChallengeHash;

@property(nonatomic) GACAppCheckBackoffWrapperFake *fakeBackoffWrapper;

- (void)verifyAllMocks;
- (void)assertGetToken_WhenNoExistingKey_Success;
- (void)assertGetToken_WhenKeyRegistered_Success;
- (void)assertAttestationResetAndGetTokenRetryWhenExistingKeyIsRejectedWithAttestationError:
    (NSError *)error;
- (void)assertAttestationResetAndGetTokenRetryWhenExistingKeyIsRejectedWithAssertionError:
    (NSError *)error;
- (void)expectAppAttestAvailabilityToBeCheckedAndNotExistingStoredKeyRequested;
- (void)expectAppAttestKeyGeneratedAndAttestedWithKeyID:(NSString *)keyID
                                        attestationData:(NSData *)attestationData;
- (void)expectAttestationReset;
- (NSError *)expectRandomChallengeRequestError;
- (FBLPromise *)rejectedPromiseWithError:(NSError *)error;
- (GACAppCheckHTTPError *)attestationRejectionHTTPError;

@end

@implementation GACAppAttestProviderTests

- (void)setUp {
  [super setUp];

  self.fakeAppAttestService = [[GACAppAttestServiceFake alloc] init];
  self.fakeAPIService = [[GACAppAttestAPIServiceFake alloc] init];
  self.fakeStorage = [[GACAppAttestKeyIDStorageFake alloc] init];
  self.fakeArtifactStorage = [[GACAppAttestArtifactStorageFake alloc] init];

  self.fakeBackoffWrapper = [[GACAppCheckBackoffWrapperFake alloc] init];
  // Don't backoff by default.
  self.fakeBackoffWrapper.isNextOperationAllowed = YES;

  self.provider = [[GACAppAttestProvider alloc] initWithAppAttestService:self.fakeAppAttestService
                                                              APIService:self.fakeAPIService
                                                            keyIDStorage:self.fakeStorage
                                                         artifactStorage:self.fakeArtifactStorage
                                                          backoffWrapper:self.fakeBackoffWrapper];

  self.randomChallenge = [@"random challenge" dataUsingEncoding:NSUTF8StringEncoding];
  self.randomChallengeHash =
      [[NSData alloc] initWithBase64EncodedString:@"vEq8yE9g+WwfifNqC2wsXN9M3NIDeOKpDBVYLpGbUDY="
                                          options:0];
}

- (void)tearDown {
  self.provider = nil;
  self.fakeArtifactStorage = nil;
  self.fakeStorage = nil;
  self.fakeAPIService = nil;
  self.fakeAppAttestService = nil;
  self.fakeBackoffWrapper = nil;
}

#pragma mark - Initial handshake (attestation)

- (void)testGetTokenWhenAppAttestIsNotSupported {
  NSError *expectedError =
      [_GACAppCheckErrorUtil unsupportedAttestationProvider:@"AppAttestProvider"];

  // 0.1. Expect backoff wrapper to be used.
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 0.2. Expect default error handler to be used.
  XCTestExpectation *errorHandlerExpectation = [self expectationWithDescription:@"Error handler"];
  self.fakeBackoffWrapper.defaultErrorHandler = ^GACAppCheckBackoffType(NSError *_Nonnull error) {
    XCTAssertEqualObjects(error, expectedError);
    [errorHandlerExpectation fulfill];
    return GACAppCheckBackoffType1Day;
  };

  // 1. Expect GACAppAttestService.isSupported.
  self.fakeAppAttestService.isSupported = NO;

  // 3. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertNil(token);
        XCTAssertEqualObjects(error, expectedError);
      }];

  [self waitForExpectations:@[
    self.fakeBackoffWrapper.backoffExpectation, errorHandlerExpectation, completionExpectation
  ]
                    timeout:0.5
               enforceOrder:YES];

  // 4. Verify mocks.
  XCTAssertEqual(self.fakeAppAttestService.generateKeyCallCount, 0);
  XCTAssertEqual(self.fakeAppAttestService.attestKeyCallCount, 0);
  XCTAssertEqual(self.fakeAPIService.getRandomChallengeCallCount, 0);
  XCTAssertEqual(self.fakeStorage.setAppAttestKeyIDCallCount, 0);
  XCTAssertEqual(self.fakeArtifactStorage.getArtifactCallCount, 0);
}

- (void)testGetToken_WhenNoExistingKey_Success {
  [self assertGetToken_WhenNoExistingKey_Success];
}

- (void)testGetToken_WhenExistingUnregisteredKey_Success {
  // 0. Expect backoff wrapper to be used.
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 1. Expect GACAppAttestService.isSupported.
  self.fakeAppAttestService.isSupported = YES;

  // 2. Expect storage getAppAttestKeyID.
  NSString *existingKeyID = @"existingKeyID";
  self.fakeStorage.getAppAttestKeyIDPromise = [FBLPromise resolvedWith:existingKeyID];

  // 5. Expect a stored artifact to be requested.
  __auto_type rejectedPromise = [self rejectedPromiseWithError:[NSError errorWithDomain:self.name
                                                                                   code:NSNotFound
                                                                               userInfo:nil]];
  self.fakeArtifactStorage.getArtifactPromise = rejectedPromise;

  // 6. Expect random challenge to be requested.
  self.fakeAPIService.getRandomChallengePromise = [FBLPromise resolvedWith:self.randomChallenge];

  // 7. Expect the key to be attested with the challenge.
  NSData *attestationData = [@"attestation data" dataUsingEncoding:NSUTF8StringEncoding];
  self.fakeAppAttestService.attestationToReturn = attestationData;

  // 8. Expect key attestation request to be sent.
  GACAppCheckToken *FACToken = [[GACAppCheckToken alloc] initWithToken:@"FAC token"
                                                        expirationDate:[NSDate date]];
  NSData *artifactData = [@"attestation artifact" dataUsingEncoding:NSUTF8StringEncoding];
  __auto_type attestKeyResponse =
      [[GACAppAttestAttestationResponse alloc] initWithArtifact:artifactData token:FACToken];
  self.fakeAPIService.attestKeyPromise = [FBLPromise resolvedWith:attestKeyResponse];

  // 9. Expect the artifact received from Firebase backend to be saved.
  self.fakeArtifactStorage.setArtifactPromise = [FBLPromise resolvedWith:artifactData];

  // 10. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertEqualObjects(token.token, FACToken.token);
        XCTAssertEqualObjects(token.expirationDate, FACToken.expirationDate);
        XCTAssertNil(error);
      }];

  [self waitForExpectations:@[ self.fakeBackoffWrapper.backoffExpectation, completionExpectation ]
                    timeout:0.5
               enforceOrder:YES];

  // 11. Verify mocks.
  XCTAssertEqual(self.fakeStorage.getAppAttestKeyIDCallCount, 1);
  XCTAssertEqual(self.fakeArtifactStorage.getArtifactCallCount, 1);
  XCTAssertEqual(self.fakeAPIService.getRandomChallengeCallCount, 1);
  XCTAssertEqual(self.fakeAppAttestService.attestKeyCallCount, 1);
  XCTAssertEqual(self.fakeAPIService.attestKeyCallCount, 1);
  XCTAssertEqual(self.fakeArtifactStorage.setArtifactCallCount, 1);

  // 12. Verify backoff result.
  XCTAssertEqualObjects(((GACAppCheckToken *)self.fakeBackoffWrapper.operationResult).token,
                        FACToken.token);
}

- (void)testGetToken_WhenUnregisteredKeyAndRandomChallengeError {
  // 0. Expect backoff wrapper to be used.
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 1. Expect GACAppAttestService.isSupported.
  self.fakeAppAttestService.isSupported = YES;

  // 2. Expect storage getAppAttestKeyID.
  NSString *existingKeyID = @"existingKeyID";
  self.fakeStorage.getAppAttestKeyIDPromise = [FBLPromise resolvedWith:existingKeyID];

  // 3. Expect a stored artifact to be requested.
  __auto_type rejectedPromise = [self rejectedPromiseWithError:[NSError errorWithDomain:self.name
                                                                                   code:NSNotFound
                                                                               userInfo:nil]];
  self.fakeArtifactStorage.getArtifactPromise = rejectedPromise;

  // 4. Expect random challenge to be requested.
  NSError *challengeError = [self expectRandomChallengeRequestError];

  // 6. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertNil(token);
        XCTAssertEqualObjects(error, challengeError);
      }];

  [self waitForExpectations:@[ self.fakeBackoffWrapper.backoffExpectation, completionExpectation ]
                    timeout:0.5
               enforceOrder:YES];

  // 7. Verify mocks.
  XCTAssertEqual(self.fakeStorage.getAppAttestKeyIDCallCount, 1);
  XCTAssertEqual(self.fakeArtifactStorage.getArtifactCallCount, 1);
  XCTAssertEqual(self.fakeAPIService.getRandomChallengeCallCount, 1);
  XCTAssertEqual(self.fakeStorage.setAppAttestKeyIDCallCount, 0);
  XCTAssertEqual(self.fakeAppAttestService.attestKeyCallCount, 0);
  XCTAssertEqual(self.fakeAPIService.attestKeyCallCount, 0);

  // 8. Verify backoff error.
  XCTAssertEqualObjects(self.fakeBackoffWrapper.operationError, challengeError);
}

- (void)testGetToken_WhenUnregisteredKeyAndKeyAttestationError {
  // 0. Expect backoff wrapper to be used.
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 1. Expect GACAppAttestService.isSupported.
  self.fakeAppAttestService.isSupported = YES;

  // 2. Expect storage getAppAttestKeyID.
  NSString *existingKeyID = @"existingKeyID";
  self.fakeStorage.getAppAttestKeyIDPromise = [FBLPromise resolvedWith:existingKeyID];

  // 3. Expect a stored artifact to be requested.
  __auto_type rejectedPromise = [self rejectedPromiseWithError:[NSError errorWithDomain:self.name
                                                                                   code:NSNotFound
                                                                               userInfo:nil]];
  self.fakeArtifactStorage.getArtifactPromise = rejectedPromise;

  // 4. Expect random challenge to be requested.
  self.fakeAPIService.getRandomChallengePromise = [FBLPromise resolvedWith:self.randomChallenge];

  // 5. Expect the key to be attested with the challenge.
  NSError *attestationError = [NSError errorWithDomain:@"testGetTokenWhenKeyAttestationError"
                                                  code:0
                                              userInfo:nil];
  NSError *expectedError =
      [_GACAppCheckErrorUtil appAttestAttestKeyFailedWithError:attestationError
                                                         keyId:existingKeyID
                                                clientDataHash:self.randomChallengeHash];
  self.fakeAppAttestService.attestKeyErrorToReturn = attestationError;

  // 7. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertNil(token);
        XCTAssertEqualObjects(error, expectedError);
      }];

  [self waitForExpectations:@[ self.fakeBackoffWrapper.backoffExpectation, completionExpectation ]
                    timeout:0.5
               enforceOrder:YES];

  // 8. Verify mocks.
  XCTAssertEqual(self.fakeStorage.getAppAttestKeyIDCallCount, 1);
  XCTAssertEqual(self.fakeArtifactStorage.getArtifactCallCount, 1);
  XCTAssertEqual(self.fakeAPIService.getRandomChallengeCallCount, 1);
  XCTAssertEqual(self.fakeAppAttestService.attestKeyCallCount, 1);
  XCTAssertEqual(self.fakeAPIService.attestKeyCallCount, 0);

  // 9. Verify backoff error.
  XCTAssertEqualObjects(self.fakeBackoffWrapper.operationError, expectedError);
}

- (void)testGetToken_WhenUnregisteredKeyAndKeyAttestationExchangeError {
  // 0. Expect backoff wrapper to be used.
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 1. Expect GACAppAttestService.isSupported.
  self.fakeAppAttestService.isSupported = YES;

  // 2. Expect storage getAppAttestKeyID.
  NSString *existingKeyID = @"existingKeyID";
  self.fakeStorage.getAppAttestKeyIDPromise = [FBLPromise resolvedWith:existingKeyID];

  // 3. Expect a stored artifact to be requested.
  __auto_type rejectedPromise = [self rejectedPromiseWithError:[NSError errorWithDomain:self.name
                                                                                   code:NSNotFound
                                                                               userInfo:nil]];
  self.fakeArtifactStorage.getArtifactPromise = rejectedPromise;

  // 4. Expect random challenge to be requested.
  self.fakeAPIService.getRandomChallengePromise = [FBLPromise resolvedWith:self.randomChallenge];

  // 5. Expect the key to be attested with the challenge.
  NSData *attestationData = [@"attestation data" dataUsingEncoding:NSUTF8StringEncoding];
  self.fakeAppAttestService.attestationToReturn = attestationData;

  // 6. Expect exchange request to be sent.
  NSError *exchangeError = [NSError errorWithDomain:@"testGetTokenWhenKeyAttestationExchangeError"
                                               code:0
                                           userInfo:nil];
  self.fakeAPIService.attestKeyPromise = [self rejectedPromiseWithError:exchangeError];

  // 7. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertNil(token);
        XCTAssertEqualObjects(error, exchangeError);
      }];

  [self waitForExpectations:@[ self.fakeBackoffWrapper.backoffExpectation, completionExpectation ]
                    timeout:0.5
               enforceOrder:YES];

  // 8. Verify mocks.
  XCTAssertEqual(self.fakeStorage.getAppAttestKeyIDCallCount, 1);
  XCTAssertEqual(self.fakeArtifactStorage.getArtifactCallCount, 1);
  XCTAssertEqual(self.fakeAPIService.getRandomChallengeCallCount, 1);
  XCTAssertEqual(self.fakeAppAttestService.attestKeyCallCount, 1);
  XCTAssertEqual(self.fakeAPIService.attestKeyCallCount, 1);

  // 9. Verify backoff error.
  XCTAssertEqualObjects(self.fakeBackoffWrapper.operationError, exchangeError);
}

#pragma mark - Rejected Attestation

- (void)testGetToken_WhenAttestationIsRejected_ThenAttestationIsResetAndRetriedOnceSuccess {
  // 1. Expect App Attest availability to be requested and stored key ID request to fail.
  [self expectAppAttestAvailabilityToBeCheckedAndNotExistingStoredKeyRequested];

  // 2. Expect the App Attest key pair to be generated and attested.
  NSString *keyID1 = @"keyID1";
  NSData *attestationData1 = [[NSUUID UUID].UUIDString dataUsingEncoding:NSUTF8StringEncoding];
  [self expectAppAttestKeyGeneratedAndAttestedWithKeyID:keyID1 attestationData:attestationData1];

  // 3. Expect exchange request to be sent.
  GACAppCheckHTTPError *APIError = [self attestationRejectionHTTPError];
  self.fakeAPIService.attestKeyPromise = [self rejectedPromiseWithError:APIError];

  // 4. Stored attestation to be reset.
  [self expectAttestationReset];

  // 5. Assert that attestation is tried successfully.
  [self assertGetToken_WhenNoExistingKey_Success];
}

- (void)testGetToken_WhenAttestationIsRejected_ThenAttestationIsResetAndRetriedOnceError {
  // 1. Expect App Attest availability to be requested and stored key ID request to fail.
  [self expectAppAttestAvailabilityToBeCheckedAndNotExistingStoredKeyRequested];

  // 2. Expect the App Attest key pair to be generated and attested.
  NSString *keyID1 = @"keyID1";
  NSData *attestationData1 = [[NSUUID UUID].UUIDString dataUsingEncoding:NSUTF8StringEncoding];
  [self expectAppAttestKeyGeneratedAndAttestedWithKeyID:keyID1 attestationData:attestationData1];

  // 3. Expect exchange request to be sent.
  GACAppCheckHTTPError *APIError = [self attestationRejectionHTTPError];
  self.fakeAPIService.attestKeyPromise = [self rejectedPromiseWithError:APIError];

  // 4. Stored attestation to be reset.
  [self expectAttestationReset];

  // 5. Expect App Attest availability to be requested and stored key ID request to fail.
  [self expectAppAttestAvailabilityToBeCheckedAndNotExistingStoredKeyRequested];

  // 6. Expect the App Attest key pair to be generated and attested.
  NSString *keyID2 = @"keyID2";
  NSData *attestationData2 = [[NSUUID UUID].UUIDString dataUsingEncoding:NSUTF8StringEncoding];
  [self expectAppAttestKeyGeneratedAndAttestedWithKeyID:keyID2 attestationData:attestationData2];

  // 7. Expect exchange request to be sent.
  // fakeAPIService.attestKeyPromise is still rejectedPromiseWithError:APIError.

  // 8. Stored attestation to be reset.
  [self expectAttestationReset];

  // 10. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertNil(token);
        XCTAssertNotNil(error);
        XCTAssert([error isKindOfClass:[GACAppCheckHTTPError class]]);
      }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5 enforceOrder:YES];

  // 11. Verify mocks.
  XCTAssertEqual(self.fakeAPIService.attestKeyCallCount, 2);
  XCTAssertEqual(self.fakeArtifactStorage.setArtifactCallCount, 2);  // 2 resets
}

- (void)testGetToken_WhenExistingKeyIsRejectedByApple_ThenAttestationIsResetAndRetriedOnce_Success {
  NSError *invalidKeyError = [NSError errorWithDomain:DCErrorDomain
                                                 code:DCErrorInvalidKey
                                             userInfo:nil];
  [self assertAttestationResetAndGetTokenRetryWhenExistingKeyIsRejectedWithAttestationError:
            invalidKeyError];
  NSError *invalidInputError = [NSError errorWithDomain:DCErrorDomain
                                                   code:DCErrorInvalidInput
                                               userInfo:nil];
  [self assertAttestationResetAndGetTokenRetryWhenExistingKeyIsRejectedWithAttestationError:
            invalidInputError];
}

#pragma mark - FAC token refresh (assertion)

- (void)testGetToken_WhenKeyRegistered_Success {
  [self assertGetToken_WhenKeyRegistered_Success];
}

- (void)testGetToken_WhenKeyRegisteredAndChallengeRequestError {
  // 1. Expect GACAppAttestService.isSupported.
  self.fakeAppAttestService.isSupported = YES;

  // 2. Expect storage getAppAttestKeyID.
  NSString *existingKeyID = @"existingKeyID";
  self.fakeStorage.getAppAttestKeyIDPromise = [FBLPromise resolvedWith:existingKeyID];

  // 3. Expect a stored artifact to be requested.
  NSData *storedArtifact = [@"storedArtifact" dataUsingEncoding:NSUTF8StringEncoding];
  self.fakeArtifactStorage.getArtifactPromise = [FBLPromise resolvedWith:storedArtifact];

  // 4. Expect random challenge to be requested.
  NSError *challengeError = [self expectRandomChallengeRequestError];

  // 7. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertNil(token);
        XCTAssertEqualObjects(error, challengeError);
      }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];

  // 8. Verify mocks.
  XCTAssertEqual(self.fakeAppAttestService.generateAssertionCallCount, 0);
  XCTAssertEqual(self.fakeAPIService.getAppCheckTokenCallCount, 0);
}

- (void)testGetToken_WhenKeyRegisteredAndGenerateAssertionError {
  // 1. Expect GACAppAttestService.isSupported.
  self.fakeAppAttestService.isSupported = YES;

  // 2. Expect storage getAppAttestKeyID.
  NSString *existingKeyID = @"existingKeyID";
  self.fakeStorage.getAppAttestKeyIDPromise = [FBLPromise resolvedWith:existingKeyID];

  // 3. Expect a stored artifact to be requested.
  NSData *storedArtifact = [@"storedArtifact" dataUsingEncoding:NSUTF8StringEncoding];
  self.fakeArtifactStorage.getArtifactPromise = [FBLPromise resolvedWith:storedArtifact];

  // 4. Expect random challenge to be requested.
  self.fakeAPIService.getRandomChallengePromise = [FBLPromise resolvedWith:self.randomChallenge];

  // 5. Don't expect assertion to be requested.
  NSError *generateAssertionError =
      [NSError errorWithDomain:@"testGetToken_WhenKeyRegisteredAndGenerateAssertionError"
                          code:0
                      userInfo:nil];

  NSMutableData *statementForAssertion = [storedArtifact mutableCopy];
  [statementForAssertion appendData:self.randomChallenge];
  NSData *clientDataHash = [GACAppCheckCryptoUtils sha256HashFromData:[statementForAssertion copy]];
  NSError *expectedError =
      [_GACAppCheckErrorUtil appAttestGenerateAssertionFailedWithError:generateAssertionError
                                                                 keyId:existingKeyID
                                                        clientDataHash:clientDataHash];
  self.fakeAppAttestService.generateAssertionErrorToReturn = generateAssertionError;

  // 7. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertNil(token);
        XCTAssertEqualObjects(error, expectedError);
      }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];

  // 8. Verify mocks.
  XCTAssertEqual(self.fakeAppAttestService.generateAssertionCallCount, 1);
  XCTAssertEqual(self.fakeAPIService.getAppCheckTokenCallCount, 0);
}

- (void)testGetToken_WhenKeyRegisteredAndTokenExchangeRequestError {
  // 1. Expect GACAppAttestService.isSupported.
  self.fakeAppAttestService.isSupported = YES;

  // 2. Expect storage getAppAttestKeyID.
  NSString *existingKeyID = @"existingKeyID";
  self.fakeStorage.getAppAttestKeyIDPromise = [FBLPromise resolvedWith:existingKeyID];

  // 3. Expect a stored artifact to be requested.
  NSData *storedArtifact = [@"storedArtifact" dataUsingEncoding:NSUTF8StringEncoding];
  self.fakeArtifactStorage.getArtifactPromise = [FBLPromise resolvedWith:storedArtifact];

  // 4. Expect random challenge to be requested.
  self.fakeAPIService.getRandomChallengePromise = [FBLPromise resolvedWith:self.randomChallenge];

  // 5. Don't expect assertion to be requested.
  NSData *assertion = [@"generatedAssertion" dataUsingEncoding:NSUTF8StringEncoding];
  self.fakeAppAttestService.assertionToReturn = assertion;

  // 6. Expect assertion request to be sent.
  NSError *tokenExchangeError =
      [NSError errorWithDomain:@"testGetToken_WhenKeyRegisteredAndTokenExchangeRequestError"
                          code:0
                      userInfo:nil];
  self.fakeAPIService.getAppCheckTokenPromise = [self rejectedPromiseWithError:tokenExchangeError];

  // 7. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertNil(token);
        XCTAssertEqualObjects(error, tokenExchangeError);
      }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];

  // 8. Verify mocks.
  XCTAssertEqual(self.fakeAppAttestService.generateAssertionCallCount, 1);
  XCTAssertEqual(self.fakeAPIService.getAppCheckTokenCallCount, 1);
}

#pragma mark - Rejected Assertion

- (void)testGetToken_WhenAssertionIsRejectedByApple_ThenResetToAttestationAndRetryOnceSuccess {
  NSError *invalidKeyError = [NSError errorWithDomain:DCErrorDomain
                                                 code:DCErrorInvalidKey
                                             userInfo:nil];
  [self assertAttestationResetAndGetTokenRetryWhenExistingKeyIsRejectedWithAssertionError:
            invalidKeyError];
  NSError *invalidInputError = [NSError errorWithDomain:DCErrorDomain
                                                   code:DCErrorInvalidInput
                                               userInfo:nil];
  [self assertAttestationResetAndGetTokenRetryWhenExistingKeyIsRejectedWithAssertionError:
            invalidInputError];
  NSError *systemFailureError = [NSError errorWithDomain:DCErrorDomain
                                                    code:DCErrorUnknownSystemFailure
                                                userInfo:nil];
  [self assertAttestationResetAndGetTokenRetryWhenExistingKeyIsRejectedWithAssertionError:
            systemFailureError];
}

#pragma mark - Request merging

- (void)testGetToken_WhenCalledSeveralTimesSuccess_ThenThereIsOnlyOneOngoingHandshake {
  // 0. Expect backoff wrapper to be used only once.
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 1. Expect GACAppAttestService.isSupported.
  self.fakeAppAttestService.isSupported = YES;

  // 2. Expect storage getAppAttestKeyID.
  NSString *existingKeyID = @"existingKeyID";
  self.fakeStorage.getAppAttestKeyIDPromise = [FBLPromise resolvedWith:existingKeyID];

  // 3. Expect a stored artifact to be requested.
  NSData *storedArtifact = [@"storedArtifact" dataUsingEncoding:NSUTF8StringEncoding];
  self.fakeArtifactStorage.getArtifactPromise = [FBLPromise resolvedWith:storedArtifact];

  // 4. Expect random challenge to be requested.
  // 4.1. Create a pending promise to fulfill later.
  FBLPromise<NSData *> *challengeRequestPromise = [FBLPromise pendingPromise];
  // 4.2. Stub getRandomChallenge method.
  self.fakeAPIService.getRandomChallengePromise = challengeRequestPromise;

  // 5. Expect assertion to be requested.
  NSData *assertion = [@"generatedAssertion" dataUsingEncoding:NSUTF8StringEncoding];
  self.fakeAppAttestService.assertionToReturn = assertion;

  // 6. Expect assertion request to be sent.
  GACAppCheckToken *FACToken = [[GACAppCheckToken alloc] initWithToken:@"FAC token"
                                                        expirationDate:[NSDate date]];
  self.fakeAPIService.getAppCheckTokenPromise = [FBLPromise resolvedWith:FACToken];

  // 7. Call get token several times.
  NSInteger callsCount = 10;
  NSMutableArray *completionExpectations = [NSMutableArray arrayWithCapacity:callsCount];

  for (NSInteger i = 0; i < callsCount; i++) {
    // 7.1 Expect the completion to be called for each get token method called.
    XCTestExpectation *completionExpectation = [self
        expectationWithDescription:[NSString stringWithFormat:@"completionExpectation%@", @(i)]];
    [completionExpectations addObject:completionExpectation];

    // 7.2. Call get token.
    [self.provider
        getTokenWithCompletion:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
          [completionExpectation fulfill];

          XCTAssertEqualObjects(token.token, FACToken.token);
          XCTAssertEqualObjects(token.expirationDate, FACToken.expirationDate);
          XCTAssertNil(error);
        }];
  }

  // 7.3. Resolve get challenge promise to finish the operation.
  [challengeRequestPromise fulfill:self.randomChallenge];

  // 7.4. Wait for all completions to be called.
  NSArray<XCTestExpectation *> *expectations =
      [completionExpectations arrayByAddingObject:self.fakeBackoffWrapper.backoffExpectation];
  [self waitForExpectations:expectations timeout:1];

  // 8. Verify mocks.
  XCTAssertEqual(self.fakeAppAttestService.generateAssertionCallCount, 1);
  XCTAssertEqual(self.fakeAPIService.getAppCheckTokenCallCount, 1);

  // 9. Check another get token call after.
  [self assertGetToken_WhenKeyRegistered_Success];
}

- (void)testGetToken_WhenCalledSeveralTimesError_ThenThereIsOnlyOneOngoingHandshake {
  // 0. Expect backoff wrapper to be used only once.
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 1. Expect GACAppAttestService.isSupported.
  self.fakeAppAttestService.isSupported = YES;

  // 2. Expect storage getAppAttestKeyID.
  NSString *existingKeyID = @"existingKeyID";
  self.fakeStorage.getAppAttestKeyIDPromise = [FBLPromise resolvedWith:existingKeyID];

  // 3. Expect a stored artifact to be requested.
  NSData *storedArtifact = [@"storedArtifact" dataUsingEncoding:NSUTF8StringEncoding];
  self.fakeArtifactStorage.getArtifactPromise = [FBLPromise resolvedWith:storedArtifact];

  // 4. Expect random challenge to be requested.
  self.fakeAPIService.getRandomChallengePromise = [FBLPromise resolvedWith:self.randomChallenge];

  // 5. Expect assertion to be requested.
  NSData *assertion = [@"generatedAssertion" dataUsingEncoding:NSUTF8StringEncoding];
  self.fakeAppAttestService.assertionToReturn = assertion;

  // 6. Expect assertion request to be sent.
  // 6.1. Create a pending promise to reject later.
  FBLPromise<GACAppCheckToken *> *assertionRequestPromise = [FBLPromise pendingPromise];
  // 6.2. Stub assertion request.
  self.fakeAPIService.getAppCheckTokenPromise = assertionRequestPromise;
  // 6.3. Create an expected error to be rejected with later.
  NSError *assertionRequestError = [NSError errorWithDomain:self.name code:0 userInfo:nil];

  // 7. Call get token several times.
  NSInteger callsCount = 10;
  NSMutableArray *completionExpectations = [NSMutableArray arrayWithCapacity:callsCount];

  for (NSInteger i = 0; i < callsCount; i++) {
    // 7.1 Expect the completion to be called for each get token method called.
    XCTestExpectation *completionExpectation = [self
        expectationWithDescription:[NSString stringWithFormat:@"completionExpectation%@", @(i)]];
    [completionExpectations addObject:completionExpectation];

    // 7.2. Call get token.
    [self.provider
        getTokenWithCompletion:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
          [completionExpectation fulfill];

          XCTAssertEqualObjects(error, assertionRequestError);
          XCTAssertNil(token);
        }];
  }

  // 7.3. Reject get challenge promise to finish the operation.
  [assertionRequestPromise reject:assertionRequestError];

  // 7.4. Wait for all completions to be called.
  NSArray<XCTestExpectation *> *expectations =
      [completionExpectations arrayByAddingObject:self.fakeBackoffWrapper.backoffExpectation];
  [self waitForExpectations:expectations timeout:1];

  // 8. Verify mocks.
  XCTAssertEqual(self.fakeAppAttestService.generateAssertionCallCount, 1);
  XCTAssertEqual(self.fakeAPIService.getAppCheckTokenCallCount, 1);

  // 9. Check another get token call after.
  [self assertGetToken_WhenKeyRegistered_Success];
}

#pragma mark - Backoff tests

- (void)testGetTokenBackoff {
  // 1. Configure backoff.
  self.fakeBackoffWrapper.isNextOperationAllowed = NO;
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 3. Call get token.
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

  // 4. Verify mocks.
  XCTAssertEqual(self.fakeStorage.getAppAttestKeyIDCallCount, 0);
  XCTAssertEqual(self.fakeAppAttestService.generateKeyCallCount, 0);
  XCTAssertEqual(self.fakeArtifactStorage.getArtifactCallCount, 0);
  XCTAssertEqual(self.fakeAPIService.getRandomChallengeCallCount, 0);
  XCTAssertEqual(self.fakeStorage.setAppAttestKeyIDCallCount, 0);
  XCTAssertEqual(self.fakeAppAttestService.attestKeyCallCount, 0);
  XCTAssertEqual(self.fakeAPIService.attestKeyCallCount, 0);
}

#pragma mark - Helpers

- (NSData *)dataHashForAssertionWithArtifactData:(NSData *)artifact {
  NSMutableData *statement = [artifact mutableCopy];
  [statement appendData:self.randomChallenge];
  return [GACAppCheckCryptoUtils sha256HashFromData:statement];
}

- (FBLPromise *)rejectedPromiseWithError:(NSError *)error {
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  [rejectedPromise reject:error];
  return rejectedPromise;
}

- (NSError *)expectRandomChallengeRequestError {
  NSError *challengeError = [NSError errorWithDomain:@"testGetToken_WhenRandomChallengeError"
                                                code:NSNotFound
                                            userInfo:nil];
  self.fakeAPIService.getRandomChallengePromise = [self rejectedPromiseWithError:challengeError];
  return challengeError;
}

- (void)resetFakeCallCountsAndErrors {
  self.fakeAppAttestService.generateKeyCallCount = 0;
  self.fakeAppAttestService.attestKeyCallCount = 0;
  self.fakeAppAttestService.generateAssertionCallCount = 0;
  self.fakeAPIService.getRandomChallengeCallCount = 0;
  self.fakeAPIService.attestKeyCallCount = 0;
  self.fakeAPIService.getAppCheckTokenCallCount = 0;
  self.fakeStorage.getAppAttestKeyIDCallCount = 0;
  self.fakeStorage.setAppAttestKeyIDCallCount = 0;
  self.fakeArtifactStorage.getArtifactCallCount = 0;
  self.fakeArtifactStorage.setArtifactCallCount = 0;

  self.fakeAppAttestService.generateKeyErrorToReturn = nil;
  self.fakeAppAttestService.attestKeyErrorToReturn = nil;
  self.fakeAppAttestService.generateAssertionErrorToReturn = nil;
  self.fakeAppAttestService.keyIdToReturn = nil;
  self.fakeAppAttestService.attestationToReturn = nil;
  self.fakeAppAttestService.assertionToReturn = nil;

  self.fakeAPIService.getRandomChallengePromise = nil;
  self.fakeAPIService.attestKeyPromise = nil;
  self.fakeAPIService.getAppCheckTokenPromise = nil;

  self.fakeStorage.getAppAttestKeyIDPromise = nil;
  self.fakeStorage.setAppAttestKeyIDPromise = nil;

  self.fakeArtifactStorage.getArtifactPromise = nil;
  self.fakeArtifactStorage.setArtifactPromise = nil;
}

- (void)verifyAllMocks {
}

- (GACAppCheckHTTPError *)attestationRejectionHTTPError {
  NSHTTPURLResponse *response =
      [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://localhost"]
                                  statusCode:403
                                 HTTPVersion:@"HTTP/1.1"
                                headerFields:nil];
  NSData *responseBody = [@"Could not verify attestation" dataUsingEncoding:NSUTF8StringEncoding];
  return [[GACAppCheckHTTPError alloc] initWithHTTPResponse:response data:responseBody];
}

- (void)assertGetToken_WhenNoExistingKey_Success {
  [self resetFakeCallCountsAndErrors];

  // 0. Expect backoff wrapper to be used.
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 1. Expect App Attest availability to be checked and no existing stored key requested.
  [self expectAppAttestAvailabilityToBeCheckedAndNotExistingStoredKeyRequested];

  // 2. Expect App Attest key to be generated.
  NSString *generatedKeyID = @"generatedKeyID";
  self.fakeAppAttestService.keyIdToReturn = generatedKeyID;

  // 3. Expect the key ID to be stored.
  self.fakeStorage.setAppAttestKeyIDPromise = [FBLPromise resolvedWith:generatedKeyID];

  // 4. Expect random challenge to be requested.
  self.fakeAPIService.getRandomChallengePromise = [FBLPromise resolvedWith:self.randomChallenge];

  // 5. Expect the key to be attested with the challenge.
  NSData *attestationData = [@"attestation data" dataUsingEncoding:NSUTF8StringEncoding];
  self.fakeAppAttestService.attestationToReturn = attestationData;

  // 6. Expect key attestation request to be sent.
  GACAppCheckToken *FACToken = [[GACAppCheckToken alloc] initWithToken:@"FAC token"
                                                        expirationDate:[NSDate date]];
  NSData *artifactData = [@"attestation artifact" dataUsingEncoding:NSUTF8StringEncoding];
  __auto_type attestKeyResponse =
      [[GACAppAttestAttestationResponse alloc] initWithArtifact:artifactData token:FACToken];
  self.fakeAPIService.attestKeyPromise = [FBLPromise resolvedWith:attestKeyResponse];

  // 7. Expect the artifact received from Firebase backend to be saved.
  self.fakeArtifactStorage.setArtifactPromise = [FBLPromise resolvedWith:artifactData];

  // 8. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertEqualObjects(token.token, FACToken.token);
        XCTAssertEqualObjects(token.expirationDate, FACToken.expirationDate);
        XCTAssertNil(error);
      }];

  [self waitForExpectations:@[ self.fakeBackoffWrapper.backoffExpectation, completionExpectation ]
                    timeout:0.5
               enforceOrder:YES];

  // 9. Verify mocks.
  XCTAssertEqual(self.fakeAppAttestService.generateKeyCallCount, 1);
  XCTAssertEqual(self.fakeStorage.setAppAttestKeyIDCallCount, 1);
  XCTAssertEqual(self.fakeAPIService.getRandomChallengeCallCount, 1);
  XCTAssertEqual(self.fakeAppAttestService.attestKeyCallCount, 1);
  XCTAssertEqual(self.fakeAPIService.attestKeyCallCount, 1);
  XCTAssertEqual(self.fakeArtifactStorage.setArtifactCallCount, 1);

  // 10. Verify backoff result.
  XCTAssertEqualObjects(((GACAppCheckToken *)self.fakeBackoffWrapper.operationResult).token,
                        FACToken.token);
}

- (void)assertGetToken_WhenKeyRegistered_Success {
  [self resetFakeCallCountsAndErrors];

  // 0. Expect backoff wrapper to be used.
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 1. Expect GACAppAttestService.isSupported.
  self.fakeAppAttestService.isSupported = YES;

  // 2. Expect storage getAppAttestKeyID.
  NSString *existingKeyID = [NSUUID UUID].UUIDString;
  self.fakeStorage.getAppAttestKeyIDPromise = [FBLPromise resolvedWith:existingKeyID];

  // 3. Expect a stored artifact to be requested.
  NSData *storedArtifact = [[NSUUID UUID].UUIDString dataUsingEncoding:NSUTF8StringEncoding];
  self.fakeArtifactStorage.getArtifactPromise = [FBLPromise resolvedWith:storedArtifact];

  // 4. Expect random challenge to be requested.
  self.fakeAPIService.getRandomChallengePromise = [FBLPromise resolvedWith:self.randomChallenge];

  // 5. Expect assertion to be requested.
  NSData *assertion = [[NSUUID UUID].UUIDString dataUsingEncoding:NSUTF8StringEncoding];
  self.fakeAppAttestService.assertionToReturn = assertion;

  // 6. Expect assertion request to be sent.
  GACAppCheckToken *FACToken = [[GACAppCheckToken alloc] initWithToken:[NSUUID UUID].UUIDString
                                                        expirationDate:[NSDate date]];
  self.fakeAPIService.getAppCheckTokenPromise = [FBLPromise resolvedWith:FACToken];

  // 7. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertEqualObjects(token.token, FACToken.token);
        XCTAssertEqualObjects(token.expirationDate, FACToken.expirationDate);
        XCTAssertNil(error);
      }];

  [self waitForExpectations:@[ self.fakeBackoffWrapper.backoffExpectation, completionExpectation ]
                    timeout:0.5];

  // 8. Verify mocks.
  XCTAssertEqual(self.fakeAppAttestService.generateAssertionCallCount, 1);
  XCTAssertEqual(self.fakeAPIService.getAppCheckTokenCallCount, 1);

  // 9. Verify backoff result.
  XCTAssertEqualObjects(((GACAppCheckToken *)self.fakeBackoffWrapper.operationResult).token,
                        FACToken.token);
}

- (void)assertAttestationResetAndGetTokenRetryWhenExistingKeyIsRejectedWithAttestationError:
    (NSError *)error {
  // 1. Expect GACAppAttestService.isSupported.
  self.fakeAppAttestService.isSupported = YES;

  // 2. Expect storage getAppAttestKeyID.
  NSString *existingKeyID = @"existingKeyID";
  self.fakeStorage.getAppAttestKeyIDPromise = [FBLPromise resolvedWith:existingKeyID];

  // 3. Expect a stored artifact to be requested.
  __auto_type rejectedPromise = [self rejectedPromiseWithError:[NSError errorWithDomain:self.name
                                                                                   code:NSNotFound
                                                                               userInfo:nil]];
  self.fakeArtifactStorage.getArtifactPromise = rejectedPromise;

  // 4. Expect random challenge to be requested.
  self.fakeAPIService.getRandomChallengePromise = [FBLPromise resolvedWith:self.randomChallenge];

  // 5. Expect the key to be attested with the challenge.
  self.fakeAppAttestService.attestKeyErrorToReturn = error;

  // 6. Stored attestation to be reset.
  [self expectAttestationReset];

  // 7. Expect App Attest availability to be requested and stored key ID request to fail.
  [self expectAppAttestAvailabilityToBeCheckedAndNotExistingStoredKeyRequested];

  // 8. Expect the App Attest key pair to be generated and attested.
  NSString *newKeyID = @"newKeyID";
  NSData *attestationData = [[NSUUID UUID].UUIDString dataUsingEncoding:NSUTF8StringEncoding];
  [self expectAppAttestKeyGeneratedAndAttestedWithKeyID:newKeyID attestationData:attestationData];

  // 9. Expect exchange request to be sent.
  GACAppCheckToken *appCheckToken = [[GACAppCheckToken alloc] initWithToken:@"App Check Token"
                                                             expirationDate:[NSDate date]];
  NSData *artifactData = [@"attestation artifact" dataUsingEncoding:NSUTF8StringEncoding];
  __auto_type attestKeyResponse =
      [[GACAppAttestAttestationResponse alloc] initWithArtifact:artifactData token:appCheckToken];
  self.fakeAPIService.attestKeyPromise = [FBLPromise resolvedWith:attestKeyResponse];

  // 10. Expect the artifact received from Firebase backend to be saved.
  self.fakeArtifactStorage.setArtifactPromise = [FBLPromise resolvedWith:artifactData];

  // 11. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertEqualObjects(token.token, appCheckToken.token);
        XCTAssertEqualObjects(token.expirationDate, appCheckToken.expirationDate);
        XCTAssertNil(error);
      }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5 enforceOrder:YES];
}

- (void)assertAttestationResetAndGetTokenRetryWhenExistingKeyIsRejectedWithAssertionError:
    (NSError *)error {
  // 1. Expect GACAppAttestService.isSupported.
  self.fakeAppAttestService.isSupported = YES;

  // 2. Expect storage getAppAttestKeyID.
  NSString *existingKeyID = @"existingKeyID";
  self.fakeStorage.getAppAttestKeyIDPromise = [FBLPromise resolvedWith:existingKeyID];

  // 3. Expect a stored artifact to be requested.
  NSData *storedArtifact = [@"storedArtifact" dataUsingEncoding:NSUTF8StringEncoding];
  self.fakeArtifactStorage.getArtifactPromise = [FBLPromise resolvedWith:storedArtifact];

  // 4. Expect random challenge to be requested.
  self.fakeAPIService.getRandomChallengePromise = [FBLPromise resolvedWith:self.randomChallenge];

  // 5. Don't expect assertion to be requested.
  self.fakeAppAttestService.generateAssertionErrorToReturn = error;

  // 6. Stored attestation to be reset.
  [self expectAttestationReset];

  // 7. Assert that attestation is tried successfully.
  [self assertGetToken_WhenNoExistingKey_Success];
}

- (void)expectAppAttestAvailabilityToBeCheckedAndNotExistingStoredKeyRequested {
  // 1. Expect GACAppAttestService.isSupported.
  self.fakeAppAttestService.isSupported = YES;

  // 2. Expect storage getAppAttestKeyID.
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  NSError *error = [NSError errorWithDomain:@"testGetToken_WhenNoExistingKey_Success"
                                       code:NSNotFound
                                   userInfo:nil];
  [rejectedPromise reject:error];
  self.fakeStorage.getAppAttestKeyIDPromise = rejectedPromise;
}

- (void)expectAppAttestKeyGeneratedAndAttestedWithKeyID:(NSString *)keyID
                                        attestationData:(NSData *)attestationData {
  // 1. Expect App Attest key to be generated.
  self.fakeAppAttestService.keyIdToReturn = keyID;

  // 2. Expect the key ID to be stored.
  self.fakeStorage.setAppAttestKeyIDPromise = [FBLPromise resolvedWith:keyID];

  // 3. Expect random challenge to be requested.
  self.fakeAPIService.getRandomChallengePromise = [FBLPromise resolvedWith:self.randomChallenge];

  // 4. Expect the key to be attested with the challenge.
  self.fakeAppAttestService.attestKeyErrorToReturn = nil;
  self.fakeAppAttestService.attestationToReturn = attestationData;
}

- (void)expectAttestationReset {
  // 1. Expect stored key ID to be reset.
  self.fakeStorage.setAppAttestKeyIDPromise = [FBLPromise resolvedWith:nil];

  // 2. Expect stored attestation artifact to be reset.
  self.fakeArtifactStorage.setArtifactPromise = [FBLPromise resolvedWith:nil];
}

@end
