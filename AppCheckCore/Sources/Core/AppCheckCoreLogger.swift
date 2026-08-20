import Foundation

@objc(AppCheckCoreLogLevel)
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
