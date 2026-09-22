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

@_spi(FirebaseInternal) @testable import AppCheckCore
import XCTest

private class MockAppCheckAPIService: NSObject, AppCheckCoreAPIServiceProtocol {
  var baseURL: String = "https://test.appcheck.url.com/beta"

  var passedRequestURL: URL?
  var passedHTTPMethod: String?
  var passedBody: Data?
  var passedAdditionalHeaders: [String: String]?

  var sendRequestResult: Result<AppCheckCoreURLSessionDataResponse, Error>?
  var appCheckTokenResult: Result<AppCheckCoreToken, Error>?

  var passedAPIResponse: AppCheckCoreURLSessionDataResponse?

  func sendRequest(withURL requestURL: URL, httpMethod: String, body: Data?,
                   additionalHeaders: [String: String]?) async throws
    -> AppCheckCoreURLSessionDataResponse {
    passedRequestURL = requestURL
    passedHTTPMethod = httpMethod
    passedBody = body
    passedAdditionalHeaders = additionalHeaders

    if let result = sendRequestResult {
      switch result {
      case let .success(response): return response
      case let .failure(error): throw error
      }
    }
    throw NSError(domain: "MockAppCheckAPIService", code: -1, userInfo: nil)
  }

  func appCheckToken(withAPIResponse response: AppCheckCoreURLSessionDataResponse) async throws
    -> AppCheckCoreToken {
    passedAPIResponse = response
    if let result = appCheckTokenResult {
      switch result {
      case let .success(token): return token
      case let .failure(error): throw error
      }
    }
    throw NSError(domain: "MockAppCheckAPIService", code: -1, userInfo: nil)
  }
}

class AppCheckCoreAppAttestAPIServiceTests: XCTestCase {
  var appAttestAPIService: AppCheckCoreAppAttestAPIService!
  private var fakeAPIService: MockAppCheckAPIService!

  let kResourceName = "projects/project_id/apps/app_id"

  override func setUp() {
    super.setUp()

    fakeAPIService = MockAppCheckAPIService()
    appAttestAPIService = AppCheckCoreAppAttestAPIService(
      apiService: fakeAPIService,
      resourceName: kResourceName
    )
  }

  override func tearDown() {
    appAttestAPIService = nil
    fakeAPIService = nil
    super.tearDown()
  }

  // MARK: - Random challenge request

  func testGetRandomChallengeWhenAPIResponseValid() async throws {
    // 1. Prepare API response.
    let challengeString = "random_challenge"
    let responseDict: [String: Any] = [
      "challenge": challengeString.data(using: .utf8)!.base64EncodedString(),
    ]
    let responseBody = try JSONSerialization.data(withJSONObject: responseDict, options: [])
    let validAPIResponse = APIResponse(code: 200, responseBody: responseBody)

    // 2. Stub API Service Request
    fakeAPIService.sendRequestResult = .success(validAPIResponse)

    // 3. Request the random challenge and verify results.
    let challenge = try await appAttestAPIService.getRandomChallenge()

    let retrievedString = String(data: challenge, encoding: .utf8)
    XCTAssertEqual(retrievedString, challengeString)

    let expectedRequestURL = "\(fakeAPIService.baseURL)/\(kResourceName):generateAppAttestChallenge"
    XCTAssertEqual(fakeAPIService.passedRequestURL?.absoluteString, expectedRequestURL)
    XCTAssertEqual(fakeAPIService.passedHTTPMethod, "POST")
  }

  func testGetRandomChallengeWhenAPIError() async {
    // 1. Prepare API response.
    let responseBodyString = "Generate challenge failed with invalid format."
    let responseBody = responseBodyString.data(using: .utf8)!
    let invalidAPIResponse = APIResponse(code: 300, responseBody: responseBody)
    let apiError = AppCheckCoreErrorUtil.apiError(
      with: invalidAPIResponse.httpResponse,
      data: invalidAPIResponse.httpBody
    )

    // 2. Stub API Service Request
    fakeAPIService.sendRequestResult = .failure(apiError)

    // 3. Request the random challenge and verify results.
    do {
      _ = try await appAttestAPIService.getRandomChallenge()
      XCTFail("Expected error to be thrown")
    } catch let error as NSError {
      XCTAssertEqual(error.domain, AppCheckCoreErrorDomain)
      XCTAssertEqual(error.code, AppCheckCoreErrorCode.unknown.rawValue)
      let failureReason = error.userInfo[NSLocalizedFailureReasonErrorKey] as? String
      XCTAssertTrue(failureReason?.contains("300") ?? false)
      XCTAssertTrue(failureReason?.contains(responseBodyString) ?? false)
    }

    let expectedRequestURL = "\(fakeAPIService.baseURL)/\(kResourceName):generateAppAttestChallenge"
    XCTAssertEqual(fakeAPIService.passedRequestURL?.absoluteString, expectedRequestURL)
    XCTAssertEqual(fakeAPIService.passedHTTPMethod, "POST")
  }

