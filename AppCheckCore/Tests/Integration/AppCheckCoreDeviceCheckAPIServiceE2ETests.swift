/*
 * Copyright 2020 Google LLC
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

import XCTest
@testable import AppCheckCore

// TODO: Replace with real resource name to run on CI
private let kResourceName = "projects/test-project-id/google-app-id"

// Tests that use the Keychain require a host app and Swift Package Manager
// does not support adding a host app to test targets.
#if !SWIFT_PACKAGE

// Skip keychain tests on Catalyst and macOS. Tests are skipped because they
// involve interactions with the keychain that require a provisioning profile.
// See go/firebase-macos-keychain-popups for more details.
#if !targetEnvironment(macCatalyst) && !os(macOS)

// TODO(ncooke3): Fix these tests up and get them running on CI.

class AppCheckCoreDeviceCheckAPIServiceE2ETests: XCTestCase {
  var deviceCheckAPIService: AppCheckCoreDeviceCheckAPIService!
  var APIService: AppCheckCoreAPIService!
  var URLSession: Foundation.URLSession!

  override func setUp() {
    super.setUp()
    URLSession = Foundation.URLSession(configuration: .default)
    APIService = AppCheckCoreAPIService(
      urlSession: URLSession,
      baseURL: nil,
      apiKey: nil,
      requestHooks: nil
    )
    deviceCheckAPIService = AppCheckCoreDeviceCheckAPIService(
      apiService: APIService,
      resourceName: kResourceName
    )
  }

  override func tearDown() {
    deviceCheckAPIService = nil
    APIService = nil
    URLSession = nil
    super.tearDown()
  }

  // TODO: Re-enable the test once secret with "GoogleService-Info.plist" is configured.
  func temporaryDisabled_testAppCheckTokenSuccess() async throws {
    let appCheckToken = try await deviceCheckAPIService.appCheckToken(
      deviceToken: Data(),
      limitedUse: false
    )

    XCTAssertNotNil(appCheckToken.token)
    XCTAssertNotNil(appCheckToken.expirationDate)
  }
}

#endif // !targetEnvironment(macCatalyst) && !os(macOS)

#endif // !SWIFT_PACKAGE
