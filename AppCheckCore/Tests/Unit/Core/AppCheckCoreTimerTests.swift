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

class AppCheckCoreTimerTests: XCTestCase {
  func testTimerProvider() {
    let queue = DispatchQueue(label: "AppCheckCoreTimerTests.testInit", qos: .default)
    let fireTimerIn: TimeInterval = 1
    let startTime = Date()
    let fireDate = Date(timeIntervalSinceNow: fireTimerIn)

    let timerProvider = AppCheckCoreTimer.timerProvider()

    let timerExpectation = expectation(description: "timer")
    let timer = timerProvider(fireDate, queue) {
      let actuallyFiredIn = Date().timeIntervalSince(startTime)
      // Check that fired at proper time (allowing some timer drift).
      XCTAssertLessThan(abs(actuallyFiredIn - fireTimerIn), 0.5)

      timerExpectation.fulfill()
    }

    XCTAssertNotNil(timer)

    waitForExpectations(timeout: fireTimerIn + 1)
  }

  func testInit() {
    let queue = DispatchQueue(label: "AppCheckCoreTimerTests.testInit", qos: .default)
    let fireTimerIn: TimeInterval = 2
    let startTime = Date()
    let fireDate = Date(timeIntervalSinceNow: fireTimerIn)

    let timerExpectation = expectation(description: "timer")
    let timer = AppCheckCoreTimer(fireDate: fireDate, dispatchQueue: queue) {
      let actuallyFiredIn = Date().timeIntervalSince(startTime)
      // Check that fired at proper time (allowing some timer drift).
      XCTAssertLessThan(abs(actuallyFiredIn - fireTimerIn), 0.5)

      timerExpectation.fulfill()
    }

    XCTAssertNotNil(timer)

    waitForExpectations(timeout: fireTimerIn + 1)
  }
}
