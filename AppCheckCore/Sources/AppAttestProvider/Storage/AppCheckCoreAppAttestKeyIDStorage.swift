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
  import GoogleUtilities_UserDefaults
#endif

@objc(GACAppAttestKeyIDStorageProtocol)
public protocol AppCheckCoreAppAttestKeyIDStorageProtocol: NSObjectProtocol {
  @objc func setAppAttestKeyID(_ keyID: String?) async throws -> String?
  @objc func getAppAttestKeyID() async throws -> String?
}

@objc(GACAppAttestKeyIDStorage)
public class AppCheckCoreAppAttestKeyIDStorage: NSObject,
  AppCheckCoreAppAttestKeyIDStorageProtocol {
  /// Suite name for the app attest key ID in UserDefaults.
  /// Do not rename: retains the "GAC" prefix for compatibility with existing stored data from v11
  /// or lower.
  static let keyIDStorageDefaultsSuiteName = "com.firebase.GACAppAttestKeyIDStorage"

  private let keySuffix: String
  private let userDefaults: GULUserDefaults

  @objc(initWithKeySuffix:)
  public init(keySuffix: String) {
    self.keySuffix = keySuffix
    userDefaults = GULUserDefaults(suiteName: Self.keyIDStorageDefaultsSuiteName)
    super.init()
  }

  @objc
  public func setAppAttestKeyID(_ keyID: String?) async throws -> String? {
    if let keyID = keyID {
      userDefaults.setObject(keyID, forKey: keyIDStorageKey)
    } else {
      userDefaults.removeObject(forKey: keyIDStorageKey)
    }
    return keyID
  }

  @objc
  public func getAppAttestKeyID() async throws -> String? {
    if let appAttestKeyID = userDefaults.object(forKey: keyIDStorageKey) as? String {
      return appAttestKeyID
    } else {
      throw AppCheckCoreErrorUtil.appAttestKeyIDNotFound()
    }
  }

  private var keyIDStorageKey: String {
    return "app_attest_keyID.\(keySuffix)"
  }
}
