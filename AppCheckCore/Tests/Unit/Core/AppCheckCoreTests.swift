@testable import AppCheckCore
import XCTest

private let kPlaceholderTokenValue = "eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ=="
private let kResourceName = "projects/test_project_id/apps/test_app_id"
private let kAppName = "AppCheckCoreTests"
private let kAppGroupID = "app_group_id"

class AppCheckCoreTests: XCTestCase {
  var fakeStorage: AppCheckCoreStorageFake!
  var fakeAppCheckProvider: AppCheckCoreProviderFake!
  var fakeTokenRefresher: AppCheckCoreTokenRefresherFake!
  var fakeSettings: AppCheckCoreSettingsFake!
  var fakeTokenDelegate: AppCheckCoreTokenDelegateFake!
  var appCheck: AppCheckCore!

  override func setUp() {
    super.setUp()

    fakeStorage = AppCheckCoreStorageFake()
    fakeAppCheckProvider = AppCheckCoreProviderFake()
    fakeTokenRefresher = AppCheckCoreTokenRefresherFake()
    fakeSettings = AppCheckCoreSettingsFake()
    fakeTokenDelegate = AppCheckCoreTokenDelegateFake()

    appCheck = AppCheckCore(serviceName: kAppName,
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

  // MARK: - Public Get Token

  func testGetToken_WhenNoCache_Success() async {
    let expectedToken = validToken()
    configuredExpectations_GetTokenWhenNoCache(expectedToken: expectedToken)

    do {
      let result = try await appCheck.token(forcingRefresh: false)
      XCTAssertEqual(result, expectedToken)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }

    XCTAssertEqual(fakeAppCheckProvider.getTokenCallCount, 1)
    XCTAssertEqual(fakeStorage.lastSetToken, expectedToken)
    XCTAssertEqual(fakeTokenRefresher.updateWithRefreshResultCallCount, 1)
    XCTAssertEqual(fakeTokenDelegate.lastToken, expectedToken)
  }

  func testGetToken_WhenCachedTokenIsValid_Success() async {
    await assertGetToken_WhenCachedTokenIsValid_Success()
  }

  func testGetTokenForcingRefresh_WhenCachedTokenIsValid_Success() async {
    let expectedToken = validToken()
    configuredExpectations_GetTokenForcingRefreshWhenCacheIsValid(expectedToken: expectedToken)

    do {
      let result = try await appCheck.token(forcingRefresh: true)
      XCTAssertEqual(result, expectedToken)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }

    XCTAssertEqual(fakeAppCheckProvider.getTokenCallCount, 1)
    XCTAssertEqual(fakeStorage.lastSetToken, expectedToken)
    XCTAssertEqual(fakeTokenRefresher.updateWithRefreshResultCallCount, 1)
    XCTAssertEqual(fakeTokenDelegate.lastToken, expectedToken)
  }

  func testGetToken_WhenCachedTokenExpired_Success() async {
    let expectedToken = validToken()
    configuredExpectations_GetTokenWhenCachedTokenExpired(expectedToken: expectedToken)

    do {
      let result = try await appCheck.token(forcingRefresh: false)
      XCTAssertEqual(result, expectedToken)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }

    XCTAssertEqual(fakeAppCheckProvider.getTokenCallCount, 1)
    XCTAssertEqual(fakeStorage.lastSetToken, expectedToken)
    XCTAssertEqual(fakeTokenRefresher.updateWithRefreshResultCallCount, 1)
    XCTAssertEqual(fakeTokenDelegate.lastToken, expectedToken)
  }

  func testGetToken_AppCheckProviderError() async {
    let cachedToken = soonExpiringToken()
    let providerError = NSError(domain: "AppCheckCoreTests", code: -1, userInfo: nil)

    configuredExpectations_GetTokenWhenError(error: providerError, token: cachedToken)

    do {
      _ = try await appCheck.token(forcingRefresh: false)
      XCTFail("Expected error")
    } catch {
      XCTAssertEqual(error as NSError, providerError)
      XCTAssertNotEqual((error as NSError).domain, AppCheckCoreErrorDomain)
    }

    XCTAssertEqual(fakeAppCheckProvider.getTokenCallCount, 1)
    XCTAssertEqual(fakeTokenDelegate.tokenDidUpdateCallCount, 0)
    XCTAssertNil(fakeStorage.lastSetToken)
    XCTAssertEqual(fakeTokenRefresher.updateWithRefreshResultCallCount, 0)
  }

  // MARK: - Token refresher

  func testTokenRefreshTriggeredAndRefreshSuccess() async {
    fakeStorage.getTokenHandler = { nil }

    let expirationDate = Date(timeIntervalSinceNow: 10000)
    let tokenToReturn = AppCheckCoreToken(token: "valid", expirationDate: expirationDate)
    fakeAppCheckProvider.tokenToReturn = tokenToReturn

    fakeStorage.setTokenHandler = { token in tokenToReturn }

    guard let handler = fakeTokenRefresher.tokenRefreshHandler else {
      XCTFail("`tokenRefreshHandler` must be not `nil`.")
      return
    }

    let completionExpectation = expectation(description: "completion")
    handler { refreshResult in
      XCTAssertEqual(refreshResult.tokenExpirationDate, expirationDate)
      XCTAssertEqual(refreshResult.status, .success)
      completionExpectation.fulfill()
    }

    await fulfillment(of: [completionExpectation], timeout: 0.5)

    XCTAssertEqual(fakeAppCheckProvider.getTokenCallCount, 1)
    XCTAssertEqual(fakeStorage.lastSetToken, tokenToReturn)
    XCTAssertEqual(fakeTokenRefresher.updateWithRefreshResultCallCount, 1)
    XCTAssertEqual(fakeTokenDelegate.tokenDidUpdateCallCount, 1)
    XCTAssertEqual(fakeTokenDelegate.lastToken, tokenToReturn)
  }

  func testTokenRefreshTriggeredAndRefreshError() async {
    fakeStorage.getTokenHandler = { nil }

    let providerError = internalError()
    fakeAppCheckProvider.errorToReturn = providerError

    guard let handler = fakeTokenRefresher.tokenRefreshHandler else {
      XCTFail("`tokenRefreshHandler` must be not `nil`.")
      return
    }

    let completionExpectation = expectation(description: "completion")
    handler { refreshResult in
      XCTAssertEqual(refreshResult.status, .failure)
      XCTAssertNil(refreshResult.tokenExpirationDate)
      XCTAssertNil(refreshResult.tokenReceivedAtDate)
      completionExpectation.fulfill()
    }

    await fulfillment(of: [completionExpectation], timeout: 0.5)

    XCTAssertEqual(fakeAppCheckProvider.getTokenCallCount, 1)
    XCTAssertEqual(fakeTokenDelegate.tokenDidUpdateCallCount, 0)
    XCTAssertNil(fakeStorage.lastSetToken)
    XCTAssertEqual(fakeTokenRefresher.updateWithRefreshResultCallCount, 0)
  }

  func testLimitedUseTokenWithSuccess() async {
    let expectedToken = validToken()
    fakeAppCheckProvider.limitedUseTokenToReturn = expectedToken

    do {
      let result = try await appCheck.limitedUseToken()
      XCTAssertEqual(result, expectedToken)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }

    XCTAssertEqual(fakeAppCheckProvider.getLimitedUseTokenCallCount, 1)
    XCTAssertEqual(fakeStorage.lastSetToken, nil)
    XCTAssertEqual(fakeTokenDelegate.tokenDidUpdateCallCount, 0)
  }

  func testLimitedUseToken_WhenTokenGenerationErrors() async {
    let providerError = AppCheckCoreErrorUtil.keychainError(with: internalError()) as NSError
    fakeAppCheckProvider.limitedUseErrorToReturn = providerError

    do {
      _ = try await appCheck.limitedUseToken()
      XCTFail("Expected error")
    } catch {
      XCTAssertEqual(error as NSError, providerError)
      XCTAssertEqual((error as NSError).domain, AppCheckCoreErrorDomain)
    }

    XCTAssertEqual(fakeAppCheckProvider.getLimitedUseTokenCallCount, 1)
    XCTAssertEqual(fakeAppCheckProvider.getTokenCallCount, 0)
    XCTAssertNil(fakeStorage.lastSetToken)
    XCTAssertEqual(fakeTokenDelegate.tokenDidUpdateCallCount, 0)
    XCTAssertEqual(fakeTokenRefresher.updateWithRefreshResultCallCount, 0)
  }

  // MARK: - Merging multiple get token requests

  func testGetToken_WhenCalledSeveralTimesSuccess_ThenThereIsOnlyOneOperation() async {
    fakeStorage.getTokenHandler = { nil }

    let expectedToken = validToken()
    fakeAppCheckProvider.tokenToReturn = expectedToken

    // Create a continuation we can resume later
    var storeTokenContinuation: CheckedContinuation<AppCheckCoreToken?, Error>?
    fakeStorage.setTokenHandler = { token in
      try await withCheckedThrowingContinuation { continuation in
        storeTokenContinuation = continuation
      }
    }

    let getTokenCallsCount = 10

    // Request token several times concurrently
    Task {
      // Delay so the task group launches before we resume the continuation
      try? await Task.sleep(nanoseconds: 100_000_000)
      storeTokenContinuation?.resume(returning: expectedToken)
    }

    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< getTokenCallsCount {
        group.addTask {
          do {
            let result = try await self.appCheck.token(forcingRefresh: false)
            XCTAssertEqual(result, expectedToken)
          } catch {
            XCTFail("Unexpected error")
          }
        }
      }
    }

    XCTAssertEqual(fakeAppCheckProvider.getTokenCallCount, 1)
    XCTAssertEqual(fakeTokenRefresher.updateWithRefreshResultCallCount, 1)
    XCTAssertEqual(fakeTokenDelegate.tokenDidUpdateCallCount, 1)

    await assertGetToken_WhenCachedTokenIsValid_Success()
  }

  func testGetToken_WhenCalledSeveralTimesError_ThenThereIsOnlyOneOperation() async {
    fakeStorage.getTokenHandler = { nil }

    let expectedToken = validToken()
    fakeAppCheckProvider.tokenToReturn = expectedToken

    var storeTokenContinuation: CheckedContinuation<AppCheckCoreToken?, Error>?
    fakeStorage.setTokenHandler = { token in
      try await withCheckedThrowingContinuation { continuation in
        storeTokenContinuation = continuation
      }
    }

    let storageError = NSError(domain: name, code: 0, userInfo: nil)
    let getTokenCallsCount = 10

    Task {
      try? await Task.sleep(nanoseconds: 100_000_000)
      storeTokenContinuation?.resume(throwing: storageError)
    }

    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< getTokenCallsCount {
        group.addTask {
          do {
            _ = try await self.appCheck.token(forcingRefresh: false)
            XCTFail("Expected error")
          } catch {
            XCTAssertEqual(error as NSError, storageError)
          }
        }
      }
    }

    XCTAssertEqual(fakeAppCheckProvider.getTokenCallCount, 1)
    XCTAssertEqual(fakeTokenDelegate.tokenDidUpdateCallCount, 0)
    XCTAssertEqual(fakeStorage.lastSetToken, expectedToken)
    XCTAssertEqual(fakeTokenRefresher.updateWithRefreshResultCallCount, 0)

    await assertGetToken_WhenCachedTokenIsValid_Success()
  }

