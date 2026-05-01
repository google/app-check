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
import RecaptchaInterop

final class RecaptchaEnterpriseCoreTokenGeneratorTests: XCTestCase {
  private let testSiteKey = "test-site-key"
  private var mockAction: MockRCAAction!

  override func setUp() {
    super.setUp()
    mockAction = MockRCAAction(customAction: "test_action")
    MockRecaptcha.mockClient = nil
    MockRecaptcha.mockError = nil
  }

  func testGetRecaptchaTokenWithoutSDK() {
    let generator = RecaptchaEnterpriseTokenGenerator(siteKey: testSiteKey, action: mockAction)

    let expectation = self.expectation(description: "Fails to generate token without Recaptcha SDK")

    generator.getRecaptchaToken().then { token in
      XCTFail("Should not succeed without SDK")
    }.catch { error in
      XCTAssertNotNil(error)
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, AppCheckCoreErrorDomain)
      XCTAssertEqual(nsError.code, AppCheckCoreErrorCode.unsupported.rawValue)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 1.0)
  }

  func testGetRecaptchaTokenSuccess() {
    // Arrange
    let mockClient = MockRecaptchaClient(dummy: ())
    mockClient.mockToken = "valid-recaptcha-token"
    MockRecaptcha.mockClient = mockClient

    let generator = RecaptchaEnterpriseTokenGenerator(
      siteKey: testSiteKey,
      action: mockAction,
      recaptchaClass: MockRecaptcha.self
    )

    let expectation = self.expectation(description: "Generates token successfully")

    // Act
    generator.getRecaptchaToken().then { token in
      // Assert
      XCTAssertEqual(token, "valid-recaptcha-token")
      expectation.fulfill()
    }.catch { error in
      XCTFail("Unexpected error: \(error)")
    }

    waitForExpectations(timeout: 1.0)
  }

  func testGetRecaptchaTokenFetchClientFailure() {
    // Arrange
    let expectedError = NSError(domain: "test", code: -1, userInfo: nil)
    MockRecaptcha.mockError = expectedError

    let generator = RecaptchaEnterpriseTokenGenerator(
      siteKey: testSiteKey,
      action: mockAction,
      recaptchaClass: MockRecaptcha.self
    )

    let expectation = self.expectation(description: "Fails when fetchClient fails")

    // Act
    generator.getRecaptchaToken().then { token in
      XCTFail("Should not succeed when fetchClient fails")
    }.catch { error in
      // Assert
      XCTAssertEqual((error as NSError).domain, expectedError.domain)
      XCTAssertEqual((error as NSError).code, expectedError.code)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 1.0)
  }

  func testGetRecaptchaTokenExecutionFailure() {
    // Arrange
    let mockClient = MockRecaptchaClient(dummy: ())
    let expectedError = NSError(domain: "test", code: -2, userInfo: nil)
    mockClient.mockError = expectedError
    MockRecaptcha.mockClient = mockClient

    let generator = RecaptchaEnterpriseTokenGenerator(
      siteKey: testSiteKey,
      action: mockAction,
      recaptchaClass: MockRecaptcha.self
    )

    let expectation = self.expectation(description: "Fails when execute fails")

    // Act
    generator.getRecaptchaToken().then { token in
      XCTFail("Should not succeed when execute fails")
    }.catch { error in
      // Assert
      XCTAssertEqual((error as NSError).domain, expectedError.domain)
      XCTAssertEqual((error as NSError).code, expectedError.code)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 1.0)
  }
}
