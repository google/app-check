import XCTest
#if canImport(Promises)
import Promises
#endif
@testable import AppCheckCore

private class MockAppCheckAPIService: NSObject, _GACAppCheckAPIServiceProtocol {
    var baseURL: String = "https://test.appcheck.url.com/alpha"
    
    var passedRequestURL: URL?
    var passedHTTPMethod: String?
    var passedBody: Data?
    var passedAdditionalHeaders: [String: String]?
    
    var sendRequestResult: Result<_GACURLSessionDataResponse, Error>?
    var appCheckTokenResult: Result<GACAppCheckToken, Error>?
    
    var passedAPIResponse: _GACURLSessionDataResponse?
    
    func sendRequest(with requestURL: URL, httpMethod: String, body: Data?, additionalHeaders: [String : String]?) -> FBLPromise<_GACURLSessionDataResponse> {
        passedRequestURL = requestURL
        passedHTTPMethod = httpMethod
        passedBody = body
        passedAdditionalHeaders = additionalHeaders
        
        let promise = FBLPromise<_GACURLSessionDataResponse>.pending()
        if let result = sendRequestResult {
            switch result {
            case .success(let response): promise.fulfill(response)
            case .failure(let error): promise.reject(error)
            }
        }
        return promise
    }
    
    func appCheckToken(withAPIResponse response: _GACURLSessionDataResponse) -> FBLPromise<GACAppCheckToken> {
        passedAPIResponse = response
        let promise = FBLPromise<GACAppCheckToken>.pending()
        if let result = appCheckTokenResult {
            switch result {
            case .success(let token): promise.fulfill(token)
            case .failure(let error): promise.reject(error)
            }
        }
        return promise
    }
}

class GACDeviceCheckAPIServiceTests: XCTestCase {
    var apiService: GACDeviceCheckAPIService!
    private var mockAPIService: MockAppCheckAPIService!
    
    let kResourceName = "projects/project_id/apps/app_id"
    
    override func setUp() {
        super.setUp()
        mockAPIService = MockAppCheckAPIService()
        apiService = GACDeviceCheckAPIService(apiService: mockAPIService, resourceName: kResourceName)
    }
    
    override func tearDown() {
        apiService = nil
        mockAPIService = nil
        super.tearDown()
    }
    
    func testAppCheckTokenSuccess() async throws {
        try await testAppCheckTokenSuccess(withLimitedUse: false)
    }
    
    func testAppCheckTokenSuccessWithLimitedUse() async throws {
        try await testAppCheckTokenSuccess(withLimitedUse: true)
    }
    
