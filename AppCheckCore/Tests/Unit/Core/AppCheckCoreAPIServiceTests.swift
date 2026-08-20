import XCTest
@testable import AppCheckCore

private let kAPIKeyHeaderKey = "X-Goog-Api-Key"
private let kAPIKeyHeaderValue = "Test-API-Key"
private let kBundleIDHeaderKey = "X-Ios-Bundle-Identifier"
private let kTestHeaderKey = "X-test-header"
private let kTestHeaderValue = "TEST_HEADER_VALUE"

class AppCheckCoreAPIServiceTests: XCTestCase {
  var apiService: AppCheckCoreAPIService!
  var fakeURLSession: AppCheckCoreURLSessionFake!
  var expectedHTTPHeaderFields: [String: String]!
  
  override func setUp() {
    super.setUp()
    
    fakeURLSession = AppCheckCoreURLSessionFake()
    
    if let bundleID = Bundle.main.bundleIdentifier {
      expectedHTTPHeaderFields = [kBundleIDHeaderKey: bundleID]
    } else {
      expectedHTTPHeaderFields = [:]
    }
    
    apiService = AppCheckCoreAPIService(
      urlSession: fakeURLSession.session,
      baseURL: nil,
      apiKey: nil,
      requestHooks: nil,
      environment: [:]
    )
  }
  
  override func tearDown() {
    apiService = nil
    fakeURLSession = nil
    expectedHTTPHeaderFields = nil
    super.tearDown()
  }
  
  // MARK: - Init
  
  func testInitDefaultBaseURL() {
    let service = AppCheckCoreAPIService(
      urlSession: fakeURLSession.session,
      baseURL: nil,
      apiKey: nil,
      requestHooks: nil,
      environment: [:]
    )
    XCTAssertNotNil(service)
    XCTAssertEqual(service.baseURL, "https://firebaseappcheck.googleapis.com/v1")
  }
  
  func testInitCustomBaseURL() {
    let customBaseURL = "https://custom.example.com/v1beta"
    let service = AppCheckCoreAPIService(
      urlSession: fakeURLSession.session,
      baseURL: customBaseURL,
      apiKey: nil,
      requestHooks: nil,
      environment: [:]
    )
    XCTAssertNotNil(service)
    XCTAssertEqual(service.baseURL, customBaseURL)
  }
  
  func testInitBaseURLStagingTriggeredByEnvVar() {
    let stagingBaseURL = "https://staging-firebaseappcheck.sandbox.googleapis.com/v1"
    let service = AppCheckCoreAPIService(
      urlSession: fakeURLSession.session,
      baseURL: nil,
      apiKey: nil,
      requestHooks: nil,
      environment: ["_AppCheckUseStaging": "YES"]
    )
    XCTAssertNotNil(service)
    XCTAssertEqual(service.baseURL, stagingBaseURL)
  }
  
  func testInitBaseURLStagingNotTriggeredWhenEnvVarIsNo() {
    let prodBaseURL = "https://firebaseappcheck.googleapis.com/v1"
    let service = AppCheckCoreAPIService(
      urlSession: fakeURLSession.session,
      baseURL: nil,
      apiKey: nil,
      requestHooks: nil,
      environment: ["_AppCheckUseStaging": "NO"]
    )
    XCTAssertNotNil(service)
    XCTAssertEqual(service.baseURL, prodBaseURL)
  }
  
  // MARK: - Send Requests
  
  func testDataRequestNetworkError() async {
    let url = URL(string: "https://some.url.com")!
    let additionalHeaders = ["header1": "value1"]
    let requestBody = "Request body".data(using: .utf8)!
    
    // 1. Stub URL session.
    let networkError = NSError(domain: "testDataRequestNetworkError", code: -1, userInfo: nil)
    stubURLSessionDataTask(response: nil, body: nil, error: networkError)
    
    // 2. Send request & 3. Verify.
    do {
      _ = try await apiService.sendRequest(withURL: url,
                                           httpMethod: "POST",
                                           body: requestBody,
                                           additionalHeaders: additionalHeaders)
      XCTFail("Expected error to be thrown")
    } catch {
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, AppCheckCoreErrorDomain)
      XCTAssertEqual(nsError.code, AppCheckCoreErrorCode.serverUnreachable.rawValue)
      XCTAssertEqual(nsError.userInfo[NSUnderlyingErrorKey] as? NSError, networkError)
    }
    
