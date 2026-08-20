import XCTest
#if canImport(FBLPromises)
import FBLPromises
#endif
@testable import AppCheckCore

class AppCheckCoreDeviceCheckAPIServiceFake: NSObject, AppCheckCoreDeviceCheckAPIServiceProtocol {
    var passedDeviceToken: Data?
    var passedLimitedUse: Bool?
    var appCheckTokenResult: Result<AppCheckCoreToken, Error>?
    
    func appCheckToken(deviceToken: Data, limitedUse: Bool) async throws -> AppCheckCoreToken {
        passedDeviceToken = deviceToken
        passedLimitedUse = limitedUse
        guard let result = appCheckTokenResult else {
            throw NSError(domain: "FakeError", code: -1, userInfo: nil)
        }
        switch result {
        case .success(let token): return token
        case .failure(let error): throw error
        }
    }
}

class AppCheckCoreDeviceCheckTokenGeneratorFake: NSObject, AppCheckCoreDeviceCheckTokenGenerator {
    var supported: Bool = true
    var generateTokenCalled = false
    var tokenToReturn: Data?
    var errorToReturn: Error?
    
    var isSupported: Bool { supported }
    
    func generateToken(completionHandler: @escaping (Data?, Error?) -> Void) {
        generateTokenCalled = true
        if let error = errorToReturn {
            completionHandler(nil, error)
        } else if let token = tokenToReturn {
            completionHandler(token, nil)
        } else {
            completionHandler(nil, NSError(domain: "FakeError", code: -1, userInfo: nil))
        }
    }
}

class AppCheckCoreBackoffWrapperFake: NSObject, AppCheckBackoffWrapperProtocol {
    var isNextOperationAllowed: Bool = true
    var backoffError: Error = NSError(domain: "BackoffError", code: -1, userInfo: nil)
    
    var backoffExpectation: XCTestExpectation?
    var defaultErrorHandlerCalled = false
    var defaultErrorHandler: ((Error) -> AppCheckBackoffType)?
    
    var operationResult: Any?
    var operationError: Error?
    
    func applyBackoffToOperation(_ operationProvider: @escaping () async throws -> Any, errorHandler: @escaping (Error) -> AppCheckBackoffType) async throws -> Any {
        backoffExpectation?.fulfill()
        if isNextOperationAllowed {
            do {
                let value = try await operationProvider()
                self.operationResult = value
                return value
            } catch {
                self.operationError = error
                _ = errorHandler(error)
                throw error
            }
        } else {
            throw backoffError
        }
    }
    
    func defaultAppCheckProviderErrorHandler() -> (Error) -> AppCheckBackoffType {
        return { error in
            self.defaultErrorHandlerCalled = true
            if let handler = self.defaultErrorHandler {
                return handler(error)
            }
            return .oneDay
        }
    }
}

class AppCheckCoreDeviceCheckProviderTests: XCTestCase {
    var provider: AppCheckCoreDeviceCheckProvider!
    var fakeAPIService: AppCheckCoreDeviceCheckAPIServiceFake!
    var fakeTokenGenerator: AppCheckCoreDeviceCheckTokenGeneratorFake!
    var fakeBackoffWrapper: AppCheckCoreBackoffWrapperFake!
    
    override func setUp() {
        super.setUp()
        fakeAPIService = AppCheckCoreDeviceCheckAPIServiceFake()
        fakeTokenGenerator = AppCheckCoreDeviceCheckTokenGeneratorFake()
        fakeBackoffWrapper = AppCheckCoreBackoffWrapperFake()
        fakeBackoffWrapper.isNextOperationAllowed = true
        
        provider = AppCheckCoreDeviceCheckProvider(apiService: fakeAPIService,
                                          deviceTokenGenerator: fakeTokenGenerator,
                                          backoffWrapper: fakeBackoffWrapper)
    }
    
    override func tearDown() {
        provider = nil
        fakeAPIService = nil
        fakeTokenGenerator = nil
        fakeBackoffWrapper = nil
        super.tearDown()
    }
    
