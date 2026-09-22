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

/// Locks in the main-thread callback-delivery contract inherited from the
/// Objective-C (v11) implementation.
///
/// In v11 every completion handler was delivered via `FBLPromise`'s bare
/// `.then` / `.catch`, which dispatch onto `FBLPromise.defaultDispatchQueue`.
/// That default is set to `dispatch_get_main_queue()` in `+[FBLPromise
/// initialize]` and is never overridden by this library or its known consumers,
/// so the effective contract was: **completion handlers always arrive on the
/// main queue.**
///
/// The contract is invisible at the v11 call site (nothing there mentions a
/// queue), so it is easy to drop during a port. These tests make it explicit.
///
/// Note: the `async` variants intentionally do *not* have this guarantee —
/// `async` callers are expected to hop to the main actor themselves, and
/// forcing a hop on them would be a new divergence.
final class AppCheckCoreMainThreadDeliveryTests: XCTestCase {
  private var fakeStorage: AppCheckCoreStorageFake!
  private var fakeAppCheckProvider: AppCheckCoreProviderFake!
  private var fakeTokenRefresher: AppCheckCoreTokenRefresherFake!
  private var fakeSettings: AppCheckCoreSettingsFake!
  private var fakeTokenDelegate: ThreadRecordingTokenDelegateFake!
  private var appCheck: AppCheckCore!

  override func setUp() {
    super.setUp()

    fakeStorage = AppCheckCoreStorageFake()
    fakeAppCheckProvider = AppCheckCoreProviderFake()
    fakeTokenRefresher = AppCheckCoreTokenRefresherFake()
    fakeSettings = AppCheckCoreSettingsFake()
    fakeTokenDelegate = ThreadRecordingTokenDelegateFake()

    appCheck = AppCheckCore(serviceName: "AppCheckCoreMainThreadDeliveryTests",
                            appCheckProvider: fakeAppCheckProvider,
                            storage: fakeStorage,
                            tokenRefresher: fakeTokenRefresher,
                            settings: fakeSettings,
                            tokenDelegate: fakeTokenDelegate)
  }

  override func tearDown() {
    appCheck = nil
    fakeAppCheckProvider = nil
    fakeStorage = nil
    fakeTokenRefresher = nil
    fakeSettings = nil
    fakeTokenDelegate = nil
    super.tearDown()
  }

  // MARK: - token(forcingRefresh:completion:)

  func testTokenForcingRefreshCompletion_DeliversOnMainThread_WhenSuccess() {
    configureSuccess()

    let expectation = expectation(description: "completion called")
    var wasMainThread = false

    appCheck.token(forcingRefresh: false) { _ in
      wasMainThread = Thread.isMainThread
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)
    XCTAssertTrue(
      wasMainThread,
      "token(forcingRefresh:completion:) must deliver its completion handler on "
        + "the main thread, matching the v11 FBLPromise default-queue behavior."
    )
  }

  func testTokenForcingRefreshCompletion_DeliversOnMainThread_WhenError() {
    configureFailure()

    let expectation = expectation(description: "completion called")
    var wasMainThread = false

    appCheck.token(forcingRefresh: false) { _ in
      wasMainThread = Thread.isMainThread
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)
    XCTAssertTrue(
      wasMainThread,
      "The error path must also deliver on the main thread; v11 used a bare "
        + "`.catch`, which dispatches to the main queue."
    )
  }

  // MARK: - limitedUseToken(completion:)

  func testLimitedUseTokenCompletion_DeliversOnMainThread_WhenSuccess() {
    fakeAppCheckProvider.limitedUseTokenToReturn =
      AppCheckCoreToken(token: UUID().uuidString, expirationDate: .distantFuture)

    let expectation = expectation(description: "completion called")
    var wasMainThread = false

    appCheck.limitedUseToken { _ in
      wasMainThread = Thread.isMainThread
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)
    XCTAssertTrue(
      wasMainThread,
      "limitedUseToken(completion:) must deliver on the main thread."
    )
  }

  func testLimitedUseTokenCompletion_DeliversOnMainThread_WhenError() {
    fakeAppCheckProvider.limitedUseErrorToReturn = NSError(
      domain: "TestDomain", code: 1, userInfo: nil
    )

    let expectation = expectation(description: "completion called")
    var wasMainThread = false

    appCheck.limitedUseToken { _ in
      wasMainThread = Thread.isMainThread
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)
    XCTAssertTrue(
      wasMainThread,
      "The limited-use error path must also deliver on the main thread."
    )
  }

  // MARK: - Delivery is still main-thread when invoked from a background queue

  func testTokenForcingRefreshCompletion_DeliversOnMainThread_WhenCalledOffMain() {
    configureSuccess()

    let expectation = expectation(description: "completion called")
    var wasMainThread = false

    DispatchQueue.global(qos: .userInitiated).async {
      self.appCheck.token(forcingRefresh: false) { _ in
        wasMainThread = Thread.isMainThread
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 5.0)
    XCTAssertTrue(
      wasMainThread,
      "Delivery must be on the main thread regardless of the calling queue; "
        + "FBLPromise dispatched to the main queue unconditionally."
    )
  }

  // MARK: - Token delegate

  func testTokenDidUpdateDelegate_CalledOnMainThread() {
    configureSuccess()

    let expectation = expectation(description: "delegate notified")
    fakeTokenDelegate.onTokenDidUpdate = { expectation.fulfill() }

    appCheck.token(forcingRefresh: false) { _ in }

    wait(for: [expectation], timeout: 5.0)
    XCTAssertEqual(
      fakeTokenDelegate.tokenDidUpdateWasMainThread, true,
      "tokenDidUpdate(_:serviceName:) was delivered on the main queue in v11 "
        + "because it was invoked from inside a bare `.then`."
    )
  }

  // MARK: - Helpers

  private func configureSuccess() {
    let token = AppCheckCoreToken(
      token: UUID().uuidString, expirationDate: .distantFuture
    )
    fakeStorage.getTokenHandler = { nil }
    fakeAppCheckProvider.tokenToReturn = token
    fakeStorage.setTokenHandler = { _ in token }
  }

  private func configureFailure() {
    fakeStorage.getTokenHandler = { nil }
    fakeAppCheckProvider.errorToReturn = NSError(
      domain: "TestDomain", code: 1, userInfo: nil
    )
  }
}

// MARK: - Fakes

/// Records the thread on which the delegate callback arrived.
private final class ThreadRecordingTokenDelegateFake: NSObject,
  AppCheckCoreTokenDelegate {
  var tokenDidUpdateWasMainThread: Bool?
  var onTokenDidUpdate: (() -> Void)?

  func tokenDidUpdate(_ token: AppCheckCoreToken, serviceName: String) {
    tokenDidUpdateWasMainThread = Thread.isMainThread
    onTokenDidUpdate?()
  }
}
