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

@testable import AppCheckCore
import DeviceCheck
import XCTest

@available(iOS 14.0, macOS 11.0, tvOS 15.0, watchOS 9.0, *)
class MockAppCheckCoreAppAttestService: NSObject, AppCheckCoreAppAttestService {
  var isSupportedResult = true
  var isSupported: Bool { return isSupportedResult }

  var generateKeyResults: [Result<String, Error>] = []
  var generateKeyCallCount = 0
  func generateKey(completionHandler: @escaping (String?, Error?) -> Void) {
    let result = generateKeyResults[generateKeyCallCount]
    generateKeyCallCount += 1
    switch result {
    case let .success(keyId): completionHandler(keyId, nil)
    case let .failure(error): completionHandler(nil, error)
    }
  }

  var attestKeyResults: [Result<Data, Error>] = []
  var attestKeyCallCount = 0
  var attestKeyArgs: [(keyId: String, clientDataHash: Data)] = []
  func attestKey(_ keyId: String, clientDataHash: Data,
                 completionHandler: @escaping (Data?, Error?) -> Void) {
    let result = attestKeyResults[attestKeyCallCount]
    attestKeyCallCount += 1
    attestKeyArgs.append((keyId, clientDataHash))
    switch result {
    case let .success(data): completionHandler(data, nil)
    case let .failure(error): completionHandler(nil, error)
    }
  }

  var generateAssertionResults: [Result<Data, Error>] = []
  var generateAssertionCallCount = 0
  var generateAssertionArgs: [(keyId: String, clientDataHash: Data)] = []
  func generateAssertion(_ keyId: String, clientDataHash: Data,
                         completionHandler: @escaping (Data?, Error?) -> Void) {
    let result = generateAssertionResults[generateAssertionCallCount]
    generateAssertionCallCount += 1
    generateAssertionArgs.append((keyId, clientDataHash))
    switch result {
    case let .success(data): completionHandler(data, nil)
    case let .failure(error): completionHandler(nil, error)
    }
  }
}

@available(iOS 14.0, macOS 11.0, tvOS 15.0, watchOS 9.0, *)
class MockAppAttestAPIService: NSObject, AppCheckCoreAppAttestAPIServiceProtocol {
  var getRandomChallengeResults: [Result<Data, Error>] = []
  var getRandomChallengeCallCount = 0
  func getRandomChallenge() async throws -> Data {
    let result = getRandomChallengeResults[getRandomChallengeCallCount]
    getRandomChallengeCallCount += 1
    return try result.get()
  }

  var attestKeyResults: [Result<AppCheckCoreAppAttestAttestationResponse, Error>] = []
  var attestKeyCallCount = 0
  var attestKeyArgs: [(attestation: Data, keyId: String, challenge: Data, limitedUse: Bool)] = []
  func attestKey(withAttestation attestation: Data, keyID: String, challenge: Data,
                 limitedUse: Bool) async throws -> AppCheckCoreAppAttestAttestationResponse {
    let result = attestKeyResults[attestKeyCallCount]
    attestKeyCallCount += 1
    attestKeyArgs.append((attestation, keyID, challenge, limitedUse))
    return try result.get()
  }

  var getAppCheckCoreTokenResults: [Result<AppCheckCoreToken, Error>] = []
  var getAppCheckCoreTokenCallCount = 0
  var getAppCheckCoreTokenArgs: [(
    artifact: Data,
    challenge: Data,
    assertion: Data,
    limitedUse: Bool
  )] = []
  func getAppCheckToken(withArtifact artifact: Data, challenge: Data, assertion: Data,
                        limitedUse: Bool) async throws -> AppCheckCoreToken {
    let result = getAppCheckCoreTokenResults[getAppCheckCoreTokenCallCount]
    getAppCheckCoreTokenCallCount += 1
    getAppCheckCoreTokenArgs.append((artifact, challenge, assertion, limitedUse))
    return try result.get()
  }
}

@available(iOS 14.0, macOS 11.0, tvOS 15.0, watchOS 9.0, *)
class MockAppAttestKeyIDStorage: NSObject, AppCheckCoreAppAttestKeyIDStorageProtocol {
  var getAppAttestKeyIDResults: [Result<String?, Error>] = []
  var getAppAttestKeyIDCallCount = 0
  func getAppAttestKeyID() async throws -> String? {
    let result = getAppAttestKeyIDResults[getAppAttestKeyIDCallCount]
    getAppAttestKeyIDCallCount += 1
    return try result.get()
  }