    func testAppCheckTokenSuccess(withLimitedUse limitedUse: Bool) async throws {
        let deviceTokenData = "device_token".data(using: .utf8)!
        let expectedResult = GACAppCheckToken(token: "app_check_token", expirationDate: Date())
        
        let expectedRequestURL = "\(mockAPIService.baseURL)/projects/project_id/apps/app_id:exchangeDeviceCheckToken"
        
        // Since we aren't using the fixture loader for the fake response, we'll just mock any response data.
        let responseBody = "{}".data(using: .utf8)!
        let httpResponse = HTTPURLResponse(url: URL(string: expectedRequestURL)!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let apiResponse = _GACURLSessionDataResponse(response: httpResponse, httpBody: responseBody)
        
        mockAPIService.sendRequestResult = .success(apiResponse)
        mockAPIService.appCheckTokenResult = .success(expectedResult)
        
        let token = try await apiService.appCheckToken(deviceToken: deviceTokenData, limitedUse: limitedUse)
        
        XCTAssertEqual(token.token, expectedResult.token)
        XCTAssertEqual(token.expirationDate, expectedResult.expirationDate)
        
        XCTAssertEqual(mockAPIService.passedRequestURL?.absoluteString, expectedRequestURL)
        XCTAssertEqual(mockAPIService.passedHTTPMethod, "POST")
        XCTAssertEqual(mockAPIService.passedAdditionalHeaders?["Content-Type"], "application/json")
        try assertHTTPBody(mockAPIService.passedBody, deviceToken: deviceTokenData, limitedUse: limitedUse)
        XCTAssertEqual(mockAPIService.passedAPIResponse, apiResponse)
    }
    
    func testAppCheckTokenResponseParsingError() async throws {
        let deviceTokenData = "device_token".data(using: .utf8)!
        let parsingError = NSError(domain: "testAppCheckTokenResponseParsingError", code: -1, userInfo: nil)
        
        let expectedRequestURL = "\(mockAPIService.baseURL)/projects/project_id/apps/app_id:exchangeDeviceCheckToken"
        let responseBody = "{}".data(using: .utf8)!
        let httpResponse = HTTPURLResponse(url: URL(string: expectedRequestURL)!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let apiResponse = _GACURLSessionDataResponse(response: httpResponse, httpBody: responseBody)
        
        mockAPIService.sendRequestResult = .success(apiResponse)
        mockAPIService.appCheckTokenResult = .failure(parsingError)
        
        do {
            _ = try await apiService.appCheckToken(deviceToken: deviceTokenData, limitedUse: false)
            XCTFail("Expected error to be thrown")
        } catch let error as NSError {
            XCTAssertEqual(error, parsingError)
        }
        
        XCTAssertEqual(mockAPIService.passedRequestURL?.absoluteString, expectedRequestURL)
        XCTAssertEqual(mockAPIService.passedHTTPMethod, "POST")
        XCTAssertEqual(mockAPIService.passedAdditionalHeaders?["Content-Type"], "application/json")
        try assertHTTPBody(mockAPIService.passedBody, deviceToken: deviceTokenData, limitedUse: false)
        XCTAssertEqual(mockAPIService.passedAPIResponse, apiResponse)
    }
    
    func testAppCheckTokenNetworkError() async throws {
        let deviceTokenData = "device_token".data(using: .utf8)!
        let apiError = NSError(domain: "testAppCheckTokenNetworkError", code: -1, userInfo: nil)
        
        mockAPIService.sendRequestResult = .failure(apiError)
        
        do {
            _ = try await apiService.appCheckToken(deviceToken: deviceTokenData, limitedUse: false)
            XCTFail("Expected error to be thrown")
        } catch let error as NSError {
            XCTAssertEqual(error, apiError)
        }
        
        try assertHTTPBody(mockAPIService.passedBody, deviceToken: deviceTokenData, limitedUse: false)
    }
    
    func testAppCheckTokenEmptyDeviceToken() async throws {
        let deviceTokenData = Data()
        
        do {
            _ = try await apiService.appCheckToken(deviceToken: deviceTokenData, limitedUse: false)
            XCTFail("Expected error to be thrown")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, AppCheckCoreErrorDomain)
            XCTAssertEqual(error.code, AppCheckCoreErrorCode.unknown.rawValue)
            let failureReason = error.userInfo[NSLocalizedFailureReasonErrorKey] as? String
            XCTAssertEqual(failureReason, "DeviceCheck token must not be empty.")
        }
        
        XCTAssertNil(mockAPIService.passedRequestURL)
    }
    
    // MARK: - Helpers
    
    func assertHTTPBody(_ body: Data?, deviceToken: Data, limitedUse: Bool) throws {
        let unwrappedBody = try XCTUnwrap(body)
        let decodedData = try JSONSerialization.jsonObject(with: unwrappedBody, options: []) as? [String: Any]
        let unwrappedDecodedData = try XCTUnwrap(decodedData)
        
        let base64EncodedDeviceToken = try XCTUnwrap(unwrappedDecodedData["device_token"] as? String)
        let decodedLimitedUse = try XCTUnwrap(unwrappedDecodedData["limited_use"] as? Bool)
        
        XCTAssertEqual(decodedLimitedUse, limitedUse)
        
        let decodedToken = try XCTUnwrap(Data(base64Encoded: base64EncodedDeviceToken))
        XCTAssertEqual(decodedToken, deviceToken)
    }
}
