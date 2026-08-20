import DeviceCheck
import Foundation

@available(iOS 14.0, macOS 11.0, tvOS 15.0, watchOS 9.0, *)
@objc(GACAppAttestProvider)
@objcMembers
public class AppCheckCoreAppAttestProvider: NSObject, AppCheckCoreProvider {
  // MARK: - Internal Properties

  private let apiService: AppCheckCoreAppAttestAPIServiceProtocol
  private let appAttestService: AppCheckCoreAppAttestService
  private let keyIDStorage: AppCheckCoreAppAttestKeyIDStorageProtocol
  private let artifactStorage: AppCheckCoreAppAttestArtifactStorageProtocol
  private let backoffWrapper: AppCheckBackoffWrapperProtocol

  private var ongoingGetTokenOperationTask: Task<AppCheckCoreToken, Error>?
  private var ongoingGetTokenOperationLimitedUse: Bool = false
  private let lock = NSLock()

  // MARK: - Initializers

  @available(*, unavailable)
  override public init() {
    fatalError("init() is unavailable")
  }

  init(appAttestService: AppCheckCoreAppAttestService,
       apiService: AppCheckCoreAppAttestAPIServiceProtocol,
       keyIDStorage: AppCheckCoreAppAttestKeyIDStorageProtocol,
       artifactStorage: AppCheckCoreAppAttestArtifactStorageProtocol,
       backoffWrapper: AppCheckBackoffWrapperProtocol) {
    self.appAttestService = appAttestService
    self.apiService = apiService
    self.keyIDStorage = keyIDStorage
    self.artifactStorage = artifactStorage
    self.backoffWrapper = backoffWrapper
    super.init()
  }

  public convenience init(serviceName: String,
                          resourceName: String,
                          baseURL: String?,
                          apiKey: String?,
                          keychainAccessGroup accessGroup: String?,
                          requestHooks: [AppCheckCoreAPIRequestHook]?) {
    let urlSession = URLSession(configuration: .ephemeral)
    let storageKeySuffix = AppCheckCoreAppAttestProvider.storageKeySuffix(
      serviceName: serviceName,
      resourceName: resourceName
    )

    let keyIDStorage = AppCheckCoreAppAttestKeyIDStorage(keySuffix: storageKeySuffix)
    let coreAPIService = AppCheckCoreAPIService(
      urlSession: urlSession,
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
      accessGroup: accessGroup
    )
    let backoffWrapper = AppCheckCoreBackoffWrapper()

    self.init(
      appAttestService: DCAppAttestService.shared,
      apiService: appAttestAPIService,
      keyIDStorage: keyIDStorage,
      artifactStorage: artifactStorage,
      backoffWrapper: backoffWrapper
    )
  }

  // MARK: - AppCheckCoreProvider

  public func getToken(completion handler: @escaping (AppCheckCoreToken?, Error?) -> Void) {
    getToken(limitedUse: false, completion: handler)
  }

  public func getLimitedUseToken(completion handler: @escaping (AppCheckCoreToken?, Error?)
    -> Void) {
    getToken(limitedUse: true, completion: handler)
  }

  // MARK: - Internal

  private func getToken(limitedUse: Bool,
                        completion handler: @escaping (AppCheckCoreToken?, Error?) -> Void) {
    Task {
      do {
        let token = try await getToken(limitedUse: limitedUse)
        handler(token, nil)
      } catch {
        handler(nil, error)
      }
    }
  }

  private enum GetTokenAction {
    case retry(Task<AppCheckCoreToken, Error>)
    case wait(Task<AppCheckCoreToken, Error>)
    case run(Task<AppCheckCoreToken, Error>)
  }