  var setAppAttestKeyIDResults: [Result<String?, Error>] = []
  var setAppAttestKeyIDCallCount = 0
  var setAppAttestKeyIDArgs: [String?] = []
  func setAppAttestKeyID(_ keyID: String?) async throws -> String? {
    let result = setAppAttestKeyIDResults[setAppAttestKeyIDCallCount]
    setAppAttestKeyIDCallCount += 1
    setAppAttestKeyIDArgs.append(keyID)
    return try result.get()
  }
}

@available(iOS 14.0, macOS 11.0, tvOS 15.0, watchOS 9.0, *)
class MockAppAttestArtifactStorage: NSObject, AppCheckCoreAppAttestArtifactStorageProtocol {
  var getArtifactResults: [Result<Data?, Error>] = []
  var getArtifactCallCount = 0
  var getArtifactArgs: [String] = []
  func getArtifact(forKey keyID: String) async throws -> Data? {
    let result = getArtifactResults[getArtifactCallCount]
    getArtifactCallCount += 1
    getArtifactArgs.append(keyID)
    return try result.get()
  }

  var setArtifactResults: [Result<Data?, Error>] = []
  var setArtifactCallCount = 0
  var setArtifactArgs: [(artifact: Data?, keyId: String)] = []
  func setArtifact(_ artifact: Data?, forKey keyID: String) async throws -> Data? {
    let result = setArtifactResults[setArtifactCallCount]
    setArtifactCallCount += 1
    setArtifactArgs.append((artifact, keyID))
    return try result.get()
  }
}

@available(iOS 14.0, macOS 11.0, tvOS 15.0, watchOS 9.0, *)
class FakeAppCheckBackoffWrapper: NSObject, AppCheckBackoffWrapperProtocol {
  var isNextOperationAllowed: Bool = true
  var backoffCalledCount = 0
  var defaultErrorHandler: ((Error) -> AppCheckBackoffType)?

  func defaultAppCheckProviderErrorHandler() -> (Error) -> AppCheckBackoffType {
    return { error in .none }
  }

  func applyBackoffToOperation(_ operation: @escaping () async throws -> Any,
                               errorHandler: @escaping (Error) -> AppCheckBackoffType) async throws
    -> Any {
    backoffCalledCount += 1
    guard isNextOperationAllowed else {
      throw NSError(domain: "FakeBackoff", code: -1, userInfo: nil)
    }
    do {
      return try await operation()
    } catch {
      if let defaultErrorHandler = defaultErrorHandler {
        _ = defaultErrorHandler(error)
      } else {
        _ = errorHandler(error)
      }
      throw error
    }
  }
}

@available(iOS 14.0, macOS 11.0, tvOS 15.0, watchOS 9.0, *)
class AppCheckCoreAppAttestProviderTests: XCTestCase {
  var provider: AppCheckCoreProvider!
  var mockAppCheckCoreAppAttestService: MockAppCheckCoreAppAttestService!
  var mockAPIService: MockAppAttestAPIService!
  var mockStorage: MockAppAttestKeyIDStorage!
  var mockArtifactStorage: MockAppAttestArtifactStorage!
  var fakeBackoffWrapper: FakeAppCheckBackoffWrapper!

  var randomChallenge: Data!
  var randomChallengeHash: Data!

  override func setUp() {
    super.setUp()
    resetMocks()
  }

  func resetMocks() {
    mockAppCheckCoreAppAttestService = MockAppCheckCoreAppAttestService()
    mockAPIService = MockAppAttestAPIService()
    mockStorage = MockAppAttestKeyIDStorage()
    mockArtifactStorage = MockAppAttestArtifactStorage()
    fakeBackoffWrapper = FakeAppCheckBackoffWrapper()

    provider = AppCheckCoreAppAttestProvider(
      appAttestService: mockAppCheckCoreAppAttestService,
      apiService: mockAPIService,
      keyIDStorage: mockStorage,
      artifactStorage: mockArtifactStorage,
      backoffWrapper: fakeBackoffWrapper
    )
    randomChallenge = "random challenge".data(using: .utf8)!
    randomChallengeHash = Data(base64Encoded: "vEq8yE9g+WwfifNqC2wsXN9M3NIDeOKpDBVYLpGbUDY=")!
  }

