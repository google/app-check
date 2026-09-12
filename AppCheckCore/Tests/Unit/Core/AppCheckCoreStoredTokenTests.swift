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

class AppCheckCoreStoredTokenTests: XCTestCase {
  // IMMUTABLE TEST: Do not edit, update, or remove under any circumstance.
  // This test locks in an immutable backwards compatibility contract with App Check 11.
  // If this test fails, revert changes to the implementation instead of modifying this test.
  func testKeychainService_MatchesContract() {
    XCTAssertEqual(
      AppCheckCoreStorage.keychainService,
      "com.google.app_check_core.token_storage",
      "Keychain service name mismatch breaks App Check 11 migration compatibility."
    )
  }

  func testLegacyStoredTokenCompatibility() throws {
    let fixtureData = try AppCheckCoreFixtureLoader.loadFixture(named: "GACAppCheckStoredToken.bin")

    let unarchived = try XCTUnwrap(
      NSKeyedUnarchiver.unarchivedObject(
        ofClass: AppCheckCoreStoredToken.self,
        from: fixtureData
      ),
      "Failed to unarchive legacy GACAppCheckStoredToken binary fixture."
    )

    XCTAssertEqual(
      unarchived.token,
      "test_legacy_app_check_token_value",
      "Token mismatch when unarchiving legacy GACAppCheckStoredToken."
    )
    XCTAssertEqual(
      unarchived.expirationDate,
      Date(timeIntervalSince1970: 1_800_000_000),
      "Expiration date mismatch when unarchiving legacy GACAppCheckStoredToken."
    )
    XCTAssertEqual(
      unarchived.receivedAtDate,
      Date(timeIntervalSince1970: 1_700_000_000),
      "Received at date mismatch when unarchiving legacy GACAppCheckStoredToken."
    )
    XCTAssertEqual(
      unarchived.storageVersion,
      2,
      "Storage version mismatch when unarchiving legacy GACAppCheckStoredToken."
    )

    let appCheckToken = try XCTUnwrap(unarchived.appCheckToken())
    XCTAssertEqual(appCheckToken.token, "test_legacy_app_check_token_value")
    XCTAssertEqual(appCheckToken.expirationDate, Date(timeIntervalSince1970: 1_800_000_000))
    XCTAssertEqual(appCheckToken.receivedAtDate, Date(timeIntervalSince1970: 1_700_000_000))
  }

  func testSecureCoding() throws {
    let tokenToArchive = AppCheckCoreStoredToken()
    tokenToArchive.token = "some_token"
    tokenToArchive.expirationDate = Date()
    tokenToArchive.receivedAtDate = tokenToArchive.expirationDate?.addingTimeInterval(-10)

    let archivedToken = try NSKeyedArchiver.archivedData(withRootObject: tokenToArchive,
                                                         requiringSecureCoding: true)
    XCTAssertNotNil(archivedToken)

    let unarchivedToken = try NSKeyedUnarchiver.unarchivedObject(
      ofClass: AppCheckCoreStoredToken.self,
      from: archivedToken
    )
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
                                          receivedAt: date)

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
