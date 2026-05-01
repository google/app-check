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
import FBLPromises
@testable import RecaptchaEnterpriseProvider

final class RecaptchaEnterpriseCoreAPIServiceTests: XCTestCase {
  private var apiService: RecaptchaEnterpriseAPIService!
  private var mockCoreAPIService: MockAppCheckCoreAPIService!
  private let testResourceName = "projects/test-project/apps/test-app"
  private let testRecaptchaToken = "recaptcha-token-123"

  override func setUp() {
    super.setUp()
    mockCoreAPIService = MockAppCheckCoreAPIService()
    apiService = RecaptchaEnterpriseAPIService(
      APIService: mockCoreAPIService,
      resourceName: testResourceName
    )
  }

  override func tearDown() {
    apiService = nil
    mockCoreAPIService = nil
    super.tearDown()
  }

  func testAppCheckTokenSuccess() throws {
    // Arrange
    let expectedAppCheckToken = AppCheckCoreToken(
      token: "app-check-token-456",
      expirationDate: Date(timeIntervalSinceNow: 3600)
    )
    mockCoreAPIService.expectedToken = expectedAppCheckToken

    let expectation = self.expectation(description: "Token exchange completes successfully")

    // Act
    apiService.appCheckToken(withRecaptchaToken: testRecaptchaToken, limitedUse: false)
      .then { token in
        // Assert
        XCTAssertEqual(token.token, expectedAppCheckToken.token)
        XCTAssertEqual(token.expirationDate, expectedAppCheckToken.expirationDate)

        // Verify request
        guard let request = self.mockCoreAPIService.lastRequest else {
          XCTFail("No request was sent")
          return
        }

        XCTAssertEqual(
          request.url?.absoluteString,
          "https://test.com/\(self.testResourceName):exchangeRecaptchaEnterpriseToken"
        )
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.additionalHeaders?["Content-Type"], "application/json")

        if let body = request.body {
          let json = try? JSONSerialization.jsonObject(with: body, options: []) as? [String: Any]
          XCTAssertEqual(json?["recaptcha_enterprise_token"] as? String, self.testRecaptchaToken)
          XCTAssertEqual(json?["limited_use"] as? Bool, false)
        } else {
          XCTFail("Request body was empty")
        }

        expectation.fulfill()
      }.catch { error in
        XCTFail("Unexpected error: \(error)")
      }

    waitForExpectations(timeout: 1.0)
  }

  func testAppCheckTokenLimitedUseSuccess() throws {
    // Arrange
    let expectedAppCheckToken = AppCheckCoreToken(
      token: "app-check-token-456",
      expirationDate: Date(timeIntervalSinceNow: 3600)
    )
    mockCoreAPIService.expectedToken = expectedAppCheckToken

    let expectation = self
      .expectation(description: "Limited use token exchange completes successfully")

    // Act
    apiService.appCheckToken(withRecaptchaToken: testRecaptchaToken, limitedUse: true)
      .then { token in
        // Assert
        guard let request = self.mockCoreAPIService.lastRequest, let body = request.body else {
          XCTFail("No request or body")
          return
        }

        let json = try? JSONSerialization.jsonObject(with: body, options: []) as? [String: Any]
        XCTAssertEqual(json?["limited_use"] as? Bool, true)

        expectation.fulfill()
      }.catch { error in
        XCTFail("Unexpected error: \(error)")
      }

    waitForExpectations(timeout: 1.0)
  }

  func testAppCheckTokenEmptyRecaptchaToken() {
    let expectation = self.expectation(description: "Token exchange fails with empty token")

    apiService.appCheckToken(withRecaptchaToken: "", limitedUse: false).then { token in
      XCTFail("Should not succeed with empty token")
    }.catch { error in
      XCTAssertNotNil(error)
      XCTAssertEqual((error as NSError).domain, AppCheckCoreErrorDomain)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 1.0)
  }
}
