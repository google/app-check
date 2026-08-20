import XCTest
@testable import AppCheckCore

class AppCheckCoreBackoffWrapperTests: XCTestCase {
  
  var backoffWrapper: AppCheckCoreBackoffWrapper!
  var currentDate: Date!
  
  var operationResult: Any?
  var operationProvider: (() async throws -> Any)!
  var operationFinishExpectation: XCTestExpectation!
  
  var errorHandler: AppCheckCoreBackoffErrorHandler!
  var errorHandlerExpectation: XCTestExpectation!
  
  override func setUp() {
    super.setUp()
    
    currentDate = Date()
    backoffWrapper = AppCheckCoreBackoffWrapper(dateProvider: { [weak self] in
      return self?.currentDate ?? Date()
    })
  }
  
  override func tearDown() {
    backoffWrapper = nil
    operationProvider = nil
    currentDate = nil
    super.tearDown()
  }
  
  func testBackoffFirstOperationAlwaysExecuted() async throws {
    setUpOperationSuccess()
    setUpErrorHandler(with: .none)
    errorHandlerExpectation.isInverted = true
    
    let result = try await backoffWrapper.applyBackoffToOperation( operationProvider, errorHandler: errorHandler)
    
    await fulfillment(of: [operationFinishExpectation, errorHandlerExpectation], timeout: 5.0)
    
    XCTAssertEqual(result as? NSObject, operationResult as? NSObject)
  }
  
  func testBackoff1DayBackoffAfterFailure() async {
    currentDate = Date()
    
    setUpOperationError()
    setUpErrorHandler(with: .oneDay)
    
    do {
      _ = try await backoffWrapper.applyBackoffToOperation( operationProvider, errorHandler: errorHandler)
      XCTFail("Expected error")
    } catch {
      XCTAssertEqual(error as NSError, operationResult as? NSError)
    }
    
    await fulfillment(of: [operationFinishExpectation, errorHandlerExpectation], timeout: 5.0)
    
    // Check backoff in 12 hours
    setUpOperationError()
    setUpErrorHandler(with: .oneDay)
    operationFinishExpectation.isInverted = true
    errorHandlerExpectation.isInverted = true
    
    currentDate = currentDate.addingTimeInterval(12 * 60 * 60)
    
    do {
      _ = try await backoffWrapper.applyBackoffToOperation( operationProvider, errorHandler: errorHandler)
      XCTFail("Expected error")
    } catch {
      XCTAssertTrue(isBackoffError(error as NSError))
    }
    
    await fulfillment(of: [operationFinishExpectation, errorHandlerExpectation], timeout: 5.0)
    
    // Check backoff one minute before allowing retry
    setUpOperationError()
    setUpErrorHandler(with: .oneDay)
    operationFinishExpectation.isInverted = true
    errorHandlerExpectation.isInverted = true
    
    currentDate = currentDate.addingTimeInterval(11 * 60 * 60 + 59 * 60)
    
    do {
      _ = try await backoffWrapper.applyBackoffToOperation( operationProvider, errorHandler: errorHandler)
      XCTFail("Expected error")
    } catch {
      XCTAssertTrue(isBackoffError(error as NSError))
    }
    
    await fulfillment(of: [operationFinishExpectation, errorHandlerExpectation], timeout: 5.0)
    
    // Check backoff one minute after allowing retry
    setUpOperationError()
    setUpErrorHandler(with: .oneDay)
    
    currentDate = currentDate.addingTimeInterval(12 * 60 * 60 + 1 * 60)
    
    do {
      _ = try await backoffWrapper.applyBackoffToOperation( operationProvider, errorHandler: errorHandler)
      XCTFail("Expected error")
    } catch {
      XCTAssertEqual(error as NSError, operationResult as? NSError)
    }
    
    await fulfillment(of: [operationFinishExpectation, errorHandlerExpectation], timeout: 5.0)
  }
  
