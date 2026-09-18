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

private let kAppName = "AppCheckCoreStorageTestsApp"
private let kGoogleAppID = "1:100000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa"

// Tests that use the Keychain require a host app and Swift Package Manager
// does not support adding a host app to test targets.
#if !SWIFT_PACKAGE

  // Skip keychain tests on Catalyst and macOS. Tests are skipped because they
  // involve interactions with the keychain that require a provisioning profile.
  // See go/firebase-macos-keychain-popups for more details.
  #if !targetEnvironment(macCatalyst) && !os(macOS)

    class AppCheckCoreStorageTests: XCTestCase {
      var tokenKey: String!
      var storage: AppCheckCoreStorage!

      override func setUp() {
        super.setUp()

        tokenKey = tokenKey(withGoogleAppID: kGoogleAppID)
        storage = AppCheckCoreStorage(tokenKey: tokenKey, accessGroup: nil)
      }

      override func tearDown() {
        storage = nil
        super.tearDown()
      }

      func testSetAndGetToken() async throws {
        let tokenToStore = AppCheckCoreToken(token: "token",
                                             expirationDate: Date.distantPast,
                                             receivedAt: Date())

        let storedToken = try await storage.setToken(tokenToStore)
        XCTAssertEqual(storedToken, tokenToStore)

        let retrievedToken = try await storage.getToken()
        XCTAssertEqual(retrievedToken?.token, tokenToStore.token)
        XCTAssertEqual(retrievedToken?.expirationDate, tokenToStore.expirationDate)
        XCTAssertEqual(retrievedToken?.receivedAtDate, tokenToStore.receivedAtDate)
      }

      func testRemoveToken() async throws {
        let removedToken = try await storage.setToken(nil as AppCheckCoreToken?)
        XCTAssertNil(removedToken)

        let retrievedToken = try await storage.getToken()
        XCTAssertNil(retrievedToken)
      }

      func testGetToken_KeychainError() async {
        // 1. Set up storage mock.
        let fakeKeychainStorage = AppCheckCoreKeychainStorageFake()
        let storage = AppCheckCoreStorage(tokenKey: tokenKey,
                                          keychainStorage: fakeKeychainStorage,
                                          accessGroup: nil)

        // 2. Create and expect keychain error.
        let gulsKeychainError = NSError(
          domain: "com.google.utilities.keychain",
          code: -1,
          userInfo: nil
        )
        fakeKeychainStorage.keychainError = gulsKeychainError

        // 3. Get token and verify results.
        do {
          _ = try await storage.getToken()
          XCTFail("Expected error to be thrown")
        } catch {
          let nsError = error as NSError
          let expectedError = AppCheckCoreErrorUtil
            .keychainError(with: gulsKeychainError) as NSError
          XCTAssertEqual(nsError.domain, expectedError.domain)
          XCTAssertEqual(nsError.code, expectedError.code)
          if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
             let expectedUnderlyingError = expectedError
             .userInfo[NSUnderlyingErrorKey] as? NSError {
            XCTAssertEqual(underlyingError.domain, expectedUnderlyingError.domain)
            XCTAssertEqual(underlyingError.code, expectedUnderlyingError.code)
          }
        }
      }

      func testSetToken_KeychainError() async {
        // 1. Set up storage mock.
        let fakeKeychainStorage = AppCheckCoreKeychainStorageFake()
        let storage = AppCheckCoreStorage(tokenKey: tokenKey,
                                          keychainStorage: fakeKeychainStorage,
                                          accessGroup: nil)

        // 2. Create and expect keychain error.
        let gulsKeychainError = NSError(
          domain: "com.google.utilities.keychain",
          code: -1,
          userInfo: nil
        )
        fakeKeychainStorage.keychainError = gulsKeychainError

        // 3. Set token and verify results.
        let tokenToStore = AppCheckCoreToken(token: "token",
                                             expirationDate: Date.distantPast,
                                             receivedAt: Date())
        do {
          _ = try await storage.setToken(tokenToStore)
          XCTFail("Expected error to be thrown")
        } catch {
          let nsError = error as NSError
          let expectedError = AppCheckCoreErrorUtil
            .keychainError(with: gulsKeychainError) as NSError
          XCTAssertEqual(nsError.domain, expectedError.domain)
          XCTAssertEqual(nsError.code, expectedError.code)
          if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
             let expectedUnderlyingError = expectedError
             .userInfo[NSUnderlyingErrorKey] as? NSError {
            XCTAssertEqual(underlyingError.domain, expectedUnderlyingError.domain)
            XCTAssertEqual(underlyingError.code, expectedUnderlyingError.code)
          }
        }
      }

      func testRemoveToken_KeychainError() async {
        // 1. Set up storage mock.
        let fakeKeychainStorage = AppCheckCoreKeychainStorageFake()
        let storage = AppCheckCoreStorage(tokenKey: tokenKey,
                                          keychainStorage: fakeKeychainStorage,
                                          accessGroup: nil)

        // 2. Create and expect keychain error.
        let gulsKeychainError = NSError(
          domain: "com.google.utilities.keychain",
          code: -1,
          userInfo: nil
        )
        fakeKeychainStorage.keychainError = gulsKeychainError

        // 3. Remove token and verify results.
        do {
          _ = try await storage.setToken(nil as AppCheckCoreToken?)
          XCTFail("Expected error to be thrown")
        } catch {
          let nsError = error as NSError
          let expectedError = AppCheckCoreErrorUtil
            .keychainError(with: gulsKeychainError) as NSError
          XCTAssertEqual(nsError.domain, expectedError.domain)
          XCTAssertEqual(nsError.code, expectedError.code)
          if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
             let expectedUnderlyingError = expectedError
             .userInfo[NSUnderlyingErrorKey] as? NSError {
            XCTAssertEqual(underlyingError.domain, expectedUnderlyingError.domain)
            XCTAssertEqual(underlyingError.code, expectedUnderlyingError.code)
          }
        }
      }

      func testSetTokenPerApp() async throws {
        // 1. Set token with a storage.
        let tokenToStore = AppCheckCoreToken(token: "token",
                                             expirationDate: Date.distantPast,
                                             receivedAt: Date())

        let storedToken = try await storage.setToken(tokenToStore)
        XCTAssertEqual(storedToken, tokenToStore)

        // 2. Try to read the token with another storage.
        let tokenKey2 = tokenKey(withGoogleAppID: "1:200000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa")
        let storage2 = AppCheckCoreStorage(tokenKey: tokenKey2, accessGroup: nil)

        let retrievedToken = try await storage2.getToken()
        XCTAssertNil(retrievedToken)
      }

      // MARK: - Private Helpers

      private func tokenKey(withGoogleAppID googleAppID: String) -> String {
        return "app_check_token.\(kAppName).\(googleAppID)"
      }
    }

  #endif // !targetEnvironment(macCatalyst) && !os(macOS)
#endif // !SWIFT_PACKAGE
