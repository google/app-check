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
  func getRandomChallenge() -> Promise<Data> {
    let promise = getRandomChallengeObjC()
    return Promise<NSData>(promise).then { nsData -> Data in
      return nsData as Data
    }
  }

  func attestKey(withAttestation attestation: Data,
                 keyID: String,
                 challenge: Data,
                 limitedUse: Bool) -> Promise<AppCheckCoreAppAttestAttestationResponse> {
    let promise = attestKeyObjC(
      withAttestation: attestation,
      keyID: keyID,
      challenge: challenge,
      limitedUse: limitedUse
    )
    return Promise<AppCheckCoreAppAttestAttestationResponse>(promise)
  }

  func getAppCheckToken(withArtifact artifact: Data,
                        challenge: Data,
                        assertion: Data,
                        limitedUse: Bool) -> Promise<AppCheckCoreToken> {
    let promise = getAppCheckTokenObjC(
      withArtifact: artifact,
      challenge: challenge,
      assertion: assertion,
      limitedUse: limitedUse
    )
    return Promise<AppCheckCoreToken>(promise)
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

  public func getRandomChallenge() -> Promise<Data> {
    let url = url(for: "generateAppAttestChallenge")
    let promise = Promise<Data>.pending()
    DispatchQueue.global().async {
      self.apiService.sendRequest(with: url, httpMethod: "POST", body: nil, additionalHeaders: nil)
        .then { response in
          do {
            let challenge = try self.randomChallenge(fromResponseBody: response.httpBody)
            promise.fulfill(challenge)
          } catch {
            promise.reject(error)
          }
        }.catch { error in
          promise.reject(error)
        }
    }
    return promise
  }

  public func attestKey(withAttestation attestation: Data,
                        keyID: String,
                        challenge: Data,
                        limitedUse: Bool) -> Promise<AppCheckCoreAppAttestAttestationResponse> {
    guard !attestation.isEmpty, !keyID.isEmpty, !challenge.isEmpty else {
      return Promise(AppCheckCoreErrorUtil
        .error(withFailureReason: "Missing or empty request parameter."))
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
      return Promise(AppCheckCoreErrorUtil.JSONSerializationError(error))
    }

    let promise = Promise<AppCheckCoreAppAttestAttestationResponse>.pending()
    DispatchQueue.global().async {
      self.apiService.sendRequest(
        with: url,
        httpMethod: "POST",
        body: httpBody,
        additionalHeaders: ["Content-Type": "application/json"]
      ).then { response in
        do {
          let attestationResponse = try AppCheckCoreAppAttestAttestationResponse(
            responseData: response.httpBody ?? Data(),
            requestDate: Date()
          )
          promise.fulfill(attestationResponse)
        } catch {
          promise.reject(error)
        }
      }.catch { error in
        promise.reject(error)
      }
    }
    return promise
  }

  public func getAppCheckToken(withArtifact artifact: Data,
                               challenge: Data,
                               assertion: Data,
                               limitedUse: Bool) -> Promise<AppCheckCoreToken> {
    guard !artifact.isEmpty, !challenge.isEmpty, !assertion.isEmpty else {
      return Promise(AppCheckCoreErrorUtil
        .error(withFailureReason: "Missing or empty request parameter."))
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
      return Promise(AppCheckCoreErrorUtil.JSONSerializationError(error))
    }

    let promise = Promise<AppCheckCoreToken>.pending()
    DispatchQueue.global().async {
      self.apiService.sendRequest(
        with: url,
        httpMethod: "POST",
        body: httpBody,
        additionalHeaders: ["Content-Type": "application/json"]
      ).then { response in
        self.apiService.appCheckToken(withAPIResponse: response)
          .then { token in
            promise.fulfill(token)
          }.catch { error in
            promise.reject(error)
          }
      }.catch { error in
        promise.reject(error)
      }
    }
    return promise
  }

  // MARK: - Objective-C Compatibility Bridge

  @objc(getRandomChallenge)
  public func getRandomChallengeObjC() -> FBLPromise<NSData> {
    return getRandomChallenge().then { challenge -> NSData in
      return challenge as NSData
    }.asObjCPromise()
  }

  @objc(attestKeyWithAttestation:keyID:challenge:limitedUse:)
  public func attestKeyObjC(withAttestation attestation: Data,
                            keyID: String,
                            challenge: Data,
                            limitedUse: Bool)
    -> FBLPromise<AppCheckCoreAppAttestAttestationResponse> {
    return attestKey(
      withAttestation: attestation,
      keyID: keyID,
      challenge: challenge,
      limitedUse: limitedUse
    ).asObjCPromise()
  }

  @objc(getAppCheckTokenWithArtifact:challenge:assertion:limitedUse:)
  public func getAppCheckTokenObjC(withArtifact artifact: Data,
                                   challenge: Data,
                                   assertion: Data,
                                   limitedUse: Bool) -> FBLPromise<AppCheckCoreToken> {
    return getAppCheckToken(
      withArtifact: artifact,
      challenge: challenge,
      assertion: assertion,
      limitedUse: limitedUse
    ).asObjCPromise()
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
