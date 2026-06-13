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
public final class AppCheckCoreToken: NSObject, Sendable {
  @objc public let token: String
  @objc public let expirationDate: Date
  @objc public let receivedAtDate: Date

  @objc public init(token: String, expirationDate: Date, receivedAtDate: Date) {
    self.token = token
    self.expirationDate = expirationDate
    self.receivedAtDate = receivedAtDate
    super.init()
  }

  @objc public convenience init(token: String, expirationDate: Date) {
    self.init(token: token, expirationDate: expirationDate, receivedAtDate: Date())
  }
}

public extension AppCheckCoreToken {
  @objc(initWithTokenExchangeResponse:requestDate:error:)
  convenience init(tokenExchangeResponse response: Data, requestDate: Date) throws {
    if response.isEmpty {
      throw AppCheckCoreErrorUtil.error(withFailureReason: "Empty server response body.")
    }

    let responseDict: [String: Any]
    do {
      responseDict = try JSONSerialization
        .jsonObject(with: response, options: []) as? [String: Any] ?? [:]
    } catch {
      throw AppCheckCoreErrorUtil.JSONSerializationError(error)
    }

    try self.init(responseDict: responseDict, requestDate: requestDate)
  }

  @objc(initWithResponseDict:requestDate:error:)
  convenience init(responseDict: [String: Any], requestDate: Date) throws {
    guard let token = responseDict["token"] as? String else {
      throw AppCheckCoreErrorUtil.appCheckTokenResponseError(withMissingField: "token")
    }

    guard let timeToLiveString = responseDict["ttl"] as? String else {
      throw AppCheckCoreErrorUtil.appCheckTokenResponseError(withMissingField: "ttl")
    }

    let timeToLiveValueString = timeToLiveString.replacingOccurrences(of: "s", with: "")
    guard let secondsToLive = Double(timeToLiveValueString), secondsToLive > 0 else {
      throw AppCheckCoreErrorUtil.appCheckTokenResponseError(withMissingField: "ttl")
    }

    let expirationDate = requestDate.addingTimeInterval(secondsToLive)
    self.init(token: token, expirationDate: expirationDate, receivedAtDate: requestDate)
  }
}
