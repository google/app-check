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

  private var ongoingTask: (id: UUID, task: Task<AppCheckCoreToken, Error>, limitedUse: Bool)?
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

  @objc public func getToken(completion handler: @escaping (AppCheckCoreToken?, NSError?) -> Void) {
    getToken(limitedUse: false, completion: handler)
  }

  @objc public func getLimitedUseToken(completion handler: @escaping (AppCheckCoreToken?, NSError?)
    -> Void) {
    getToken(limitedUse: true, completion: handler)
  }

  private func getToken(limitedUse: Bool,
                        completion handler: @escaping (AppCheckCoreToken?, NSError?) -> Void) {
    Task {
      do {
        let token = try await getOrCreateOngoingTokenTask(limitedUse: limitedUse)
        handler(token, nil)
      } catch {
        handler(nil, error as NSError)
      }
    }
  }

  private func getOrCreateOngoingTokenTask(limitedUse: Bool) async throws -> AppCheckCoreToken {
    os_unfair_lock_lock(&lock)

    if let ongoing = ongoingTask {
      if limitedUse || ongoing.limitedUse != limitedUse {
        let ongoingTaskRef = ongoing.task
        os_unfair_lock_unlock(&lock)
        _ = try? await ongoingTaskRef.value
        return try await getOrCreateOngoingTokenTask(limitedUse: limitedUse)
      }
      os_unfair_lock_unlock(&lock)
      return try await ongoing.task.value
    }

    let taskId = UUID()
    let task = Task {
      defer {
        os_unfair_lock_lock(&lock)
        if self.ongoingTask?.id == taskId {
          self.ongoingTask = nil
        }
        os_unfair_lock_unlock(&lock)
      }
      return try await self.getTokenWithBackoff(limitedUse: limitedUse)
    }

    ongoingTask = (taskId, task, limitedUse)
    os_unfair_lock_unlock(&lock)

    return try await task.value
  }

  private func getTokenWithBackoff(limitedUse: Bool) async throws -> AppCheckCoreToken {
    if let wrapper = backoffWrapper as? AppCheckCoreBackoffWrapper {
      return try await wrapper.applyBackoff(
        to: {
          try await self.getTokenSequence(limitedUse: limitedUse)
        },
        errorHandler: { err in
          let code = wrapper.defaultAppCheckProviderErrorHandler()(err as NSError)
          return AppCheckCoreBackoffType(rawValue: code) ?? .none
        }
      )
    } else {
      let promise = backoffWrapper.applyBackoffToOperation(
        {
          let promise = FBLPromise<AnyObject>.__pending()
          Task {
            do {
              let token = try await self.getTokenSequence(limitedUse: limitedUse)
              promise.__fulfill(token)
            } catch {
              promise.__reject(error as NSError)
            }
          }
          return promise
        },
        errorHandler: { err in
          self.backoffWrapper.defaultAppCheckProviderErrorHandler()(err)
        }
      )

      return try await withCheckedThrowingContinuation { continuation in
        promise.__onQueue(.promises, then: { val in
          if let token = val as? AppCheckCoreToken {
            continuation.resume(returning: token)
          } else {
            continuation
              .resume(throwing: AppCheckCoreErrorUtil
                .error(withFailureReason: "Invalid token type returned from promise."))
          }
          return nil
        }).__onQueue(.promises, catch: { err in
          continuation.resume(throwing: err)
        })
      }
    }
  }

  private func getTokenSequence(limitedUse: Bool) async throws -> AppCheckCoreToken {
    var attempts = 0
    while true {
      attempts += 1
      do {
        let state = try await attestationState()
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
          return try await initialHandshake(keyID: state.appAttestKeyID, limitedUse: limitedUse)

        case .keyRegistered:
          guard let keyID = state.appAttestKeyID, let artifact = state.attestationArtifact else {
            throw AppCheckCoreErrorUtil
              .error(withFailureReason: "Key registered but key ID or artifact is missing.")
          }
          return try await refreshToken(keyID: keyID, artifact: artifact, limitedUse: limitedUse)
        }
      } catch {
        if let rejectionError = error as? AppCheckCoreAppAttestRejectionError {
          if attempts < 2 {
            continue
          } else {
            throw rejectionError.underlyingError
          }
        }
        throw error
      }
    }
  }

  // MARK: - Initial handshake sequence (attestation)

  private func initialHandshake(keyID: String?,
                                limitedUse: Bool) async throws -> AppCheckCoreToken {
    let (attestationResult, response) = try await attestKeyGenerateIfNeeded(
      keyID: keyID,
      limitedUse: limitedUse
    )
    _ = try await artifactStorage.setArtifact(response.artifact, forKey: attestationResult.keyID)
    return response.token
  }

  private struct KeyAttestationResult {
    let keyID: String
    let challenge: Data
    let attestation: Data
  }

  private func attestKeyGenerateIfNeeded(keyID: String?,
                                         limitedUse: Bool) async throws -> (
    KeyAttestationResult,
    AppCheckCoreAppAttestAttestationResponse
  ) {
    let challenge: Data
    let resolvedKeyID: String

    do {
      async let challengeTask = apiService.getRandomChallenge()
      async let keyIDTask = generateAppAttestKeyIDIfNeeded(keyID)
      challenge = try await challengeTask
      resolvedKeyID = try await keyIDTask
    } catch {
      throw error
    }

    do {
      let attestation = try await attestKey(resolvedKeyID, challenge: challenge)
      let attestationResult = KeyAttestationResult(
        keyID: resolvedKeyID,
        challenge: challenge,
        attestation: attestation
      )

      let response = try await apiService.attestKey(
        withAttestation: attestationResult.attestation,
        keyID: attestationResult.keyID,
        challenge: attestationResult.challenge,
        limitedUse: limitedUse
      )
      return (attestationResult, response)
    } catch {
      let nsError = error as NSError
      let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
      let isAppleInvalidKeyError = underlying != nil &&
        (underlying?.domain == "com.apple.devicecheck.error" || underlying?
          .domain == "DCErrorDomain") &&
        (underlying?.code == 2 || underlying?.code == 3)

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

        _ = try? await resetAttestation()
        throw AppCheckCoreAppAttestRejectionError(underlyingError: nsError)
      }
      throw error
    }
  }

  private func attestKey(_ keyID: String, challenge: Data) async throws -> Data {
    let challengeHash = AppCheckCoreCryptoUtils.sha256Hash(from: challenge)
    return try await withCheckedThrowingContinuation { continuation in
      appAttestService.attestKey(keyID, clientDataHash: challengeHash) { attestation, error in
        if let error = error {
          let wrapped = AppCheckCoreErrorUtil.appAttestAttestKeyFailed(
            withError: error,
            keyId: keyID,
            clientDataHash: challengeHash
          )
          continuation.resume(throwing: wrapped)
        } else if let attestation = attestation {
          continuation.resume(returning: attestation)
        } else {
          continuation
            .resume(throwing: AppCheckCoreErrorUtil
              .error(withFailureReason: "Attest key returned nil attestation and nil error."))
        }
      }
    }
  }

  private func resetAttestation() async throws {
    _ = try await keyIDStorage.setAppAttestKeyID(nil)
    _ = try await artifactStorage.setArtifact(nil, forKey: "")
  }

  // MARK: - Token refresh sequence (assertion)

  private func refreshToken(keyID: String, artifact: Data,
                            limitedUse: Bool) async throws -> AppCheckCoreToken {
    let challenge = try await apiService.getRandomChallenge()
    let assertion = try await generateAssertion(
      keyID: keyID,
      artifact: artifact,
      challenge: challenge
    )
    return try await apiService.getAppCheckToken(
      withArtifact: artifact,
      challenge: challenge,
      assertion: assertion,
      limitedUse: limitedUse
    )
  }

  private func generateAssertion(keyID: String, artifact: Data,
                                 challenge: Data) async throws -> Data {
    var statementForAssertion = artifact
    statementForAssertion.append(challenge)
    let statementHash = AppCheckCoreCryptoUtils.sha256Hash(from: statementForAssertion)

    do {
      return try await withCheckedThrowingContinuation { continuation in
        appAttestService
          .generateAssertion(keyID, clientDataHash: statementHash) { assertion, error in
            if let error = error {
              let wrapped = AppCheckCoreErrorUtil.appAttestGenerateAssertionFailed(
                withError: error,
                keyId: keyID,
                clientDataHash: statementHash
              )
              continuation.resume(throwing: wrapped)
            } else if let assertion = assertion {
              continuation.resume(returning: assertion)
            } else {
              continuation
                .resume(throwing: AppCheckCoreErrorUtil
                  .error(
                    withFailureReason: "Generate assertion returned nil assertion and nil error."
                  ))
            }
          }
      }
    } catch {
      let nsError = error as NSError
      let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
      let isAppleInvalidKeyError = underlying != nil &&
        (underlying?.domain == "com.apple.devicecheck.error" || underlying?
          .domain == "DCErrorDomain") &&
        (underlying?.code == 2 || underlying?.code == 3)

      if isAppleInvalidKeyError {
        let logMessage =
          "App Attest invalid key/input; the existing attestation will be reset. DC Error Code: \(underlying?.code ?? 0)."
        GACAppCheckLog(
          code: .loggerAppCheckMessageCodeAssertionRejected,
          logLevel: .debug,
          message: logMessage as NSString
        )

        _ = try? await resetAttestation()
        throw AppCheckCoreAppAttestRejectionError(underlyingError: nsError)
      }
      throw error
    }
  }

  // MARK: - State handling

  private func attestationState() async throws -> AppCheckCoreAppAttestProviderState {
    do {
      try await isAppAttestSupported()
    } catch {
      return AppCheckCoreAppAttestProviderState(unsupportedWithError: error)
    }

    let keyID: String
    do {
      keyID = try await keyIDStorage.getAppAttestKeyID()
    } catch {
      return AppCheckCoreAppAttestProviderState(supportedInitialState: ())
    }

    let artifact: Data
    do {
      if let data = try await artifactStorage.getArtifact(forKey: keyID) {
        artifact = data
      } else {
        return AppCheckCoreAppAttestProviderState(generatedKeyID: keyID)
      }
    } catch {
      return AppCheckCoreAppAttestProviderState(generatedKeyID: keyID)
    }

    return AppCheckCoreAppAttestProviderState(registeredKeyID: keyID, artifact: artifact)
  }

  private func isAppAttestSupported() async throws {
    if appAttestService.isSupported {
      return
    } else {
      throw AppCheckCoreErrorUtil.unsupportedAttestationProvider("AppAttestProvider")
    }
  }

  private func generateAppAttestKeyIDIfNeeded(_ storedKeyID: String?) async throws -> String {
    if let stored = storedKeyID {
      return stored
    }
    return try await generateAppAttestKey()
  }

  private func generateAppAttestKey() async throws -> String {
    let keyID: String = try await withCheckedThrowingContinuation { continuation in
      appAttestService.generateKey { keyID, error in
        if let error = error {
          continuation
            .resume(throwing: AppCheckCoreErrorUtil.appAttestGenerateKeyFailed(withError: error))
        } else if let keyID = keyID {
          continuation.resume(returning: keyID)
        } else {
          continuation
            .resume(throwing: AppCheckCoreErrorUtil
              .error(withFailureReason: "Generate key returned nil key ID and nil error."))
        }
      }
    }

    _ = try await keyIDStorage.setAppAttestKeyID(keyID)
    return keyID
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
