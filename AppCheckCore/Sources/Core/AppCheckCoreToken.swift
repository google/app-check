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

@objc(GACAppCheckToken)
@objcMembers
public class AppCheckCoreToken: NSObject, @unchecked Sendable {
  public let token: String
  public let expirationDate: Date
  public let receivedAtDate: Date

  @objc(initWithToken:expirationDate:receivedAtDate:)
  public init(token: String, expirationDate: Date, receivedAt receivedAtDate: Date) {
    self.token = token
    self.expirationDate = expirationDate
    self.receivedAtDate = receivedAtDate
    super.init()
  }

  public convenience init(token: String, expirationDate: Date) {
    self.init(token: token, expirationDate: expirationDate, receivedAt: Date())
  }
}
