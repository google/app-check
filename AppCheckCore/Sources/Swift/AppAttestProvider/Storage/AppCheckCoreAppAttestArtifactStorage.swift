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

@objc(GACAppAttestArtifactStorageProtocol)
public protocol AppCheckCoreAppAttestArtifactStorageProtocol: NSObjectProtocol {
  @objc func setArtifact(_ artifact: Data?, forKey keyID: String) -> FBLPromise<NSData>
  @objc func getArtifactForKey(_ keyID: String) -> FBLPromise<NSData>
}

public extension AppCheckCoreAppAttestArtifactStorageProtocol {
  func getArtifact(forKey keyID: String) async throws -> Data? {
    let promise: FBLPromise<NSData> = getArtifactForKey(keyID)
    return try await withCheckedThrowingContinuation { continuation in
      promise.__onQueue(.promises, then: { val in
        continuation.resume(returning: val as? Data)
        return nil
      }).__onQueue(.promises, catch: { err in
        continuation.resume(throwing: err)
      })
    }
  }

  func setArtifact(_ artifact: Data?, forKey keyID: String) async throws -> Data? {
    let promise: FBLPromise<NSData> = setArtifact(artifact, forKey: keyID)
    return try await withCheckedThrowingContinuation { continuation in
      promise.__onQueue(.promises, then: { val in
        continuation.resume(returning: val as? Data)
        return nil
      }).__onQueue(.promises, catch: { err in
        continuation.resume(throwing: err)
      })
    }
  }
}

@objc(GACAppAttestArtifactStorage)
public final class AppCheckCoreAppAttestArtifactStorage: NSObject,
  AppCheckCoreAppAttestArtifactStorageProtocol, @unchecked Sendable {
  private let keySuffix: String
  private let keychainStorage: GULKeychainStorage
  private let accessGroup: String?
  private let queue = AsyncQueue()

  private static let kKeychainService = "com.firebase.app_check.app_attest_artifact_storage"

  @objc public init(keySuffix: String,
                    keychainStorage: GULKeychainStorage,
                    accessGroup: String?) {
    self.keySuffix = keySuffix
    self.keychainStorage = keychainStorage
    self.accessGroup = accessGroup
    super.init()
  }

  @objc public convenience init(keySuffix: String,
                                accessGroup: String?) {
    let keychainStorage = GULKeychainStorage(service: Self.kKeychainService)
    self.init(keySuffix: keySuffix, keychainStorage: keychainStorage, accessGroup: accessGroup)
  }

  // Swift async methods
  public func getArtifact(forKey keyID: String) async throws -> Data? {
    try await queue.enqueue {
      try await withCheckedThrowingContinuation { continuation in
        self.keychainStorage.getObjectForKey(
          self.artifactKey(),
          objectClass: AppCheckCoreAppAttestStoredArtifact.self,
          accessGroup: self.accessGroup
        ) { storedArtifact, error in
          if let error = error {
            continuation.resume(throwing: AppCheckCoreErrorUtil.keychainError(with: error))
          } else if let storedArtifact = storedArtifact as? AppCheckCoreAppAttestStoredArtifact {
            if storedArtifact.keyID == keyID {
              continuation.resume(returning: storedArtifact.artifact)
            } else {
              continuation.resume(returning: nil)
            }
          } else {
            continuation.resume(returning: nil)
          }
        }
      }
    }
  }

  public func setArtifact(_ artifact: Data?, forKey keyID: String) async throws -> Data? {
    try await queue.enqueue {
      try await withCheckedThrowingContinuation { continuation in
        if let artifact = artifact {
          let storedArtifact = AppCheckCoreAppAttestStoredArtifact(keyID: keyID, artifact: artifact)
          self.keychainStorage.setObject(
            storedArtifact,
            forKey: self.artifactKey(),
            accessGroup: self.accessGroup
          ) { storedValue, error in
            if let error = error {
              continuation.resume(throwing: AppCheckCoreErrorUtil.keychainError(with: error))
            } else {
              continuation.resume(returning: artifact)
            }
          }
        } else {
          self.keychainStorage.removeObject(
            forKey: self.artifactKey(),
            accessGroup: self.accessGroup
          ) { error in
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

  // MARK: - Objective-C Compatibility Bridge

  @objc public func setArtifact(_ artifact: Data?, forKey keyID: String) -> FBLPromise<NSData> {
    let promise = FBLPromise<NSData>.__pending()
    Task {
      do {
        let result = try await self.setArtifact(artifact, forKey: keyID)
        promise.__fulfill(result as NSData?)
      } catch {
        promise.__reject(error as NSError)
      }
    }
    return promise
  }

  @objc public func getArtifactForKey(_ keyID: String) -> FBLPromise<NSData> {
    let promise = FBLPromise<NSData>.__pending()
    Task {
      do {
        let result = try await self.getArtifact(forKey: keyID)
        promise.__fulfill(result as NSData?)
      } catch {
        promise.__reject(error as NSError)
      }
    }
    return promise
  }

  private func artifactKey() -> String {
    return "app_check_app_attest_artifact.\(keySuffix)"
  }
}
