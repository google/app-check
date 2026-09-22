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

@testable import AppCheckCore
import XCTest

private let kTestTokenValue = "test-token"
/// Placeholder value that indicates failure: `{"error":"UNKNOWN_ERROR"}` encoded as base64
private let kPlaceholderTokenValue = "eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ=="
private let kTestErrorDomain = "TestErrorDomain"
private let kTestErrorCode = 42

class AppCheckCoreTokenResultTests: XCTestCase {
  func testInitWithToken() {
    let expectedExpirationDate = Date(timeIntervalSince1970: 1_693_314_000.0)
    let expectedReceivedAtDate = Date(timeIntervalSince1970: 1_693_317_600.0)
    let expectedToken = AppCheckCoreToken(token: kTestTokenValue,
                                          expirationDate: expectedExpirationDate,
                                          receivedAt: expectedReceivedAtDate)

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
    XCTAssertEqual(
      placeholderToken.receivedAtDate.timeIntervalSince(expectedReceivedAtDate),
      0,
      accuracy: 5.0
    )
    XCTAssertEqual(placeholderToken.expirationDate, expectedExpirationDate)
  }
}
