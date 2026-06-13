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

import Foundation

@objc(GACAppCheckProtocol)
public protocol AppCheckCoreProtocol: NSObjectProtocol {
  @objc(tokenForcingRefresh:completion:)
  func token(forcingRefresh: Bool, completion handler: @escaping (AppCheckCoreTokenResult) -> Void)

  @objc(limitedUseTokenWithCompletion:)
  func limitedUseToken(completion handler: @escaping (AppCheckCoreTokenResult) -> Void)
}

public extension AppCheckCoreProtocol {
  func token(forcingRefresh: Bool) async -> AppCheckCoreTokenResult {
    await withCheckedContinuation { continuation in
      self.token(forcingRefresh: forcingRefresh) { result in
        continuation.resume(returning: result)
      }
    }
  }

  func limitedUseToken() async -> AppCheckCoreTokenResult {
    await withCheckedContinuation { continuation in
      self.limitedUseToken { result in
        continuation.resume(returning: result)
      }
    }
  }
}

@objc(GACAppCheck)
public final class AppCheckCore: NSObject, AppCheckCoreProtocol, @unchecked Sendable {
  private let serviceName: String
  private let appCheckProvider: AppCheckCoreProvider
  private let storage: AppCheckCoreStorageProtocol
  private let settings: AppCheckCoreSettingsProtocol
  private weak var tokenDelegate: AppCheckCoreTokenDelegate?
  private let tokenRefresher: AppCheckCoreTokenRefresherProtocol?

  private var ongoingTask: (id: UUID, task: Task<AppCheckCoreToken, Error>)?
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
      Task {
        do {
          let token = try await self.retrieveOrRefreshToken(forcingRefresh: false)
          let refreshResult = AppCheckCoreTokenRefreshResult.makeWithSuccess(
            expirationDate: token.expirationDate,
            receivedAtDate: token.receivedAtDate
          )
          completion(refreshResult)
        } catch {
          completion(AppCheckCoreTokenRefreshResult.makeWithStatusFailure())
        }
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
    Task {
      do {
        let token = try await self.retrieveOrRefreshToken(forcingRefresh: forcingRefresh)
        handler(AppCheckCoreTokenResult(token: token))
      } catch {
        handler(AppCheckCoreTokenResult(error: error))
      }
    }
  }

  @objc public func limitedUseToken(completion handler: @escaping (AppCheckCoreTokenResult)
    -> Void) {
    Task {
      do {
        let token = try await self.limitedUseToken()
        handler(AppCheckCoreTokenResult(token: token))
      } catch {
        handler(AppCheckCoreTokenResult(error: error))
      }
    }
  }

  // MARK: - Internal Async Methods

  private func retrieveOrRefreshToken(forcingRefresh: Bool) async throws -> AppCheckCoreToken {
    os_unfair_lock_lock(&lock)
    if forcingRefresh {
      ongoingTask = nil
    }

    if let ongoing = ongoingTask {
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
      return try await self.createRetrieveOrRefreshToken(forcingRefresh: forcingRefresh)
    }

    ongoingTask = (taskId, task)
    os_unfair_lock_unlock(&lock)

    return try await task.value
  }

  private func createRetrieveOrRefreshToken(forcingRefresh: Bool) async throws
    -> AppCheckCoreToken {
    do {
      return try await getCachedValidToken(forcingRefresh: forcingRefresh)
    } catch {
      return try await refreshToken()
    }
  }

  private func getCachedValidToken(forcingRefresh: Bool) async throws -> AppCheckCoreToken {
    if forcingRefresh {
      throw AppCheckCoreErrorUtil.cachedTokenNotFound()
    }

    guard let token = try await storage.getToken() else {
      throw AppCheckCoreErrorUtil.cachedTokenNotFound()
    }

    let isTokenExpiredOrExpiresSoon = token.expirationDate.timeIntervalSinceNow < Self
      .tokenExpirationThreshold
    if isTokenExpiredOrExpiresSoon {
      throw AppCheckCoreErrorUtil.cachedTokenExpired()
    }

    return token
  }

  private func refreshToken() async throws -> AppCheckCoreToken {
    let rawToken: AppCheckCoreToken = try await withCheckedThrowingContinuation { continuation in
      appCheckProvider.getToken { token, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else if let token = token {
          continuation.resume(returning: token)
        } else {
          continuation
            .resume(throwing: AppCheckCoreErrorUtil
              .error(withFailureReason: "Provider returned nil token and nil error."))
        }
      }
    }

    let storedToken = try await storage.setToken(rawToken)
    let token = storedToken ?? rawToken

    let refreshResult = AppCheckCoreTokenRefreshResult.makeWithSuccess(
      expirationDate: token.expirationDate,
      receivedAtDate: token.receivedAtDate
    )
    tokenRefresher?.updateWithRefreshResult(refreshResult)
    tokenDelegate?.tokenDidUpdate(token, serviceName: serviceName)

    return token
  }

  private func limitedUseToken() async throws -> AppCheckCoreToken {
    return try await withCheckedThrowingContinuation { continuation in
      appCheckProvider.getLimitedUseToken { token, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else if let token = token {
          continuation.resume(returning: token)
        } else {
          continuation
            .resume(throwing: AppCheckCoreErrorUtil
              .error(withFailureReason: "Provider returned nil token and nil error."))
        }
      }
    }
  }
}
