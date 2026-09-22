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
#if COCOAPODS
  import GoogleUtilities
#else
  import GoogleUtilities_Environment
#endif

@objc(GACAppCheckStorageProtocol)
package protocol AppCheckCoreStorageProtocol: NSObjectProtocol {
  func setToken(_ token: AppCheckCoreToken?) async throws -> AppCheckCoreToken?
  func getToken() async throws -> AppCheckCoreToken?
}

@objc(GACAppCheckStorage)
package final class AppCheckCoreStorage: NSObject, AppCheckCoreStorageProtocol {
  /// Storage service name for Keychain.
  /// Internal scope exists for testing purposes.
  /// Do not rename: retains value for compatibility with existing stored data from v11 or lower.
  static let keychainService = "com.google.app_check_core.token_storage"

  package let tokenKey: String
  let keychainStorage: GULKeychainStorage
  package let accessGroup: String?

  package init(tokenKey: String,
               keychainStorage: GULKeychainStorage,
               accessGroup: String?) {
    self.tokenKey = tokenKey
    self.keychainStorage = keychainStorage
    self.accessGroup = accessGroup
    super.init()
  }

  package convenience init(tokenKey: String, accessGroup: String?) {
    let keychainStorage = GULKeychainStorage(service: Self.keychainService)
    self.init(tokenKey: tokenKey, keychainStorage: keychainStorage, accessGroup: accessGroup)
  }

  package func getToken() async throws -> AppCheckCoreToken? {
    return try await withSafeCheckedThrowingContinuation { continuation in
      keychainStorage.getObjectForKey(
        tokenKey,
        objectClass: AppCheckCoreStoredToken.self,
        accessGroup: accessGroup
      ) { storedToken, error in
        if let error = error {
          // Wrap keychain error
          let wrappedError = AppCheckCoreErrorUtil.keychainError(with: error)
          continuation.resume(throwing: wrappedError)
        } else if let stored = storedToken as? AppCheckCoreStoredToken {
          continuation.resume(returning: stored.appCheckToken())
        } else {
          continuation.resume(returning: nil)
        }
      }
    }
  }

  package func setToken(_ token: AppCheckCoreToken?) async throws -> AppCheckCoreToken? {
    return try await withSafeCheckedThrowingContinuation { continuation in
      if let token = token {
        let storedToken = AppCheckCoreStoredToken()
        storedToken.update(with: token)
        keychainStorage
          .setObject(storedToken, forKey: tokenKey, accessGroup: accessGroup) { _, error in
            if let error = error {
              let wrappedError = AppCheckCoreErrorUtil.keychainError(with: error)
              continuation.resume(throwing: wrappedError)
            } else {
              continuation.resume(returning: token)
            }
          }
      } else {
        keychainStorage.removeObject(forKey: tokenKey, accessGroup: accessGroup) { error in
          if let error = error {
            let wrappedError = AppCheckCoreErrorUtil.keychainError(with: error)
            continuation.resume(throwing: wrappedError)
          } else {
            continuation.resume(returning: nil)
          }
        }
      }
    }
  }
}
