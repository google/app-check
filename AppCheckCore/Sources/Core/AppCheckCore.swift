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

public typealias AppCheckCoreTokenHandler = (AppCheckCoreTokenResult) -> Void

@objc(GACAppCheckProtocol)
public protocol AppCheckCoreProtocol: NSObjectProtocol {
  @objc(tokenForcingRefresh:completion:)
  func token(forcingRefresh: Bool, completion: @escaping AppCheckCoreTokenHandler)

  @objc(limitedUseTokenWithCompletion:)
  func limitedUseToken(completion: @escaping AppCheckCoreTokenHandler)
}

@objc(GACAppCheck)
public class AppCheckCore: NSObject, AppCheckCoreProtocol {
  public let serviceName: String
  public let appCheckProvider: AppCheckCoreProvider
  public let settings: AppCheckCoreSettingsProtocol
  public weak var tokenDelegate: AppCheckCoreTokenDelegate?
  public let storage: AppCheckCoreStorageProtocol
  public let tokenRefresher: AppCheckCoreTokenRefresherProtocol

  @objc(
    initWithServiceName:resourceName:appCheckProvider:settings:tokenDelegate:keychainAccessGroup:
  )
  public init(serviceName: String,
              resourceName: String,
              appCheckProvider: AppCheckCoreProvider,
              settings: AppCheckCoreSettingsProtocol,
              tokenDelegate: AppCheckCoreTokenDelegate?,
              keychainAccessGroup: String?) {
    self.serviceName = serviceName
    self.appCheckProvider = appCheckProvider
    self.settings = settings
    self.tokenDelegate = tokenDelegate
    let tokenKey = "app_check_token.\(serviceName).\(resourceName)"
    storage = AppCheckCoreStorage(tokenKey: tokenKey, accessGroup: keychainAccessGroup)
    let refreshResult = AppCheckCoreTokenRefreshResult(
      status: .never,
      expirationDate: nil,
      receivedAtDate: nil
    )
    tokenRefresher = AppCheckCoreTokenRefresher(refreshResult: refreshResult, settings: settings)
    super.init()

    tokenRefresher.tokenRefreshHandler = { [weak self] completion in
      self?.periodicTokenRefresh(completion: completion)
    }
  }

  init(serviceName: String,
       appCheckProvider: AppCheckCoreProvider,
       storage: AppCheckCoreStorageProtocol,
       tokenRefresher: AppCheckCoreTokenRefresherProtocol,
       settings: AppCheckCoreSettingsProtocol,
       tokenDelegate: AppCheckCoreTokenDelegate?) {
    self.serviceName = serviceName
    self.appCheckProvider = appCheckProvider
    self.storage = storage
    self.tokenRefresher = tokenRefresher
    self.settings = settings
    self.tokenDelegate = tokenDelegate
    super.init()

    self.tokenRefresher.tokenRefreshHandler = { [weak self] completion in
      self?.periodicTokenRefresh(completion: completion)
    }
  }

  private func periodicTokenRefresh(completion: @escaping AppCheckCoreTokenRefreshCompletion) {
    Task {
      let refreshResult: AppCheckCoreTokenRefreshResult
      do {
        let token = try await self.token(forcingRefresh: false)
        refreshResult = AppCheckCoreTokenRefreshResult(status: .success,
                                                       expirationDate: token.expirationDate,
                                                       receivedAtDate: token.receivedAtDate)
      } catch {
        refreshResult = AppCheckCoreTokenRefreshResult(status: .failure,
                                                       expirationDate: nil,
                                                       receivedAtDate: nil)
      }
      // Parity with v11: `-[GACAppCheck periodicTokenRefreshWithCompletion:]`
      // used bare `.then` / `.catch`, so this ran on the main queue.
      DispatchQueue.main.async {
        completion(refreshResult)
      }
    }
  }

  private var ongoingTask: Task<AppCheckCoreToken, Error>?
  private let lock = NSLock()
  private let kTokenExpirationThreshold: TimeInterval = 5 * 60 // 5 minutes

  private enum GetTokenAction {
    case wait(Task<AppCheckCoreToken, Error>)
    case run(Task<AppCheckCoreToken, Error>)
  }

  public func token(forcingRefresh: Bool) async throws -> AppCheckCoreToken {
    let action: GetTokenAction = lock.execute {
      // If not forcing refresh and there is an ongoing task, return it
      if !forcingRefresh, let ongoing = ongoingTask {
        return .wait(ongoing)
      }

      // Create a new task and store it only if not forcing refresh
      let task = Task { () -> AppCheckCoreToken in
        defer {
          if !forcingRefresh {
            self.lock.execute {
              self.ongoingTask = nil
            }
          }
        }
        return try await self.createRetrieveOrRefreshToken(forcingRefresh: forcingRefresh)
      }

      if !forcingRefresh {
        self.ongoingTask = task
      }

      return .run(task)
    }

    switch action {
    case let .wait(ongoingTask):
      return try await ongoingTask.value
    case let .run(newTask):
      return try await newTask.value
    }
  }

