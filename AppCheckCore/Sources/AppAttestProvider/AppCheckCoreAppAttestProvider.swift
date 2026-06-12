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
#if canImport(DeviceCheck)
  import DeviceCheck
#endif

@objc(GACAppAttestService)
public protocol AppCheckCoreAppAttestService: NSObjectProtocol {
  @objc var isSupported: Bool { get }
  @objc func generateKey(completionHandler: @escaping (String?, Error?) -> Void)
  @objc func attestKey(_ keyId: String, clientDataHash: Data,
                       completionHandler: @escaping (Data?, Error?) -> Void)
  @objc func generateAssertion(_ keyId: String, clientDataHash: Data,
                               completionHandler: @escaping (Data?, Error?) -> Void)
}

#if canImport(DeviceCheck)
  extension DCAppAttestService: AppCheckCoreAppAttestService {}
#endif

@objc(GACAppAttestProvider)
public final class AppCheckCoreAppAttestProvider: NSObject, AppCheckCoreProvider,
  @unchecked Sendable {
  private let apiService: AppCheckCoreAppAttestAPIServiceProtocol
  private let appAttestService: AppCheckCoreAppAttestService
  private let keyIDStorage: AppCheckCoreAppAttestKeyIDStorageProtocol
  private let artifactStorage: AppCheckCoreAppAttestArtifactStorageProtocol
  private let backoffWrapper: AppCheckCoreBackoffWrapperProtocol

  private var ongoingPromise: (id: UUID, promise: Promise<AppCheckCoreToken>, limitedUse: Bool)?
  private var lock = os_unfair_lock()

  @objc(initWithAppAttestService:APIService:keyIDStorage:artifactStorage:backoffWrapper:)
  public init(appAttestService: AppCheckCoreAppAttestService,
              apiService: AppCheckCoreAppAttestAPIServiceProtocol,
              keyIDStorage: AppCheckCoreAppAttestKeyIDStorageProtocol,
              artifactStorage: AppCheckCoreAppAttestArtifactStorageProtocol,
              backoffWrapper: AppCheckCoreBackoffWrapperProtocol) {
    self.appAttestService = appAttestService
    self.apiService = apiService
    self.keyIDStorage = keyIDStorage
    self.artifactStorage = artifactStorage
    self.backoffWrapper = backoffWrapper
    super.init()
  }

  @objc public convenience init(serviceName: String,
                                resourceName: String,
                                baseURL: String?,
                                apiKey: String?,
                                keychainAccessGroup: String?,
                                requestHooks: [Any]?) {
    let session = URLSession(configuration: .ephemeral)
    let storageKeySuffix = "\(serviceName).\(resourceName)"
    let keyIDStorage = AppCheckCoreAppAttestKeyIDStorage(keySuffix: storageKeySuffix)
    let coreAPIService = AppCheckCoreAPIService(
      urlSession: session,
      baseURL: baseURL,
      apiKey: apiKey,
      requestHooks: requestHooks
    )
    let appAttestAPIService = AppCheckCoreAppAttestAPIService(
      apiService: coreAPIService,
      resourceName: resourceName
    )
    let artifactStorage = AppCheckCoreAppAttestArtifactStorage(
      keySuffix: storageKeySuffix,
      accessGroup: keychainAccessGroup
    )
    let backoffWrapper = AppCheckCoreBackoffWrapper()

    #if canImport(DeviceCheck)
      let service = DCAppAttestService.shared
    #else
      let service = DummyAppAttestService()
    #endif

    self.init(
      appAttestService: service,
      apiService: appAttestAPIService,
      keyIDStorage: keyIDStorage,
      artifactStorage: artifactStorage,
      backoffWrapper: backoffWrapper
    )
  }

  // MARK: - AppCheckCoreProvider

  @objc public func getToken(completion handler: @escaping (AppCheckCoreToken?, Error?) -> Void) {
    getToken(limitedUse: false, completion: handler)
  }

  @objc public func getLimitedUseToken(completion handler: @escaping (AppCheckCoreToken?, Error?)
    -> Void) {
    getToken(limitedUse: true, completion: handler)
  }

  private func getToken(limitedUse: Bool,
                        completion handler: @escaping (AppCheckCoreToken?, Error?) -> Void) {
    getOrCreateOngoingTokenPromise(limitedUse: limitedUse)
      .then { token in
        handler(token, nil)
      }
      .catch { error in
        handler(nil, error)
      }
  }

  private func getOrCreateOngoingTokenPromise(limitedUse: Bool) -> Promise<AppCheckCoreToken> {
    os_unfair_lock_lock(&lock)

    if let ongoing = ongoingPromise {
      if limitedUse || ongoing.limitedUse != limitedUse {
        let ongoingPromiseRef = ongoing.promise
        os_unfair_lock_unlock(&lock)

        let recoveryPromise = Promise<AppCheckCoreToken>.pending()
        ongoingPromiseRef.always {
          self.getOrCreateOngoingTokenPromise(limitedUse: limitedUse).then { token in
            recoveryPromise.fulfill(token)
          }.catch { error in
            recoveryPromise.reject(error)
          }
        }
        return recoveryPromise
      }
      os_unfair_lock_unlock(&lock)
      return ongoing.promise
    }

    let promiseId = UUID()
    let promise = getTokenWithBackoff(limitedUse: limitedUse)

    promise.always {
      os_unfair_lock_lock(&self.lock)
      if self.ongoingPromise?.id == promiseId {
        self.ongoingPromise = nil
      }
      os_unfair_lock_unlock(&self.lock)
    }

    ongoingPromise = (promiseId, promise, limitedUse)
    os_unfair_lock_unlock(&lock)

    return promise
  }

  private func getTokenWithBackoff(limitedUse: Bool) -> Promise<AppCheckCoreToken> {
    let errorHandler: (Error) -> AppCheckCoreBackoffType = { error in
      let nsError = error as NSError
      let code = self.backoffWrapper.defaultAppCheckProviderErrorHandler()(nsError)
      return AppCheckCoreBackoffType(rawValue: code) ?? .none
    }

    if let wrapper = backoffWrapper as? AppCheckCoreBackoffWrapper {
      return wrapper.applyBackoff(
        to: {
          self.getTokenSequence(limitedUse: limitedUse)
        },
        errorHandler: errorHandler
      )
    } else {
      let fblPromise = backoffWrapper.applyBackoffToOperation(
        {
          let swiftPromise = self.getTokenSequence(limitedUse: limitedUse)
          return swiftPromise.asObjCPromise()
        },
        errorHandler: { err in
          self.backoffWrapper.defaultAppCheckProviderErrorHandler()(err)
        }
      )

      return Promise<AnyObject>(fblPromise).then { val in
        if let token = val as? AppCheckCoreToken {
          return Promise(token)
        } else {
          throw AppCheckCoreErrorUtil
            .error(withFailureReason: "Invalid token type returned from promise.")
        }
      }
    }
  }

  private func getTokenSequence(limitedUse: Bool) -> Promise<AppCheckCoreToken> {
    return getTokenSequenceHelper(attempts: 0, limitedUse: limitedUse)
  }

  private func getTokenSequenceHelper(attempts: Int,
                                      limitedUse: Bool) -> Promise<AppCheckCoreToken> {
    return attestationState().then { state -> Promise<AppCheckCoreToken> in
      switch state.state {
      case .unsupported:
        let logMessage = "App Attest is not supported."
        GACAppCheckLog(
          code: .loggerAppCheckMessageCodeAppAttestNotSupported,
          logLevel: .debug,
          message: logMessage as NSString
        )
        throw state.appAttestUnsupportedError ?? AppCheckCoreErrorUtil
          .unsupportedAttestationProvider("AppAttestProvider")

      case .supportedInitial, .keyGenerated:
        return self.initialHandshake(keyID: state.appAttestKeyID, limitedUse: limitedUse)

      case .keyRegistered:
        guard let keyID = state.appAttestKeyID, let artifact = state.attestationArtifact else {
          throw AppCheckCoreErrorUtil
            .error(withFailureReason: "Key registered but key ID or artifact is missing.")
        }
        return self.refreshToken(keyID: keyID, artifact: artifact, limitedUse: limitedUse)
      }
    }
    .recover { error -> Promise<AppCheckCoreToken> in
      if error is AppCheckCoreAppAttestRejectionError && attempts < 1 {
        return self.getTokenSequenceHelper(attempts: attempts + 1, limitedUse: limitedUse)
      }
      if let rejectionError = error as? AppCheckCoreAppAttestRejectionError {
        throw rejectionError.underlyingError
      }
      throw error
    }
  }

  // MARK: - Initial handshake sequence (attestation)

  private func initialHandshake(keyID: String?, limitedUse: Bool) -> Promise<AppCheckCoreToken> {
    return attestKeyGenerateIfNeeded(keyID: keyID, limitedUse: limitedUse)
      .then { attestationResult, response in
        let setArtifactPromise = self.artifactStorage.setArtifact(
          response.artifact,
          forKey: attestationResult.keyID
        )
        return setArtifactPromise.then { _ in
          Promise(response.token)
        }
      }
  }

  private struct KeyAttestationResult {
    let keyID: String
    let challenge: Data
    let attestation: Data
  }

  private func attestKeyGenerateIfNeeded(keyID: String?,
                                         limitedUse: Bool) -> Promise<(
    KeyAttestationResult,
    AppCheckCoreAppAttestAttestationResponse
  )> {
    return apiService.getRandomChallenge().then { challenge -> Promise<(
      KeyAttestationResult,
      AppCheckCoreAppAttestAttestationResponse
    )> in
      return self.generateAppAttestKeyIDIfNeeded(keyID).then { resolvedKeyID -> Promise<(
        KeyAttestationResult,
        AppCheckCoreAppAttestAttestationResponse
      )> in
        return self.attestKey(resolvedKeyID, challenge: challenge).then { attestation -> Promise<(
          KeyAttestationResult,
          AppCheckCoreAppAttestAttestationResponse
        )> in
          let attestationResult = KeyAttestationResult(
            keyID: resolvedKeyID,
            challenge: challenge,
            attestation: attestation
          )

          return self.apiService.attestKey(
            withAttestation: attestationResult.attestation,
            keyID: attestationResult.keyID,
            challenge: attestationResult.challenge,
            limitedUse: limitedUse
          ).then { response in
            Promise((attestationResult, response))
          }
        }
      }
    }
    .recover { error -> Promise<(KeyAttestationResult, AppCheckCoreAppAttestAttestationResponse)> in
      let nsError = error as NSError
      let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
      let isAppleInvalidKeyError = underlying != nil &&
        (underlying?.domain == "com.apple.devicecheck.error" || underlying?
          .domain == "DCErrorDomain") &&
        (underlying?.code == 3 || underlying?.code == 2)

      let isBackendForbiddenError = (error as? GACAppCheckHTTPError)?.httpResponse.statusCode == 403

      if isAppleInvalidKeyError || isBackendForbiddenError {
        let message = isAppleInvalidKeyError
          ?
          "App Attest invalid key/input; the existing attestation will be reset. DC Error Code: \(underlying?.code ?? 0)."
          :
          "App Attest attestation was rejected by backend. The existing attestation will be reset."
        GACAppCheckLog(
          code: .loggerAppCheckMessageCodeAttestationRejected,
          logLevel: .debug,
          message: message as NSString
        )

        return self.resetAttestation().then { _ -> Promise<(
          KeyAttestationResult,
          AppCheckCoreAppAttestAttestationResponse
        )> in
          throw AppCheckCoreAppAttestRejectionError(underlyingError: nsError)
        }
      }
      throw error
    }
  }

  private func attestKey(_ keyID: String, challenge: Data) -> Promise<Data> {
    let challengeHash = AppCheckCoreCryptoUtils.sha256Hash(from: challenge)
    return Promise<Data> { fulfill, reject in
      self.appAttestService.attestKey(keyID, clientDataHash: challengeHash) { attestation, error in
        if let error = error {
          let wrapped = AppCheckCoreErrorUtil.appAttestAttestKeyFailed(
            withError: error,
            keyId: keyID,
            clientDataHash: challengeHash
          )
          reject(wrapped)
        } else if let attestation = attestation {
          fulfill(attestation)
        } else {
          reject(AppCheckCoreErrorUtil
            .error(withFailureReason: "Attest key returned nil attestation and nil error."))
        }
      }
    }
  }

  private func resetAttestation() -> Promise<Void> {
    return keyIDStorage.setAppAttestKeyID(nil).then { _ in
      self.artifactStorage.setArtifact(nil, forKey: "").then { _ in
        Promise(())
      }
    }
  }

  // MARK: - Token refresh sequence (assertion)

  private func refreshToken(keyID: String, artifact: Data,
                            limitedUse: Bool) -> Promise<AppCheckCoreToken> {
    return apiService.getRandomChallenge().then { challenge -> Promise<AppCheckCoreToken> in
      return self.generateAssertion(keyID: keyID, artifact: artifact, challenge: challenge)
        .then { assertion -> Promise<AppCheckCoreToken> in
          return self.apiService.getAppCheckToken(
            withArtifact: artifact,
            challenge: challenge,
            assertion: assertion,
            limitedUse: limitedUse
          )
        }
    }
    .recover { error -> Promise<AppCheckCoreToken> in
      let nsError = error as NSError
      let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
      let isAppleInvalidKeyError = underlying != nil &&
        (underlying?.domain == "com.apple.devicecheck.error" || underlying?
          .domain == "DCErrorDomain") &&
        (underlying?.code == 3 || underlying?.code == 2)

      let isBackendForbiddenError = (error as? GACAppCheckHTTPError)?.httpResponse.statusCode == 403

      if isAppleInvalidKeyError || isBackendForbiddenError {
        let message = isAppleInvalidKeyError
          ?
          "App Attest assertion invalid key/input; the existing attestation will be reset. DC Error Code: \(underlying?.code ?? 0)."
          : "App Attest assertion was rejected by backend. The existing attestation will be reset."
        GACAppCheckLog(
          code: .loggerAppCheckMessageCodeAttestationRejected,
          logLevel: .debug,
          message: message as NSString
        )

        return self.resetAttestation().then { _ -> Promise<AppCheckCoreToken> in
          throw AppCheckCoreAppAttestRejectionError(underlyingError: nsError)
        }
      }
      throw error
    }
  }

  private func generateAssertion(keyID: String, artifact: Data, challenge: Data) -> Promise<Data> {
    var statementForAssertion = artifact
    statementForAssertion.append(challenge)
    let statementHash = AppCheckCoreCryptoUtils.sha256Hash(from: statementForAssertion)

    return Promise<Data> { fulfill, reject in
      self.appAttestService
        .generateAssertion(keyID, clientDataHash: statementHash) { assertion, error in
          if let error = error {
            let wrapped = AppCheckCoreErrorUtil.appAttestGenerateAssertionFailed(
              withError: error,
              keyId: keyID,
              clientDataHash: statementHash
            )
            reject(wrapped)
          } else if let assertion = assertion {
            fulfill(assertion)
          } else {
            reject(AppCheckCoreErrorUtil
              .error(withFailureReason: "Generate assertion returned nil assertion and nil error."))
          }
        }
    }
  }

  // MARK: - State handling

  private func attestationState() -> Promise<AppCheckCoreAppAttestProviderState> {
    return isAppAttestSupported().then { _ -> Promise<AppCheckCoreAppAttestProviderState> in
      let keyPromise = self.keyIDStorage.getAppAttestKeyID()
      return keyPromise.then { keyIDStr -> Promise<AppCheckCoreAppAttestProviderState> in
        guard !keyIDStr.isEmpty else {
          return Promise(AppCheckCoreAppAttestProviderState(supportedInitialState: ()))
        }

        let artifactPromise = self.artifactStorage.getArtifact(forKey: keyIDStr)
        return artifactPromise.then { artifactOpt -> Promise<AppCheckCoreAppAttestProviderState> in
          if let artifactData = artifactOpt {
            return Promise(AppCheckCoreAppAttestProviderState(
              registeredKeyID: keyIDStr,
              artifact: artifactData
            ))
          } else {
            return Promise(AppCheckCoreAppAttestProviderState(generatedKeyID: keyIDStr))
          }
        }.recover { _ in
          Promise(AppCheckCoreAppAttestProviderState(generatedKeyID: keyIDStr))
        }
      }.recover { _ in
        Promise(AppCheckCoreAppAttestProviderState(supportedInitialState: ()))
      }
    }.recover { error in
      Promise(AppCheckCoreAppAttestProviderState(unsupportedWithError: error))
    }
  }

  private func isAppAttestSupported() -> Promise<Void> {
    if appAttestService.isSupported {
      return Promise(())
    } else {
      let error = AppCheckCoreErrorUtil.unsupportedAttestationProvider("AppAttestProvider")
      return Promise(error)
    }
  }

  private func generateAppAttestKeyIDIfNeeded(_ storedKeyID: String?) -> Promise<String> {
    if let stored = storedKeyID {
      return Promise(stored)
    }
    return generateAppAttestKey()
  }

  private func generateAppAttestKey() -> Promise<String> {
    let keyIDPromise = Promise<String> { fulfill, reject in
      self.appAttestService.generateKey { keyID, error in
        if let error = error {
          reject(AppCheckCoreErrorUtil.appAttestGenerateKeyFailed(withError: error))
        } else if let keyID = keyID {
          fulfill(keyID)
        } else {
          reject(AppCheckCoreErrorUtil
            .error(withFailureReason: "Generate key returned nil key ID and nil error."))
        }
      }
    }

    return keyIDPromise.then { keyID -> Promise<String> in
      let setKeyPromise = self.keyIDStorage.setAppAttestKeyID(keyID)
      return setKeyPromise.then { _ in
        Promise(keyID)
      }
    }
  }
}

#if !canImport(DeviceCheck)
  private final class DummyAppAttestService: NSObject, AppCheckCoreAppAttestService {
    var isSupported: Bool { return false }
    func generateKey(completionHandler: @escaping (String?, Error?) -> Void) {
      completionHandler(
        nil,
        AppCheckCoreErrorUtil.unsupportedAttestationProvider("AppAttestProvider")
      )
    }

    func attestKey(_ keyId: String, clientDataHash: Data,
                   completionHandler: @escaping (Data?, Error?) -> Void) {
      completionHandler(
        nil,
        AppCheckCoreErrorUtil.unsupportedAttestationProvider("AppAttestProvider")
      )
    }

    func generateAssertion(_ keyId: String, clientDataHash: Data,
                           completionHandler: @escaping (Data?, Error?) -> Void) {
      completionHandler(
        nil,
        AppCheckCoreErrorUtil.unsupportedAttestationProvider("AppAttestProvider")
      )
    }
  }
#endif
