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

@_spi(FirebaseInternal) @testable import AppCheckCore
import XCTest

class AppCheckCoreErrorsTests: XCTestCase {
  func testErrorDomainIsUnchanged() {
    XCTAssertEqual(AppCheckCoreErrorDomain, "com.google.app_check_core")
    XCTAssertEqual(AppCheckCoreErrorCode.errorDomain, "com.google.app_check_core")
  }

  func testErrorCodePatternMatching() {
    let error = NSError(
      domain: AppCheckCoreErrorDomain,
      code: AppCheckCoreErrorCode.keychain.rawValue,
      userInfo: nil
    )

    var matched = false
    do {
      throw error
    } catch AppCheckCoreErrorCode.keychain {
      matched = true
    } catch {
      XCTFail("Failed to pattern match AppCheckCoreErrorCode")
    }

    XCTAssertTrue(matched)
  }
}