  // MARK: - Assertion request

  func testGetAppCheckTokenSuccess() async throws {
    try await testGetAppCheckTokenSuccess(withLimitedUse: false)
  }

  func testGetAppCheckTokenSuccessWithLimitedUse() async throws {
    try await testGetAppCheckTokenSuccess(withLimitedUse: true)
  }

  func testGetAppCheckTokenSuccess(withLimitedUse limitedUse: Bool) async throws {
    let artifact = generateRandomData()
    let challenge = generateRandomData()
    let assertion = generateRandomData()

    // 1. Prepare response.
    let responseBody = "{}".data(using: .utf8)!
    let validAPIResponse = APIResponse(code: 200, responseBody: responseBody)

    // 2. Stub API Service
    fakeAPIService.sendRequestResult = .success(validAPIResponse)

    let expectedToken = AppCheckCoreToken(token: "app_check_token", expirationDate: Date())
    fakeAPIService.appCheckTokenResult = .success(expectedToken)

    // 3. Send request.
    let token = try await appAttestAPIService.getAppCheckToken(
      withArtifact: artifact,
      challenge: challenge,
      assertion: assertion,
      limitedUse: limitedUse
    )

    // 4. Verify.
    XCTAssertEqual(token.token, expectedToken.token)
    XCTAssertEqual(token.expirationDate, expectedToken.expirationDate)

    let expectedRequestURL = "\(fakeAPIService.baseURL)/\(kResourceName):exchangeAppAttestAssertion"
    XCTAssertEqual(fakeAPIService.passedRequestURL?.absoluteString, expectedRequestURL)
    XCTAssertEqual(fakeAPIService.passedHTTPMethod, "POST")
    try assertTokenExchangeBody(
      fakeAPIService.passedBody,
      artifact: artifact,
      challenge: challenge,
      assertion: assertion,
      limitedUse: limitedUse
    )
  }

  // MARK: - Attestation request

  func testAttestKeySuccess() async throws {
    try await testAttestKeySuccess(withLimitedUse: false)
  }

  func testAttestKeySuccessWithLimitedUse() async throws {
    try await testAttestKeySuccess(withLimitedUse: true)
  }

  func testAttestKeySuccess(withLimitedUse limitedUse: Bool) async throws {
    let attestation = generateRandomData()
    let challenge = generateRandomData()
    let keyID = UUID().uuidString

    // 1. Prepare response.
    let expectedArtifactString = "valid Firebase app attest artifact"
    let responseDict: [String: Any] = [
      "artifact": expectedArtifactString.data(using: .utf8)!.base64EncodedString(),
      "appCheckToken": [
        "token": "valid_app_check_token",
        "ttl": "1800s",
      ],
    ]
    let responseBody = try JSONSerialization.data(withJSONObject: responseDict, options: [])
    let validAPIResponse = APIResponse(code: 200, responseBody: responseBody)

    // 2. Stub API Service
    fakeAPIService.sendRequestResult = .success(validAPIResponse)

    // 3. Send request.
    let response = try await appAttestAPIService.attestKey(
      withAttestation: attestation,
      keyID: keyID,
      challenge: challenge,
      limitedUse: limitedUse
    )

    // 4. Verify.
    let expectedArtifact = expectedArtifactString.data(using: .utf8)!
    XCTAssertEqual(response.artifact, expectedArtifact)
    XCTAssertEqual(response.token.token, "valid_app_check_token")

    let expectedRequestURL =
      "\(fakeAPIService.baseURL)/\(kResourceName):exchangeAppAttestAttestation"
    XCTAssertEqual(fakeAPIService.passedRequestURL?.absoluteString, expectedRequestURL)
    XCTAssertEqual(fakeAPIService.passedHTTPMethod, "POST")
    try assertAttestKeyBody(
      fakeAPIService.passedBody,
      attestation: attestation,
      challenge: challenge,
      keyID: keyID,
      limitedUse: limitedUse
    )
  }

