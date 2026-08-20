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
@objcMembers
public class AppCheckCoreLogger: NSObject {
  private static var _logLevel: AppCheckCoreLogLevel = .warning

  public static var logLevel: AppCheckCoreLogLevel {
    get { return _logLevel }
    set { _logLevel = newValue }
  }

  public static func log(code: AppCheckCoreMessageCode, logLevel: AppCheckCoreLogLevel,
                         message: String) {
    #if !NDEBUG
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
        print("<\(levelString)> [AppCheckCore][\(codeString)] \(message)")
      }
    #endif
  }
}
