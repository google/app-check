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

@objc(GACAppCheck)
@objcMembers
public class AppCheckCore: NSObject {
  public let serviceName: String
  public let appCheckProvider: AppCheckCoreProvider
  public let settings: AppCheckCoreSettingsProtocol
  public weak var tokenDelegate: AppCheckCoreTokenDelegate?
  public let storage: AppCheckCoreStorageProtocol
  public let tokenRefresher: AppCheckCoreTokenRefresherProtocol

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
      do {
        let token = try await self.token(forcingRefresh: false)
        let refreshResult = AppCheckCoreTokenRefreshResult(status: .success,
                                                           expirationDate: token.expirationDate,
                                                           receivedAtDate: token.receivedAtDate)
        completion(refreshResult)
      } catch {
        let refreshResult = AppCheckCoreTokenRefreshResult(status: .failure,
                                                           expirationDate: nil,
                                                           receivedAtDate: nil)
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
    tokenRefresher.updateWithRefreshResult(refreshResult)

    if let tokenDelegate = tokenDelegate {
      tokenDelegate.tokenDidUpdate(token, serviceName: serviceName)
    }

    return token
  }

  @objc(tokenForcingRefresh:completion:)
  public func token(forcingRefresh: Bool, completion: @escaping AppCheckCoreTokenHandler) {
    Task {
      do {
        let token = try await self.token(forcingRefresh: forcingRefresh)
        completion(AppCheckCoreTokenResult(token: token))
      } catch {
        completion(AppCheckCoreTokenResult(error: error))
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
        completion(AppCheckCoreTokenResult(token: token))
      } catch {
        completion(AppCheckCoreTokenResult(error: error))
      }
    }
  }
}