  private func createRetrieveOrRefreshToken(forcingRefresh: Bool) async throws
    -> AppCheckCoreToken {
    do {
      let token = try await getCachedValidToken(forcingRefresh: forcingRefresh)
      return token
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

    let isTokenExpiredOrExpiresSoon = token.expirationDate
      .timeIntervalSinceNow < kTokenExpirationThreshold
    if isTokenExpiredOrExpiresSoon {
      throw AppCheckCoreErrorUtil.cachedTokenExpired()
    }

    return token
  }

  private func refreshToken() async throws -> AppCheckCoreToken {
    let token = try await appCheckProvider.getToken()

    _ = try await storage.setToken(token)

    let refreshResult = AppCheckCoreTokenRefreshResult(status: .success,
                                                       expirationDate: token.expirationDate,
                                                       receivedAtDate: token.receivedAtDate)

    // Parity with v11: both of these ran inside a bare `FBLPromise.then`, which
    // dispatches onto `FBLPromise.defaultDispatchQueue` (the main queue). They
    // are awaited rather than fire-and-forget because the v11 promise only
    // resolved *after* this block completed, so callers were guaranteed the
    // delegate had already been notified by the time they received the token.
    await notifyTokenUpdateOnMainQueue(token, refreshResult: refreshResult)

    return token
  }

  @objc(tokenForcingRefresh:completion:)
  public func token(forcingRefresh: Bool, completion: @escaping AppCheckCoreTokenHandler) {
    Task {
      do {
        let token = try await self.token(forcingRefresh: forcingRefresh)
        Self.deliverOnMainQueue(AppCheckCoreTokenResult(token: token), to: completion)
      } catch {
        Self.deliverOnMainQueue(AppCheckCoreTokenResult(error: error), to: completion)
      }
    }
  }

  public func limitedUseToken() async throws -> AppCheckCoreToken {
    return try await appCheckProvider.getLimitedUseToken()
  }

  @objc(limitedUseTokenWithCompletion:)
  public func limitedUseToken(completion: @escaping AppCheckCoreTokenHandler) {
    Task {
      do {
        let token = try await self.limitedUseToken()
        Self.deliverOnMainQueue(AppCheckCoreTokenResult(token: token), to: completion)
      } catch {
        Self.deliverOnMainQueue(AppCheckCoreTokenResult(error: error), to: completion)
      }
    }
  }

  // MARK: - Main-queue delivery (v11 parity)

  /// Delivers a completion handler on the main queue.
  ///
  /// In v11 every public completion handler was invoked from a bare
  /// `FBLPromise` `.then` / `.catch`, which dispatches onto
  /// `FBLPromise.defaultDispatchQueue`. That default is `dispatch_get_main_queue()`
  /// (set in `+[FBLPromise initialize]`) and is never reassigned by this library
  /// or its known consumers, so handlers were always delivered on the main
  /// queue — and always asynchronously, since `FBLPromise` used an
  /// unconditional `dispatch_group_async` with no same-queue fast path.
  ///
  /// `DispatchQueue.main.async` is used rather than `MainActor.run` to reproduce
  /// that "always async" behavior exactly, including when the caller is already
  /// on the main thread.
  ///
  /// Note this applies only to the completion-handler API. The `async` variants
  /// resume on the cooperative pool as normal; `async` callers are expected to
  /// hop to the main actor themselves, and forcing a hop would be a new
  /// divergence rather than parity.
  private static func deliverOnMainQueue(_ result: AppCheckCoreTokenResult,
                                         to completion: @escaping AppCheckCoreTokenHandler) {
    DispatchQueue.main.async {
      completion(result)
    }
  }

  /// Notifies the token refresher and token delegate on the main queue.
  ///
  /// Mirrors the v11 bare `.then` in `-[GACAppCheck refreshToken]`, which ran
  /// both of these on the main queue before resolving the promise. Suspends
  /// until they have run so that ordering relative to the returned token is
  /// preserved.
  private func notifyTokenUpdateOnMainQueue(
    _ token: AppCheckCoreToken,
    refreshResult: AppCheckCoreTokenRefreshResult
  ) async {
    let tokenRefresher = self.tokenRefresher
    let tokenDelegate = self.tokenDelegate
    let serviceName = self.serviceName

    await withCheckedContinuation { continuation in
      DispatchQueue.main.async {
        tokenRefresher.updateWithRefreshResult(refreshResult)
        tokenDelegate?.tokenDidUpdate(token, serviceName: serviceName)
        continuation.resume()
      }
    }
  }
}
