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

@objc(GACAppCheckTokenRefreshStatus)
public enum AppCheckCoreTokenRefreshStatus: Int, Sendable {
  case never
  case success
  case failure
}

@objc(GACAppCheckTokenRefreshResult)
public final class AppCheckCoreTokenRefreshResult: NSObject, Sendable {
  @objc public let status: AppCheckCoreTokenRefreshStatus
  @objc public let tokenExpirationDate: Date?
  @objc public let tokenReceivedAtDate: Date?

  private init(status: AppCheckCoreTokenRefreshStatus, expirationDate: Date?,
               receivedAtDate: Date?) {
    self.status = status
    tokenExpirationDate = expirationDate
    tokenReceivedAtDate = receivedAtDate
    super.init()
  }

  @objc public convenience init(statusNever: ()) {
    self.init(status: .never, expirationDate: nil, receivedAtDate: nil)
  }

  @objc public convenience init(statusFailure: ()) {
    self.init(status: .failure, expirationDate: nil, receivedAtDate: nil)
  }

  @objc public convenience init(statusSuccessAndExpirationDate expirationDate: Date,
                                receivedAtDate: Date) {
    self.init(status: .success, expirationDate: expirationDate, receivedAtDate: receivedAtDate)
  }

  // Bridging initializers for Objective-C:
  @objc public convenience init(statusNever: Bool) {
    self.init(status: .never, expirationDate: nil, receivedAtDate: nil)
  }

  @objc public convenience init(statusFailure: Bool) {
    self.init(status: .failure, expirationDate: nil, receivedAtDate: nil)
  }
}

// Extension to expose the parameterless initializers to Objective-C under their original names.
// Note: In Swift, parameterless init() can conflict or have name mapping issues if they return
// GACAppCheckTokenRefreshResult.
// We can use objc selectors:
public extension AppCheckCoreTokenRefreshResult {
  @objc(initWithStatusNever)
  static func makeWithStatusNever() -> AppCheckCoreTokenRefreshResult {
    return AppCheckCoreTokenRefreshResult(status: .never, expirationDate: nil, receivedAtDate: nil)
  }

  @objc(initWithStatusFailure)
  static func makeWithStatusFailure() -> AppCheckCoreTokenRefreshResult {
    return AppCheckCoreTokenRefreshResult(
      status: .failure,
      expirationDate: nil,
      receivedAtDate: nil
    )
  }

  @objc(initWithStatusSuccessAndExpirationDate:receivedAtDate:)
  static func makeWithSuccess(expirationDate: Date,
                              receivedAtDate: Date) -> AppCheckCoreTokenRefreshResult {
    return AppCheckCoreTokenRefreshResult(
      status: .success,
      expirationDate: expirationDate,
      receivedAtDate: receivedAtDate
    )
  }
}
