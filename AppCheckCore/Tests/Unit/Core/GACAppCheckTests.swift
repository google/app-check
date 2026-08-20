import XCTest
@testable import AppCheckCore

private let kPlaceholderTokenValue = "eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ=="
private let kResourceName = "projects/test_project_id/apps/test_app_id"
private let kAppName = "GACAppCheckTests"
private let kAppGroupID = "app_group_id"

class GACAppCheckTests: XCTestCase {
  
  var fakeStorage: GACAppCheckStorageFake!
  var fakeAppCheckProvider: GACAppCheckProviderFake!
  var fakeTokenRefresher: GACAppCheckTokenRefresherFake!
  var fakeSettings: GACAppCheckSettingsFake!
  var fakeTokenDelegate: GACAppCheckTokenDelegateFake!
  var appCheck: GACAppCheck!
  
  override func setUp() {
    super.setUp()
    
    fakeStorage = GACAppCheckStorageFake()
    fakeAppCheckProvider = GACAppCheckProviderFake()
    fakeTokenRefresher = GACAppCheckTokenRefresherFake()
    fakeSettings = GACAppCheckSettingsFake()
    fakeTokenDelegate = GACAppCheckTokenDelegateFake()
    
    appCheck = GACAppCheck(serviceName: kAppName,
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
    
    let result = await appCheck.token(forcingRefresh: false)
    
    XCTAssertEqual(result.token, expectedToken)
    XCTAssertNil(result.error)
    
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
    
    let result = await appCheck.token(forcingRefresh: true)
    
    XCTAssertEqual(result.token, expectedToken)
    XCTAssertNil(result.error)
    
    XCTAssertEqual(fakeAppCheckProvider.getTokenCallCount, 1)
    XCTAssertEqual(fakeStorage.lastSetToken, expectedToken)
    XCTAssertEqual(fakeTokenRefresher.updateWithRefreshResultCallCount, 1)
    XCTAssertEqual(fakeTokenDelegate.lastToken, expectedToken)
  }
  
  func testGetToken_WhenCachedTokenExpired_Success() async {
    let expectedToken = validToken()
    configuredExpectations_GetTokenWhenCachedTokenExpired(expectedToken: expectedToken)
    
    let result = await appCheck.token(forcingRefresh: false)
    
    XCTAssertEqual(result.token, expectedToken)
    XCTAssertNil(result.error)
    
    XCTAssertEqual(fakeAppCheckProvider.getTokenCallCount, 1)
    XCTAssertEqual(fakeStorage.lastSetToken, expectedToken)
    XCTAssertEqual(fakeTokenRefresher.updateWithRefreshResultCallCount, 1)
    XCTAssertEqual(fakeTokenDelegate.lastToken, expectedToken)
  }
  
  func testGetToken_AppCheckProviderError() async {
    let cachedToken = soonExpiringToken()
    let providerError = NSError(domain: "GACAppCheckTests", code: -1, userInfo: nil)
    
    configuredExpectations_GetTokenWhenError(error: providerError, token: cachedToken)
    
    let result = await appCheck.token(forcingRefresh: false)
    
    XCTAssertEqual(result.token.token, kPlaceholderTokenValue)
    XCTAssertNotNil(result.error)
    XCTAssertEqual(result.error as NSError?, providerError)
    XCTAssertNotEqual((result.error as NSError?)?.domain, GACAppCheckErrorDomain)
    
    XCTAssertEqual(fakeAppCheckProvider.getTokenCallCount, 1)
    XCTAssertEqual(fakeTokenDelegate.tokenDidUpdateCallCount, 0)
    XCTAssertNil(fakeStorage.lastSetToken)
    XCTAssertEqual(fakeTokenRefresher.updateWithRefreshResultCallCount, 0)
  }
  
  // MARK: - Token refresher
  
  func testTokenRefreshTriggeredAndRefreshSuccess() async {
    fakeStorage.getTokenHandler = { return nil }
    
    let expirationDate = Date(timeIntervalSinceNow: 10000)
    let tokenToReturn = GACAppCheckToken(token: "valid", expirationDate: expirationDate)
    fakeAppCheckProvider.tokenToReturn = tokenToReturn
    
    fakeStorage.setTokenHandler = { token in return tokenToReturn }
    
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
    fakeStorage.getTokenHandler = { return nil }
    
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
    
    let result = await appCheck.limitedUseToken()
    
    XCTAssertEqual(result.token, expectedToken)
    XCTAssertNil(result.error)
    
    XCTAssertEqual(fakeAppCheckProvider.getLimitedUseTokenCallCount, 1)
    XCTAssertEqual(fakeStorage.lastSetToken, nil)
    XCTAssertEqual(fakeTokenDelegate.tokenDidUpdateCallCount, 0)
  }
  
  func testLimitedUseToken_WhenTokenGenerationErrors() async {
    let providerError = _GACAppCheckErrorUtil.keychainError(withError: internalError()) as NSError
    fakeAppCheckProvider.limitedUseErrorToReturn = providerError
    
    let result = await appCheck.limitedUseToken()
    
    XCTAssertEqual(result.token.token, kPlaceholderTokenValue)
    XCTAssertNotNil(result.error)
    XCTAssertEqual(result.error as NSError?, providerError)
    XCTAssertEqual((result.error as NSError?)?.domain, GACAppCheckErrorDomain)
    
    XCTAssertEqual(fakeAppCheckProvider.getLimitedUseTokenCallCount, 1)
    XCTAssertEqual(fakeAppCheckProvider.getTokenCallCount, 0)
    XCTAssertNil(fakeStorage.lastSetToken)
    XCTAssertEqual(fakeTokenDelegate.tokenDidUpdateCallCount, 0)
    XCTAssertEqual(fakeTokenRefresher.updateWithRefreshResultCallCount, 0)
  }
  
  // MARK: - Merging multiple get token requests
  
  func testGetToken_WhenCalledSeveralTimesSuccess_ThenThereIsOnlyOneOperation() async {
    fakeStorage.getTokenHandler = { return nil }
    
    let expectedToken = validToken()
    fakeAppCheckProvider.tokenToReturn = expectedToken
    
    // Create a continuation we can resume later
    var storeTokenContinuation: CheckedContinuation<GACAppCheckToken?, Error>?
    fakeStorage.setTokenHandler = { token in
      return try await withCheckedThrowingContinuation { continuation in
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
      for _ in 0..<getTokenCallsCount {
        group.addTask {
          let result = await self.appCheck.token(forcingRefresh: false)
          XCTAssertEqual(result.token, expectedToken)
          XCTAssertNil(result.error)
        }
      }
    }
    
    XCTAssertEqual(fakeAppCheckProvider.getTokenCallCount, 1)
    XCTAssertEqual(fakeTokenRefresher.updateWithRefreshResultCallCount, 1)
    XCTAssertEqual(fakeTokenDelegate.tokenDidUpdateCallCount, 1)
    
    await assertGetToken_WhenCachedTokenIsValid_Success()
  }
  
  func testGetToken_WhenCalledSeveralTimesError_ThenThereIsOnlyOneOperation() async {
    fakeStorage.getTokenHandler = { return nil }
    
    let expectedToken = validToken()
    fakeAppCheckProvider.tokenToReturn = expectedToken
    
    var storeTokenContinuation: CheckedContinuation<GACAppCheckToken?, Error>?
    fakeStorage.setTokenHandler = { token in
      return try await withCheckedThrowingContinuation { continuation in
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
      for _ in 0..<getTokenCallsCount {
        group.addTask {
          let result = await self.appCheck.token(forcingRefresh: false)
          XCTAssertEqual(result.token.token, kPlaceholderTokenValue)
          XCTAssertNotNil(result.error)
          XCTAssertEqual(result.error as NSError?, storageError)
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
  
  private func validToken() -> GACAppCheckToken {
    return GACAppCheckToken(token: UUID().uuidString, expirationDate: Date.distantFuture)
  }
  
  private func soonExpiringToken() -> GACAppCheckToken {
    let date = Date(timeIntervalSinceNow: 4.5 * 60)
    return GACAppCheckToken(token: "valid", expirationDate: date)
  }
  
  private func assertGetToken_WhenCachedTokenIsValid_Success() async {
    let initialCallCount = fakeAppCheckProvider.getTokenCallCount
    let cachedToken = validToken()
    
    configuredExpectation_GetTokenWhenCacheTokenIsValid(expectedToken: cachedToken)
    
    let result = await appCheck.token(forcingRefresh: false)
    
    XCTAssertEqual(result.token, cachedToken)
    XCTAssertNil(result.error)
    
    XCTAssertEqual(fakeAppCheckProvider.getTokenCallCount, initialCallCount)
  }
  
  private func configuredExpectations_GetTokenWhenNoCache(expectedToken: GACAppCheckToken) {
    fakeStorage.getTokenHandler = { return nil }
    fakeAppCheckProvider.tokenToReturn = expectedToken
    fakeStorage.setTokenHandler = { token in return expectedToken }
  }
  
  private func configuredExpectation_GetTokenWhenCacheTokenIsValid(expectedToken: GACAppCheckToken) {
    fakeStorage.getTokenHandler = { return expectedToken }
  }
  
  private func configuredExpectations_GetTokenForcingRefreshWhenCacheIsValid(expectedToken: GACAppCheckToken) {
    fakeAppCheckProvider.tokenToReturn = expectedToken
    fakeStorage.setTokenHandler = { token in return expectedToken }
  }
  
  private func configuredExpectations_GetTokenWhenCachedTokenExpired(expectedToken: GACAppCheckToken) {
    let cachedToken = GACAppCheckToken(token: "expired", expirationDate: Date())
    fakeStorage.getTokenHandler = { return cachedToken }
    
    fakeAppCheckProvider.tokenToReturn = expectedToken
    fakeStorage.setTokenHandler = { token in return expectedToken }
  }
  
  private func configuredExpectations_GetTokenWhenError(error: Error, token: GACAppCheckToken?) {
    fakeStorage.getTokenHandler = { return token }
    fakeAppCheckProvider.errorToReturn = error
  }
}