  override func tearDown() {
    provider = nil
    mockArtifactStorage = nil
    mockStorage = nil
    mockAPIService = nil
    mockAppCheckCoreAppAttestService = nil
    fakeBackoffWrapper = nil
    super.tearDown()
  }

  func dataHashForAssertion(withArtifactData artifact: Data) -> Data {
    var statement = artifact
    statement.append(randomChallenge)
    return AppCheckCoreCryptoUtils.sha256Hash(from: statement)
  }

  func attestationRejectionHTTPError() -> AppCheckCoreHTTPError {
    let response = HTTPURLResponse(
      url: URL(string: "http://localhost")!,
      statusCode: 403,
      httpVersion: "HTTP/1.1",
      headerFields: nil
    )!
    let responseBody = "Could not verify attestation".data(using: .utf8)!
    return AppCheckCoreHTTPError(httpResponse: response, data: responseBody)
  }

  func expectAppAttestAvailabilityToBeCheckedAndNotExistingStoredKeyRequested() {
    mockAppCheckCoreAppAttestService.isSupportedResult = true
    mockStorage.getAppAttestKeyIDResults.append(.success(nil))
  }

  func expectAppAttestKeyGeneratedAndAttested(withKeyID keyID: String, attestationData: Data) {
    mockAppCheckCoreAppAttestService.generateKeyResults.append(.success(keyID))
    mockStorage.setAppAttestKeyIDResults.append(.success(keyID))
    mockAPIService.getRandomChallengeResults.append(.success(randomChallenge))
    mockAppCheckCoreAppAttestService.attestKeyResults.append(.success(attestationData))
  }

  func expectAttestationReset() {
    mockStorage.setAppAttestKeyIDResults.append(.success(nil))
    mockArtifactStorage.setArtifactResults.append(.success(nil))
  }

  // MARK: - Initial handshake (attestation)

  func testGetTokenWhenAppAttestIsNotSupported() async {
    mockAppCheckCoreAppAttestService.isSupportedResult = false

    let expectedError = AppCheckCoreErrorUtil.unsupportedAttestationProvider("AppAttestProvider")

    do {
      _ = try await provider.getToken()
      XCTFail("Should throw")
    } catch {
      XCTAssertEqual((error as NSError).code, (expectedError as NSError).code)
    }

    XCTAssertEqual(fakeBackoffWrapper.backoffCalledCount, 1)
    XCTAssertEqual(mockAppCheckCoreAppAttestService.generateKeyCallCount, 0)
    XCTAssertEqual(mockStorage.getAppAttestKeyIDCallCount, 0)
  }

  func testGetToken_WhenNoExistingKey_Success() async throws {
    try await assertGetToken_WhenNoExistingKey_Success()
  }

  func testGetToken_WhenExistingUnregisteredKey_Success() async throws {
    mockAppCheckCoreAppAttestService.isSupportedResult = true

    let existingKeyID = "existingKeyID"
    mockStorage.getAppAttestKeyIDResults.append(.success(existingKeyID))

    mockArtifactStorage.getArtifactResults.append(.success(nil))

    mockAPIService.getRandomChallengeResults.append(.success(randomChallenge))

    let attestationData = "attestation data".data(using: .utf8)!
    mockAppCheckCoreAppAttestService.attestKeyResults.append(.success(attestationData))

    let facToken = AppCheckCoreToken(token: "FAC token", expirationDate: Date())
    let artifactData = "attestation artifact".data(using: .utf8)!
    let attestKeyResponse = AppCheckCoreAppAttestAttestationResponse(
      artifact: artifactData,
      token: facToken
    )
    mockAPIService.attestKeyResults.append(.success(attestKeyResponse))

    mockArtifactStorage.setArtifactResults.append(.success(artifactData))

    let token = try await provider.getToken()

    XCTAssertEqual(token.token, facToken.token)
    XCTAssertEqual(token.expirationDate, facToken.expirationDate)

    XCTAssertEqual(fakeBackoffWrapper.backoffCalledCount, 1)
    XCTAssertEqual(mockAppCheckCoreAppAttestService.generateKeyCallCount, 0)
    XCTAssertEqual(mockStorage.setAppAttestKeyIDCallCount, 0)
    XCTAssertEqual(mockAppCheckCoreAppAttestService.attestKeyArgs.first?.keyId, existingKeyID)
    XCTAssertEqual(
      mockAppCheckCoreAppAttestService.attestKeyArgs.first?.clientDataHash,
      randomChallengeHash
    )

    XCTAssertEqual(mockAPIService.attestKeyArgs.first?.attestation, attestationData)
    XCTAssertEqual(mockAPIService.attestKeyArgs.first?.keyId, existingKeyID)
    XCTAssertEqual(mockAPIService.attestKeyArgs.first?.challenge, randomChallenge)
    XCTAssertEqual(mockAPIService.attestKeyArgs.first?.limitedUse, false)
    XCTAssertEqual(mockArtifactStorage.setArtifactArgs.first?.artifact, artifactData)
    XCTAssertEqual(mockArtifactStorage.setArtifactArgs.first?.keyId, existingKeyID)
  }

