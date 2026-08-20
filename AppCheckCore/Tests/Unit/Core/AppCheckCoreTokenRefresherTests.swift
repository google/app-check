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

class AppCheckCoreTokenRefresherTests: XCTestCase {
  var fakeTimer: AppCheckCoreFakeTimer!
  var settings: AppCheckCoreSettings!
  var initialTokenRefreshResult: AppCheckCoreTokenRefreshResult!

  override func setUp() {
    super.setUp()

    settings = AppCheckCoreSettings()
    fakeTimer = AppCheckCoreFakeTimer()

    let receivedAtDate = Date()
    initialTokenRefreshResult = AppCheckCoreTokenRefreshResult(status: .success,
                                                               expirationDate: receivedAtDate
                                                                 .addingTimeInterval(1000),
                                                               receivedAt: receivedAtDate)
  }

  override func tearDown() {
    fakeTimer = nil
    settings = nil
    super.tearDown()
  }

  // MARK: - Auto refresh is allowed

  func testInitialRefreshWhenAutoRefreshAllowed() {
    initialTokenRefreshResult = AppCheckCoreTokenRefreshResult(status: .never,
                                                               expirationDate: nil,
                                                               receivedAt: nil)
    let refresher = createRefresher()

    settings.isTokenAutoRefreshEnabled = true

    let initialTimerCreatedExpectation = expectation(description: "initial refresh timer created")
    initialTimerCreatedExpectation.isInverted = true
    fakeTimer.createHandler = { [weak self] fireDate in
      self?.fakeTimer.createHandler = nil
      initialTimerCreatedExpectation.fulfill()
    }

    settings.isTokenAutoRefreshEnabled = true

    var initialRefreshCompletion: AppCheckCoreTokenRefreshCompletion?
    let initialRefreshExpectation = expectation(description: "initial refresh")
    refresher.tokenRefreshHandler = { completion in
      initialRefreshCompletion = completion
      initialRefreshExpectation.fulfill()
    }

    let initialTokenExpirationDate = Date(timeIntervalSinceNow: 60 * 60)
    let initialTokenReceivedDate = Date()
    let initialRefreshResult = AppCheckCoreTokenRefreshResult(status: .success,
                                                              expirationDate: initialTokenExpirationDate,
                                                              receivedAt: initialTokenReceivedDate)

    wait(for: [initialTimerCreatedExpectation, initialRefreshExpectation], timeout: 1)

    settings.isTokenAutoRefreshEnabled = true

    let expectedRefreshDate = self.expectedRefreshDate(
      receivedDate: initialTokenReceivedDate,
      expirationDate: initialTokenExpirationDate
    )
    let nextTimerCreateExpectation = expectation(description: "next refresh create timer")
    fakeTimer.createHandler = { [weak self] fireDate in
      self?.fakeTimer.createHandler = nil
      XCTAssertEqual(fireDate, expectedRefreshDate)
      nextTimerCreateExpectation.fulfill()
    }

    initialRefreshCompletion?(initialRefreshResult)
    wait(for: [nextTimerCreateExpectation], timeout: 0.5)

    settings.isTokenAutoRefreshEnabled = true

    let nextRefreshResult = AppCheckCoreTokenRefreshResult(status: .success,
                                                           expirationDate: expectedRefreshDate
                                                             .addingTimeInterval(60 * 60),
                                                           receivedAt: expectedRefreshDate)
    let nextRefreshExpectation = expectation(description: "next refresh")
    refresher.tokenRefreshHandler = { completion in
      nextRefreshExpectation.fulfill()
      completion(nextRefreshResult)
    }

    fireTimer()

    wait(for: [nextRefreshExpectation], timeout: 1)
  }

  func testNoTimeScheduledUntilHandlerSet() {
    let timerCreateExpectation1 = expectation(description: "create timer 1")
    timerCreateExpectation1.isInverted = true
    fakeTimer.createHandler = { fireDate in
      timerCreateExpectation1.fulfill()
    }

    let refresher = createRefresher()
    XCTAssertNotNil(refresher)

    wait(for: [timerCreateExpectation1], timeout: 0.5)

    settings.isTokenAutoRefreshEnabled = true

    let timerCreateExpectation2 = expectation(description: "create timer 2")
    fakeTimer.createHandler = { fireDate in
      timerCreateExpectation2.fulfill()
    }

    refresher.tokenRefreshHandler = { completion in }

    wait(for: [timerCreateExpectation2], timeout: 0.5)
  }

