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
#if canImport(GoogleUtilities)
  import GoogleUtilities
#endif
@testable import AppCheckCore

class MockAppCheckDebugProviderAPIService: NSObject, AppCheckCoreDebugProviderAPIServiceProtocol {
  var passedDebugToken: String?
  var passedLimitedUse: Bool?

  var tokenResult: Result<AppCheckCoreToken, Error>?
  var limitedUseTokenResult: Result<AppCheckCoreToken, Error>?

  func appCheckToken(debugToken: String, limitedUse: Bool) async throws -> AppCheckCoreToken {
    passedDebugToken = debugToken
    passedLimitedUse = limitedUse

    let result = limitedUse ? limitedUseTokenResult : tokenResult

    guard let result = result else {
      throw NSError(domain: "MockError", code: -1, userInfo: nil)
    }

    switch result {
    case let .success(token):
      return token
    case let .failure(error):
      throw error
    }
  }
}

class AppCheckCoreDebugProviderTests: XCTestCase {
  let kDebugTokenEnvKey = "AppCheckDebugToken"
  let kFirebaseDebugTokenEnvKey = "FIRAAppCheckDebugToken"
  let kDebugTokenUserDefaultsKey = "AppCheckCoreDebugToken"
  let kDebugTokenRegisteredUserDefaultsKey = "AppCheckCoreDebugTokenRegistered"

  var provider: AppCheckCoreDebugProvider!
  var fakeAPIService: MockAppCheckDebugProviderAPIService!

  override func setUp() {
    super.setUp()
    fakeAPIService = MockAppCheckDebugProviderAPIService()
    provider = AppCheckCoreDebugProvider(apiService: fakeAPIService,
                                         serviceName: "test-service",
                                         resourceName: "projects/test-project/apps/test-app",
                                         environment: [:])
  }

  override func tearDown() {
    provider = nil
    UserDefaults.standard.removeObject(forKey: kDebugTokenUserDefaultsKey)
    UserDefaults.standard.removeObject(forKey: kDebugTokenRegisteredUserDefaultsKey)
    super.tearDown()
  }

  // MARK: - Debug token generating/storing

  func testCurrentTokenWhenEnvironmentVariableSetAndTokenStored() {
    UserDefaults.standard.set("stored token", forKey: kDebugTokenUserDefaultsKey)
    let envToken = "env token"
    provider = AppCheckCoreDebugProvider(apiService: fakeAPIService,
                                         serviceName: "test-service",
                                         resourceName: "projects/test-project/apps/test-app",
                                         environment: [kDebugTokenEnvKey: envToken])

    XCTAssertEqual(provider.currentDebugToken(), envToken)
  }

  func testCurrentTokenWhenFirebaseAndCoreEnvironmentVariablesSetAndTokenStored() {
    UserDefaults.standard.set("stored token", forKey: kDebugTokenUserDefaultsKey)
    let envToken = "env token"
    provider = AppCheckCoreDebugProvider(apiService: fakeAPIService,
                                         serviceName: "test-service",
                                         resourceName: "projects/test-project/apps/test-app",
                                         environment: [
                                           kDebugTokenEnvKey: envToken,
                                           kFirebaseDebugTokenEnvKey: "firebase env token",
                                         ])

    XCTAssertEqual(provider.currentDebugToken(), envToken)
  }

  func testCurrentTokenWhenFirebaseEnvironmentVariableSetAndTokenStored() {
    UserDefaults.standard.set("stored token", forKey: kDebugTokenUserDefaultsKey)
    let envToken = "env token"
    provider = AppCheckCoreDebugProvider(apiService: fakeAPIService,
                                         serviceName: "test-service",
                                         resourceName: "projects/test-project/apps/test-app",
                                         environment: [kFirebaseDebugTokenEnvKey: envToken])

    XCTAssertEqual(provider.currentDebugToken(), envToken)
  }

  func testCurrentTokenWhenFirebaseAndCoreEnvironmentVariablesSet() {
    let envToken = "env token"
    provider = AppCheckCoreDebugProvider(apiService: fakeAPIService,
                                         serviceName: "test-service",
                                         resourceName: "projects/test-project/apps/test-app",
                                         environment: [
                                           kDebugTokenEnvKey: envToken,
                                           kFirebaseDebugTokenEnvKey: "firebase env token",
                                         ])

    XCTAssertEqual(provider.currentDebugToken(), envToken)
  }

  func testCurrentTokenWhenNoEnvironmentVariableAndTokenStored() {
    let storedToken = "stored token"
    UserDefaults.standard.set(storedToken, forKey: kDebugTokenUserDefaultsKey)

    XCTAssertEqual(provider.currentDebugToken(), storedToken)
    XCTAssertEqual(provider.currentDebugToken(), storedToken)
  }

