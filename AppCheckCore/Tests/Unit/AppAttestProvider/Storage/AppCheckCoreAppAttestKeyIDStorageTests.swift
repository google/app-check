/*
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

@testable import AppCheckCore
import XCTest

private let kAppName = "AppCheckCoreAppAttestKeyIDStorageTestsApp"
private let kAppID = "app_id"

class AppCheckCoreAppAttestKeyIDStorageTests: XCTestCase {
  var keySuffix: String!
  var storage: AppCheckCoreAppAttestKeyIDStorage!

  override func setUp() {
    super.setUp()
    keySuffix = "\(kAppName).\(kAppID)"
    storage = AppCheckCoreAppAttestKeyIDStorage(keySuffix: keySuffix)
  }

  override func tearDown() async throws {
    // Remove the app attest key ID from storage.
    _ = try? await storage.setAppAttestKeyID(nil)
    storage = nil
    try await super.tearDown()
  }

  func testInitWithApp() {
    XCTAssertNotNil(AppCheckCoreAppAttestKeyIDStorage(keySuffix: keySuffix))
  }

  func testSetAndGetAppAttestKeyID() async throws {
    let appAttestKeyID = "app_attest_key_ID"

    let setKeyID = try await storage.setAppAttestKeyID(appAttestKeyID)
    XCTAssertEqual(setKeyID, appAttestKeyID)

    let getKeyID = try await storage.getAppAttestKeyID()
    XCTAssertEqual(getKeyID, appAttestKeyID)
  }

  func testRemoveAppAttestKeyID() async throws {
    let setKeyID = try await storage.setAppAttestKeyID(nil)
    XCTAssertNil(setKeyID)
  }

  func testGetAppAttestKeyID_WhenAppAttestKeyIDNotFoundError() async {
    do {
      _ = try await storage.getAppAttestKeyID()
      XCTFail("Expected getAppAttestKeyID to throw.")
    } catch {
      let nsError = error as NSError
      let expectedError = AppCheckCoreErrorUtil.appAttestKeyIDNotFound() as NSError
      XCTAssertEqual(nsError.domain, expectedError.domain)
      XCTAssertEqual(nsError.code, expectedError.code)
    }
  }

  func testSetGetAppAttestKeyIDPerApp() async throws {
    // Assert storages for apps with the same name can independently set/get app attest key ID.
    try await assertIndependentSetGetForStorages(
      appName1: kAppName,
      appID1: "app_id_1",
      appName2: kAppName,
      appID2: "app_id_2"
    )
    // Assert storages for apps with the same app ID can independently set/get app attest key ID.
    try await assertIndependentSetGetForStorages(
      appName1: "app_1",
      appID1: kAppID,
      appName2: "app_2",
      appID2: kAppID
    )
    // Assert storages for apps with different info can independently set/get app attest key ID.
    try await assertIndependentSetGetForStorages(
      appName1: "app_1",
      appID1: "app_id_1",
      appName2: "app_2",
      appID2: "app_id_2"
    )
  }

  // MARK: - Helpers

  func assertIndependentSetGetForStorages(appName1: String,
                                          appID1: String,
                                          appName2: String,
                                          appID2: String) async throws {
    let keySuffix1 = AppCheckCoreAppAttestKeyIDStorageTests.storageKeySuffix(
      appName: appName1,
      appID: appID1
    )
    let keySuffix2 = AppCheckCoreAppAttestKeyIDStorageTests.storageKeySuffix(
      appName: appName2,
      appID: appID2
    )

    // Create two storages.
    let storage1 = AppCheckCoreAppAttestKeyIDStorage(keySuffix: keySuffix1)
    let storage2 = AppCheckCoreAppAttestKeyIDStorage(keySuffix: keySuffix2)

    // 1. Independently set app attest key IDs for the two storages.
    let appAttestKeyID1 = "app_attest_key_ID1"
    let setKeyID1 = try await storage1.setAppAttestKeyID(appAttestKeyID1)
    XCTAssertEqual(setKeyID1, appAttestKeyID1)

    let appAttestKeyID2 = "app_attest_key_ID2"
    let setKeyID2 = try await storage2.setAppAttestKeyID(appAttestKeyID2)
    XCTAssertEqual(setKeyID2, appAttestKeyID2)

    // 2. Get app attest key IDs for the two storages.
    let getKeyID1 = try await storage1.getAppAttestKeyID()
    XCTAssertEqual(getKeyID1, appAttestKeyID1)

    let getKeyID2 = try await storage2.getAppAttestKeyID()
    XCTAssertEqual(getKeyID2, appAttestKeyID2)

    // 3. Assert that the app attest key IDs were set and retrieved independently of one another.
    XCTAssertNotEqual(getKeyID1, getKeyID2)

    // Cleanup storages.
    _ = try await storage1.setAppAttestKeyID(nil)
    _ = try await storage2.setAppAttestKeyID(nil)
  }

  static func storageKeySuffix(appName: String, appID: String) -> String {
    return "\(appName).\(appID)"
  }
}
