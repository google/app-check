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
}

// MARK: - Mocks

private class MockRCAAction: NSObject, RCAActionProtocol {
  var action: String { return customAction }

  static var login: RCAActionProtocol { return MockRCAAction(customAction: "login") }
  static var signup: RCAActionProtocol { return MockRCAAction(customAction: "signup") }

  let customAction: String

  required init(customAction: String) {
    self.customAction = customAction
    super.init()
  }
}
