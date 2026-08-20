import XCTest
@testable import AppCheckCore

class GACAppCheckCryptoUtilsTests: XCTestCase {
  func testSHA256HashFromData() {
    let dataToHash = "some data to hash".data(using: .utf8)!
    
    let hashData = GACAppCheckCryptoUtils.sha256Hash(from: dataToHash)
    
    // Convert to a base64 encoded string to compare.
    let base64EncodedHashString = hashData.base64EncodedString()
    
    // Base64 encoded hash of UTF8 encoded string "some data to hash".
    let expectedHashString = "ai2iCUOTHpg0/BLP5btHu9muQ0iaMHJpYrV29OOZPlA="
    
    XCTAssertEqual(base64EncodedHashString, expectedHashString)
  }
}