  func testGetToken_WhenUnregisteredKeyAndRandomChallengeError() async throws {
    mockAppCheckCoreAppAttestService.isSupportedResult = true
    let existingKeyID = "existingKeyID"
    mockStorage.getAppAttestKeyIDResults.append(.success(existingKeyID))
    mockArtifactStorage.getArtifactResults.append(.success(nil))

    let challengeError = NSError(domain: "testGetToken_WhenRandomChallengeError", code: NSNotFound)
    mockAPIService.getRandomChallengeResults.append(.failure(challengeError))

    do {
      _ = try await provider.getToken()
      XCTFail("Should throw")
    } catch {
      XCTAssertEqual((error as NSError).domain, challengeError.domain)
    }

    XCTAssertEqual(fakeBackoffWrapper.backoffCalledCount, 1)
    XCTAssertEqual(mockStorage.setAppAttestKeyIDCallCount, 0)
    XCTAssertEqual(mockAppCheckCoreAppAttestService.attestKeyCallCount, 0)
    XCTAssertEqual(mockAPIService.attestKeyCallCount, 0)
  }

  func testGetToken_WhenUnregisteredKeyAndKeyAttestationError() async throws {
    mockAppCheckCoreAppAttestService.isSupportedResult = true
    let existingKeyID = "existingKeyID"
    mockStorage.getAppAttestKeyIDResults.append(.success(existingKeyID))
    mockArtifactStorage.getArtifactResults.append(.success(nil))
    mockAPIService.getRandomChallengeResults.append(.success(randomChallenge))

    let attestationError = NSError(domain: "test", code: 0)
    let expectedError = AppCheckCoreErrorUtil.appAttestAttestKeyFailed(
      with: attestationError,
      keyId: existingKeyID,
      clientDataHash: randomChallengeHash
    )
    mockAppCheckCoreAppAttestService.attestKeyResults.append(.failure(attestationError))

    do {
      _ = try await provider.getToken()
      XCTFail("Should throw")
    } catch {
      XCTAssertEqual((error as NSError).code, (expectedError as NSError).code)
    }

    XCTAssertEqual(fakeBackoffWrapper.backoffCalledCount, 1)
    XCTAssertEqual(mockAPIService.attestKeyCallCount, 0)
  }

  func testGetToken_WhenUnregisteredKeyAndKeyAttestationExchangeError() async throws {
    mockAppCheckCoreAppAttestService.isSupportedResult = true
    let existingKeyID = "existingKeyID"
    mockStorage.getAppAttestKeyIDResults.append(.success(existingKeyID))
    mockArtifactStorage.getArtifactResults.append(.success(nil))
    mockAPIService.getRandomChallengeResults.append(.success(randomChallenge))
    let attestationData = "attestation data".data(using: .utf8)!
    mockAppCheckCoreAppAttestService.attestKeyResults.append(.success(attestationData))

    let exchangeError = NSError(domain: "test", code: 0)
    mockAPIService.attestKeyResults.append(.failure(exchangeError))

    do {
      _ = try await provider.getToken()
      XCTFail("Should throw")
    } catch {
      XCTAssertEqual((error as NSError).domain, exchangeError.domain)
    }

    XCTAssertEqual(fakeBackoffWrapper.backoffCalledCount, 1)
  }

  // MARK: - Rejected Attestation

