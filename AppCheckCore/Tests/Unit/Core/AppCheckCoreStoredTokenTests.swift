import XCTest
@testable import AppCheckCore

class AppCheckCoreStoredTokenTests: XCTestCase {

  func testSecureCoding() throws {
    let tokenToArchive = AppCheckCoreStoredToken()
    tokenToArchive.token = "some_token"
    tokenToArchive.expirationDate = Date()
    tokenToArchive.receivedAtDate = tokenToArchive.expirationDate?.addingTimeInterval(-10)

    let archivedToken = try NSKeyedArchiver.archivedData(withRootObject: tokenToArchive,
                                                         requiringSecureCoding: true)
    XCTAssertNotNil(archivedToken)

    let unarchivedToken = try NSKeyedUnarchiver.unarchivedObject(ofClass: AppCheckCoreStoredToken.self,
                                                                 from: archivedToken)
    XCTAssertNotNil(unarchivedToken)
    XCTAssertEqual(unarchivedToken?.token, tokenToArchive.token)
    XCTAssertEqual(unarchivedToken?.expirationDate, tokenToArchive.expirationDate)
    XCTAssertEqual(unarchivedToken?.receivedAtDate, tokenToArchive.receivedAtDate)
    XCTAssertEqual(unarchivedToken?.storageVersion, tokenToArchive.storageVersion)
  }

  func testConvertingToAndFromAppCheckCoreToken() {
    let date = Date()
    let originalToken = AppCheckCoreToken(token: "___",
                                         expirationDate: date,
                                         receivedAtDate: date)

    let storedToken = AppCheckCoreStoredToken()
    storedToken.update(with: originalToken)
    XCTAssertEqual(originalToken.token, storedToken.token)
    XCTAssertEqual(originalToken.expirationDate, storedToken.expirationDate)
    XCTAssertEqual(originalToken.receivedAtDate, storedToken.receivedAtDate)

    let recoveredToken = storedToken.appCheckToken()
    XCTAssertNotNil(recoveredToken)
    XCTAssertEqual(recoveredToken?.token, storedToken.token)
    XCTAssertEqual(recoveredToken?.expirationDate, storedToken.expirationDate)
    XCTAssertEqual(recoveredToken?.receivedAtDate, storedToken.receivedAtDate)
  }
}
