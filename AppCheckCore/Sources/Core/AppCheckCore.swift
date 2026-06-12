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

@objc(GACAppCheckProtocol)
public protocol AppCheckCoreProtocol: NSObjectProtocol {
  @objc(tokenForcingRefresh:completion:)
  func token(forcingRefresh: Bool, completion handler: @escaping (AppCheckCoreTokenResult) -> Void)

  @objc(limitedUseTokenWithCompletion:)
  func limitedUseToken(completion handler: @escaping (AppCheckCoreTokenResult) -> Void)
}

@objc(GACAppCheck)
public final class AppCheckCore: NSObject, AppCheckCoreProtocol, @unchecked Sendable {
  private let serviceName: String
  private let appCheckProvider: AppCheckCoreProvider
  private let storage: AppCheckCoreStorageProtocol
  private let settings: AppCheckCoreSettingsProtocol
  private weak var tokenDelegate: AppCheckCoreTokenDelegate?
  private let tokenRefresher: AppCheckCoreTokenRefresherProtocol?

  private var ongoingPromise: (id: UUID, promise: Promise<AppCheckCoreToken>)?
  private var lock = os_unfair_lock()
  private static let tokenExpirationThreshold: TimeInterval = 5 * 60 // 5 min.

  @objc public init(serviceName: String,
                    appCheckProvider: AppCheckCoreProvider,
                    storage: AppCheckCoreStorageProtocol,
                    tokenRefresher: AppCheckCoreTokenRefresherProtocol?,
                    settings: AppCheckCoreSettingsProtocol,
                    tokenDelegate: AppCheckCoreTokenDelegate?) {
    self.serviceName = serviceName
    self.appCheckProvider = appCheckProvider
    self.storage = storage
    self.tokenRefresher = tokenRefresher
    self.settings = settings
    self.tokenDelegate = tokenDelegate
    super.init()

    self.tokenRefresher?.tokenRefreshHandler = { [weak self] completion in
      guard let self = self else { return }
      self.retrieveOrRefreshToken(forcingRefresh: false)
        .then { token in
          let refreshResult = AppCheckCoreTokenRefreshResult.makeWithSuccess(
            expirationDate: token.expirationDate,
            receivedAtDate: token.receivedAtDate
          )
          completion(refreshResult)
        }
        .catch { _ in
          completion(AppCheckCoreTokenRefreshResult.makeWithStatusFailure())
        }
    }
  }

  @objc public convenience init(serviceName: String,
                                resourceName: String,
                                appCheckProvider: AppCheckCoreProvider,
                                settings: AppCheckCoreSettingsProtocol,
                                tokenDelegate: AppCheckCoreTokenDelegate?,
                                keychainAccessGroup: String?) {
    let refreshResult = AppCheckCoreTokenRefreshResult.makeWithStatusNever()
    let tokenRefresher = Self.makeTokenRefresher(refreshResult: refreshResult, settings: settings)
    let tokenKey = "app_check_token.\(serviceName).\(resourceName)"
    let storage = Self.makeStorage(tokenKey: tokenKey, accessGroup: keychainAccessGroup)

    self.init(
      serviceName: serviceName,
      appCheckProvider: appCheckProvider,
      storage: storage,
      tokenRefresher: tokenRefresher,
      settings: settings,
      tokenDelegate: tokenDelegate
    )
  }

  @objc(makeTokenRefresherWithRefreshResult:settings:)
  public dynamic class func makeTokenRefresher(refreshResult: AppCheckCoreTokenRefreshResult,
                                               settings: AppCheckCoreSettingsProtocol)
    -> AppCheckCoreTokenRefresherProtocol {
    AppCheckCoreTokenRefresher(refreshResult: refreshResult, settings: settings)
  }

  @objc(makeStorageWithTokenKey:accessGroup:)
  public dynamic class func makeStorage(tokenKey: String,
                                        accessGroup: String?) -> AppCheckCoreStorageProtocol {
    AppCheckCoreStorage(tokenKey: tokenKey, accessGroup: accessGroup)
  }

  // MARK: - AppCheckCoreProtocol

  @objc public func token(forcingRefresh: Bool,
                          completion handler: @escaping (AppCheckCoreTokenResult) -> Void) {
    retrieveOrRefreshToken(forcingRefresh: forcingRefresh)
      .then { token in
        handler(AppCheckCoreTokenResult(token: token))
      }
      .catch { error in
        handler(AppCheckCoreTokenResult(error: error))
      }
  }