  // MARK: - Helpers

  private func internalError() -> NSError {
    return NSError(domain: "com.internal.error", code: -1, userInfo: nil)
  }

  private func validToken() -> AppCheckCoreToken {
    return AppCheckCoreToken(token: UUID().uuidString, expirationDate: Date.distantFuture)
  }

  private func soonExpiringToken() -> AppCheckCoreToken {
    let date = Date(timeIntervalSinceNow: 4.5 * 60)
    return AppCheckCoreToken(token: "valid", expirationDate: date)
  }

  private func assertGetToken_WhenCachedTokenIsValid_Success() async {
    let initialCallCount = fakeAppCheckProvider.getTokenCallCount
    let cachedToken = validToken()

    configuredExpectation_GetTokenWhenCacheTokenIsValid(expectedToken: cachedToken)

    do {
      let result = try await appCheck.token(forcingRefresh: false)
      XCTAssertEqual(result, cachedToken)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }

    XCTAssertEqual(fakeAppCheckProvider.getTokenCallCount, initialCallCount)
  }

  private func configuredExpectations_GetTokenWhenNoCache(expectedToken: AppCheckCoreToken) {
    fakeStorage.getTokenHandler = { nil }
    fakeAppCheckProvider.tokenToReturn = expectedToken
    fakeStorage.setTokenHandler = { token in expectedToken }
  }

  private func configuredExpectation_GetTokenWhenCacheTokenIsValid(expectedToken: AppCheckCoreToken) {
    fakeStorage.getTokenHandler = { expectedToken }
  }

  private func configuredExpectations_GetTokenForcingRefreshWhenCacheIsValid(expectedToken: AppCheckCoreToken) {
    fakeAppCheckProvider.tokenToReturn = expectedToken
    fakeStorage.setTokenHandler = { token in expectedToken }
  }

  private func configuredExpectations_GetTokenWhenCachedTokenExpired(expectedToken: AppCheckCoreToken) {
    let cachedToken = AppCheckCoreToken(token: "expired", expirationDate: Date())
    fakeStorage.getTokenHandler = { cachedToken }

    fakeAppCheckProvider.tokenToReturn = expectedToken
    fakeStorage.setTokenHandler = { token in expectedToken }
  }

  private func configuredExpectations_GetTokenWhenError(error: Error, token: AppCheckCoreToken?) {
    fakeStorage.getTokenHandler = { token }
    fakeAppCheckProvider.errorToReturn = error
  }
}
