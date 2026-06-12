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

public let AppCheckCoreErrorDomain: String = "com.google.app_check_core"

@objc(GACAppCheckErrorCode)
public enum AppCheckCoreErrorCode: Int, Error {
  case unknown = 0
  case serverUnreachable = 1
  case invalidConfiguration = 2
  case keychain = 3
  case unsupported = 4
}

extension AppCheckCoreErrorCode: CustomNSError {
  public static var errorDomain: String {
    return AppCheckCoreErrorDomain
  }

  public var errorCode: Int {
    return rawValue
  }

  public var errorUserInfo: [String: Any] {
    return [:]
  }
}

@objc(GACAppCheckMessageCode)
public enum AppCheckCoreMessageCode: Int {
  case loggerAppCheckMessageCodeUnknown = 1001

  // App Check
  case loggerAppCheckMessageCodeProviderIsMissing = 2002
  case loggerAppCheckMessageCodeStagingModeEnabled = 2003
  case loggerAppCheckMessageCodeUnexpectedHTTPCode = 3001

  // Debug Provider
  case loggerAppCheckMessageLocalDebugToken = 4001
  case loggerAppCheckMessageEnvironmentVariableDebugToken = 4002
  case loggerAppCheckMessageDebugProviderFirebaseEnvironmentVariable = 4003
  case loggerAppCheckMessageDebugProviderFailedExchange = 4004

  // App Attest Provider
  case loggerAppCheckMessageCodeAppAttestNotSupported = 7001
  case loggerAppCheckMessageCodeAttestationRejected = 7002
  case loggerAppCheckMessageCodeAssertionRejected = 7003
}
