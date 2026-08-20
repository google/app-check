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

import XCTest
@testable import AppCheckCore

private class MockAppCheckAPIService: NSObject, AppCheckCoreAPIServiceProtocol {
    var baseURL: String = "https://test.appcheck.url.com/beta"
    
    var passedRequestURL: URL?
    var passedHTTPMethod: String?
    var passedBody: Data?
    var passedAdditionalHeaders: [String: String]?
    
    var sendRequestResult: Result<AppCheckCoreURLSessionDataResponse, Error>?
    var appCheckTokenResult: Result<AppCheckCoreToken, Error>?
    
    var passedAPIResponse: AppCheckCoreURLSessionDataResponse?
    
    func sendRequest(withURL requestURL: URL, httpMethod: String, body: Data?, additionalHeaders: [String : String]?) async throws -> AppCheckCoreURLSessionDataResponse {
        passedRequestURL = requestURL
        passedHTTPMethod = httpMethod
        passedBody = body
        passedAdditionalHeaders = additionalHeaders
        
        if let result = sendRequestResult {
            switch result {
            case .success(let response): return response
            case .failure(let error): throw error
            }
        }
        throw NSError(domain: "MockAppCheckAPIService", code: -1, userInfo: nil)
    }
    
    func appCheckToken(withAPIResponse response: AppCheckCoreURLSessionDataResponse) async throws -> AppCheckCoreToken {
        passedAPIResponse = response
        if let result = appCheckTokenResult {
            switch result {
            case .success(let token): return token
            case .failure(let error): throw error
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
        appAttestAPIService = AppCheckCoreAppAttestAPIService(apiService: fakeAPIService, resourceName: kResourceName)
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
            "challenge": challengeString.data(using: .utf8)!.base64EncodedString()
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
        let apiError = AppCheckCoreErrorUtil.apiError(with: invalidAPIResponse.httpResponse, data: invalidAPIResponse.httpBody)
        
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
        try assertTokenExchangeBody(fakeAPIService.passedBody, artifact: artifact, challenge: challenge, assertion: assertion, limitedUse: limitedUse)
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
                "ttl": "1800s"
            ]
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
        
        let expectedRequestURL = "\(fakeAPIService.baseURL)/\(kResourceName):exchangeAppAttestAttestation"
        XCTAssertEqual(fakeAPIService.passedRequestURL?.absoluteString, expectedRequestURL)
        XCTAssertEqual(fakeAPIService.passedHTTPMethod, "POST")
        try assertAttestKeyBody(fakeAPIService.passedBody, attestation: attestation, challenge: challenge, keyID: keyID, limitedUse: limitedUse)
    }
    
    // MARK: - Helpers
    
    private func APIResponse(code: Int, responseBody: Data) -> AppCheckCoreURLSessionDataResponse {
        let httpResponse = HTTPURLResponse(url: URL(string: "https://test.com")!, statusCode: code, httpVersion: nil, headerFields: nil)!
        return AppCheckCoreURLSessionDataResponse(response: httpResponse, httpBody: responseBody)
    }
    
    private func generateRandomData() -> Data {
        return UUID().uuidString.data(using: .utf8)!
    }
    
    private func assertTokenExchangeBody(_ requestBody: Data?, artifact: Data, challenge: Data, assertion: Data, limitedUse: Bool) throws {
        let unwrappedBody = try XCTUnwrap(requestBody)
        let decodedData = try JSONSerialization.jsonObject(with: unwrappedBody, options: []) as? [String: Any]
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
    
    private func assertAttestKeyBody(_ requestBody: Data?, attestation: Data, challenge: Data, keyID: String, limitedUse: Bool) throws {
        let unwrappedBody = try XCTUnwrap(requestBody)
        let decodedData = try JSONSerialization.jsonObject(with: unwrappedBody, options: []) as? [String: Any]
        let unwrappedDecodedData = try XCTUnwrap(decodedData)
        
        let base64EncodedAttestation = try XCTUnwrap(unwrappedDecodedData["attestation_statement"] as? String)
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