  private func getToken(limitedUse: Bool) async throws -> AppCheckCoreToken {
    let action: GetTokenAction = lock.execute {
      if let ongoingTask = ongoingGetTokenOperationTask {
        if limitedUse || ongoingGetTokenOperationLimitedUse != limitedUse {
          return .retry(ongoingTask)
        }
        return .wait(ongoingTask)
      }

      ongoingGetTokenOperationLimitedUse = limitedUse
      let newTask = Task {
        try await createGetTokenSequenceWithBackoff(limitedUse: limitedUse)
      }
      ongoingGetTokenOperationTask = newTask
      return .run(newTask)
    }

    switch action {
    case let .retry(ongoingTask):
      _ = try? await ongoingTask.value
      return try await getToken(limitedUse: limitedUse)
    case let .wait(ongoingTask):
      return try await ongoingTask.value
    case let .run(newTask):
      defer {
        lock.execute {
          ongoingGetTokenOperationTask = nil
        }
      }
      return try await newTask.value
    }
  }

  private func createGetTokenSequenceWithBackoff(limitedUse: Bool) async throws
    -> AppCheckCoreToken {
    let result = try await backoffWrapper.applyBackoffToOperation({
      try await self.createGetTokenSequence(limitedUse: limitedUse)
    }, errorHandler: backoffWrapper.defaultAppCheckProviderErrorHandler())
    return result as! AppCheckCoreToken
  }

  private func createGetTokenSequence(limitedUse: Bool) async throws -> AppCheckCoreToken {
    var attempts = 0
    while attempts < 2 {
      do {
        let attestState = try await attestationState()

        switch attestState.state {
        case .unsupported:
          AppCheckCoreLogger.log(
            code: .appAttestNotSupported,
            logLevel: .debug,
            message: "App Attest is not supported."
          )
          if let error = attestState.appAttestUnsupportedError {
            if let rejectionError = error as? AppCheckCoreAppAttestRejectionError {
              throw rejectionError.underlyingError ?? rejectionError
            }; throw error
          }
          throw AppCheckCoreErrorUtil.unsupportedAttestationProvider("AppAttestProvider")
        case .supportedInitial, .keyGenerated:
          return try await initialHandshake(
            keyID: attestState.appAttestKeyID,
            limitedUse: limitedUse
          )
        case .keyRegistered:
          guard let keyID = attestState.appAttestKeyID,
                let artifact = attestState.attestationArtifact else {
            throw AppCheckCoreErrorUtil.unsupportedAttestationProvider("AppAttestProvider")
          }
          return try await refreshToken(keyID: keyID, artifact: artifact, limitedUse: limitedUse)
        @unknown default:
          throw AppCheckCoreErrorUtil.unsupportedAttestationProvider("AppAttestProvider")
        }
      } catch {
        if error is AppCheckCoreAppAttestRejectionError, attempts == 0 {
          attempts += 1
          continue
        }
        if let rejectionError = error as? AppCheckCoreAppAttestRejectionError {
          throw rejectionError.underlyingError ?? rejectionError
        }; throw error
      }
    }
    throw AppCheckCoreErrorUtil.unsupportedAttestationProvider("AppAttestProvider")
  }

  // MARK: - Initial handshake sequence (attestation)

  private func initialHandshake(keyID: String?,
                                limitedUse: Bool) async throws -> AppCheckCoreToken {
    let (attestedKeyID, _, firebaseResponse) = try await attestKeyGenerateIfNeeded(
      keyID: keyID,
      limitedUse: limitedUse
    )
    return try await saveArtifactAndGetAppCheckToken(
      response: firebaseResponse,
      keyID: attestedKeyID
    )
  }

  private func saveArtifactAndGetAppCheckToken(response: AppCheckCoreAppAttestAttestationResponse,
                                               keyID: String) async throws -> AppCheckCoreToken {
    _ = try await artifactStorage.setArtifact(response.artifact, forKey: keyID)
    return response.token
  }

