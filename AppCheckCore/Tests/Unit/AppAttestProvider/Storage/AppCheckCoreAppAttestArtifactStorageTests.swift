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

private let kAppName = "AppCheckCoreAppAttestArtifactStorageTests"
private let kAppID = "1:100000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa"

// Tests that use the Keychain require a host app and Swift Package Manager
// does not support adding a host app to test targets.
#if !SWIFT_PACKAGE

  // Skip keychain tests on Catalyst and macOS. Tests are skipped because they
  // involve interactions with the keychain that require a provisioning profile.
  // See go/firebase-macos-keychain-popups for more details.
  #if !targetEnvironment(macCatalyst) && !os(macOS)

    class AppCheckCoreAppAttestArtifactStorageTests: XCTestCase {
      var keySuffix: String!
      var storage: AppCheckCoreAppAttestArtifactStorage!

      override func setUp() {
        super.setUp()

        keySuffix = AppCheckCoreAppAttestArtifactStorageTests.artifactKeySuffix(
          appName: kAppName,
          appID: kAppID
        )
        storage = AppCheckCoreAppAttestArtifactStorage(keySuffix: keySuffix, accessGroup: nil)
      }

      override func tearDown() {
        storage = nil
        super.tearDown()
      }

      func testSetAndGetArtifact() async throws {
        _ = try await assertSetGetForStorage()
      }

      func testRemoveArtifact() async throws {
        let keyID = UUID().uuidString

        // 1. Save an artifact to storage and check it is stored.
        _ = try await assertSetGetForStorage()

        // 2. Remove artifact.
        let setArtifact = try await storage.setArtifact(nil, forKey: keyID)
        XCTAssertNil(setArtifact)

        // 3. Check it has been removed.
        let getArtifact = try await storage.getArtifact(forKey: keyID)
        XCTAssertNil(getArtifact)
      }

      func testSetAndGetPerApp() async throws {
        // Assert storages for apps with the same name can independently set/get artifact.
        try await assertIndependentSetGetForStorages(
          appName1: kAppName,
          appID1: "app_id_1",
          appName2: kAppName,
          appID2: "app_id_2"
        )
        // Assert storages for apps with the same app ID can independently set/get artifact.
        try await assertIndependentSetGetForStorages(
          appName1: "app_1",
          appID1: kAppID,
          appName2: "app_2",
          appID2: kAppID
        )
        // Assert storages for apps with different info can independently set/get artifact.
        try await assertIndependentSetGetForStorages(
          appName1: "app_1",
          appID1: "app_id_1",
          appName2: "app_2",
          appID2: "app_id_2"
        )
      }

      func testSetArtifactForOneKeyGetForAnotherKey() async throws {
        // Set an artifact for a key.
        _ = try await assertSetGetForStorage()

        // Try to get artifact for a different key.
        let keyID = UUID().uuidString
        let getArtifact = try await storage.getArtifact(forKey: keyID)
        XCTAssertNil(getArtifact)
      }

      func testSetArtifactForNewKeyRemovesArtifactForOldKey() async throws {
        // 1. Store an artifact.
        let oldKeyID = try await assertSetGetForStorage()

        // 2. Replace the artifact.
        let newKeyID = try await assertSetGetForStorage()
        XCTAssertNotEqual(oldKeyID, newKeyID)

        // 3. Check old artifact was removed.
        let getArtifact = try await storage.getArtifact(forKey: oldKeyID)
        XCTAssertNil(getArtifact)
      }

      func testGetArtifact_KeychainError() async {
        // 1. Set up storage mock.
        let fakeKeychainStorage = AppCheckCoreKeychainStorageFake()
        let artifactStorage = AppCheckCoreAppAttestArtifactStorage(
          keySuffix: keySuffix,
          keychainStorage: fakeKeychainStorage,
          accessGroup: nil
        )

        // 2. Create and expect keychain error.
        let gulsKeychainError = NSError(domain: "com.guls.keychain", code: -1, userInfo: nil)
        fakeKeychainStorage.keychainError = gulsKeychainError

        // 3. Get artifact and verify results.
        do {
          _ = try await artifactStorage.getArtifact(forKey: "key")
          XCTFail("Expected error to be thrown")
        } catch {
          let nsError = error as NSError
          let expectedError = AppCheckCoreErrorUtil
            .keychainError(withError: gulsKeychainError) as NSError
          XCTAssertEqual(nsError, expectedError)
        }
      }

      func testSetArtifact_KeychainError() async {
        // 1. Set up storage mock.
        let fakeKeychainStorage = AppCheckCoreKeychainStorageFake()
        let artifactStorage = AppCheckCoreAppAttestArtifactStorage(
          keySuffix: keySuffix,
          keychainStorage: fakeKeychainStorage,
          accessGroup: nil
        )

        // 2. Create and expect keychain error.
        let gulsKeychainError = NSError(domain: "com.guls.keychain", code: -1, userInfo: nil)
        fakeKeychainStorage.keychainError = gulsKeychainError

        // 3. Set artifact and verify results.
        let artifact = "artifact".data(using: .utf8)
        do {
          _ = try await artifactStorage.setArtifact(artifact, forKey: "key")
          XCTFail("Expected error to be thrown")
        } catch {
          let nsError = error as NSError
          let expectedError = AppCheckCoreErrorUtil
            .keychainError(withError: gulsKeychainError) as NSError
          XCTAssertEqual(nsError, expectedError)
        }
      }

      func testRemoveArtifact_KeychainError() async {
        // 1. Set up storage mock.
        let fakeKeychainStorage = AppCheckCoreKeychainStorageFake()
        let artifactStorage = AppCheckCoreAppAttestArtifactStorage(
          keySuffix: keySuffix,
          keychainStorage: fakeKeychainStorage,
          accessGroup: nil
        )

        // 2. Create and expect keychain error.
        let gulsKeychainError = NSError(domain: "com.guls.keychain", code: -1, userInfo: nil)
        fakeKeychainStorage.keychainError = gulsKeychainError

        // 3. Remove artifact and verify results.
        do {
          _ = try await artifactStorage.setArtifact(nil, forKey: "key")
          XCTFail("Expected error to be thrown")
        } catch {
          let nsError = error as NSError
          let expectedError = AppCheckCoreErrorUtil
            .keychainError(withError: gulsKeychainError) as NSError
          XCTAssertEqual(nsError, expectedError)
        }
      }

      // MARK: - Helpers

      /// Sets a random artifact for a random key and asserts it can be read.
      /// - Returns: The random key ID used to set and get the artifact.
      private func assertSetGetForStorage() async throws -> String {
        let artifactToSet = UUID().uuidString.data(using: .utf8)
        let keyID = UUID().uuidString

        let setArtifact = try await storage.setArtifact(artifactToSet, forKey: keyID)
        XCTAssertEqual(setArtifact, artifactToSet)

        let getArtifact = try await storage.getArtifact(forKey: keyID)
        XCTAssertEqual(getArtifact, artifactToSet)

        addTeardownBlock { [weak self] in
          // Cleanup storage.
          _ = try? await self?.storage.setArtifact(nil, forKey: keyID)
        }

        return keyID
      }

      private func assertIndependentSetGetForStorages(appName1: String,
                                                      appID1: String,
                                                      appName2: String,
                                                      appID2: String) async throws {
        let keyID = UUID().uuidString
        let keySuffix1 = AppCheckCoreAppAttestArtifactStorageTests.artifactKeySuffix(
          appName: appName1,
          appID: appID1
        )
        let keySuffix2 = AppCheckCoreAppAttestArtifactStorageTests.artifactKeySuffix(
          appName: appName2,
          appID: appID2
        )

        // Create two storages.
        let storage1 = AppCheckCoreAppAttestArtifactStorage(keySuffix: keySuffix1, accessGroup: nil)
        let storage2 = AppCheckCoreAppAttestArtifactStorage(keySuffix: keySuffix2, accessGroup: nil)

        // 1. Independently set artifacts for the two storages.
        let artifact1 = "app_attest_artifact1".data(using: .utf8)
        let setArtifact1 = try await storage1.setArtifact(artifact1, forKey: keyID)
        XCTAssertEqual(setArtifact1, artifact1)

        let artifact2 = "app_attest_artifact2".data(using: .utf8)
        let setArtifact2 = try await storage2.setArtifact(artifact2, forKey: keyID)
        XCTAssertEqual(setArtifact2, artifact2)

        // 2. Get artifacts for the two storages.
        let getArtifact1 = try await storage1.getArtifact(forKey: keyID)
        XCTAssertEqual(getArtifact1, artifact1)

        let getArtifact2 = try await storage2.getArtifact(forKey: keyID)
        XCTAssertEqual(getArtifact2, artifact2)

        // 3. Assert that artifacts were set and retrieved independently of one another.
        XCTAssertNotEqual(getArtifact1, getArtifact2)

        // Cleanup storages.
        _ = try await storage1.setArtifact(nil, forKey: keyID)
        _ = try await storage2.setArtifact(nil, forKey: keyID)
      }

      static func artifactKeySuffix(appName: String, appID: String) -> String {
        return "\(appName).\(appID)"
      }
    }

  #endif // !targetEnvironment(macCatalyst) && !os(macOS)

#endif // !SWIFT_PACKAGE
