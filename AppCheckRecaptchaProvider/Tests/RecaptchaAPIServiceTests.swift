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

@available(iOS 15.0, visionOS 1.0, *)
@available(macOS, unavailable)
@available(macCatalyst, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
final class RecaptchaAPIServiceTests: XCTestCase {
  private var apiService: RecaptchaAPIService!
  private var mockCoreAPIService: MockAppCheckCoreAPIService!
  private let testResourceName = "projects/test-project/apps/test-app"
  private let testRecaptchaToken = "recaptcha-token-123"

  override func setUp() {
    super.setUp()
    mockCoreAPIService = MockAppCheckCoreAPIService()
    apiService = RecaptchaAPIService(
      apiService: mockCoreAPIService,
      resourceName: testResourceName
    )
  }

  override func tearDown() {
    apiService = nil
    mockCoreAPIService = nil
    super.tearDown()
  }

  func testAppCheckTokenSuccess() async throws {
    // Arrange
    let expectedAppCheckToken = AppCheckCoreToken(
      token: "app-check-token-456",
      expirationDate: Date(timeIntervalSinceNow: 3600)
    )
    mockCoreAPIService.expectedToken = expectedAppCheckToken

    // Act
    do {
      let token = try await apiService.appCheckToken(with: testRecaptchaToken, limitedUse: false)
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
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testAppCheckTokenLimitedUseSuccess() async throws {
    // Arrange
    let expectedAppCheckToken = AppCheckCoreToken(
      token: "app-check-token-456",
      expirationDate: Date(timeIntervalSinceNow: 3600)
    )
    mockCoreAPIService.expectedToken = expectedAppCheckToken

    // Act
    do {
      let _ = try await apiService.appCheckToken(with: testRecaptchaToken, limitedUse: true)
      // Assert
      guard let request = self.mockCoreAPIService.lastRequest, let body = request.body else {
        XCTFail("No request or body")
        return
      }

      let json = try? JSONSerialization.jsonObject(with: body, options: []) as? [String: Any]
      XCTAssertEqual(json?["limited_use"] as? Bool, true)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testAppCheckTokenEmptyRecaptchaToken() async {
    do {
      let _ = try await apiService.appCheckToken(with: "", limitedUse: false)
      XCTFail("Should not succeed with empty token")
    } catch {
      XCTAssertNotNil(error)
      XCTAssertEqual((error as NSError).domain, AppCheckCoreErrorDomain)
    }
  }

  func testAppCheckTokenInvalidURL() async {
    mockCoreAPIService.baseURL = "not a scheme://test.com"
    let apiService = RecaptchaAPIService(
      apiService: mockCoreAPIService,
      resourceName: "invalid_resource_name"
    )

    do {
      let _ = try await apiService.appCheckToken(with: testRecaptchaToken, limitedUse: false)
      XCTFail("Should not succeed with invalid URL")
    } catch {
      XCTAssertEqual((error as NSError).domain, AppCheckCoreErrorDomain)
      let expectedFailureReason =
        "Invalid URL string: not a scheme://test.com/invalid_resource_name:exchangeRecaptchaEnterpriseToken"
      XCTAssertEqual((error as NSError).localizedFailureReason, expectedFailureReason)
    }
  }
}