  func testGetToken_WhenAttestationIsRejected_ThenAttestationIsResetAndRetriedOnceSuccess() async throws {
    expectAppAttestAvailabilityToBeCheckedAndNotExistingStoredKeyRequested()

    let keyID1 = "keyID1"
    let attestationData1 = UUID().uuidString.data(using: .utf8)!
    expectAppAttestKeyGeneratedAndAttested(withKeyID: keyID1, attestationData: attestationData1)

    let apiError = attestationRejectionHTTPError()
    mockAPIService.attestKeyResults.append(.failure(apiError))

    expectAttestationReset()
    expectAppAttestAvailabilityToBeCheckedAndNotExistingStoredKeyRequested()

    let keyID2 = "keyID2"
    let attestationData2 = UUID().uuidString.data(using: .utf8)!
    expectAppAttestKeyGeneratedAndAttested(withKeyID: keyID2, attestationData: attestationData2)

    let facToken = AppCheckCoreToken(token: "FAC token", expirationDate: Date())
    let artifactData = "attestation artifact".data(using: .utf8)!
    let attestKeyResponse = AppCheckCoreAppAttestAttestationResponse(
      artifact: artifactData,
      token: facToken
    )
    mockAPIService.attestKeyResults.append(.success(attestKeyResponse))

    mockArtifactStorage.setArtifactResults.append(.success(artifactData))

    let token = try await provider.getToken()

    XCTAssertEqual(token.token, facToken.token)
    XCTAssertEqual(token.expirationDate, facToken.expirationDate)
  }

  func testGetToken_WhenAttestationIsRejected_ThenAttestationIsResetAndRetriedOnceError() async throws {
    expectAppAttestAvailabilityToBeCheckedAndNotExistingStoredKeyRequested()

    let keyID1 = "keyID1"
    let attestationData1 = UUID().uuidString.data(using: .utf8)!
    expectAppAttestKeyGeneratedAndAttested(withKeyID: keyID1, attestationData: attestationData1)

    let apiError = attestationRejectionHTTPError()
    mockAPIService.attestKeyResults.append(.failure(apiError))

    expectAttestationReset()
    expectAppAttestAvailabilityToBeCheckedAndNotExistingStoredKeyRequested()

    let keyID2 = "keyID2"
    let attestationData2 = UUID().uuidString.data(using: .utf8)!
    expectAppAttestKeyGeneratedAndAttested(withKeyID: keyID2, attestationData: attestationData2)

    mockAPIService.attestKeyResults.append(.failure(apiError))

    expectAttestationReset()

    do {
      _ = try await provider.getToken()
      XCTFail("Should throw")
    } catch {
      XCTAssertTrue(error is AppCheckCoreHTTPError)
    }
  }

  func testGetToken_WhenExistingKeyIsRejectedByApple_ThenAttestationIsResetAndRetriedOnce_Success() async throws {
    let invalidKeyError = NSError(
      domain: DCErrorDomain,
      code: DCError.invalidKey.rawValue,
      userInfo: nil
    )
    try await assertAttestationResetAndGetTokenRetryWhenExistingKeyIsRejectedWithAttestationError(
      invalidKeyError
    )

    resetMocks()
    let invalidInputError = NSError(
      domain: DCErrorDomain,
      code: DCError.invalidInput.rawValue,
      userInfo: nil
    )
    try await assertAttestationResetAndGetTokenRetryWhenExistingKeyIsRejectedWithAttestationError(
      invalidInputError
    )
  }

  // MARK: - FAC token refresh (assertion)

  func testGetToken_WhenKeyRegistered_Success() async throws {
    try await assertGetToken_WhenKeyRegistered_Success()
  }

  func testGetToken_WhenKeyRegisteredAndChallengeRequestError() async throws {
    mockAppCheckCoreAppAttestService.isSupportedResult = true
    let existingKeyID = "existingKeyID"
    mockStorage.getAppAttestKeyIDResults.append(.success(existingKeyID))

    let storedArtifact = "storedArtifact".data(using: .utf8)!
    mockArtifactStorage.getArtifactResults.append(.success(storedArtifact))

    let challengeError = NSError(domain: "testGetToken_WhenRandomChallengeError", code: NSNotFound)
    mockAPIService.getRandomChallengeResults.append(.failure(challengeError))

    do {
      _ = try await provider.getToken()
      XCTFail("Should throw")
    } catch {
      XCTAssertEqual((error as NSError).domain, challengeError.domain)
    }

    XCTAssertEqual(mockAppCheckCoreAppAttestService.generateAssertionCallCount, 0)
    XCTAssertEqual(mockAPIService.getAppCheckCoreTokenCallCount, 0)
  }