  func testAttestKeySuccessUsesRequestDate() async throws {
    let attestation = generateRandomData()
    let challenge = generateRandomData()
    let keyID = UUID().uuidString
    let requestDate = Date(timeIntervalSince1970: 100_000)

    let responseDict: [String: Any] = [
      "artifact": "artifact".data(using: .utf8)!.base64EncodedString(),
      "appCheckToken": [
        "token": "valid_token",
        "ttl": "1800s",
      ],
    ]
    let responseBody = try JSONSerialization.data(withJSONObject: responseDict, options: [])
    let httpResponse = HTTPURLResponse(
      url: URL(string: "https://test.com")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    )!
    let apiResponse = AppCheckCoreURLSessionDataResponse(
      response: httpResponse,
      httpBody: responseBody,
      requestDate: requestDate
    )
    fakeAPIService.sendRequestResult = .success(apiResponse)

    let response = try await appAttestAPIService.attestKey(
      withAttestation: attestation,
      keyID: keyID,
      challenge: challenge,
      limitedUse: false
    )

    let expectedExpiration = requestDate.addingTimeInterval(1800)
    XCTAssertEqual(response.token.expirationDate, expectedExpiration)
  }

  // MARK: - Malformed server responses

  // Backfilled from the v11 Objective-C suite (`GACAppAttestAPIServiceTests.m`),
  // which covered these paths but had no Swift equivalent. These are all
  // "server returned 200 but the body is wrong" cases — the ones most likely to
  // regress silently, since the happy path and the HTTP-error path both still
  // pass without them.

  func testGetRandomChallengeWhenAPIResponseEmpty() async {
    // 1. Prepare an empty 200 response.
    let emptyAPIResponse = APIResponse(code: 200, responseBody: Data())

    // 2. Stub API Service Request.
    fakeAPIService.sendRequestResult = .success(emptyAPIResponse)

    // 3. Request the random challenge and verify results.
    do {
      _ = try await appAttestAPIService.getRandomChallenge()
      XCTFail("Expected error to be thrown")
    } catch let error as NSError {
      let failureReason = error.userInfo[NSLocalizedFailureReasonErrorKey] as? String
      XCTAssertEqual(failureReason, "Empty server response body.")
    }

    let expectedRequestURL = "\(fakeAPIService.baseURL)/\(kResourceName):generateAppAttestChallenge"
    XCTAssertEqual(fakeAPIService.passedRequestURL?.absoluteString, expectedRequestURL)
    XCTAssertEqual(fakeAPIService.passedHTTPMethod, "POST")
  }

  func testGetRandomChallengeWhenAPIResponseInvalidFormat() async {
    // 1. Prepare a 200 response whose body is not JSON.
    let responseBodyString = "Generate challenge failed with invalid format."
    let responseBody = responseBodyString.data(using: .utf8)!
    let invalidAPIResponse = APIResponse(code: 200, responseBody: responseBody)

    // 2. Stub API Service Request.
    fakeAPIService.sendRequestResult = .success(invalidAPIResponse)

    // 3. Request the random challenge and verify results.
    do {
      _ = try await appAttestAPIService.getRandomChallenge()
      XCTFail("Expected error to be thrown")
    } catch let error as NSError {
      let failureReason = error.userInfo[NSLocalizedFailureReasonErrorKey] as? String
      XCTAssertEqual(failureReason, "JSON serialization error.")
    }

    let expectedRequestURL = "\(fakeAPIService.baseURL)/\(kResourceName):generateAppAttestChallenge"
    XCTAssertEqual(fakeAPIService.passedRequestURL?.absoluteString, expectedRequestURL)
    XCTAssertEqual(fakeAPIService.passedHTTPMethod, "POST")
  }

  func testGetRandomChallengeWhenResponseMissingField() async throws {
    // 1. Prepare a well-formed JSON 200 response that omits `challenge`.
    let missingFieldBody = try AppCheckCoreFixtureLoader
      .loadFixture(named: "AppAttestResponseMissingChallenge.json")
    let incompleteAPIResponse = APIResponse(code: 200, responseBody: missingFieldBody)

    // 2. Stub API Service Request.
    fakeAPIService.sendRequestResult = .success(incompleteAPIResponse)

    // 3. Request the random challenge and verify results.
    do {
      _ = try await appAttestAPIService.getRandomChallenge()
      XCTFail("Expected error to be thrown")
    } catch let error as NSError {
      XCTAssertEqual(error.domain, AppCheckCoreErrorDomain)
      XCTAssertEqual(error.code, AppCheckCoreErrorCode.unknown.rawValue)

      // The missing field name must be named in the error, otherwise the error
      // is not actionable.
      let failureReason = error.userInfo[NSLocalizedFailureReasonErrorKey] as? String
      XCTAssertTrue(
        failureReason?.contains("`challenge`") ?? false,
        "Expected the missing field `challenge` to be named in the failure "
          + "reason, got: \(failureReason ?? "nil")"
      )
    }
  }

