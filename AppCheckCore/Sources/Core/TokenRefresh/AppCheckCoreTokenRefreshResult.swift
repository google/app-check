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
public enum AppCheckCoreTokenRefreshStatus: Int {
  case never = 0
  case success = 1
  case failure = 2
}

@objc(GACAppCheckTokenRefreshResult)
@objcMembers
public class AppCheckCoreTokenRefreshResult: NSObject {
  public let status: AppCheckCoreTokenRefreshStatus
  public let tokenExpirationDate: Date?
  public let tokenReceivedAtDate: Date?

  public init(status: AppCheckCoreTokenRefreshStatus,
              expirationDate tokenExpirationDate: Date?,
              receivedAtDate tokenReceivedAtDate: Date?) {
    self.status = status
    self.tokenExpirationDate = tokenExpirationDate
    self.tokenReceivedAtDate = tokenReceivedAtDate
    super.init()
  }

  public convenience init(statusNever: ()) {
    self.init(status: .never, expirationDate: nil, receivedAtDate: nil)
  }

  public convenience init(statusFailure: ()) {
    self.init(status: .failure, expirationDate: nil, receivedAtDate: nil)
  }

  public convenience init(statusSuccessAndExpirationDate tokenExpirationDate: Date,
                          receivedAtDate tokenReceivedAtDate: Date) {
    self.init(
      status: .success,
      expirationDate: tokenExpirationDate,
      receivedAtDate: tokenReceivedAtDate
    )
  }
}