  func testGetToken_WhenKeyRegisteredAndGenerateAssertionError() async throws {
    mockAppCheckCoreAppAttestService.isSupportedResult = true
    let existingKeyID = "existingKeyID"
    mockStorage.getAppAttestKeyIDResults.append(.success(existingKeyID))

    let storedArtifact = "storedArtifact".data(using: .utf8)!
    mockArtifactStorage.getArtifactResults.append(.success(storedArtifact))

    mockAPIService.getRandomChallengeResults.append(.success(randomChallenge))

    let generateAssertionError = NSError(
      domain: "testGetToken_WhenKeyRegisteredAndGenerateAssertionError",
      code: 0
    )
    let clientDataHash = dataHashForAssertion(withArtifactData: storedArtifact)
    let expectedError = AppCheckCoreErrorUtil.appAttestGenerateAssertionFailed(
      with: generateAssertionError,
      keyId: existingKeyID,
      clientDataHash: clientDataHash
    )

    mockAppCheckCoreAppAttestService.generateAssertionResults
      .append(.failure(generateAssertionError))

    do {
      _ = try await provider.getToken()
      XCTFail("Should throw")
    } catch {
      XCTAssertEqual((error as NSError).code, (expectedError as NSError).code)
    }

    XCTAssertEqual(mockAPIService.getAppCheckCoreTokenCallCount, 0)
  }

  func testGetToken_WhenKeyRegisteredAndTokenExchangeRequestError() async throws {
    mockAppCheckCoreAppAttestService.isSupportedResult = true
    let existingKeyID = "existingKeyID"
    mockStorage.getAppAttestKeyIDResults.append(.success(existingKeyID))

    let storedArtifact = "storedArtifact".data(using: .utf8)!
    mockArtifactStorage.getArtifactResults.append(.success(storedArtifact))

    mockAPIService.getRandomChallengeResults.append(.success(randomChallenge))

    let assertion = "generatedAssertion".data(using: .utf8)!
    mockAppCheckCoreAppAttestService.generateAssertionResults.append(.success(assertion))

    let tokenExchangeError = NSError(
      domain: "testGetToken_WhenKeyRegisteredAndTokenExchangeRequestError",
      code: 0
    )
    mockAPIService.getAppCheckCoreTokenResults.append(.failure(tokenExchangeError))

    do {
      _ = try await provider.getToken()
      XCTFail("Should throw")
    } catch {
      XCTAssertEqual((error as NSError).domain, tokenExchangeError.domain)
    }
  }

  // MARK: - Rejected Assertion

  func testGetToken_WhenAssertionIsRejectedByApple_ThenResetToAttestationAndRetryOnceSuccess() async throws {
    let invalidKeyError = NSError(
      domain: DCErrorDomain,
      code: DCError.invalidKey.rawValue,
      userInfo: nil
    )
    try await assertAttestationResetAndGetTokenRetryWhenExistingKeyIsRejectedWithAssertionError(
      invalidKeyError
    )

    resetMocks()
    let invalidInputError = NSError(
      domain: DCErrorDomain,
      code: DCError.invalidInput.rawValue,
      userInfo: nil
    )
    try await assertAttestationResetAndGetTokenRetryWhenExistingKeyIsRejectedWithAssertionError(
      invalidInputError
    )

    resetMocks()
    let systemFailureError = NSError(
      domain: DCErrorDomain,
      code: DCError.unknownSystemFailure.rawValue,
      userInfo: nil
    )
    try await assertAttestationResetAndGetTokenRetryWhenExistingKeyIsRejectedWithAssertionError(
      systemFailureError
    )
  }

  // MARK: - Request merging