  private func attestKey(keyID: String,
                         challenge: Data) async throws
    -> AppCheckCoreAppAttestKeyAttestationResult {
    let challengeHash = AppCheckCoreCryptoUtils.sha256Hash(from: challenge)
    do {
      let attestation =
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
          Data,
          Error
        >) in
          appAttestService.attestKey(keyID, clientDataHash: challengeHash) { data, error in
            if let error = error {
              continuation.resume(throwing: error)
            } else if let data = data {
              continuation.resume(returning: data)
            } else {
              let unknownError = NSError(domain: "AppCheckCore", code: 0, userInfo: nil)
              continuation.resume(throwing: unknownError)
            }
          }
        }
      return AppCheckCoreAppAttestKeyAttestationResult(
        keyID: keyID,
        challenge: challenge,
        attestation: attestation
      )
    } catch {
      throw AppCheckCoreErrorUtil.appAttestAttestKeyFailed(
        with: error,
        keyId: keyID,
        clientDataHash: challengeHash
      )
    }
  }

  private func attestKeyGenerateIfNeeded(keyID: String?,
                                         limitedUse: Bool) async throws -> (
    String,
    Data,
    AppCheckCoreAppAttestAttestationResponse
  ) {
    let challenge: Data
    let generatedKeyID: String

    do {
      async let fetchChallenge = apiService.getRandomChallenge()
      async let fetchKeyID = generateAppAttestKeyIDIfNeeded(storedKeyID: keyID)
      challenge = try await fetchChallenge
      generatedKeyID = try await fetchKeyID
    } catch {
      if let rejectionError = error as? AppCheckCoreAppAttestRejectionError {
        throw rejectionError.underlyingError ?? rejectionError
      }; throw error
    }

    let attestationResult: AppCheckCoreAppAttestKeyAttestationResult
    do {
      attestationResult = try await attestKey(keyID: generatedKeyID, challenge: challenge)
    } catch {
      let nsError = error as NSError
      if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
         underlyingError.domain == DCErrorDomain,
         underlyingError.code == DCError.invalidKey.rawValue || underlyingError.code == DCError
         .invalidInput.rawValue {
        AppCheckCoreLogger.log(
          code: .attestationRejected,
          logLevel: .debug,
          message: "App Attest invalid key/input; the existing attestation will be reset. DC Error Code: \(underlyingError.code)."
        )
        try await resetAttestation()
        throw AppCheckCoreAppAttestRejectionError(underlyingError: error)
      }
      if let rejectionError = error as? AppCheckCoreAppAttestRejectionError {
        throw rejectionError.underlyingError ?? rejectionError
      }; throw error
    }

    do {
      let response = try await apiService.attestKey(
        withAttestation: attestationResult.attestation,
        keyID: attestationResult.keyID,
        challenge: attestationResult.challenge,
        limitedUse: limitedUse
      )
      return (attestationResult.keyID, attestationResult.attestation, response)
    } catch let httpError as AppCheckCoreHTTPError where httpError.httpResponse.statusCode == 403 {
      AppCheckCoreLogger.log(
        code: .attestationRejected,
        logLevel: .debug,
        message: "App Attest attestation was rejected by backend. The existing attestation will be reset."
      )
      try await resetAttestation()
      throw AppCheckCoreAppAttestRejectionError(underlyingError: httpError)
    } catch {
      if let rejectionError = error as? AppCheckCoreAppAttestRejectionError {
        throw rejectionError.underlyingError ?? rejectionError
      }; throw error
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
    let token = try await apiService.getAppCheckToken(
      withArtifact: assertion.artifact,
      challenge: assertion.challenge,
      assertion: assertion.assertion,
      limitedUse: limitedUse
    )
    return token
  }

  private func generateAssertion(keyID: String, artifact: Data,
                                 challenge: Data) async throws
    -> AppCheckCoreAppAttestAssertionData {
    var statementForAssertion = artifact
    statementForAssertion.append(challenge)

    let statementHash = AppCheckCoreCryptoUtils.sha256Hash(from: statementForAssertion)

    do {
      let assertion =
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
          Data,
          Error
        >) in
          appAttestService.generateAssertion(keyID, clientDataHash: statementHash) { data, error in
            if let error = error {
              continuation.resume(throwing: error)
            } else if let data = data {
              continuation.resume(returning: data)
            } else {
              let unknownError = NSError(domain: "AppCheckCore", code: 0, userInfo: nil)
              continuation.resume(throwing: unknownError)
            }
          }
        }
      return AppCheckCoreAppAttestAssertionData(
        challenge: challenge,
        artifact: artifact,
        assertion: assertion
      )
    } catch {
      let wrappedError = AppCheckCoreErrorUtil.appAttestGenerateAssertionFailed(
        with: error,
        keyId: keyID,
        clientDataHash: statementHash
      )

      let nsError = wrappedError as NSError
      if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
         underlyingError.domain == DCErrorDomain,
         underlyingError.code == DCError.invalidKey.rawValue ||
         underlyingError.code == DCError.invalidInput.rawValue ||
         underlyingError.code == DCError.unknownSystemFailure.rawValue {
        AppCheckCoreLogger.log(
          code: .assertionRejected,
          logLevel: .debug,
          message: "App Attest invalid key/input/system failure; the existing attestation will be reset. DC Error Code: \(underlyingError.code)."
        )
        try await resetAttestation()
        throw AppCheckCoreAppAttestRejectionError(underlyingError: wrappedError)
      }
      throw wrappedError
    }
  }

  // MARK: - State handling

  private func attestationState() async throws -> AppCheckCoreAppAttestProviderState {
    do {
      try await isAppAttestSupported()
    } catch {
      return AppCheckCoreAppAttestProviderState(unsupportedWithError: error)
    }

    let appAttestKeyID = try await keyIDStorage.getAppAttestKeyID()
    guard let keyID = appAttestKeyID else {
      return AppCheckCoreAppAttestProviderState(supportedInitialState: ())
    }

    let attestationArtifact = try await artifactStorage.getArtifact(forKey: keyID)
    guard let artifact = attestationArtifact else {
      return AppCheckCoreAppAttestProviderState(generatedKeyID: keyID)
    }

    return AppCheckCoreAppAttestProviderState(registeredKeyID: keyID, artifact: artifact)
  }

  // MARK: - Helpers

  private func isAppAttestSupported() async throws {
    if appAttestService.isSupported {
      return
    } else {
      throw AppCheckCoreErrorUtil.unsupportedAttestationProvider("AppAttestProvider")
    }
  }

  private func generateAppAttestKeyIDIfNeeded(storedKeyID: String?) async throws -> String {
    if let storedKeyID = storedKeyID {
      return storedKeyID
    } else {
      return try await generateAppAttestKey()
    }
  }

  private func generateAppAttestKey() async throws -> String {
    do {
      let keyID = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
        String,
        Error
      >) in
        appAttestService.generateKey { key, error in
          if let error = error {
            continuation.resume(throwing: error)
          } else if let key = key {
            continuation.resume(returning: key)
          } else {
            let unknownError = NSError(domain: "AppCheckCore", code: 0, userInfo: nil)
            continuation.resume(throwing: unknownError)
          }
        }
      }
      _ = try await keyIDStorage.setAppAttestKeyID(keyID)
      return keyID
    } catch {
      throw AppCheckCoreErrorUtil.appAttestGenerateKeyFailed(with: error)
    }
  }

  static func storageKeySuffix(serviceName: String, resourceName: String) -> String {
    return "\(serviceName).\(resourceName)"
  }
}

// MARK: - Data Objects

private class AppCheckCoreAppAttestKeyAttestationResult {
  let keyID: String
  let challenge: Data
  let attestation: Data

  init(keyID: String, challenge: Data, attestation: Data) {
    self.keyID = keyID
    self.challenge = challenge
    self.attestation = attestation
  }
}

private class AppCheckCoreAppAttestAssertionData {
  let challenge: Data
  let artifact: Data
  let assertion: Data

  init(challenge: Data, artifact: Data, assertion: Data) {
    self.challenge = challenge
    self.artifact = artifact
    self.assertion = assertion
  }
}

extension NSLock {
  func execute<T>(_ block: () -> T) -> T {
    lock()
    defer { self.unlock() }
    return block()
  }
}