  func testExponentialBackoff() async throws {
    currentDate = Date()
    
    setUpOperationError()
    setUpErrorHandler(with: .exponential)
    
    do {
      _ = try await backoffWrapper.applyBackoffToOperation( operationProvider, errorHandler: errorHandler)
      XCTFail("Expected error")
    } catch {
      XCTAssertEqual(error as NSError, operationResult as? NSError)
    }
    
    await fulfillment(of: [operationFinishExpectation, errorHandlerExpectation], timeout: 5.0)
    
    let numberOfAttempts = 20
    let maximumBackoff: TimeInterval = 4 * 60 * 60
    let maxJitterPortion = 0.5
    
    for attempt in 0..<numberOfAttempts {
      let expectedMinBackoff = min(pow(2.0, Double(attempt)), maximumBackoff)
      let expectedMaxBackoff = min(expectedMinBackoff * (1 + maxJitterPortion), maximumBackoff)
      
      await assertBackoffInterval(isAtLeast: expectedMinBackoff, andAtMost: expectedMaxBackoff)
    }
    
    // Test recovery after success
    currentDate = currentDate.addingTimeInterval(maximumBackoff)
    
    setUpOperationSuccess()
    setUpErrorHandler(with: .none)
    errorHandlerExpectation.isInverted = true
    
    let result = try await backoffWrapper.applyBackoffToOperation( operationProvider, errorHandler: errorHandler)
    await fulfillment(of: [operationFinishExpectation, errorHandlerExpectation], timeout: 5.0)
    XCTAssertEqual(result as? NSObject, operationResult as? NSObject)
    
    // Set up operation failure (no backoff after success)
    setUpOperationError()
    setUpErrorHandler(with: .exponential)
    
    do {
      _ = try await backoffWrapper.applyBackoffToOperation( operationProvider, errorHandler: errorHandler)
      XCTFail("Expected error")
    } catch {
      XCTAssertEqual(error as NSError, operationResult as? NSError)
    }
    
    await fulfillment(of: [operationFinishExpectation, errorHandlerExpectation], timeout: 5.0)
  }
  
  func testDefaultAppCheckProviderErrorHandler() {
    let handler = backoffWrapper.defaultAppCheckProviderErrorHandler()
    
    let nonHTTPError = NSError(domain: "test", code: 1, userInfo: nil)
    XCTAssertEqual(handler(nonHTTPError), .none)
    
    XCTAssertEqual(handler(httpError(withStatusCode: 400)), .oneDay)
    XCTAssertEqual(handler(httpError(withStatusCode: 403)), .exponential)
    XCTAssertEqual(handler(httpError(withStatusCode: 404)), .oneDay)
    XCTAssertEqual(handler(httpError(withStatusCode: 429)), .exponential)
    XCTAssertEqual(handler(httpError(withStatusCode: 503)), .exponential)
    
    for statusCode in 400..<600 {
      if statusCode == 400 || statusCode == 404 { continue }
      XCTAssertEqual(handler(httpError(withStatusCode: statusCode)), .exponential)
    }
  }
  
  // MARK: - Helpers
  
  private func setUpErrorHandler(with backoffType: AppCheckBackoffType) {
    errorHandlerExpectation = expectation(description: "Error handler")
    errorHandler = { [weak self] error in
      self?.errorHandlerExpectation.fulfill()
      return backoffType
    }
  }
  
  private func setUpOperationSuccess() {
    operationFinishExpectation = expectation(description: "Operation performed")
    operationResult = NSObject()
    operationProvider = { [weak self] in
      self?.operationFinishExpectation.fulfill()
      return self?.operationResult as Any
    }
  }
  
  private func setUpOperationError() {
    operationFinishExpectation = expectation(description: "Operation performed")
    operationResult = NSError(domain: name, code: -1, userInfo: nil)
    operationProvider = { [weak self] in
      self?.operationFinishExpectation.fulfill()
      throw (self?.operationResult as! Error)
    }
  }
  
  private func isBackoffError(_ error: NSError) -> Bool {
    return error.localizedDescription.contains("Too many attempts. Underlying error:")
  }
  
  private func httpError(withStatusCode statusCode: Int) -> AppCheckCoreHTTPError {
    let httpResponse = HTTPURLResponse(url: URL(string: "https://localhost")!,
                                       statusCode: statusCode,
                                       httpVersion: nil,
                                       headerFields: nil)!
    return AppCheckCoreHTTPError(httpResponse: httpResponse, data: nil)
  }
  
  private func assertBackoffInterval(isAtLeast minBackoff: TimeInterval, andAtMost maxBackoff: TimeInterval) async {
    let lastFailureDate = currentDate!
    
    // Test backoff before min interval
    currentDate = lastFailureDate.addingTimeInterval(minBackoff - 0.5)
    
    setUpOperationError()
    setUpErrorHandler(with: .exponential)
    operationFinishExpectation.isInverted = true
    errorHandlerExpectation.isInverted = true
    
    do {
      _ = try await backoffWrapper.applyBackoffToOperation( operationProvider, errorHandler: errorHandler)
      XCTFail("Expected error")
    } catch {
      XCTAssertTrue(isBackoffError(error as NSError))
    }
    
    await fulfillment(of: [operationFinishExpectation, errorHandlerExpectation], timeout: 5.0)
    
    // Test backoff after max interval
    currentDate = lastFailureDate.addingTimeInterval(maxBackoff + 0.5)
    
    setUpOperationError()
    setUpErrorHandler(with: .exponential)
    
    do {
      _ = try await backoffWrapper.applyBackoffToOperation( operationProvider, errorHandler: errorHandler)
      XCTFail("Expected error")
    } catch {
      XCTAssertFalse(isBackoffError(error as NSError))
    }
    
    await fulfillment(of: [operationFinishExpectation, errorHandlerExpectation], timeout: 5.0)
  }
}
