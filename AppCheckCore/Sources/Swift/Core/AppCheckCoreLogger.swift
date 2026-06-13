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

@objc(GACAppCheckLogLevel)
public enum AppCheckCoreLogLevel: Int, Sendable {
  case debug = 1
  case info = 2
  case warning = 3
  case error = 4
  case fault = 5
}

@objc(GACAppCheckLogger)
public final class AppCheckCoreLogger: NSObject, Sendable {
  private static var lock = os_unfair_lock()
  private static var _logLevel: AppCheckCoreLogLevel = .warning

  @objc public static var logLevel: AppCheckCoreLogLevel {
    get {
      os_unfair_lock_lock(&lock)
      defer { os_unfair_lock_unlock(&lock) }
      return _logLevel
    }
    set {
      os_unfair_lock_lock(&lock)
      defer { os_unfair_lock_unlock(&lock) }
      _logLevel = newValue
    }
  }

  override private init() {}
}

@_cdecl("GACAppCheckLog")
public func GACAppCheckLog(code: AppCheckCoreMessageCode, logLevel: AppCheckCoreLogLevel,
                           message: NSString) {
  #if DEBUG
    if logLevel.rawValue >= AppCheckCoreLogger.logLevel.rawValue {
      let messageCodeStr = String(format: "I-GAC%06ld", code.rawValue)
      let logLevelStr: String
      switch logLevel {
      case .debug: logLevelStr = "Debug"
      case .info: logLevelStr = "Info"
      case .warning: logLevelStr = "Warning"
      case .error: logLevelStr = "Error"
      case .fault: logLevelStr = "Fault"
      @unknown default: logLevelStr = "Unknown"
      }
      NSLog("<%@> [AppCheckCore][%@] %@", logLevelStr, messageCodeStr, message)
    }
  #endif
}
