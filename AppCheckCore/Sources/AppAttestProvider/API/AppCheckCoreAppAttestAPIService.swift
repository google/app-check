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

import FBLPromises
import Foundation
import Promises

@objc(GACAppAttestAPIServiceProtocol)
public protocol AppCheckCoreAppAttestAPIServiceProtocol: NSObjectProtocol, Sendable {
  @objc(getRandomChallenge)
  func getRandomChallengeObjC() -> FBLPromise<NSData>

  @objc(attestKeyWithAttestation:keyID:challenge:limitedUse:)
  func attestKeyObjC(withAttestation attestation: Data,
                     keyID: String,
                     challenge: Data,
                     limitedUse: Bool) -> FBLPromise<AppCheckCoreAppAttestAttestationResponse>

  @objc(getAppCheckTokenWithArtifact:challenge:assertion:limitedUse:)
  func getAppCheckTokenObjC(withArtifact artifact: Data,
                            challenge: Data,
                            assertion: Data,
                            limitedUse: Bool) -> FBLPromise<AppCheckCoreToken>
}

public extension AppCheckCoreAppAttestAPIServiceProtocol {
  func getRandomChallenge() async throws -> Data {
    let promise = getRandomChallengeObjC()
    return try await withCheckedThrowingContinuation { continuation in
      promise.__onQueue(.promises, then: { nsData in
        if let data = nsData as? Data {
          continuation.resume(returning: data)
        } else {
          continuation
            .resume(throwing: AppCheckCoreErrorUtil
              .error(withFailureReason: "Invalid data type returned from promise."))
        }
        return nil
      }).__onQueue(.promises, catch: { error in
        continuation.resume(throwing: error)
      })
    }
  }

  func attestKey(withAttestation attestation: Data,
                 keyID: String,
                 challenge: Data,
                 limitedUse: Bool) async throws -> AppCheckCoreAppAttestAttestationResponse {
    let promise = attestKeyObjC(
      withAttestation: attestation,
      keyID: keyID,
      challenge: challenge,
      limitedUse: limitedUse
    )
    return try await withCheckedThrowingContinuation { continuation in
      promise.__onQueue(.promises, then: { response in
        if let response = response as? AppCheckCoreAppAttestAttestationResponse {
          continuation.resume(returning: response)
        } else {
          continuation
            .resume(throwing: AppCheckCoreErrorUtil
              .error(withFailureReason: "Invalid response type returned from promise."))
        }
        return nil
      }).__onQueue(.promises, catch: { error in
        continuation.resume(throwing: error)
      })
    }
  }

  func getAppCheckToken(withArtifact artifact: Data,
                        challenge: Data,
                        assertion: Data,
                        limitedUse: Bool) async throws -> AppCheckCoreToken {
    let promise = getAppCheckTokenObjC(
      withArtifact: artifact,
      challenge: challenge,
      assertion: assertion,
      limitedUse: limitedUse
    )
    return try await withCheckedThrowingContinuation { continuation in
      promise.__onQueue(.promises, then: { token in
        if let token = token as? AppCheckCoreToken {
          continuation.resume(returning: token)
        } else {
          continuation
            .resume(throwing: AppCheckCoreErrorUtil
              .error(withFailureReason: "Invalid token type returned from promise."))
        }
        return nil
      }).__onQueue(.promises, catch: { error in
        continuation.resume(throwing: error)
      })
    }
  }
}

