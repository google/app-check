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

@objc(GACAppAttestArtifactStorageProtocol)
public protocol AppCheckCoreAppAttestArtifactStorageProtocol: NSObjectProtocol {
  @objc(setArtifact:forKey:)
  func setArtifactObjC(_ artifact: Data?, forKey keyID: String) -> FBLPromise<NSData>

  @objc(getArtifactForKey:)
  func getArtifactForKeyObjC(_ keyID: String) -> FBLPromise<NSData>
}

public extension AppCheckCoreAppAttestArtifactStorageProtocol {
  func getArtifact(forKey keyID: String) -> Promise<Data?> {
    let promise = getArtifactForKeyObjC(keyID)
    return Promise<NSData?>(promise).then { nsDataOpt -> Promise<Data?> in
      return Promise(nsDataOpt as Data?)
    }
  }

  func setArtifact(_ artifact: Data?, forKey keyID: String) -> Promise<Data?> {
    let promise = setArtifactObjC(artifact, forKey: keyID)
    return Promise<NSData?>(promise).then { nsDataOpt -> Promise<Data?> in
      return Promise(nsDataOpt as Data?)
    }
  }
}

@objc(GACAppAttestArtifactStorage)
public final class AppCheckCoreAppAttestArtifactStorage: NSObject,
  AppCheckCoreAppAttestArtifactStorageProtocol, @unchecked Sendable {
  private let keySuffix: String
  private let keychainStorage: GULKeychainStorage
  private let accessGroup: String?

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

  public func getArtifact(forKey keyID: String) -> Promise<Data?> {
    return Promise<Data?> { fulfill, reject in
      self.keychainStorage.getObjectForKey(
        self.artifactKey(),
        objectClass: AppCheckCoreAppAttestStoredArtifact.self,
        accessGroup: self.accessGroup
      ) { storedArtifact, error in
        if let error = error {
          reject(AppCheckCoreErrorUtil.keychainError(with: error))
        } else if let storedArtifact = storedArtifact as? AppCheckCoreAppAttestStoredArtifact {
          if storedArtifact.keyID == keyID {
            fulfill(storedArtifact.artifact)
          } else {
            fulfill(nil)
          }
        } else {
          fulfill(nil)
        }
      }
    }
  }

  public func setArtifact(_ artifact: Data?, forKey keyID: String) -> Promise<Data?> {
    return Promise<Data?> { fulfill, reject in
      if let artifact = artifact {
        let storedArtifact = AppCheckCoreAppAttestStoredArtifact(keyID: keyID, artifact: artifact)
        self.keychainStorage.setObject(
          storedArtifact,
          forKey: self.artifactKey(),
          accessGroup: self.accessGroup
        ) { storedValue, error in
          if let error = error {
            reject(AppCheckCoreErrorUtil.keychainError(with: error))
          } else {
            fulfill(artifact)
          }
        }
      } else {
        self.keychainStorage.removeObject(
          forKey: self.artifactKey(),
          accessGroup: self.accessGroup
        ) { error in
          if let error = error {
            reject(AppCheckCoreErrorUtil.keychainError(with: error))
          } else {
            fulfill(nil)
          }
        }
      }
    }
  }

  // MARK: - Objective-C Compatibility Bridge

  @objc(setArtifact:forKey:)
  public func setArtifactObjC(_ artifact: Data?, forKey keyID: String) -> FBLPromise<NSData> {
    return setArtifact(artifact, forKey: keyID).then { dataOpt -> NSData? in
      return dataOpt as NSData?
    }.asObjCPromise()
  }

  @objc(getArtifactForKey:)
  public func getArtifactForKeyObjC(_ keyID: String) -> FBLPromise<NSData> {
    return getArtifact(forKey: keyID).then { dataOpt -> NSData? in
      return dataOpt as NSData?
    }.asObjCPromise()
  }

  private func artifactKey() -> String {
    return "app_check_app_attest_artifact.\(keySuffix)"
  }
}
