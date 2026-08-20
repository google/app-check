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
