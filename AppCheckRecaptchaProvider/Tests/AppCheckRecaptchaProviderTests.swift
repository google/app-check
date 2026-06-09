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

import XCTest

@testable import AppCheckCore
@testable import AppCheckRecaptchaProvider
import Promises

@available(iOS 15.0, visionOS 1.0, *)
@available(macOS, unavailable)
@available(macCatalyst, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
final class AppCheckRecaptchaProviderTests: XCTestCase {
  private var provider: AppCheckRecaptchaProvider!
  private let testSiteKey = "test-site-key"
  private let testResourceName = "projects/test-project/apps/test-app"

  override func setUp() {
    super.setUp()
    let mockCoreAPIService = MockAppCheckCoreAPIService()
    let apiService = RecaptchaAPIService(
      apiService: mockCoreAPIService,
      resourceName: testResourceName
    )
    provider = AppCheckRecaptchaProvider(
      tokenGenerator: nil,
      apiService: apiService
    )
  }

  override func tearDown() {
    provider = nil
    super.tearDown()
  }

  func testIsSupportedReturnsFalse() {
    XCTAssertFalse(AppCheckRecaptchaProvider.isSupported())
  }

  func testGetTokenWithoutRecaptchaSDK() {
    // When the Recaptcha SDK is not linked, the tokenGenerator will be nil.
    // We should expect an unsupported attestation provider error.

    let expectation = self.expectation(description: "Get token fails without SDK")

    provider.getToken { token, error in
      XCTAssertNil(token)
      XCTAssertNotNil(error)

      let nsError = error as NSError?
      XCTAssertEqual(nsError?.domain, AppCheckCoreErrorDomain)
      XCTAssertEqual(nsError?.code, AppCheckCoreErrorCode.unsupported.rawValue)
      XCTAssertEqual(
        nsError?.localizedFailureReason,
        "The reCAPTCHA Enterprise SDK is not linked. See https://cloud.google.com/recaptcha/docs/instrument-ios-apps#prepare-environment"
      )

      expectation.fulfill()
    }

    waitForExpectations(timeout: 1.0)
  }

  func testGetLimitedUseTokenWithoutRecaptchaSDK() {
    let expectation = self.expectation(description: "Get limited use token fails without SDK")

    provider.getLimitedUseToken { token, error in
      XCTAssertNil(token)
      XCTAssertNotNil(error)

      let nsError = error as NSError?
      XCTAssertEqual(nsError?.domain, AppCheckCoreErrorDomain)
      XCTAssertEqual(nsError?.code, AppCheckCoreErrorCode.unsupported.rawValue)
      XCTAssertEqual(
        nsError?.localizedFailureReason,
        "The reCAPTCHA Enterprise SDK is not linked. See https://cloud.google.com/recaptcha/docs/instrument-ios-apps#prepare-environment"
      )

      expectation.fulfill()
    }

    waitForExpectations(timeout: 1.0)
  }

  func testInitReturnsNilWithoutRecaptchaSDK() {
    // When the Recaptcha SDK is not linked, the convenience initializer should return nil.
    let provider = AppCheckRecaptchaProvider(
      siteKey: testSiteKey,
      resourceName: testResourceName,
      APIKey: "test-api-key"
    )
    XCTAssertNil(provider)
  }

  func testInitWithCustomActionNameReturnsNilWithoutRecaptchaSDK() {
    // When the Recaptcha SDK is not linked, the convenience initializer should return nil
    // even with a custom action name.
    let provider = AppCheckRecaptchaProvider(
      siteKey: testSiteKey,
      resourceName: testResourceName,
      APIKey: "test-api-key",
      actionName: "custom_action"
    )
    XCTAssertNil(provider)
  }

  private func createProviderWithMocks(expectedToken: AppCheckCoreToken)
    -> AppCheckRecaptchaProvider {
    let mockClient = MockRecaptchaClient()
    mockClient.mockToken = "valid-recaptcha-token"
    MockRecaptcha.mockClient = mockClient

    let tokenGenerator = RecaptchaTokenGenerator(
      siteKey: testSiteKey,
      recaptchaAction: MockRCAAction(customAction: "app_check_ios"),
      recaptchaClass: MockRecaptcha.self,
      backoffWrapper: MockBackoffWrapper()
    )

    let mockCoreAPIService = MockAppCheckCoreAPIService()
    mockCoreAPIService.expectedToken = expectedToken

    let apiService = RecaptchaAPIService(
      apiService: mockCoreAPIService,
      resourceName: testResourceName
    )

    return AppCheckRecaptchaProvider(
      tokenGenerator: tokenGenerator,
      apiService: apiService
    )
  }

  func testGetTokenSuccess() {
    // Arrange
    let expectedAppCheckToken = AppCheckCoreToken(
      token: "app-check-token-456",
      expirationDate: Date(timeIntervalSinceNow: 3600)
    )
    let providerWithMocks = createProviderWithMocks(expectedToken: expectedAppCheckToken)

    let expectation = self.expectation(description: "Get token succeeds")

    // Act
    providerWithMocks.getToken { token, error in
      // Assert
      XCTAssertNotNil(token)
      XCTAssertNil(error)
      XCTAssertEqual(token?.token, expectedAppCheckToken.token)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 1.0)
  }

  func testGetLimitedUseTokenSuccess() {
    // Arrange
    let expectedAppCheckToken = AppCheckCoreToken(
      token: "app-check-token-456",
      expirationDate: Date(timeIntervalSinceNow: 3600)
    )
    let providerWithMocks = createProviderWithMocks(expectedToken: expectedAppCheckToken)

    let expectation = self.expectation(description: "Get limited use token succeeds")

    // Act
    providerWithMocks.getLimitedUseToken { token, error in
      // Assert
      XCTAssertNotNil(token)
      XCTAssertNil(error)
      XCTAssertEqual(token?.token, expectedAppCheckToken.token)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 1.0)
  }
}
