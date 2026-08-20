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
@objcMembers
public class AppCheckCoreStoredToken: NSObject, NSSecureCoding {
  private let kTokenKey = "token"
  private let kExpirationDateKey = "expirationDate"
  private let kReceivedAtDateKey = "receivedAtDate"
  private let kStorageVersionKey = "storageVersion"

  private let kStorageVersion: Int = 2

  public var token: String?
  public var expirationDate: Date?
  public var receivedAtDate: Date?

  public var storageVersion: Int {
    return kStorageVersion
  }

  public static var supportsSecureCoding: Bool {
    return true
  }

  override public init() {
    super.init()
  }

  public func encode(with coder: NSCoder) {
    coder.encode(token, forKey: kTokenKey)
    coder.encode(expirationDate, forKey: kExpirationDateKey)
    coder.encode(receivedAtDate, forKey: kReceivedAtDateKey)
    coder.encode(storageVersion, forKey: kStorageVersionKey)
  }

  public required init?(coder: NSCoder) {
    super.init()
    let decodedStorageVersion = coder.decodeInteger(forKey: kStorageVersionKey)
    if decodedStorageVersion > kStorageVersion {
      // TODO: Log a message.
    }

    token = coder.decodeObject(of: NSString.self, forKey: kTokenKey) as String?
    expirationDate = coder.decodeObject(of: NSDate.self, forKey: kExpirationDateKey) as Date?
    receivedAtDate = coder.decodeObject(of: NSDate.self, forKey: kReceivedAtDateKey) as Date?
  }
}

public extension AppCheckCoreStoredToken {
  @objc func update(with token: AppCheckCoreToken) {
    self.token = token.token
    expirationDate = token.expirationDate
    receivedAtDate = token.receivedAtDate
  }

  @objc func appCheckToken() -> AppCheckCoreToken? {
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
