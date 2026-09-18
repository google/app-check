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

class AppCheckCoreCryptoUtilsTests: XCTestCase {
  func testSHA256HashFromData() {
    let dataToHash = "some data to hash".data(using: .utf8)!

    let hashData = AppCheckCoreCryptoUtils.sha256Hash(from: dataToHash)

    // Convert to a base64 encoded string to compare.
    let base64EncodedHashString = hashData.base64EncodedString()

    // Base64 encoded hash of UTF8 encoded string "some data to hash".
    let expectedHashString = "ai2iCUOTHpg0/BLP5btHu9muQ0iaMHJpYrV29OOZPlA="

    XCTAssertEqual(base64EncodedHashString, expectedHashString)
  }
}
