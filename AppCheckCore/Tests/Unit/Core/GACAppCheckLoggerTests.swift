import XCTest
@testable import AppCheckCore

class AppCheckCoreLoggerTests: XCTestCase {
  func testDefaultLogLevel() {
    let defaultLogLevel = AppCheckCoreLogger.logLevel
    
    XCTAssertEqual(defaultLogLevel, .warning)
  }
  
  func testSetLogLevel() {
    let expectedLogLevel: AppCheckCoreLogLevel = .debug
    
    AppCheckCoreLogger.logLevel = expectedLogLevel
    
    XCTAssertEqual(AppCheckCoreLogger.logLevel, expectedLogLevel)
  }
}