    XCTAssertTrue(fakeURLSession.isInvoked)
  }
  
  func testDataRequestNot2xxHTTPStatusCode() async {
    let url = URL(string: "https://some.url.com")!
    let requestBody = "Request body".data(using: .utf8)!
    let responseBodyString = "Token verification failed."
    let httpResponseBody = responseBodyString.data(using: .utf8)!
    let httpResponse = AppCheckCoreURLSessionFake.httpResponse(withCode: 300)
    
    stubURLSessionDataTask(response: httpResponse, body: httpResponseBody, error: nil)
    
    do {
      _ = try await apiService.sendRequest(withURL: url,
                                           httpMethod: "POST",
                                           body: requestBody,
                                           additionalHeaders: nil)
      XCTFail("Expected error to be thrown")
    } catch {
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, AppCheckCoreErrorDomain)
      XCTAssertEqual(nsError.code, AppCheckCoreErrorCode.unknown.rawValue)
      
      let failureReason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String
      XCTAssertNotNil(failureReason)
      XCTAssertTrue(failureReason?.contains("300") ?? false)
      XCTAssertTrue(failureReason?.contains(responseBodyString) ?? false)
    }
    
    XCTAssertTrue(fakeURLSession.isInvoked)
  }
  
  func testDataRequestWithRequestHooks() async throws {
    let url = URL(string: "https://some.url.com")!
    let httpMethod = "POST"
    let requestBody = "Request body".data(using: .utf8)!
    let requestTimeout: TimeInterval = 5.0
    expectedHTTPHeaderFields[kTestHeaderKey] = kTestHeaderValue
    
    let headerRequestHook: AppCheckCoreAPIRequestHook = { request in
      request.addValue(kTestHeaderValue, forHTTPHeaderField: kTestHeaderKey)
    }
    let timeoutRequestHook: AppCheckCoreAPIRequestHook = { request in
      request.timeoutInterval = requestTimeout
    }
    let cellularAccessRequestHook: AppCheckCoreAPIRequestHook = { request in
      request.allowsCellularAccess = false
    }
    
    apiService = AppCheckCoreAPIService(
      urlSession: fakeURLSession.session,
      baseURL: nil,
      apiKey: nil,
      requestHooks: [headerRequestHook, timeoutRequestHook, cellularAccessRequestHook],
      environment: [:]
    )
    
    let requestValidation: (URLRequest) -> Bool = { request in
      XCTAssertEqual(request.url, url)
      XCTAssertEqual(request.httpMethod, httpMethod)
      XCTAssertEqual(request.httpBody, requestBody)
      XCTAssertEqual(request.allHTTPHeaderFields, self.expectedHTTPHeaderFields)
      XCTAssertEqual(request.timeoutInterval, requestTimeout)
      XCTAssertEqual(request.allowsCellularAccess, false)
      return true
    }
    
    let httpResponseBody = "A response".data(using: .utf8)!
    let httpResponse = AppCheckCoreURLSessionFake.httpResponse(withCode: 200)
    stubURLSessionDataTask(response: httpResponse, body: httpResponseBody, error: nil, requestValidationBlock: requestValidation)
    
    let result = try await apiService.sendRequest(withURL: url,
                                                  httpMethod: httpMethod,
                                                  body: requestBody,
                                                  additionalHeaders: nil)
    
    XCTAssertEqual(result.httpResponse, httpResponse)
    XCTAssertEqual(result.httpBody, httpResponseBody)
    XCTAssertTrue(fakeURLSession.isInvoked)
  }
  
  func testDataRequestWithAdditionalHeaders() async throws {
    let url = URL(string: "https://some.url.com")!
    let httpMethod = "POST"
    let requestBody = "Request body".data(using: .utf8)!
    let additionalHeaders = [kTestHeaderKey: kTestHeaderValue]
    
    for (k, v) in additionalHeaders {
      expectedHTTPHeaderFields[k] = v
    }
    
    let requestValidation: (URLRequest) -> Bool = { request in
      XCTAssertEqual(request.url, url)
      XCTAssertEqual(request.httpMethod, httpMethod)
      XCTAssertEqual(request.httpBody, requestBody)
      XCTAssertEqual(request.allHTTPHeaderFields, self.expectedHTTPHeaderFields)
      return true
    }
    
    let httpResponseBody = "A response".data(using: .utf8)!
    let httpResponse = AppCheckCoreURLSessionFake.httpResponse(withCode: 200)
    stubURLSessionDataTask(response: httpResponse, body: httpResponseBody, error: nil, requestValidationBlock: requestValidation)
    
    let result = try await apiService.sendRequest(withURL: url,
                                                  httpMethod: httpMethod,
                                                  body: requestBody,
                                                  additionalHeaders: additionalHeaders)
    
    XCTAssertEqual(result.httpResponse, httpResponse)
    XCTAssertEqual(result.httpBody, httpResponseBody)
    XCTAssertTrue(fakeURLSession.isInvoked)
  }
  
  func testDataRequestWithAPIKey() async throws {
    let url = URL(string: "https://some.url.com")!
    let httpMethod = "POST"
    let requestBody = "Request body".data(using: .utf8)!
    expectedHTTPHeaderFields[kAPIKeyHeaderKey] = kAPIKeyHeaderValue
    
    apiService = AppCheckCoreAPIService(
      urlSession: fakeURLSession.session,
      baseURL: nil,
      apiKey: kAPIKeyHeaderValue,
      requestHooks: nil,
      environment: [:]
    )
    
    let requestValidation: (URLRequest) -> Bool = { request in
      XCTAssertEqual(request.url, url)
      XCTAssertEqual(request.httpMethod, httpMethod)
      XCTAssertEqual(request.httpBody, requestBody)
      XCTAssertEqual(request.allHTTPHeaderFields, self.expectedHTTPHeaderFields)
      return true
    }
    
    let httpResponseBody = "A response".data(using: .utf8)!
    let httpResponse = AppCheckCoreURLSessionFake.httpResponse(withCode: 200)
    stubURLSessionDataTask(response: httpResponse, body: httpResponseBody, error: nil, requestValidationBlock: requestValidation)
    
    let result = try await apiService.sendRequest(withURL: url,
                                                  httpMethod: httpMethod,
                                                  body: requestBody,
                                                  additionalHeaders: nil)
    
    XCTAssertEqual(result.httpResponse, httpResponse)
    XCTAssertEqual(result.httpBody, httpResponseBody)
    XCTAssertTrue(fakeURLSession.isInvoked)
  }
  
  // MARK: - Token Exchange API response
  
  func testAppCheckTokenWithAPIResponseValidResponse() async throws {
    let responseBody = try AppCheckCoreFixtureLoader.loadFixture(named: "FACTokenExchangeResponseSuccess.json")
    XCTAssertNotNil(responseBody)
    
    let httpResponse = AppCheckCoreURLSessionFake.httpResponse(withCode: 200)
    let apiResponse = AppCheckCoreURLSessionDataResponse(response: httpResponse, httpBody: responseBody)
    
    let expectedFACToken = "valid_app_check_token"
    
    let token = try await apiService.appCheckToken(withAPIResponse: apiResponse)
    
    XCTAssertEqual(token.token, expectedFACToken)
    XCTAssertTrue(AppCheckCoreDateTestUtils.isDate(token.expirationDate, approximatelyEqualCurrentPlusTimeInterval: 1800, precision: 10))
  }
  
  func testAppCheckTokenWithAPIResponseInvalidFormat() async {
    let responseBodyString = "Token verification failed."
    let responseBody = responseBodyString.data(using: .utf8)!
    let httpResponse = AppCheckCoreURLSessionFake.httpResponse(withCode: 200)
    let apiResponse = AppCheckCoreURLSessionDataResponse(response: httpResponse, httpBody: responseBody)
    
    do {
      _ = try await apiService.appCheckToken(withAPIResponse: apiResponse)
      XCTFail("Expected error to be thrown")
    } catch {
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, AppCheckCoreErrorDomain)
      XCTAssertEqual(nsError.code, AppCheckCoreErrorCode.unknown.rawValue)
      let failureReason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String
      XCTAssertEqual(failureReason, "JSON serialization error.")
    }
  }
  
  func testAppCheckTokenResponseMissingFields() async throws {
    try await assertMissingFieldError(fixtureName: "DeviceCheckResponseMissingToken.json", missingField: "token")
    try await assertMissingFieldError(fixtureName: "DeviceCheckResponseMissingTimeToLive.json", missingField: "ttl")
  }
  
  func assertMissingFieldError(fixtureName: String, missingField: String) async throws {
    let missingFieldBody = try AppCheckCoreFixtureLoader.loadFixture(named: fixtureName)
    XCTAssertNotNil(missingFieldBody)
    
    let httpResponse = AppCheckCoreURLSessionFake.httpResponse(withCode: 200)
    let apiResponse = AppCheckCoreURLSessionDataResponse(response: httpResponse, httpBody: missingFieldBody)
    
    do {
      _ = try await apiService.appCheckToken(withAPIResponse: apiResponse)
      XCTFail("Expected error to be thrown")
    } catch {
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, AppCheckCoreErrorDomain)
      XCTAssertEqual(nsError.code, AppCheckCoreErrorCode.unknown.rawValue)
      let failureReason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String
      XCTAssertTrue(failureReason?.contains("`\(missingField)`") ?? false, "Fixture `\(fixtureName)`: expected missing field \(missingField) error not found")
    }
  }
  
  // MARK: - Helpers
  
  private func stubURLSessionDataTask(response: HTTPURLResponse?,
                                      body: Data?,
                                      error: Error?,
                                      requestValidationBlock: ((URLRequest) -> Bool)? = nil) {
    fakeURLSession.requestValidationBlock = requestValidationBlock
    fakeURLSession.resultError = error
    if error == nil {
      fakeURLSession.resultResponse = AppCheckCoreURLSessionDataResponse(response: response, httpBody: body)
    } else {
      fakeURLSession.resultResponse = nil
    }
  }
}
