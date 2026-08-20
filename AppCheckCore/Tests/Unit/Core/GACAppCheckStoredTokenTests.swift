import XCTest
@testable import AppCheckCore

class GACAppCheckStoredTokenTests: XCTestCase {

  func testSecureCoding() throws {
    let tokenToArchive = GACAppCheckStoredToken()
    tokenToArchive.token = "some_token"
    tokenToArchive.expirationDate = Date()
    tokenToArchive.receivedAtDate = tokenToArchive.expirationDate?.addingTimeInterval(-10)

    let archivedToken = try NSKeyedArchiver.archivedData(withRootObject: tokenToArchive,
                                                         requiringSecureCoding: true)
    XCTAssertNotNil(archivedToken)

    let unarchivedToken = try NSKeyedUnarchiver.unarchivedObject(ofClass: GACAppCheckStoredToken.self,
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

    let storedToken = GACAppCheckStoredToken()
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