  func testGetToken_WhenCalledSeveralTimesSuccess_ThenThereIsOnlyOneOngoingHandshake() async throws {
    mockAppCheckCoreAppAttestService.isSupportedResult = true
    let existingKeyID = "existingKeyID"
    mockStorage.getAppAttestKeyIDResults.append(.success(existingKeyID))

    let storedArtifact = "storedArtifact".data(using: .utf8)!
    mockArtifactStorage.getArtifactResults.append(.success(storedArtifact))

    mockAPIService.getRandomChallengeResults.append(.success(randomChallenge))

    let assertion = "generatedAssertion".data(using: .utf8)!
    mockAppCheckCoreAppAttestService.generateAssertionResults.append(.success(assertion))

    let facToken = AppCheckCoreToken(token: "FAC token", expirationDate: Date())
    mockAPIService.getAppCheckCoreTokenResults.append(.success(facToken))

    let callsCount = 10
    async let results = withTaskGroup(of: AppCheckCoreToken?.self) { group in
      for _ in 0 ..< callsCount {
        group.addTask {
          try? await self.provider.getToken()
        }
      }
      var tokens = [AppCheckCoreToken?]()
      for await token in group {
        tokens.append(token)
      }
      return tokens
    }

    let tokens = await results
    for token in tokens {
      XCTAssertEqual(token?.token, facToken.token)
      XCTAssertEqual(token?.expirationDate, facToken.expirationDate)
    }

    XCTAssertEqual(mockStorage.getAppAttestKeyIDCallCount, 1)
    XCTAssertEqual(mockArtifactStorage.getArtifactCallCount, 1)
    XCTAssertEqual(mockAPIService.getRandomChallengeCallCount, 1)
    XCTAssertEqual(mockAppCheckCoreAppAttestService.generateAssertionCallCount, 1)
    XCTAssertEqual(mockAPIService.getAppCheckCoreTokenCallCount, 1)
  }

  func testGetToken_WhenCalledSeveralTimesError_ThenThereIsOnlyOneOngoingHandshake() async throws {
    mockAppCheckCoreAppAttestService.isSupportedResult = true
    let existingKeyID = "existingKeyID"
    mockStorage.getAppAttestKeyIDResults.append(.success(existingKeyID))

    let storedArtifact = "storedArtifact".data(using: .utf8)!
    mockArtifactStorage.getArtifactResults.append(.success(storedArtifact))

    mockAPIService.getRandomChallengeResults.append(.success(randomChallenge))

    let assertion = "generatedAssertion".data(using: .utf8)!
    mockAppCheckCoreAppAttestService.generateAssertionResults.append(.success(assertion))

    let assertionRequestError = NSError(domain: "test", code: 0)
    mockAPIService.getAppCheckCoreTokenResults.append(.failure(assertionRequestError))

    let callsCount = 10
    async let results = withTaskGroup(of: Error?.self) { group in
      for _ in 0 ..< callsCount {
        group.addTask {
          do {
            _ = try await self.provider.getToken()
            return nil
          } catch {
            return error
          }
        }
      }
      var errors = [Error?]()
      for await error in group {
        errors.append(error)
      }
      return errors
    }

    let errors = await results
    for error in errors {
      XCTAssertEqual((error as NSError?)?.domain, assertionRequestError.domain)
    }

    XCTAssertEqual(mockStorage.getAppAttestKeyIDCallCount, 1)
    XCTAssertEqual(mockArtifactStorage.getArtifactCallCount, 1)
    XCTAssertEqual(mockAPIService.getRandomChallengeCallCount, 1)
    XCTAssertEqual(mockAppCheckCoreAppAttestService.generateAssertionCallCount, 1)
    XCTAssertEqual(mockAPIService.getAppCheckCoreTokenCallCount, 1)
  }

  // MARK: - Backoff tests

  func testGetTokenBackoff() async {
    fakeBackoffWrapper.isNextOperationAllowed = false

    do {
      _ = try await provider.getToken()
      XCTFail("Should throw")
    } catch {
      XCTAssertEqual((error as NSError).domain, "FakeBackoff")
    }

    XCTAssertEqual(fakeBackoffWrapper.backoffCalledCount, 1)
    XCTAssertEqual(mockAppCheckCoreAppAttestService.generateKeyCallCount, 0)
    XCTAssertEqual(mockStorage.getAppAttestKeyIDCallCount, 0)
  }

  // MARK: - Helpers