  func testCurrentTokenWhenNoEnvironmentVariableAndNoTokenStored() {
    UserDefaults.standard.removeObject(forKey: kDebugTokenUserDefaultsKey)
    XCTAssertNil(UserDefaults.standard.string(forKey: kDebugTokenUserDefaultsKey))

    let generatedToken = provider.currentDebugToken()
    XCTAssertNotNil(generatedToken)

    // Check if the generated token is stored to the user defaults.
    XCTAssertEqual(UserDefaults.standard.string(forKey: kDebugTokenUserDefaultsKey), generatedToken)

    // Check if the same token is used once generated.
    XCTAssertEqual(provider.currentDebugToken(), generatedToken)
  }

  // MARK: - Debug token to FAC token exchange

  func testGetTokenSuccess() async throws {
    // 1. Stub API service.
    let expectedDebugToken = provider.currentDebugToken()
    let validToken = AppCheckCoreToken(
      token: "valid_token",
      expirationDate: Date(),
      receivedAtDate: Date()
    )
    fakeAPIService.tokenResult = .success(validToken)

    // 2. Validate get token.
    let token = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
      AppCheckCoreToken,
      Error
    >) in
      provider.getToken { token, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else if let token = token {
          continuation.resume(returning: token)
        } else {
          continuation.resume(throwing: NSError(domain: "TestError", code: -1, userInfo: nil))
        }
      }
    }

    XCTAssertEqual(token.token, validToken.token)
    XCTAssertEqual(token.expirationDate, validToken.expirationDate)
    XCTAssertEqual(token.receivedAtDate, validToken.receivedAtDate)

    // 3. Verify fakes.
    XCTAssertEqual(fakeAPIService.passedDebugToken, expectedDebugToken)
    XCTAssertEqual(fakeAPIService.passedLimitedUse, false)
  }

  func testGetTokenAPIError() async throws {
    // 1. Stub API service.
    let expectedDebugToken = provider.currentDebugToken()
    let apiError = NSError(domain: "testGetTokenAPIError", code: -1, userInfo: nil)
    fakeAPIService.tokenResult = .failure(apiError)

    // 2. Validate get token.
    do {
      _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
        AppCheckCoreToken,
        Error
      >) in
        provider.getToken { token, error in
          if let error = error {
            continuation.resume(throwing: error)
          } else if let token = token {
            continuation.resume(returning: token)
          } else {
            continuation.resume(throwing: NSError(domain: "TestError", code: -1, userInfo: nil))
          }
        }
      }
      XCTFail("Expected error to be thrown")
    } catch let error as NSError {
      XCTAssertEqual(error, apiError)
    }

    // 3. Verify fakes.
    XCTAssertEqual(fakeAPIService.passedDebugToken, expectedDebugToken)
    XCTAssertEqual(fakeAPIService.passedLimitedUse, false)
  }

  func testGetLimitedUseTokenSuccess() async throws {
    // 1. Stub API service.
    let expectedDebugToken = provider.currentDebugToken()
    let validToken = AppCheckCoreToken(
      token: "valid_token",
      expirationDate: Date(),
      receivedAtDate: Date()
    )
    fakeAPIService.limitedUseTokenResult = .success(validToken)

    // 2. Validate get limited-use token.
    let token = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
      AppCheckCoreToken,
      Error
    >) in
      provider.getLimitedUseToken { token, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else if let token = token {
          continuation.resume(returning: token)
        } else {
          continuation.resume(throwing: NSError(domain: "TestError", code: -1, userInfo: nil))
        }
      }
    }

    XCTAssertEqual(token.token, validToken.token)
    XCTAssertEqual(token.expirationDate, validToken.expirationDate)
    XCTAssertEqual(token.receivedAtDate, validToken.receivedAtDate)

    // 3. Verify fakes.
    XCTAssertEqual(fakeAPIService.passedDebugToken, expectedDebugToken)
    XCTAssertEqual(fakeAPIService.passedLimitedUse, true)
  }

  func testGetLimitedUseTokenAPIError() async throws {
    // 1. Stub API service.
    let expectedDebugToken = provider.currentDebugToken()
    let apiError = NSError(domain: "testGetLimitedUseTokenAPIError", code: -1, userInfo: nil)
    fakeAPIService.limitedUseTokenResult = .failure(apiError)

    // 2. Validate get limited-use token.
    do {
      _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
        AppCheckCoreToken,
        Error
      >) in
        provider.getLimitedUseToken { token, error in
          if let error = error {
            continuation.resume(throwing: error)
          } else if let token = token {
            continuation.resume(returning: token)
          } else {
            continuation.resume(throwing: NSError(domain: "TestError", code: -1, userInfo: nil))
          }
        }
      }
      XCTFail("Expected error to be thrown")
    } catch let error as NSError {
      XCTAssertEqual(error, apiError)
    }

    // 3. Verify fakes.
    XCTAssertEqual(fakeAPIService.passedDebugToken, expectedDebugToken)
    XCTAssertEqual(fakeAPIService.passedLimitedUse, true)
  }

  func testGetTokenSuccessSetsRegisteredFlag() async throws {
    // 1. Stub API service.
    let expectedDebugToken = provider.currentDebugToken()
    let validToken = AppCheckCoreToken(
      token: "valid_token",
      expirationDate: Date(),
      receivedAtDate: Date()
    )
    fakeAPIService.tokenResult = .success(validToken)

    // The mirror way to get registeredUserDefaultsKey, or since we know it, we can just hardcode or
    // access it
    let registeredKey =
      "\(kDebugTokenRegisteredUserDefaultsKey)_test-service_projects_test-project_apps_test-app"
    UserDefaults.standard.removeObject(forKey: registeredKey)

    // 2. Validate get token.
    _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
      AppCheckCoreToken,
      Error
    >) in
      provider.getToken { token, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else if let token = token {
          continuation.resume(returning: token)
        } else {
          continuation.resume(throwing: NSError(domain: "TestError", code: -1, userInfo: nil))
        }
      }
    }

    // 3. Verify flag is now YES.
    XCTAssertTrue(UserDefaults.standard.bool(forKey: registeredKey))

    // 4. Verify fakes.
    XCTAssertEqual(fakeAPIService.passedDebugToken, expectedDebugToken)
    XCTAssertEqual(fakeAPIService.passedLimitedUse, false)
  }

  func testGetTokenPermanentFailureClearsRegisteredFlag() async throws {
    // 1. Stub API service.
    let expectedDebugToken = provider.currentDebugToken()
    let apiError = NSError(
      domain: "testGetTokenPermanentFailureClearsRegisteredFlag",
      code: -1,
      userInfo: nil
    )
    fakeAPIService.tokenResult = .failure(apiError)

    let registeredKey =
      "\(kDebugTokenRegisteredUserDefaultsKey)_test-service_projects_test-project_apps_test-app"
    UserDefaults.standard.set(true, forKey: registeredKey)

    // 2. Validate get token.
    do {
      _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
        AppCheckCoreToken,
        Error
      >) in
        provider.getToken { token, error in
          if let error = error {
            continuation.resume(throwing: error)
          } else if let token = token {
            continuation.resume(returning: token)
          } else {
            continuation.resume(throwing: NSError(domain: "TestError", code: -1, userInfo: nil))
          }
        }
      }
      XCTFail("Expected error to be thrown")
    } catch _ {
      // expected
    }

    // 3. Verify flag is cleared.
    XCTAssertNil(UserDefaults.standard.object(forKey: registeredKey))

    // 4. Verify fakes.
    XCTAssertEqual(fakeAPIService.passedDebugToken, expectedDebugToken)
    XCTAssertEqual(fakeAPIService.passedLimitedUse, false)
  }

  func testGetTokenNetworkFailureDoesNotClearRegisteredFlag() async throws {
    // 1. Stub API service.
    let expectedDebugToken = provider.currentDebugToken()
    let networkError = NSError(
      domain: AppCheckCoreErrorDomain,
      code: AppCheckCoreErrorCode.serverUnreachable.rawValue,
      userInfo: nil
    )
    fakeAPIService.tokenResult = .failure(networkError)

    let registeredKey =
      "\(kDebugTokenRegisteredUserDefaultsKey)_test-service_projects_test-project_apps_test-app"
    UserDefaults.standard.set(true, forKey: registeredKey)

    // 2. Validate get token.
    do {
      _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
        AppCheckCoreToken,
        Error
      >) in
        provider.getToken { token, error in
          if let error = error {
            continuation.resume(throwing: error)
          } else if let token = token {
            continuation.resume(returning: token)
          } else {
            continuation.resume(throwing: NSError(domain: "TestError", code: -1, userInfo: nil))
          }
        }
      }
      XCTFail("Expected error to be thrown")
    } catch let error as NSError {
      XCTAssertEqual(error, networkError)
    }

    // 3. Verify flag is still YES.
    XCTAssertTrue(UserDefaults.standard.bool(forKey: registeredKey))

    // 4. Verify fakes.
    XCTAssertEqual(fakeAPIService.passedDebugToken, expectedDebugToken)
    XCTAssertEqual(fakeAPIService.passedLimitedUse, false)
  }
}
