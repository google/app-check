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

class AppCheckCoreLoggerTests: XCTestCase {
  override func tearDown() {
    // `logLevel` is global state; restore the default so tests can't leak into
    // one another (test execution order is not guaranteed).
    AppCheckCoreLogger.logLevel = .warning
    super.tearDown()
  }

  func testDefaultLogLevel() {
    let defaultLogLevel = AppCheckCoreLogger.logLevel

    XCTAssertEqual(defaultLogLevel, .warning)
  }

  func testSetLogLevel() {
    let expectedLogLevel: AppCheckCoreLogLevel = .debug

    AppCheckCoreLogger.logLevel = expectedLogLevel

    XCTAssertEqual(AppCheckCoreLogger.logLevel, expectedLogLevel)
  }

  /// The Objective-C `logLevel` class property was `atomic`, backed by a
  /// `volatile` static. Concurrent reads and writes must stay race-free.
  /// Run with the Thread Sanitizer enabled to get full value from this test.
  func testLogLevelConcurrentAccessIsRaceFree() {
    let iterations = 1000
    let group = DispatchGroup()

    for index in 0 ..< iterations {
      DispatchQueue.global().async(group: group) {
        AppCheckCoreLogger.logLevel = index.isMultiple(of: 2) ? .debug : .fault
      }
      DispatchQueue.global().async(group: group) {
        _ = AppCheckCoreLogger.logLevel
      }
    }

    XCTAssertEqual(group.wait(timeout: .now() + 30), .success)

    // Whatever the interleaving, the final value must be one that was written.
    let finalLogLevel = AppCheckCoreLogger.logLevel
    XCTAssertTrue(finalLogLevel == .debug || finalLogLevel == .fault)
  }
}
