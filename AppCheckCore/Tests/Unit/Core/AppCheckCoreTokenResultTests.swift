import XCTest
@testable import AppCheckCore

private let kTestTokenValue = "test-token"
/// Placeholder value that indicates failure: `{"error":"UNKNOWN_ERROR"}` encoded as base64
private let kPlaceholderTokenValue = "eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ=="
private let kTestErrorDomain = "TestErrorDomain"
private let kTestErrorCode = 42

class AppCheckCoreTokenResultTests: XCTestCase {
  
  func testInitWithToken() {
    let expectedExpirationDate = Date(timeIntervalSince1970: 1693314000.0)
    let expectedReceivedAtDate = Date(timeIntervalSince1970: 1693317600.0)
    let expectedToken = AppCheckCoreToken(token: kTestTokenValue,
                                         expirationDate: expectedExpirationDate,
                                         receivedAtDate: expectedReceivedAtDate)
    
    let tokenResult = AppCheckCoreTokenResult(token: expectedToken)
    
    XCTAssertEqual(tokenResult.token, expectedToken)
    XCTAssertNil(tokenResult.error)
  }
  
  func testInitWithError() {
    let expectedError = NSError(domain: kTestErrorDomain,
                                code: kTestErrorCode,
                                userInfo: nil)
    
    let tokenResult = AppCheckCoreTokenResult(error: expectedError)
    
    XCTAssertEqual(tokenResult.token.token, kPlaceholderTokenValue)
    XCTAssertNotNil(tokenResult.error)
    XCTAssertEqual(tokenResult.error as NSError?, expectedError)
  }
  
  func testInitWithTokenAndError() {
    let placeholderToken = AppCheckCoreTokenResult.placeholderToken()
    let expectedError = NSError(domain: kTestErrorDomain,
                                code: kTestErrorCode,
                                userInfo: nil)
    
    let tokenResult = AppCheckCoreTokenResult(token: placeholderToken, error: expectedError)
    
    XCTAssertEqual(tokenResult.token, placeholderToken)
    XCTAssertNotNil(tokenResult.error)
    XCTAssertEqual(tokenResult.error as NSError?, expectedError)
  }
  
  func testPlaceholderToken() {
    let expectedExpirationDate = Date.distantPast
    let expectedReceivedAtDate = Date() // Current time
    
    let placeholderToken = AppCheckCoreTokenResult.placeholderToken()
    
    XCTAssertEqual(placeholderToken.token, kPlaceholderTokenValue)
    // Verify that the placeholder token's received at time is approximately equal to current time.
    XCTAssertEqual(placeholderToken.receivedAtDate.timeIntervalSince(expectedReceivedAtDate), 0, accuracy: 5.0)
    XCTAssertEqual(placeholderToken.expirationDate, expectedExpirationDate)
  }
}