  func testNextRefreshOnRefreshSuccess() {
    let refresher = createRefresher()

    let refreshedTokenExpirationDate = initialTokenRefreshResult.tokenExpirationDate!
      .addingTimeInterval(60 * 60)
    let refreshResult = AppCheckCoreTokenRefreshResult(status: .success,
                                                       expirationDate: refreshedTokenExpirationDate,
                                                       receivedAt: initialTokenRefreshResult
                                                         .tokenExpirationDate!)

    settings.isTokenAutoRefreshEnabled = true
    settings.isTokenAutoRefreshEnabled = true

    let initialRefreshExpectation = expectation(description: "initial refresh")
    refresher.tokenRefreshHandler = { completion in
      initialRefreshExpectation.fulfill()
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        completion(refreshResult)
      }
    }

    let expectedFireDate = expectedRefreshDate(
      receivedDate: refreshResult.tokenReceivedAtDate!,
      expirationDate: refreshResult.tokenExpirationDate!
    )
    let createTimerExpectation = expectation(description: "create timer")
    fakeTimer.createHandler = { fireDate in
      createTimerExpectation.fulfill()
      XCTAssertEqual(fireDate, expectedFireDate)
    }

    settings.isTokenAutoRefreshEnabled = true

    fireTimer()

    wait(for: [initialRefreshExpectation, createTimerExpectation], timeout: 1, enforceOrder: true)
  }

  func testBackoff() {
    let refresher = createRefresher()

    var expectedBackoffTime: TimeInterval = 0
    let maximumBackoffTime: TimeInterval = 16 * 60

    settings.isTokenAutoRefreshEnabled = true

    for _ in 0 ..< 10 {
      settings.isTokenAutoRefreshEnabled = true

      let initialRefreshExpectation = expectation(description: "initial refresh")
      refresher.tokenRefreshHandler = { completion in
        initialRefreshExpectation.fulfill()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          let refreshFailure = AppCheckCoreTokenRefreshResult(
            status: .failure,
            expirationDate: nil,
            receivedAt: nil
          )
          completion(refreshFailure)
        }
      }

      expectedBackoffTime = expectedBackoffTime == 0 ? 30 : expectedBackoffTime * 2
      expectedBackoffTime = min(expectedBackoffTime, maximumBackoffTime)
      let expectedFireDate = Date().addingTimeInterval(expectedBackoffTime)

      let createTimerExpectation = expectation(description: "create timer")
      fakeTimer.createHandler = { fireDate in
        createTimerExpectation.fulfill()
        XCTAssertLessThan(abs(expectedFireDate.timeIntervalSince(fireDate)), 2)
      }

      settings.isTokenAutoRefreshEnabled = true

      fireTimer()

      wait(for: [initialRefreshExpectation, createTimerExpectation], timeout: 1, enforceOrder: true)
    }
  }

  // MARK: - Auto refresh is not allowed

  func testNoInitialRefreshWhenAutoRefreshIsNotAllowed() {
    let refresher = createRefresher()

    settings.isTokenAutoRefreshEnabled = false

    let timerCreateExpectation = expectation(description: "create timer")
    timerCreateExpectation.isInverted = true

    fakeTimer.createHandler = { [weak self] fireDate in
      self?.fakeTimer.createHandler = nil
      timerCreateExpectation.fulfill()
    }

    let refreshResult = AppCheckCoreTokenRefreshResult(status: .success,
                                                       expirationDate: Date(timeIntervalSinceNow: 60 *
                                                         60),
                                                       receivedAt: Date())
    let refreshExpectation = expectation(description: "refresh")
    refreshExpectation.isInverted = true

    refresher.tokenRefreshHandler = { completion in
      refreshExpectation.fulfill()
      completion(refreshResult)
    }

    wait(for: [timerCreateExpectation, refreshExpectation], timeout: 1)
  }

  func testNoRefreshWhenAutoRefreshWasDisabledAfterInit() {
    let refresher = createRefresher()

    settings.isTokenAutoRefreshEnabled = true

    let expectedTimerFireDate = expectedRefreshDate(
      receivedDate: initialTokenRefreshResult.tokenReceivedAtDate!,
      expirationDate: initialTokenRefreshResult.tokenExpirationDate!
    )
    let timerCreateExpectation = expectation(description: "create timer")

    fakeTimer.createHandler = { [weak self] fireDate in
      self?.fakeTimer.createHandler = nil
      XCTAssertEqual(fireDate, expectedTimerFireDate)
      timerCreateExpectation.fulfill()
    }

    let refreshResult = AppCheckCoreTokenRefreshResult(status: .success,
                                                       expirationDate: expectedTimerFireDate
                                                         .addingTimeInterval(60 * 60),
                                                       receivedAt: expectedTimerFireDate)
    let noRefreshExpectation = expectation(description: "initial refresh")
    noRefreshExpectation.isInverted = true
    refresher.tokenRefreshHandler = { completion in
      noRefreshExpectation.fulfill()
      completion(refreshResult)
    }

    wait(for: [timerCreateExpectation], timeout: 1)

    settings.isTokenAutoRefreshEnabled = false

    fireTimer()

    wait(for: [noRefreshExpectation], timeout: 1)
  }

  // MARK: - Update token expiration

  func testUpdateWithRefreshResultWhenAutoRefreshIsAllowed() {
    let refresher = createRefresher()

    let newExpirationDate = initialTokenRefreshResult.tokenExpirationDate!
      .addingTimeInterval(10 * 60)
    let newRefreshResult = AppCheckCoreTokenRefreshResult(status: .success,
                                                          expirationDate: newExpirationDate,
                                                          receivedAt: initialTokenRefreshResult
                                                            .tokenExpirationDate!)

    settings.isTokenAutoRefreshEnabled = true

    let expectedTimerFireDate = expectedRefreshDate(
      receivedDate: newRefreshResult.tokenReceivedAtDate!,
      expirationDate: newRefreshResult.tokenExpirationDate!
    )
    let timerCreateExpectation = expectation(description: "create timer")

    fakeTimer.createHandler = { [weak self] fireDate in
      self?.fakeTimer.createHandler = nil
      XCTAssertEqual(fireDate, expectedTimerFireDate)
      timerCreateExpectation.fulfill()
    }

    refresher.updateWithRefreshResult(newRefreshResult)

    wait(for: [timerCreateExpectation], timeout: 1)
  }

  func testUpdateWithRefreshResultWhenAutoRefreshIsNotAllowed() {
    let refresher = createRefresher()

    let newRefreshResult = AppCheckCoreTokenRefreshResult(status: .success,
                                                          expirationDate: Date(timeIntervalSinceNow: 60 *
                                                            60),
                                                          receivedAt: initialTokenRefreshResult
                                                            .tokenExpirationDate!)

    settings.isTokenAutoRefreshEnabled = false

    let timerCreateExpectation = expectation(description: "create timer")
    timerCreateExpectation.isInverted = true

    fakeTimer.createHandler = { [weak self] fireDate in
      self?.fakeTimer.createHandler = nil
      timerCreateExpectation.fulfill()
    }

    refresher.updateWithRefreshResult(newRefreshResult)

    wait(for: [timerCreateExpectation], timeout: 1)
  }

  func testUpdateWithRefreshResult_WhenTokenExpiresLessThanIn1Minute() {
    let refresher = createRefresher()

    let newExpirationDate = Date(timeIntervalSinceNow: 0.5 * 60)
    let newRefreshResult = AppCheckCoreTokenRefreshResult(status: .success,
                                                          expirationDate: newExpirationDate,
                                                          receivedAt: Date())

    settings.isTokenAutoRefreshEnabled = true

    let timerCreateExpectation = expectation(description: "create timer")

    fakeTimer.createHandler = { [weak self] fireDate in
      self?.fakeTimer.createHandler = nil
      XCTAssertEqual(fireDate.timeIntervalSinceNow, 60, accuracy: 1)
      timerCreateExpectation.fulfill()
    }

    refresher.updateWithRefreshResult(newRefreshResult)

    wait(for: [timerCreateExpectation], timeout: 1)
  }

  // MARK: - Helpers

  private func fireTimer() {
    if let handler = fakeTimer.handler {
      handler()
    } else {
      XCTFail("handler must not be nil!")
    }
  }

  private func createRefresher() -> AppCheckCoreTokenRefresher {
    return AppCheckCoreTokenRefresher(refreshResult: initialTokenRefreshResult,
                                      timerProvider: fakeTimer.fakeTimerProvider(),
                                      settings: settings)
  }

  private func expectedRefreshDate(receivedDate: Date, expirationDate: Date) -> Date {
    let timeToLive = expirationDate.timeIntervalSince(receivedDate)
    XCTAssertGreaterThanOrEqual(timeToLive, 0)

    var timeToRefresh = timeToLive / 2 + 5 * 60

    let minimalAutoRefreshInterval: TimeInterval = 60
    timeToRefresh = max(timeToRefresh, minimalAutoRefreshInterval)

    let refreshDate = receivedDate.addingTimeInterval(timeToRefresh)
    let now = Date()

    return max(refreshDate, now)
  }
}
