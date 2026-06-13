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

@objc(GACAppCheckTokenResult)
public final class AppCheckCoreTokenResult: NSObject, Sendable {
  @objc public let token: AppCheckCoreToken
  @objc public let error: Error?

  @objc public init(token: AppCheckCoreToken, error: Error?) {
    self.token = token
    self.error = error
    super.init()
  }

  @objc public convenience init(token: AppCheckCoreToken) {
    self.init(token: token, error: nil)
  }

  @objc public convenience init(error: Error) {
    self.init(token: Self.placeholderToken(), error: error)
  }

  @objc static func placeholderToken() -> AppCheckCoreToken {
    let placeholderTokenValue = "eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ=="
    return AppCheckCoreToken(token: placeholderTokenValue, expirationDate: Date.distantPast)
  }
}