  func testGetAppCheckTokenNetworkError() async {
    let artifact = generateRandomData()
    let challenge = generateRandomData()
    let assertion = generateRandomData()

    // 1. Stub the API service to fail with a network error.
    let networkError = NSError(domain: "AppCheckCoreAppAttestAPIServiceTests",
                               code: 0, userInfo: nil)
    fakeAPIService.sendRequestResult = .failure(networkError)

    // 2. Send request and verify the error propagates unchanged — v11 did not
    //    wrap or translate transport errors here.
    do {
      _ = try await appAttestAPIService.getAppCheckToken(
        withArtifact: artifact,
        challenge: challenge,
        assertion: assertion,
        limitedUse: false
      )
      XCTFail("Expected error to be thrown")
    } catch let error as NSError {
      XCTAssertEqual(error.domain, networkError.domain)
      XCTAssertEqual(error.code, networkError.code)
    }

    let expectedRequestURL =
      "\(fakeAPIService.baseURL)/\(kResourceName):exchangeAppAttestAssertion"
    XCTAssertEqual(fakeAPIService.passedRequestURL?.absoluteString, expectedRequestURL)
    XCTAssertEqual(fakeAPIService.passedHTTPMethod, "POST")
    XCTAssertEqual(fakeAPIService.passedAdditionalHeaders?["Content-Type"], "application/json")
  }

  func testGetAppCheckTokenUnexpectedResponse() async throws {
    let artifact = generateRandomData()
    let challenge = generateRandomData()
    let assertion = generateRandomData()

    // 1. Return a 200 whose body cannot be parsed into a token.
    let responseBody = "Unexpected response.".data(using: .utf8)!
    let unexpectedAPIResponse = APIResponse(code: 200, responseBody: responseBody)
    fakeAPIService.sendRequestResult = .success(unexpectedAPIResponse)
    fakeAPIService.appCheckTokenResult = .failure(
      NSError(domain: AppCheckCoreErrorDomain,
              code: AppCheckCoreErrorCode.unknown.rawValue,
              userInfo: [NSLocalizedFailureReasonErrorKey: "JSON serialization error."])
    )

    // 2. Send request and verify an error surfaces.
    do {
      _ = try await appAttestAPIService.getAppCheckToken(
        withArtifact: artifact,
        challenge: challenge,
        assertion: assertion,
        limitedUse: false
      )
      XCTFail("Expected error to be thrown")
    } catch {
      // Expected.
    }

    let expectedRequestURL =
      "\(fakeAPIService.baseURL)/\(kResourceName):exchangeAppAttestAssertion"
    XCTAssertEqual(fakeAPIService.passedRequestURL?.absoluteString, expectedRequestURL)
    XCTAssertEqual(fakeAPIService.passedHTTPMethod, "POST")
    XCTAssertEqual(fakeAPIService.passedAdditionalHeaders?["Content-Type"], "application/json")
  }

  func testAttestKeyNetworkError() async {
    let attestation = generateRandomData()
    let challenge = generateRandomData()
    let keyID = "test_key_id"

    // 1. Stub the API service to fail with a network error.
    let networkError = NSError(domain: "AppCheckCoreAppAttestAPIServiceTests",
                               code: 0, userInfo: nil)
    fakeAPIService.sendRequestResult = .failure(networkError)

    // 2. Send request and verify the error propagates unchanged.
    do {
      _ = try await appAttestAPIService.attestKey(
        withAttestation: attestation,
        keyID: keyID,
        challenge: challenge,
        limitedUse: false
      )
      XCTFail("Expected error to be thrown")
    } catch let error as NSError {
      XCTAssertEqual(error.domain, networkError.domain)
      XCTAssertEqual(error.code, networkError.code)
    }

    let expectedRequestURL =
      "\(fakeAPIService.baseURL)/\(kResourceName):exchangeAppAttestAttestation"
    XCTAssertEqual(fakeAPIService.passedRequestURL?.absoluteString, expectedRequestURL)
    XCTAssertEqual(fakeAPIService.passedHTTPMethod, "POST")
    XCTAssertEqual(fakeAPIService.passedAdditionalHeaders?["Content-Type"], "application/json")
  }

