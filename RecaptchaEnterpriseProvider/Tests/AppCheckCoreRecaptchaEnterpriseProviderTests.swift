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
import Promises
@testable import RecaptchaEnterpriseProvider

final class AppCheckCoreRecaptchaEnterpriseProviderTests: XCTestCase {
  private var provider: AppCheckCoreRecaptchaEnterpriseProvider!
  private let testSiteKey = "test-site-key"
  private let testResourceName = "projects/test-project/apps/test-app"
  private let testAPIKey = "test-api-key"

  override func setUp() {
    super.setUp()
    provider = AppCheckCoreRecaptchaEnterpriseProvider(
      siteKey: testSiteKey,
      resourceName: testResourceName,
      APIKey: testAPIKey,
      requestHooks: nil
    )
  }

  override func tearDown() {
    provider = nil
    super.tearDown()
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

      expectation.fulfill()
    }

    waitForExpectations(timeout: 1.0)
  }

  func testGetTokenSuccess() {
    // Arrange
    let mockClient = MockRecaptchaClient(dummy: ())
    mockClient.mockToken = "valid-recaptcha-token"
    MockRecaptcha.mockClient = mockClient

    let tokenGenerator = RecaptchaEnterpriseTokenGenerator(
      siteKey: testSiteKey,
      action: MockRCAAction(customAction: "app_check_ios"),
      recaptchaClass: MockRecaptcha.self
    )

    let mockCoreAPIService = MockAppCheckCoreAPIService()
    let expectedAppCheckToken = AppCheckCoreToken(
      token: "app-check-token-456",
      expirationDate: Date(timeIntervalSinceNow: 3600)
    )
    mockCoreAPIService.expectedToken = expectedAppCheckToken

    let apiService = RecaptchaEnterpriseAPIService(
      APIService: mockCoreAPIService,
      resourceName: testResourceName
    )

    let providerWithMocks = AppCheckCoreRecaptchaEnterpriseProvider(
      tokenGenerator: tokenGenerator,
      apiService: apiService
    )

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
}