@objc(GACAppAttestAPIService)
public final class AppCheckCoreAppAttestAPIService: NSObject,
  AppCheckCoreAppAttestAPIServiceProtocol, @unchecked Sendable {
  private let apiService: AppCheckCoreAPIServiceProtocol
  private let resourceName: String

  @objc(initWithAPIService:resourceName:)
  public init(apiService: AppCheckCoreAPIServiceProtocol, resourceName: String) {
    self.apiService = apiService
    self.resourceName = resourceName
    super.init()
  }

  // MARK: - AppCheckCoreAppAttestAPIServiceProtocol

  public func getRandomChallenge() async throws -> Data {
    let url = url(for: "generateAppAttestChallenge")
    let response = try await apiService.sendRequest(
      with: url,
      httpMethod: "POST",
      body: nil,
      additionalHeaders: nil
    )
    return try randomChallenge(fromResponseBody: response.httpBody)
  }

  public func attestKey(withAttestation attestation: Data,
                        keyID: String,
                        challenge: Data,
                        limitedUse: Bool) async throws -> AppCheckCoreAppAttestAttestationResponse {
    guard !attestation.isEmpty, !keyID.isEmpty, !challenge.isEmpty else {
      throw AppCheckCoreErrorUtil.error(withFailureReason: "Missing or empty request parameter.")
    }

    let url = url(for: "exchangeAppAttestAttestation")
    let bodyDict: [String: Any] = [
      "key_id": keyID,
      "attestation_statement": attestation.base64EncodedString(),
      "challenge": challenge.base64EncodedString(),
      "limited_use": limitedUse,
    ]

    let httpBody: Data
    do {
      httpBody = try JSONSerialization.data(withJSONObject: bodyDict, options: [])
    } catch {
      throw AppCheckCoreErrorUtil.JSONSerializationError(error)
    }

    let response = try await apiService.sendRequest(
      with: url,
      httpMethod: "POST",
      body: httpBody,
      additionalHeaders: ["Content-Type": "application/json"]
    )

    let attestationResponse = try AppCheckCoreAppAttestAttestationResponse(
      responseData: response.httpBody ?? Data(),
      requestDate: Date()
    )
    return attestationResponse
  }

  public func getAppCheckToken(withArtifact artifact: Data,
                               challenge: Data,
                               assertion: Data,
                               limitedUse: Bool) async throws -> AppCheckCoreToken {
    guard !artifact.isEmpty, !challenge.isEmpty, !assertion.isEmpty else {
      throw AppCheckCoreErrorUtil.error(withFailureReason: "Missing or empty request parameter.")
    }

    let url = url(for: "exchangeAppAttestAssertion")
    let bodyDict: [String: Any] = [
      "artifact": artifact.base64EncodedString(),
      "challenge": challenge.base64EncodedString(),
      "assertion": assertion.base64EncodedString(),
      "limited_use": limitedUse,
    ]

    let httpBody: Data
    do {
      httpBody = try JSONSerialization.data(withJSONObject: bodyDict, options: [])
    } catch {
      throw AppCheckCoreErrorUtil.JSONSerializationError(error)
    }

    let response = try await apiService.sendRequest(
      with: url,
      httpMethod: "POST",
      body: httpBody,
      additionalHeaders: ["Content-Type": "application/json"]
    )

    return try apiService.appCheckToken(withAPIResponse: response)
  }

  // MARK: - Objective-C Compatibility Bridge

  @objc(getRandomChallenge)
  public func getRandomChallengeObjC() -> FBLPromise<NSData> {
    let promise = FBLPromise<NSData>.__pending()
    Task {
      do {
        let challenge = try await self.getRandomChallenge()
        promise.__fulfill(challenge as NSData)
      } catch {
        promise.__reject(error as NSError)
      }
    }
    return promise
  }

  @objc(attestKeyWithAttestation:keyID:challenge:limitedUse:)
  public func attestKeyObjC(withAttestation attestation: Data,
                            keyID: String,
                            challenge: Data,
                            limitedUse: Bool)
    -> FBLPromise<AppCheckCoreAppAttestAttestationResponse> {
    let promise = FBLPromise<AppCheckCoreAppAttestAttestationResponse>.__pending()
    Task {
      do {
        let response = try await self.attestKey(
          withAttestation: attestation,
          keyID: keyID,
          challenge: challenge,
          limitedUse: limitedUse
        )
        promise.__fulfill(response)
      } catch {
        promise.__reject(error as NSError)
      }
    }
    return promise
  }

  @objc(getAppCheckTokenWithArtifact:challenge:assertion:limitedUse:)
  public func getAppCheckTokenObjC(withArtifact artifact: Data,
                                   challenge: Data,
                                   assertion: Data,
                                   limitedUse: Bool) -> FBLPromise<AppCheckCoreToken> {
    let promise = FBLPromise<AppCheckCoreToken>.__pending()
    Task {
      do {
        let token = try await self.getAppCheckToken(
          withArtifact: artifact,
          challenge: challenge,
          assertion: assertion,
          limitedUse: limitedUse
        )
        promise.__fulfill(token)
      } catch {
        promise.__reject(error as NSError)
      }
    }
    return promise
  }

  // MARK: - Helpers

  private func url(for endpoint: String) -> URL {
    let urlString = "\(apiService.baseURL)/\(resourceName):\(endpoint)"
    return URL(string: urlString)!
  }

  private func randomChallenge(fromResponseBody response: Data?) throws -> Data {
    guard let response = response, !response.isEmpty else {
      throw AppCheckCoreErrorUtil.error(withFailureReason: "Empty server response body.")
    }

    let responseDict: [String: Any]
    do {
      responseDict = try JSONSerialization
        .jsonObject(with: response, options: []) as? [String: Any] ?? [:]
    } catch {
      throw AppCheckCoreErrorUtil.JSONSerializationError(error)
    }

    guard let challenge = responseDict["challenge"] as? String else {
      throw AppCheckCoreErrorUtil.appCheckTokenResponseError(withMissingField: "challenge")
    }

    guard let randomChallenge = Data(base64Encoded: challenge) else {
      throw AppCheckCoreErrorUtil.appCheckTokenResponseError(withMissingField: "challenge")
    }

    return randomChallenge
  }
}
