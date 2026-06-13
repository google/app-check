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
import GoogleUtilities_UserDefaults

@objc(GACAppAttestKeyIDStorageProtocol)
public protocol AppCheckCoreAppAttestKeyIDStorageProtocol: NSObjectProtocol {
  @objc func setAppAttestKeyID(_ keyID: String?) -> FBLPromise<NSString>
  @objc func getAppAttestKeyID() -> FBLPromise<NSString>
}

public extension AppCheckCoreAppAttestKeyIDStorageProtocol {
  func getAppAttestKeyID() async throws -> String {
    let promise: FBLPromise<NSString> = getAppAttestKeyID()
    return try await withCheckedThrowingContinuation { continuation in
      promise.__onQueue(.promises, then: { val in
        if let keyID = val as? String {
          continuation.resume(returning: keyID)
        } else {
          continuation.resume(throwing: AppCheckCoreErrorUtil.appAttestKeyIDNotFound())
        }
        return nil
      }).__onQueue(.promises, catch: { err in
        continuation.resume(throwing: err)
      })
    }
  }

  func setAppAttestKeyID(_ keyID: String?) async throws -> String? {
    let promise: FBLPromise<NSString> = setAppAttestKeyID(keyID)
    return try await withCheckedThrowingContinuation { continuation in
      promise.__onQueue(.promises, then: { val in
        continuation.resume(returning: val as? String)
        return nil
      }).__onQueue(.promises, catch: { err in
        continuation.resume(throwing: err)
      })
    }
  }
}

@objc(GACAppAttestKeyIDStorage)
public final class AppCheckCoreAppAttestKeyIDStorage: NSObject,
  AppCheckCoreAppAttestKeyIDStorageProtocol, @unchecked Sendable {
  private let keySuffix: String
  private let userDefaults: GULUserDefaults
  private let queue = AsyncQueue()

  private static let kKeyIDStorageDefaultsSuiteName = "com.firebase.GACAppAttestKeyIDStorage"

  @objc public init(keySuffix: String) {
    self.keySuffix = keySuffix
    userDefaults = GULUserDefaults(suiteName: Self.kKeyIDStorageDefaultsSuiteName)
    super.init()
  }

  // Swift native async methods
  public func getAppAttestKeyID() async throws -> String {
    try await queue.enqueue {
      guard let appAttestKeyID = self.userDefaults
        .object(forKey: self.keyIDStorageKey()) as? String else {
        throw AppCheckCoreErrorUtil.appAttestKeyIDNotFound()
      }
      return appAttestKeyID
    }
  }

  public func setAppAttestKeyID(_ keyID: String?) async throws -> String? {
    try await queue.enqueue {
      if let keyID = keyID {
        self.userDefaults.setObject(keyID, forKey: self.keyIDStorageKey())
      } else {
        self.userDefaults.removeObject(forKey: self.keyIDStorageKey())
      }
      return keyID
    }
  }

  // MARK: - Objective-C Compatibility Bridge

  @objc public func setAppAttestKeyID(_ keyID: String?) -> FBLPromise<NSString> {
    let promise = FBLPromise<NSString>.__pending()
    Task {
      do {
        let result = try await self.setAppAttestKeyID(keyID)
        promise.__fulfill(result as NSString?)
      } catch {
        promise.__reject(error as NSError)
      }
    }
    return promise
  }

  @objc public func getAppAttestKeyID() -> FBLPromise<NSString> {
    let promise = FBLPromise<NSString>.__pending()
    Task {
      do {
        let result = try await self.getAppAttestKeyID()
        promise.__fulfill(result as NSString)
      } catch {
        promise.__reject(error as NSError)
      }
    }
    return promise
  }

  private func keyIDStorageKey() -> String {
    return "app_attest_keyID.\(keySuffix)"
  }
}
