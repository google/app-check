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
import Promises

@objc(GACAppAttestKeyIDStorageProtocol)
public protocol AppCheckCoreAppAttestKeyIDStorageProtocol: NSObjectProtocol {
  @objc(setAppAttestKeyID:)
  func setAppAttestKeyIDObjC(_ keyID: String?) -> FBLPromise<NSString>

  @objc(getAppAttestKeyID)
  func getAppAttestKeyIDObjC() -> FBLPromise<NSString>
}

public extension AppCheckCoreAppAttestKeyIDStorageProtocol {
  func getAppAttestKeyID() -> Promise<String> {
    let promise = getAppAttestKeyIDObjC()
    return Promise<NSString>(promise).then { nsString in
      Promise(nsString as String)
    }
  }

  func setAppAttestKeyID(_ keyID: String?) -> Promise<String?> {
    let promise = setAppAttestKeyIDObjC(keyID)
    return Promise<NSString?>(promise).then { nsStringOpt in
      Promise(nsStringOpt as String?)
    }
  }
}

@objc(GACAppAttestKeyIDStorage)
public final class AppCheckCoreAppAttestKeyIDStorage: NSObject,
  AppCheckCoreAppAttestKeyIDStorageProtocol, @unchecked Sendable {
  private let keySuffix: String
  private let userDefaults: GULUserDefaults

  private static let kKeyIDStorageDefaultsSuiteName = "com.firebase.GACAppAttestKeyIDStorage"

  @objc public init(keySuffix: String) {
    self.keySuffix = keySuffix
    userDefaults = GULUserDefaults(suiteName: Self.kKeyIDStorageDefaultsSuiteName)
    super.init()
  }

  public func getAppAttestKeyID() -> Promise<String> {
    guard let appAttestKeyID = userDefaults.object(forKey: keyIDStorageKey()) as? String else {
      return Promise(AppCheckCoreErrorUtil.appAttestKeyIDNotFound())
    }
    return Promise(appAttestKeyID)
  }

  public func setAppAttestKeyID(_ keyID: String?) -> Promise<String?> {
    if let keyID = keyID {
      userDefaults.setObject(keyID, forKey: keyIDStorageKey())
    } else {
      userDefaults.removeObject(forKey: keyIDStorageKey())
    }
    return Promise(keyID)
  }

  // MARK: - Objective-C Compatibility Bridge

  @objc(setAppAttestKeyID:)
  public func setAppAttestKeyIDObjC(_ keyID: String?) -> FBLPromise<NSString> {
    return setAppAttestKeyID(keyID).then { stringOpt -> NSString? in
      return stringOpt as NSString?
    }.asObjCPromise()
  }

  @objc(getAppAttestKeyID)
  public func getAppAttestKeyIDObjC() -> FBLPromise<NSString> {
    return getAppAttestKeyID().then { string -> NSString in
      return string as NSString
    }.asObjCPromise()
  }

  private func keyIDStorageKey() -> String {
    return "app_attest_keyID.\(keySuffix)"
  }
}
