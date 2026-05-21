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
@testable import AppCheckRecaptchaEnterpriseProvider
import FBLPromises
import Promises
import RecaptchaInterop

@available(iOS 15.0, visionOS 1.0, *)
@available(macOS, unavailable)
@available(macCatalyst, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
final class RecaptchaEnterpriseTokenGeneratorTests: XCTestCase {
  private let testSiteKey = "test-site-key"
  private var mockAction: MockRCAAction!

  override func setUp() {
    super.setUp()
    mockAction = MockRCAAction(customAction: "test_action")
    MockRecaptcha.mockClient = nil
    MockRecaptcha.mockError = nil
  }

  func testGetRecaptchaTokenSuccess() {
    // Arrange
    let mockClient = MockRecaptchaClient()
    mockClient.mockToken = "valid-recaptcha-token"
    MockRecaptcha.mockClient = mockClient

    let generator = RecaptchaEnterpriseTokenGenerator(
      siteKey: testSiteKey,
      recaptchaAction: mockAction,
      recaptchaClass: MockRecaptcha.self,
      backoffWrapper: MockBackoffWrapper()
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
      recaptchaAction: mockAction,
      recaptchaClass: MockRecaptcha.self,
      backoffWrapper: MockBackoffWrapper()
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
    let mockClient = MockRecaptchaClient()
    let expectedError = NSError(domain: "test", code: -2, userInfo: nil)
    mockClient.mockError = expectedError
    MockRecaptcha.mockClient = mockClient

    let generator = RecaptchaEnterpriseTokenGenerator(
      siteKey: testSiteKey,
      recaptchaAction: mockAction,
      recaptchaClass: MockRecaptcha.self,
      backoffWrapper: MockBackoffWrapper()
    )

    let expectation = self.expectation(description: "Fails when execute fails")

    // Act
    generator.getRecaptchaToken().then { token in
      XCTFail("Should not succeed when execute fails")
    }.catch { error in
      // Assert
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, AppCheckCoreErrorDomain)
      XCTAssertEqual(nsError.code, AppCheckCoreErrorCode.unknown.rawValue)

      let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
      XCTAssertNotNil(underlyingError)
      XCTAssertEqual(underlyingError?.domain, expectedError.domain)
      XCTAssertEqual(underlyingError?.code, expectedError.code)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 1.0)
  }

  func testGetRecaptchaTokenCallsBackoffWrapper() {
    // Arrange
    let mockClient = MockRecaptchaClient()
    mockClient.mockToken = "valid-recaptcha-token"
    MockRecaptcha.mockClient = mockClient

    let mockBackoffWrapper = MockBackoffWrapper()

    let generator = RecaptchaEnterpriseTokenGenerator(
      siteKey: testSiteKey,
      recaptchaAction: mockAction,
      recaptchaClass: MockRecaptcha.self,
      backoffWrapper: mockBackoffWrapper
    )

    let expectation = self.expectation(description: "Calls backoff wrapper")

    // Act
    generator.getRecaptchaToken().then { token in
      // Assert
      XCTAssertTrue(mockBackoffWrapper.applyBackoffCalled)
      expectation.fulfill()
    }.catch { error in
      XCTFail("Unexpected error: \(error)")
    }

    waitForExpectations(timeout: 1.0)
  }

  func testGetRecaptchaTokenBackoffWrapperError() {
    // Arrange
    let mockClient = MockRecaptchaClient()
    MockRecaptcha.mockClient = mockClient

    let mockBackoffWrapper = MockBackoffWrapper()
    mockBackoffWrapper.shouldReturnError = true
    let expectedError = NSError(domain: "test", code: -3, userInfo: nil)
    mockBackoffWrapper.mockError = expectedError

    let generator = RecaptchaEnterpriseTokenGenerator(
      siteKey: testSiteKey,
      recaptchaAction: mockAction,
      recaptchaClass: MockRecaptcha.self,
      backoffWrapper: mockBackoffWrapper
    )

    let expectation = self.expectation(description: "Fails when backoff wrapper fails")

    // Act
    generator.getRecaptchaToken().then { token in
      XCTFail("Should not succeed when backoff wrapper fails")
    }.catch { error in
      // Assert
      XCTAssertEqual((error as NSError).domain, expectedError.domain)
      XCTAssertEqual((error as NSError).code, expectedError.code)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 1.0)
  }

  func testGetRecaptchaTokenMapsNetworkErrorToServerUnreachable() {
    // Arrange
    let mockClient = MockRecaptchaClient()
    let recaptchaError = NSError(
      domain: "RecaptchaErrorDomain",
      code: RecaptchaEnterpriseTokenGenerator.networkErrorCode,
      userInfo: nil
    )
    mockClient.mockError = recaptchaError
    MockRecaptcha.mockClient = mockClient

    let mockBackoffWrapper = MockBackoffWrapper()

    let generator = RecaptchaEnterpriseTokenGenerator(
      siteKey: testSiteKey,
      recaptchaAction: mockAction,
      recaptchaClass: MockRecaptcha.self,
      backoffWrapper: mockBackoffWrapper
    )

    let expectation = self.expectation(description: "Maps NetworkError to ServerUnreachable")

    // Act
    generator.getRecaptchaToken().then { token in
      XCTFail("Should not succeed when execute fails")
    }.catch { error in
      // Assert
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, AppCheckCoreErrorDomain)
      XCTAssertEqual(nsError.code, AppCheckCoreErrorCode.serverUnreachable.rawValue)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 1.0)
  }

  func testGetRecaptchaTokenMapsInternalErrorToServerUnreachable() {
    // Arrange
    let mockClient = MockRecaptchaClient()
    let recaptchaError = NSError(
      domain: "RecaptchaErrorDomain",
      code: RecaptchaEnterpriseTokenGenerator.internalErrorCode,
      userInfo: nil
    )
    mockClient.mockError = recaptchaError
    MockRecaptcha.mockClient = mockClient

    let mockBackoffWrapper = MockBackoffWrapper()

    let generator = RecaptchaEnterpriseTokenGenerator(
      siteKey: testSiteKey,
      recaptchaAction: mockAction,
      recaptchaClass: MockRecaptcha.self,
      backoffWrapper: mockBackoffWrapper
    )

    let expectation = self.expectation(description: "Maps InternalError to ServerUnreachable")

    // Act
    generator.getRecaptchaToken().then { token in
      XCTFail("Should not succeed when execute fails")
    }.catch { error in
      // Assert
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, AppCheckCoreErrorDomain)
      XCTAssertEqual(nsError.code, AppCheckCoreErrorCode.serverUnreachable.rawValue)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 1.0)
  }

  func testErrorHandlerTriggersBackoffForServerUnreachable() {
    // Arrange
    let mockClient = MockRecaptchaClient()
    mockClient.mockToken = "valid-recaptcha-token"
    MockRecaptcha.mockClient = mockClient

    let mockBackoffWrapper = MockBackoffWrapper()

    let generator = RecaptchaEnterpriseTokenGenerator(
      siteKey: testSiteKey,
      recaptchaAction: mockAction,
      recaptchaClass: MockRecaptcha.self,
      backoffWrapper: mockBackoffWrapper
    )

    let expectation = self.expectation(description: "Calls backoff wrapper")

    // Act
    generator.getRecaptchaToken().then { _ in
      // Assert
      XCTAssertNotNil(mockBackoffWrapper.capturedErrorHandler)
      if let errorHandler = mockBackoffWrapper.capturedErrorHandler {
        let serverUnreachableError = NSError(
          domain: AppCheckCoreErrorDomain,
          code: AppCheckCoreErrorCode.serverUnreachable.rawValue,
          userInfo: nil
        )
        let backoffType = errorHandler(serverUnreachableError)
        XCTAssertEqual(backoffType, .typeExponential)
      }
      expectation.fulfill()
    }.catch { error in
      XCTFail("Unexpected error: \(error)")
    }

    waitForExpectations(timeout: 1.0)
  }

  func testErrorHandlerDoesNotTriggerBackoffForOtherErrors() {
    // Arrange
    let mockClient = MockRecaptchaClient()
    mockClient.mockToken = "valid-recaptcha-token"
    MockRecaptcha.mockClient = mockClient

    let mockBackoffWrapper = MockBackoffWrapper()

    let generator = RecaptchaEnterpriseTokenGenerator(
      siteKey: testSiteKey,
      recaptchaAction: mockAction,
      recaptchaClass: MockRecaptcha.self,
      backoffWrapper: mockBackoffWrapper
    )

    let expectation = self.expectation(description: "Calls backoff wrapper")

    // Act
    generator.getRecaptchaToken().then { _ in
      // Assert
      XCTAssertNotNil(mockBackoffWrapper.capturedErrorHandler)
      if let errorHandler = mockBackoffWrapper.capturedErrorHandler {
        let otherError = NSError(
          domain: AppCheckCoreErrorDomain,
          code: AppCheckCoreErrorCode.unknown.rawValue,
          userInfo: nil
        )
        let backoffType = errorHandler(otherError)
        XCTAssertEqual(backoffType, .typeNone)
      }
      expectation.fulfill()
    }.catch { error in
      XCTFail("Unexpected error: \(error)")
    }

    waitForExpectations(timeout: 1.0)
  }

  func testGetRecaptchaTokenExecutionNilNilFallback() {
    // Arrange
    let mockClient = MockRecaptchaClient()
    MockRecaptcha.mockClient = mockClient

    let generator = RecaptchaEnterpriseTokenGenerator(
      siteKey: testSiteKey,
      recaptchaAction: mockAction,
      recaptchaClass: MockRecaptcha.self,
      backoffWrapper: MockBackoffWrapper()
    )

    let expectation = self
      .expectation(description: "Fails with fallback error when execute returns nil, nil")

    // Act
    generator.getRecaptchaToken().then { token in
      XCTFail("Should not succeed when execute returns nil, nil")
    }.catch { error in
      // Assert
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, AppCheckCoreErrorDomain)
      XCTAssertEqual(nsError.code, AppCheckCoreErrorCode.unknown.rawValue)
      XCTAssertEqual(nsError.localizedFailureReason, "Failed to execute Recaptcha action")
      expectation.fulfill()
    }

    waitForExpectations(timeout: 1.0)
  }
}
