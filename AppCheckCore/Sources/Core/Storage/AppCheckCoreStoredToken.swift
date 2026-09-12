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

/// Explicit Objective-C class name registration for NSSecureCoding backward compatibility.
/// Do not rename or remove: required to unarchive legacy data stored by Objective-C versions of the
/// SDK.
@objc(GACAppCheckStoredToken)
@objcMembers
public class AppCheckCoreStoredToken: NSObject, NSSecureCoding {
  private static let kTokenKey = "token"
  private static let kExpirationDateKey = "expirationDate"
  private static let kReceivedAtDateKey = "receivedAtDate"
  private static let kStorageVersionKey = "storageVersion"

  private static let kStorageVersion: Int = 2

  public var token: String?
  public var expirationDate: Date?
  public var receivedAtDate: Date?

  public var storageVersion: Int {
    return Self.kStorageVersion
  }

  public static var supportsSecureCoding: Bool {
    return true
  }

  override public init() {
    super.init()
  }

  public func encode(with coder: NSCoder) {
    coder.encode(token, forKey: Self.kTokenKey)
    coder.encode(expirationDate, forKey: Self.kExpirationDateKey)
    coder.encode(receivedAtDate, forKey: Self.kReceivedAtDateKey)
    coder.encode(storageVersion, forKey: Self.kStorageVersionKey)
  }

  public required init?(coder: NSCoder) {
    super.init()
    let decodedStorageVersion = coder.decodeInteger(forKey: Self.kStorageVersionKey)
    if decodedStorageVersion > Self.kStorageVersion {
      // TODO: Log a message.
    }

    token = coder.decodeObject(of: NSString.self, forKey: Self.kTokenKey) as String?
    expirationDate = coder.decodeObject(of: NSDate.self, forKey: Self.kExpirationDateKey) as Date?
    receivedAtDate = coder.decodeObject(of: NSDate.self, forKey: Self.kReceivedAtDateKey) as Date?
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
      receivedAt: receivedAtDate
    )
  }
}
