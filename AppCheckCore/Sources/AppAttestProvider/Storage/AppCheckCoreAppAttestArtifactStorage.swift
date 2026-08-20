/*
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import GoogleUtilities_Environment

@objc(GACAppAttestArtifactStorageProtocol)
public protocol AppCheckCoreAppAttestArtifactStorageProtocol: NSObjectProtocol {
  @objc func setArtifact(_ artifact: Data?, forKey keyID: String) async throws -> Data?
  @objc func getArtifact(forKey keyID: String) async throws -> Data?
}

private let kKeychainService = "com.firebase.app_check.app_attest_artifact_storage"

@objc(GACAppAttestArtifactStorage)
public class AppCheckCoreAppAttestArtifactStorage: NSObject,
  AppCheckCoreAppAttestArtifactStorageProtocol {
  private let keySuffix: String
  private let keychainStorage: GULKeychainStorage
  private let accessGroup: String?

  @objc(initWithKeySuffix:keychainStorage:accessGroup:)
  public init(keySuffix: String, keychainStorage: GULKeychainStorage, accessGroup: String?) {
    self.keySuffix = keySuffix
    self.keychainStorage = keychainStorage
    self.accessGroup = accessGroup
    super.init()
  }

  @objc(initWithKeySuffix:accessGroup:)
  public convenience init(keySuffix: String, accessGroup: String?) {
    let keychainStorage = GULKeychainStorage(service: kKeychainService)
    self.init(keySuffix: keySuffix, keychainStorage: keychainStorage, accessGroup: accessGroup)
  }

  @objc
  public func getArtifact(forKey keyID: String) async throws -> Data? {
    do {
      let storedArtifact =
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
          NSSecureCoding?,
          Error
        >) in
          keychainStorage.getObjectForKey(
            artifactKey,
            objectClass: AppCheckCoreAppAttestStoredArtifact.self,
            accessGroup: accessGroup
          ) { result, error in
            if let error = error {
              continuation.resume(throwing: error)
            } else {
              continuation.resume(returning: result)
            }
          }
        }

      if let artifact = storedArtifact as? AppCheckCoreAppAttestStoredArtifact,
         artifact.keyID == keyID {
        return artifact.artifact
      } else {
        return nil
      }
    } catch {
      throw AppCheckCoreErrorUtil.keychainError(with: error)
    }
  }

  @objc
  public func setArtifact(_ artifact: Data?, forKey keyID: String) async throws -> Data? {
    if let artifact = artifact {
      return try await storeArtifact(artifact, forKey: keyID)
    } else {
      do {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
          Void,
          Error
        >) in
          keychainStorage.removeObject(forKey: artifactKey, accessGroup: accessGroup) { error in
            if let error = error {
              continuation.resume(throwing: error)
            } else {
              continuation.resume(returning: ())
            }
          }
        }
        return nil
      } catch {
        throw AppCheckCoreErrorUtil.keychainError(with: error)
      }
    }
  }

  private func storeArtifact(_ artifact: Data, forKey keyID: String) async throws -> Data {
    let storedArtifact = AppCheckCoreAppAttestStoredArtifact(keyID: keyID, artifact: artifact)

    do {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
        Void,
        Error
      >) in
        keychainStorage
          .setObject(storedArtifact, forKey: artifactKey,
                     accessGroup: accessGroup) { result, error in
            if let error = error {
              continuation.resume(throwing: error)
            } else {
              continuation.resume(returning: ())
            }
          }
      }
      return artifact
    } catch {
      throw AppCheckCoreErrorUtil.keychainError(with: error)
    }
  }

  private var artifactKey: String {
    return "app_check_app_attest_artifact.\(keySuffix)"
  }
}
