import XCTest
@testable import AppCheckCore

class GACAppCheckLoggerTests: XCTestCase {
  func testDefaultLogLevel() {
    let defaultLogLevel = GACAppCheckLogger.logLevel
    
    XCTAssertEqual(defaultLogLevel, .warning)
  }
  
  func testSetLogLevel() {
    let expectedLogLevel: GACAppCheckLogLevel = .debug
    
    GACAppCheckLogger.logLevel = expectedLogLevel
    
    XCTAssertEqual(GACAppCheckLogger.logLevel, expectedLogLevel)
  }
}
