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

@objc(GACAppCheckStoredToken)
public final class AppCheckCoreStoredToken: NSObject, NSSecureCoding, @unchecked Sendable {
  @objc public var token: String?
  @objc public var expirationDate: Date?
  @objc public var receivedAtDate: Date?

  @objc public var storageVersion: Int {
    return 2
  }

  @objc public static var supportsSecureCoding: Bool {
    return true
  }

  @objc override public init() {
    super.init()
  }

  @objc public init?(coder: NSCoder) {
    let decodedStorageVersion = coder.decodeInteger(forKey: "storageVersion")
    if decodedStorageVersion > 2 {
      // TODO: Log a message.
    }

    token = coder.decodeObject(of: NSString.self, forKey: "token") as String?
    expirationDate = coder.decodeObject(of: NSDate.self, forKey: "expirationDate") as Date?
    receivedAtDate = coder.decodeObject(of: NSDate.self, forKey: "receivedAtDate") as Date?
    super.init()
  }

  @objc public func encode(with coder: NSCoder) {
    coder.encode(token, forKey: "token")
    coder.encode(expirationDate, forKey: "expirationDate")
    coder.encode(receivedAtDate, forKey: "receivedAtDate")
    coder.encode(storageVersion, forKey: "storageVersion")
  }

  @objc(updateWithToken:) public func update(with token: AppCheckCoreToken) {
    self.token = token.token
    expirationDate = token.expirationDate
    receivedAtDate = token.receivedAtDate
  }

  @objc public func appCheckToken() -> AppCheckCoreToken? {
    guard let token = token,
          let expirationDate = expirationDate,
          let receivedAtDate = receivedAtDate else {
      return nil
    }
    return AppCheckCoreToken(
      token: token,
      expirationDate: expirationDate,
      receivedAtDate: receivedAtDate
    )
  }
}