  func testAttestKeyUnexpectedResponse() async {
    let attestation = generateRandomData()
    let challenge = generateRandomData()
    let keyID = "test_key_id"

    // 1. Return a 200 whose body is not the expected attestation response.
    let responseBody = "Unexpected response.".data(using: .utf8)!
    let unexpectedAPIResponse = APIResponse(code: 200, responseBody: responseBody)
    fakeAPIService.sendRequestResult = .success(unexpectedAPIResponse)

    // 2. Send request and verify an error surfaces rather than a malformed
    //    artifact being accepted.
    do {
      _ = try await appAttestAPIService.attestKey(
        withAttestation: attestation,
        keyID: keyID,
        challenge: challenge,
        limitedUse: false
      )
      XCTFail("Expected error to be thrown")
    } catch {
      // Expected.
    }

    let expectedRequestURL =
      "\(fakeAPIService.baseURL)/\(kResourceName):exchangeAppAttestAttestation"
    XCTAssertEqual(fakeAPIService.passedRequestURL?.absoluteString, expectedRequestURL)
    XCTAssertEqual(fakeAPIService.passedHTTPMethod, "POST")
    XCTAssertEqual(fakeAPIService.passedAdditionalHeaders?["Content-Type"], "application/json")
  }

  // MARK: - Helpers

  private func APIResponse(code: Int, responseBody: Data) -> AppCheckCoreURLSessionDataResponse {
    let httpResponse = HTTPURLResponse(
      url: URL(string: "https://test.com")!,
      statusCode: code,
      httpVersion: nil,
      headerFields: nil
    )!
    return AppCheckCoreURLSessionDataResponse(response: httpResponse, httpBody: responseBody)
  }

  private func generateRandomData() -> Data {
    return UUID().uuidString.data(using: .utf8)!
  }

  private func assertTokenExchangeBody(_ requestBody: Data?, artifact: Data, challenge: Data,
                                       assertion: Data, limitedUse: Bool) throws {
    let unwrappedBody = try XCTUnwrap(requestBody)
    let decodedData = try JSONSerialization
      .jsonObject(with: unwrappedBody, options: []) as? [String: Any]
    let unwrappedDecodedData = try XCTUnwrap(decodedData)

    let base64EncodedArtifact = try XCTUnwrap(unwrappedDecodedData["artifact"] as? String)
    let decodedArtifact = try XCTUnwrap(Data(base64Encoded: base64EncodedArtifact))
    XCTAssertEqual(decodedArtifact, artifact)

    let base64EncodedChallenge = try XCTUnwrap(unwrappedDecodedData["challenge"] as? String)
    let decodedChallenge = try XCTUnwrap(Data(base64Encoded: base64EncodedChallenge))
    XCTAssertEqual(decodedChallenge, challenge)

    let base64EncodedAssertion = try XCTUnwrap(unwrappedDecodedData["assertion"] as? String)
    let decodedAssertion = try XCTUnwrap(Data(base64Encoded: base64EncodedAssertion))
    XCTAssertEqual(decodedAssertion, assertion)

    let decodedLimitedUse = try XCTUnwrap(unwrappedDecodedData["limited_use"] as? Bool)
    XCTAssertEqual(decodedLimitedUse, limitedUse)
  }

  private func assertAttestKeyBody(_ requestBody: Data?, attestation: Data, challenge: Data,
                                   keyID: String, limitedUse: Bool) throws {
    let unwrappedBody = try XCTUnwrap(requestBody)
    let decodedData = try JSONSerialization
      .jsonObject(with: unwrappedBody, options: []) as? [String: Any]
    let unwrappedDecodedData = try XCTUnwrap(decodedData)

    let base64EncodedAttestation =
      try XCTUnwrap(unwrappedDecodedData["attestation_statement"] as? String)
    let decodedAttestation = try XCTUnwrap(Data(base64Encoded: base64EncodedAttestation))
    XCTAssertEqual(decodedAttestation, attestation)

    let base64EncodedChallenge = try XCTUnwrap(unwrappedDecodedData["challenge"] as? String)
    let decodedChallenge = try XCTUnwrap(Data(base64Encoded: base64EncodedChallenge))
    XCTAssertEqual(decodedChallenge, challenge)

    let decodedKeyID = try XCTUnwrap(unwrappedDecodedData["key_id"] as? String)
    XCTAssertEqual(decodedKeyID, keyID)

    let decodedLimitedUse = try XCTUnwrap(unwrappedDecodedData["limited_use"] as? Bool)
    XCTAssertEqual(decodedLimitedUse, limitedUse)
  }
}
