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
import GoogleUtilities_Environment
import Promises

@objc(GACAppCheckStorageProtocol)
public protocol AppCheckCoreStorageProtocol: NSObjectProtocol, Sendable {
  @objc(getToken)
  func getTokenObjC() -> FBLPromise<AppCheckCoreToken>

  @objc(setToken:)
  func setTokenObjC(_ token: AppCheckCoreToken?) -> FBLPromise<AppCheckCoreToken>
}

public extension AppCheckCoreStorageProtocol {
  func getToken() -> Promise<AppCheckCoreToken?> {
    let promise = getTokenObjC()
    return Promise<AnyObject>(promise).then { val in
      Promise(val as? AppCheckCoreToken)
    }
  }

  func setToken(_ token: AppCheckCoreToken?) -> Promise<AppCheckCoreToken?> {
    let promise = setTokenObjC(token)
    return Promise<AnyObject>(promise).then { val in
      Promise(val as? AppCheckCoreToken)
    }
  }
}

@objc(GACAppCheckStorage)
public final class AppCheckCoreStorage: NSObject, AppCheckCoreStorageProtocol, @unchecked Sendable {
  private let tokenKey: String
  private let keychainStorage: GULKeychainStorage
  private let accessGroup: String?
  private let queue = AsyncQueue()

  @objc public init(tokenKey: String, keychainStorage: GULKeychainStorage, accessGroup: String?) {
    self.tokenKey = tokenKey
    self.keychainStorage = keychainStorage
    self.accessGroup = accessGroup
    super.init()
  }

  @objc public convenience init(tokenKey: String, accessGroup: String?) {
    let keychainStorage = GULKeychainStorage(service: "com.google.app_check_core.token_storage")
    self.init(tokenKey: tokenKey, keychainStorage: keychainStorage, accessGroup: accessGroup)
  }

  @objc public func getToken() async throws -> AppCheckCoreToken? {
    return try await queue.enqueue {
      try await withCheckedThrowingContinuation { continuation in
        self.keychainStorage.getObjectForKey(
          self.tokenKey,
          objectClass: AppCheckCoreStoredToken.self,
          accessGroup: self.accessGroup
        ) { storedToken, error in
          if let error = error {
            continuation.resume(throwing: AppCheckCoreErrorUtil.keychainError(with: error))
          } else if let stored = storedToken as? AppCheckCoreStoredToken {
            continuation.resume(returning: stored.appCheckToken())
          } else {
            continuation.resume(returning: nil)
          }
        }
      }
    }
  }

  @objc public func setToken(_ token: AppCheckCoreToken?) async throws -> AppCheckCoreToken? {
    return try await queue.enqueue {
      if let token = token {
        let storedToken = AppCheckCoreStoredToken()
        storedToken.update(with: token)
        return try await withCheckedThrowingContinuation { continuation in
          self.keychainStorage.setObject(
            storedToken,
            forKey: self.tokenKey,
            accessGroup: self.accessGroup
          ) { _, error in
            if let error = error {
              continuation.resume(throwing: AppCheckCoreErrorUtil.keychainError(with: error))
            } else {
              continuation.resume(returning: token)
            }
          }
        }
      } else {
        return try await withCheckedThrowingContinuation { continuation in
          self.keychainStorage
            .removeObject(forKey: self.tokenKey, accessGroup: self.accessGroup) { error in
              if let error = error {
                continuation.resume(throwing: AppCheckCoreErrorUtil.keychainError(with: error))
              } else {
                continuation.resume(returning: nil)
              }
            }
        }
      }
    }
  }

  @objc(getToken)
  public func getTokenObjC() -> FBLPromise<AppCheckCoreToken> {
    let promise = FBLPromise<AppCheckCoreToken>.__pending()
    Task {
      do {
        if let token = try await self.getToken() {
          promise.__fulfill(token)
        } else {
          promise.__fulfill(nil)
        }
      } catch {
        promise.__reject(error as NSError)
      }
    }
    return promise
  }

  @objc(setToken:)
  public func setTokenObjC(_ token: AppCheckCoreToken?) -> FBLPromise<AppCheckCoreToken> {
    let promise = FBLPromise<AppCheckCoreToken>.__pending()
    Task {
      do {
        if let returnedToken = try await self.setToken(token) {
          promise.__fulfill(returnedToken)
        } else {
          promise.__fulfill(nil)
        }
      } catch {
        promise.__reject(error as NSError)
      }
    }
    return promise
  }
}