  func assertGetToken_WhenNoExistingKey_Success() async throws {
    expectAppAttestAvailabilityToBeCheckedAndNotExistingStoredKeyRequested()

    let generatedKeyID = "generatedKeyID"
    mockAppCheckCoreAppAttestService.generateKeyResults.append(.success(generatedKeyID))

    mockStorage.setAppAttestKeyIDResults.append(.success(generatedKeyID))

    mockAPIService.getRandomChallengeResults.append(.success(randomChallenge))

    let attestationData = "attestation data".data(using: .utf8)!
    mockAppCheckCoreAppAttestService.attestKeyResults.append(.success(attestationData))

    let facToken = AppCheckCoreToken(token: "FAC token", expirationDate: Date())
    let artifactData = "attestation artifact".data(using: .utf8)!
    let attestKeyResponse = AppCheckCoreAppAttestAttestationResponse(
      artifact: artifactData,
      token: facToken
    )
    mockAPIService.attestKeyResults.append(.success(attestKeyResponse))

    mockArtifactStorage.setArtifactResults.append(.success(artifactData))

    let token = try await provider.getToken()

    XCTAssertEqual(token.token, facToken.token)
    XCTAssertEqual(token.expirationDate, facToken.expirationDate)
  }

  func assertGetToken_WhenKeyRegistered_Success() async throws {
    mockAppCheckCoreAppAttestService.isSupportedResult = true
    let existingKeyID = UUID().uuidString
    mockStorage.getAppAttestKeyIDResults.append(.success(existingKeyID))

    let storedArtifact = UUID().uuidString.data(using: .utf8)!
    mockArtifactStorage.getArtifactResults.append(.success(storedArtifact))

    mockAPIService.getRandomChallengeResults.append(.success(randomChallenge))

    let assertion = UUID().uuidString.data(using: .utf8)!
    mockAppCheckCoreAppAttestService.generateAssertionResults.append(.success(assertion))

    let facToken = AppCheckCoreToken(token: UUID().uuidString, expirationDate: Date())
    mockAPIService.getAppCheckCoreTokenResults.append(.success(facToken))

    let token = try await provider.getToken()

    XCTAssertEqual(token.token, facToken.token)
    XCTAssertEqual(token.expirationDate, facToken.expirationDate)
  }

  func assertAttestationResetAndGetTokenRetryWhenExistingKeyIsRejectedWithAttestationError(_ error: NSError) async throws {
    mockAppCheckCoreAppAttestService.isSupportedResult = true
    let existingKeyID = "existingKeyID"
    mockStorage.getAppAttestKeyIDResults.append(.success(existingKeyID))

    mockArtifactStorage.getArtifactResults.append(.success(nil))

    mockAPIService.getRandomChallengeResults.append(.success(randomChallenge))

    mockAppCheckCoreAppAttestService.attestKeyResults.append(.failure(error))

    expectAttestationReset()
    expectAppAttestAvailabilityToBeCheckedAndNotExistingStoredKeyRequested()

    let newKeyID = "newKeyID"
    let attestationData = UUID().uuidString.data(using: .utf8)!
    expectAppAttestKeyGeneratedAndAttested(withKeyID: newKeyID, attestationData: attestationData)

    let appCheckToken = AppCheckCoreToken(token: "App Check Token", expirationDate: Date())
    let artifactData = "attestation artifact".data(using: .utf8)!
    let attestKeyResponse = AppCheckCoreAppAttestAttestationResponse(
      artifact: artifactData,
      token: appCheckToken
    )
    mockAPIService.attestKeyResults.append(.success(attestKeyResponse))

    mockArtifactStorage.setArtifactResults.append(.success(artifactData))

    let token = try await provider.getToken()

    XCTAssertEqual(token.token, appCheckToken.token)
    XCTAssertEqual(token.expirationDate, appCheckToken.expirationDate)
  }

  func assertAttestationResetAndGetTokenRetryWhenExistingKeyIsRejectedWithAssertionError(_ error: NSError) async throws {
    mockAppCheckCoreAppAttestService.isSupportedResult = true
    let existingKeyID = "existingKeyID"
    mockStorage.getAppAttestKeyIDResults.append(.success(existingKeyID))

    let storedArtifact = "storedArtifact".data(using: .utf8)!
    mockArtifactStorage.getArtifactResults.append(.success(storedArtifact))

    mockAPIService.getRandomChallengeResults.append(.success(randomChallenge))

    mockAppCheckCoreAppAttestService.generateAssertionResults.append(.failure(error))

    expectAttestationReset()

    // Assert that attestation is tried successfully.
    try await assertGetToken_WhenNoExistingKey_Success()
  }
}
