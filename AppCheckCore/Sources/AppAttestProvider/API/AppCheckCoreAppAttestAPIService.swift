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

import Foundation

private let kGenerateAppAttestChallengeEndpoint = "generateAppAttestChallenge"
private let kExchangeAppAttestAttestationEndpoint = "exchangeAppAttestAttestation"
private let kExchangeAppAttestAssertionEndpoint = "exchangeAppAttestAssertion"

private let kRequestFieldArtifact = "artifact"
private let kRequestFieldAssertion = "assertion"
private let kRequestFieldChallenge = "challenge"
private let kRequestFieldKeyID = "keyId"
private let kRequestFieldAttestation = "attestation"
private let kRequestFieldLimitedUse = "limitedUse"
private let kContentTypeKey = "Content-Type"
private let kJSONContentType = "application/json"
private let kHTTPMethodPost = "POST"

@objc(GACAppAttestAPIServiceProtocol)
public protocol AppCheckCoreAppAttestAPIServiceProtocol: NSObjectProtocol {
  @objc func getRandomChallenge() async throws -> Data
  
  @objc
  func attestKey(withAttestation attestation: Data, keyID: String, challenge: Data, limitedUse: Bool) async throws -> AppCheckCoreAppAttestAttestationResponse
  
  @objc
  func getAppCheckToken(withArtifact artifact: Data, challenge: Data, assertion: Data, limitedUse: Bool) async throws -> AppCheckCoreToken
}

@objc(GACAppAttestAPIService)
public class AppCheckCoreAppAttestAPIService: NSObject, AppCheckCoreAppAttestAPIServiceProtocol {
  private let apiService: GACAppCheckAPIServiceProtocol
  private let resourceName: String

  @objc(initWithAPIService:resourceName:)
  public init(apiService: GACAppCheckAPIServiceProtocol, resourceName: String) {
    self.apiService = apiService
    self.resourceName = resourceName
    super.init()
  }

  // MARK: - API Calls

  @objc
  public func getRandomChallenge() async throws -> Data {
    let url = urlForEndpoint(kGenerateAppAttestChallengeEndpoint)
    let response = try await apiService.sendRequest(withURL: url, httpMethod: kHTTPMethodPost, body: nil, additionalHeaders: nil)
    return try randomChallengeWithAPIResponse(response)
  }

  @objc
  public func attestKey(withAttestation attestation: Data, keyID: String, challenge: Data, limitedUse: Bool) async throws -> AppCheckCoreAppAttestAttestationResponse {
    let url = urlForEndpoint(kExchangeAppAttestAttestationEndpoint)
    let body = try httpBody(withAttestation: attestation, keyID: keyID, challenge: challenge, limitedUse: limitedUse)
    
    let urlResponse = try await apiService.sendRequest(withURL: url, httpMethod: kHTTPMethodPost, body: body, additionalHeaders: [kContentTypeKey: kJSONContentType])
    
    guard let responseData = urlResponse.httpBody else {
      throw _GACAppCheckErrorUtil.error(withFailureReason: "Invalid or missing response data.")
    }
    let response = try AppCheckCoreAppAttestAttestationResponse(responseData: responseData, requestDate: Date())
    
    return response
  }

  @objc
  public func getAppCheckToken(withArtifact artifact: Data, challenge: Data, assertion: Data, limitedUse: Bool) async throws -> AppCheckCoreToken {
    let url = urlForEndpoint(kExchangeAppAttestAssertionEndpoint)
    let body = try httpBody(withArtifact: artifact, challenge: challenge, assertion: assertion, limitedUse: limitedUse)
    
    let urlResponse = try await apiService.sendRequest(withURL: url, httpMethod: kHTTPMethodPost, body: body, additionalHeaders: [kContentTypeKey: kJSONContentType])
    
    let token = try await apiService.appCheckToken(withAPIResponse: urlResponse)
    // We assume AppCheckCoreToken is identical to GACAppCheckToken or bridges correctly
    return token as! AppCheckCoreToken
  }

  // MARK: - Challenge parsing

  private func randomChallengeWithAPIResponse(_ response: GACURLSessionDataResponse) throws -> Data {
    guard let responseData = response.httpBody else {
      throw _GACAppCheckErrorUtil.error(withFailureReason: "Empty server response body.")
    }
    
    if responseData.isEmpty {
      throw _GACAppCheckErrorUtil.error(withFailureReason: "Empty server response body.")
    }

    guard let responseDict = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any] else {
      throw _GACAppCheckErrorUtil.jsonSerializationError(NSError(domain: NSCocoaErrorDomain, code: 0, userInfo: nil))
    }

    guard let challengeBase64 = responseDict["challenge"] as? String else {
      throw _GACAppCheckErrorUtil.appCheckTokenResponseError(withMissingField: "challenge")
    }

    guard let challenge = Data(base64Encoded: challengeBase64) else {
      throw _GACAppCheckErrorUtil.error(withFailureReason: "Invalid base64 string for challenge.")
    }

    return challenge
  }

  // MARK: - Body Builders

  private func httpBody(withAttestation attestation: Data, keyID: String, challenge: Data, limitedUse: Bool) throws -> Data {
    if attestation.isEmpty || keyID.isEmpty || challenge.isEmpty {
      throw _GACAppCheckErrorUtil.error(withFailureReason: "Missing or empty request parameter.")
    }

    let jsonObject: [String: Any] = [
      kRequestFieldKeyID: keyID,
      kRequestFieldAttestation: attestation.base64EncodedString(),
      kRequestFieldChallenge: challenge.base64EncodedString(),
      kRequestFieldLimitedUse: limitedUse
    ]

    return try httpBody(withJSONObject: jsonObject)
  }

  private func httpBody(withArtifact artifact: Data, challenge: Data, assertion: Data, limitedUse: Bool) throws -> Data {
    if artifact.isEmpty || challenge.isEmpty || assertion.isEmpty {
      throw _GACAppCheckErrorUtil.error(withFailureReason: "Missing or empty request parameter.")
    }

    let jsonObject: [String: Any] = [
      kRequestFieldArtifact: artifact.base64EncodedString(),
      kRequestFieldChallenge: challenge.base64EncodedString(),
      kRequestFieldAssertion: assertion.base64EncodedString(),
      kRequestFieldLimitedUse: limitedUse
    ]

    return try httpBody(withJSONObject: jsonObject)
  }

  private func httpBody(withJSONObject jsonObject: Any) throws -> Data {
    do {
      return try JSONSerialization.data(withJSONObject: jsonObject, options: [])
    } catch {
      throw _GACAppCheckErrorUtil.jsonSerializationError(error as NSError)
    }
  }

  // MARK: - URL Helpers

  private func urlForEndpoint(_ endpoint: String) -> URL {
    let urlString = "\(apiService.baseURL)/\(resourceName):\(endpoint)"
    return URL(string: urlString)!
  }
}