    func testGetTokenSuccess() async throws {
        fakeTokenGenerator.supported = true
        let deviceToken = Data()
        fakeTokenGenerator.tokenToReturn = deviceToken
        
        let validToken = AppCheckCoreToken(token: "valid_token", expirationDate: Date.distantFuture, receivedAtDate: Date())
        fakeAPIService.appCheckTokenResult = .success(validToken)
        
        fakeBackoffWrapper.backoffExpectation = expectation(description: "Backoff")
        
        let token = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppCheckCoreToken, Error>) in
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
        
        await fulfillment(of: [fakeBackoffWrapper.backoffExpectation!], timeout: 0.5)
        
        XCTAssertEqual(token.token, validToken.token)
        XCTAssertEqual(token.expirationDate, validToken.expirationDate)
        XCTAssertEqual(token.receivedAtDate, validToken.receivedAtDate)
        
        XCTAssertNil(fakeBackoffWrapper.operationError)
        let wrapperResult = fakeBackoffWrapper.operationResult as? AppCheckCoreToken
        XCTAssertEqual(wrapperResult?.token, validToken.token)
        
        XCTAssertEqual(fakeAPIService.passedDeviceToken, deviceToken)
        XCTAssertEqual(fakeAPIService.passedLimitedUse, false)
        XCTAssertTrue(fakeTokenGenerator.generateTokenCalled)
    }
    
    func testGetTokenWhenDeviceCheckIsNotSupported() async throws {
        let expectedError = AppCheckCoreErrorUtil.unsupportedAttestationProvider("DeviceCheckProvider")
        
        fakeBackoffWrapper.backoffExpectation = expectation(description: "Backoff")
        let errorHandlerExpectation = expectation(description: "Error handler")
        
        fakeBackoffWrapper.defaultErrorHandler = { error in
            let nsError = error as NSError
            let expNSError = expectedError as NSError
            XCTAssertEqual(nsError.domain, expNSError.domain)
            XCTAssertEqual(nsError.code, expNSError.code)
            errorHandlerExpectation.fulfill()
            return .oneDay
        }
        
        fakeTokenGenerator.supported = false
        
        do {
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppCheckCoreToken, Error>) in
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
            XCTFail("Expected error")
        } catch let error as NSError {
            let expNSError = expectedError as NSError
            XCTAssertEqual(error.domain, expNSError.domain)
            XCTAssertEqual(error.code, expNSError.code)
        }
        
        await fulfillment(of: [fakeBackoffWrapper.backoffExpectation!, errorHandlerExpectation], timeout: 0.5)
        
        XCTAssertNil(fakeAPIService.passedDeviceToken)
        XCTAssertFalse(fakeTokenGenerator.generateTokenCalled)
        
        let opError = fakeBackoffWrapper.operationError as? NSError
        XCTAssertEqual(opError?.domain, (expectedError as NSError).domain)
        XCTAssertEqual(opError?.code, (expectedError as NSError).code)
        XCTAssertNil(fakeBackoffWrapper.operationResult)
    }
    
    func testGetTokenWhenDeviceTokenFails() async throws {
        let deviceTokenError = NSError(domain: "AppCheckCoreDeviceCheckProviderTests", code: -1, userInfo: nil)
        
        fakeBackoffWrapper.backoffExpectation = expectation(description: "Backoff")
        let errorHandlerExpectation = expectation(description: "Error handler")
        
        fakeBackoffWrapper.defaultErrorHandler = { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, deviceTokenError.domain)
            XCTAssertEqual(nsError.code, deviceTokenError.code)
            errorHandlerExpectation.fulfill()
            return .oneDay
        }
        
        fakeTokenGenerator.supported = true
        fakeTokenGenerator.errorToReturn = deviceTokenError
        
        do {
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppCheckCoreToken, Error>) in
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
            XCTFail("Expected error")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, deviceTokenError.domain)
            XCTAssertEqual(error.code, deviceTokenError.code)
        }
        
        await fulfillment(of: [fakeBackoffWrapper.backoffExpectation!, errorHandlerExpectation], timeout: 0.5)
        
        XCTAssertNil(fakeAPIService.passedDeviceToken)
        XCTAssertTrue(fakeTokenGenerator.generateTokenCalled)
        
        let opError = fakeBackoffWrapper.operationError as? NSError
        XCTAssertEqual(opError?.domain, deviceTokenError.domain)
        XCTAssertEqual(opError?.code, deviceTokenError.code)
        XCTAssertNil(fakeBackoffWrapper.operationResult)
    }
    
    func testGetTokenWhenAPIServiceFails() async throws {
        let apiError = NSError(domain: "AppCheckCoreDeviceCheckProviderTests", code: -1, userInfo: nil)
        
        fakeBackoffWrapper.backoffExpectation = expectation(description: "Backoff")
        let errorHandlerExpectation = expectation(description: "Error handler")
        
        fakeBackoffWrapper.defaultErrorHandler = { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, apiError.domain)
            XCTAssertEqual(nsError.code, apiError.code)
            errorHandlerExpectation.fulfill()
            return .oneDay
        }
        
        fakeTokenGenerator.supported = true
        let deviceToken = Data()
        fakeTokenGenerator.tokenToReturn = deviceToken
        
        fakeAPIService.appCheckTokenResult = .failure(apiError)
        
        do {
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppCheckCoreToken, Error>) in
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
            XCTFail("Expected error")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, apiError.domain)
            XCTAssertEqual(error.code, apiError.code)
        }
        
        await fulfillment(of: [fakeBackoffWrapper.backoffExpectation!, errorHandlerExpectation], timeout: 0.5)
        
        XCTAssertEqual(fakeAPIService.passedDeviceToken, deviceToken)
        XCTAssertEqual(fakeAPIService.passedLimitedUse, false)
        XCTAssertTrue(fakeTokenGenerator.generateTokenCalled)
        
        let opError = fakeBackoffWrapper.operationError as? NSError
        XCTAssertEqual(opError?.domain, apiError.domain)
        XCTAssertEqual(opError?.code, apiError.code)
        XCTAssertNil(fakeBackoffWrapper.operationResult)
    }
    
    func testGetLimitedUseTokenSuccess() async throws {
        fakeTokenGenerator.supported = true
        let deviceToken = Data()
        fakeTokenGenerator.tokenToReturn = deviceToken
        
        let validToken = AppCheckCoreToken(token: "valid_token", expirationDate: Date.distantFuture, receivedAtDate: Date())
        fakeAPIService.appCheckTokenResult = .success(validToken)
        
        fakeBackoffWrapper.backoffExpectation = expectation(description: "Backoff")
        
        let token = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppCheckCoreToken, Error>) in
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
        
        await fulfillment(of: [fakeBackoffWrapper.backoffExpectation!], timeout: 0.5)
        
        XCTAssertEqual(token.token, validToken.token)
        XCTAssertEqual(token.expirationDate, validToken.expirationDate)
        XCTAssertEqual(token.receivedAtDate, validToken.receivedAtDate)
        
        XCTAssertNil(fakeBackoffWrapper.operationError)
        let wrapperResult = fakeBackoffWrapper.operationResult as? AppCheckCoreToken
        XCTAssertEqual(wrapperResult?.token, validToken.token)
        
        XCTAssertEqual(fakeAPIService.passedDeviceToken, deviceToken)
        XCTAssertEqual(fakeAPIService.passedLimitedUse, true)
        XCTAssertTrue(fakeTokenGenerator.generateTokenCalled)
    }
    
    // MARK: - Backoff tests
    
    func testGetTokenBackoff() async throws {
        fakeBackoffWrapper.isNextOperationAllowed = false
        fakeBackoffWrapper.backoffExpectation = expectation(description: "Backoff")
        
        do {
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppCheckCoreToken, Error>) in
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
            XCTFail("Expected error")
        } catch let error as NSError {
            let backoffError = fakeBackoffWrapper.backoffError as NSError
            XCTAssertEqual(error.domain, backoffError.domain)
            XCTAssertEqual(error.code, backoffError.code)
        }
        
        await fulfillment(of: [fakeBackoffWrapper.backoffExpectation!], timeout: 0.5)
        
        XCTAssertNil(fakeAPIService.passedDeviceToken)
        XCTAssertFalse(fakeTokenGenerator.generateTokenCalled)
    }
}