  @objc public func limitedUseToken(completion handler: @escaping (AppCheckCoreTokenResult)
    -> Void) {
    limitedUseToken()
      .then { token in
        handler(AppCheckCoreTokenResult(token: token))
      }
      .catch { error in
        handler(AppCheckCoreTokenResult(error: error))
      }
  }

  // MARK: - Internal Methods

  private func retrieveOrRefreshToken(forcingRefresh: Bool) -> Promise<AppCheckCoreToken> {
    os_unfair_lock_lock(&lock)
    if forcingRefresh {
      ongoingPromise = nil
    }

    if let ongoing = ongoingPromise {
      os_unfair_lock_unlock(&lock)
      return ongoing.promise
    }

    let promiseId = UUID()
    let promise = createRetrieveOrRefreshToken(forcingRefresh: forcingRefresh)

    promise.always {
      os_unfair_lock_lock(&self.lock)
      if self.ongoingPromise?.id == promiseId {
        self.ongoingPromise = nil
      }
      os_unfair_lock_unlock(&self.lock)
    }

    ongoingPromise = (promiseId, promise)
    os_unfair_lock_unlock(&lock)

    return promise
  }

  private func createRetrieveOrRefreshToken(forcingRefresh: Bool) -> Promise<AppCheckCoreToken> {
    return getCachedValidToken(forcingRefresh: forcingRefresh)
      .recover { _ -> Promise<AppCheckCoreToken> in
        return self.refreshToken()
      }
  }

  private func getCachedValidToken(forcingRefresh: Bool) -> Promise<AppCheckCoreToken> {
    if forcingRefresh {
      return Promise(AppCheckCoreErrorUtil.cachedTokenNotFound())
    }

    return storage.getToken().then { token -> Promise<AppCheckCoreToken> in
      guard let token = token else {
        throw AppCheckCoreErrorUtil.cachedTokenNotFound()
      }

      let isTokenExpiredOrExpiresSoon = token.expirationDate.timeIntervalSinceNow < Self
        .tokenExpirationThreshold
      if isTokenExpiredOrExpiresSoon {
        throw AppCheckCoreErrorUtil.cachedTokenExpired()
      }

      return Promise(token)
    }
  }

  private func refreshToken() -> Promise<AppCheckCoreToken> {
    let rawTokenPromise = Promise<AppCheckCoreToken> { fulfill, reject in
      self.appCheckProvider.getToken { token, error in
        if let error = error {
          reject(error)
        } else if let token = token {
          fulfill(token)
        } else {
          reject(AppCheckCoreErrorUtil
            .error(withFailureReason: "Provider returned nil token and nil error."))
        }
      }
    }

    return rawTokenPromise.then { rawToken -> Promise<AppCheckCoreToken> in
      let setTokenPromise = self.storage.setToken(rawToken)
      return setTokenPromise.then { storedTokenOpt -> Promise<AppCheckCoreToken> in
        let token = storedTokenOpt ?? rawToken

        let refreshResult = AppCheckCoreTokenRefreshResult.makeWithSuccess(
          expirationDate: token.expirationDate,
          receivedAtDate: token.receivedAtDate
        )
        self.tokenRefresher?.updateWithRefreshResult(refreshResult)
        self.tokenDelegate?.tokenDidUpdate(token, serviceName: self.serviceName)

        return Promise(token)
      }
    }
  }

  private func limitedUseToken() -> Promise<AppCheckCoreToken> {
    return Promise<AppCheckCoreToken> { fulfill, reject in
      self.appCheckProvider.getLimitedUseToken { token, error in
        if let error = error {
          reject(error)
        } else if let token = token {
          fulfill(token)
        } else {
          reject(AppCheckCoreErrorUtil
            .error(withFailureReason: "Provider returned nil token and nil error."))
        }
      }
    }
  }
}

public extension AppCheckCore {
  @available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 7.0, *)
  func token(forcingRefresh: Bool) async -> AppCheckCoreTokenResult {
    return await withCheckedContinuation { continuation in
      self.token(forcingRefresh: forcingRefresh) { result in
        continuation.resume(returning: result)
      }
    }
  }

  @available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 7.0, *)
  func limitedUseToken() async -> AppCheckCoreTokenResult {
    return await withCheckedContinuation { continuation in
      self.limitedUseToken { result in
        continuation.resume(returning: result)
      }
    }
  }
}
