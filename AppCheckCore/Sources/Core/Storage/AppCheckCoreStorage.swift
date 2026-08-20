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
import GoogleUtilities_Environment

@objc(GACAppCheckStorageProtocol)
public protocol AppCheckCoreStorageProtocol: NSObjectProtocol {
  func setToken(_ token: AppCheckCoreToken?) async throws -> AppCheckCoreToken?
  func getToken() async throws -> AppCheckCoreToken?
}

@objc(GACAppCheckStorage)
@objcMembers
public class AppCheckCoreStorage: NSObject, AppCheckCoreStorageProtocol {
  private let kKeychainService = "com.google.app_check_core.token_storage"

  public let tokenKey: String
  public let keychainStorage: GULKeychainStorage
  public let accessGroup: String?

  public init(tokenKey: String,
              keychainStorage: GULKeychainStorage,
              accessGroup: String?) {
    self.tokenKey = tokenKey
    self.keychainStorage = keychainStorage
    self.accessGroup = accessGroup
    super.init()
  }

  public convenience init(tokenKey: String, accessGroup: String?) {
    let keychainStorage = GULKeychainStorage(service: "com.google.app_check_core.token_storage")
    self.init(tokenKey: tokenKey, keychainStorage: keychainStorage, accessGroup: accessGroup)
  }

  public func getToken() async throws -> AppCheckCoreToken? {
    return try await withCheckedThrowingContinuation { continuation in
      keychainStorage.getObjectForKey(
        tokenKey,
        objectClass: AppCheckCoreStoredToken.self,
        accessGroup: accessGroup
      ) { storedToken, error in
        if let error = error {
          // Wrap keychain error
          let wrappedError = NSError(
            domain: AppCheckCoreErrorDomain,
            code: AppCheckCoreErrorCode.keychain.rawValue,
            userInfo: [NSUnderlyingErrorKey: error]
          )
          continuation.resume(throwing: wrappedError)
        } else if let stored = storedToken as? AppCheckCoreStoredToken {
          continuation.resume(returning: stored.appCheckToken())
        } else {
          continuation.resume(returning: nil)
        }
      }
    }
  }

  public func setToken(_ token: AppCheckCoreToken?) async throws -> AppCheckCoreToken? {
    return try await withCheckedThrowingContinuation { continuation in
      if let token = token {
        let storedToken = AppCheckCoreStoredToken()
        storedToken.update(with: token)
        keychainStorage
          .setObject(storedToken, forKey: tokenKey, accessGroup: accessGroup) { result, error in
            if let error = error {
              let wrappedError = NSError(
                domain: AppCheckCoreErrorDomain,
                code: AppCheckCoreErrorCode.keychain.rawValue,
                userInfo: [NSUnderlyingErrorKey: error]
              )
              continuation.resume(throwing: wrappedError)
            } else {
              continuation.resume(returning: token)
            }
          }
      } else {
        keychainStorage.removeObject(forKey: tokenKey, accessGroup: accessGroup) { error in
          if let error = error {
            let wrappedError = NSError(
              domain: AppCheckCoreErrorDomain,
              code: AppCheckCoreErrorCode.keychain.rawValue,
              userInfo: [NSUnderlyingErrorKey: error]
            )
            continuation.resume(throwing: wrappedError)
          } else {
            continuation.resume(returning: nil)
          }
        }
      }
    }
  }
}
