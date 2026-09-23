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
public enum AppCheckCoreLogLevel: Int {
  case debug = 1
  case info = 2
  case warning = 3
  case error = 4
  case fault = 5
}

@objc(GACAppCheckLogger)
public class AppCheckCoreLogger: NSObject {
  private static let logLevelLock = NSLock()
  private static var _logLevel: AppCheckCoreLogLevel = .warning

  /// The current log level.
  ///
  /// Access is serialized by a lock to match the `atomic` semantics of the
  /// Objective-C `GACAppCheckLogger.logLevel` class property, which was backed
  /// by a `volatile` static.
  @objc public static var logLevel: AppCheckCoreLogLevel {
    get {
      logLevelLock.lock()
      defer { logLevelLock.unlock() }
      return _logLevel
    }
    set {
      logLevelLock.lock()
      defer { logLevelLock.unlock() }
      _logLevel = newValue
    }
  }

  public static func log(code: AppCheckCoreMessageCode, logLevel: AppCheckCoreLogLevel,
                         message: String) {
    // Don't log anything in non-debug builds.
    //
    // Note: this must be `DEBUG`, not `!NDEBUG`. `NDEBUG` is a C preprocessor
    // macro and is never defined as a Swift compilation condition, so
    // `#if !NDEBUG` is unconditionally true in Swift and would leak logging
    // (including the App Check debug token) into Release builds.
    #if DEBUG
      if logLevel.rawValue >= self.logLevel.rawValue {
        let levelString: String
        switch logLevel {
        case .fault: levelString = "Fault"
        case .error: levelString = "Error"
        case .warning: levelString = "Warning"
        case .info: levelString = "Info"
        case .debug: levelString = "Debug"
        @unknown default: levelString = "Unknown"
        }
        let codeString = String(format: "I-GAC%06ld", code.rawValue)
        // `NSLog` (rather than `print`) so output reaches the system log and is
        // visible in Console.app without a debugger attached, matching the
        // Objective-C implementation.
        NSLog("<%@> [AppCheckCore][%@] %@", levelString, codeString, message)
      }
    #endif
  }
}
