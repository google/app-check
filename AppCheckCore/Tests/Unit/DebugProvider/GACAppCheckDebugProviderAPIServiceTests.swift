import XCTest
#if canImport(Promises)
import Promises
#endif
@testable import AppCheckCore

class MockAppCheckAPIService: NSObject, _GACAppCheckAPIServiceProtocol {
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

class GACAppCheckDebugProviderAPIServiceTests: XCTestCase {
    var debugAPIService: GACAppCheckDebugProviderAPIService!
    var mockAPIService: MockAppCheckAPIService!
    
    let kResourceName = "projects/test_project_id/apps/test_app_id"
    
    override func setUp() {
        super.setUp()
        mockAPIService = MockAppCheckAPIService()
        debugAPIService = GACAppCheckDebugProviderAPIService(apiService: mockAPIService, resourceName: kResourceName)
    }
    
    override func tearDown() {
        debugAPIService = nil
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
        let debugToken = UUID().uuidString
        let expectedResult = GACAppCheckToken(token: "app_check_token", expirationDate: Date())
        
        let expectedRequestURL = "\(mockAPIService.baseURL)/projects/test_project_id/apps/test_app_id:exchangeDebugToken"
        let fakeResponseData = "fake response".data(using: .utf8)!
        let httpResponse = HTTPURLResponse(url: URL(string: expectedRequestURL)!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let apiResponse = _GACURLSessionDataResponse(response: httpResponse, httpBody: fakeResponseData)
        
        mockAPIService.sendRequestResult = .success(apiResponse)
        mockAPIService.appCheckTokenResult = .success(expectedResult)
        
        let token = try await debugAPIService.appCheckToken(debugToken: debugToken, limitedUse: limitedUse)
        
        XCTAssertEqual(token.token, expectedResult.token)
        XCTAssertEqual(token.expirationDate, expectedResult.expirationDate)
        
        XCTAssertEqual(mockAPIService.passedRequestURL?.absoluteString, expectedRequestURL)
        XCTAssertEqual(mockAPIService.passedHTTPMethod, "POST")
        XCTAssertEqual(mockAPIService.passedAdditionalHeaders?["Content-Type"], "application/json")
        try assertHTTPBody(mockAPIService.passedBody, debugToken: debugToken, limitedUse: limitedUse)
        XCTAssertEqual(mockAPIService.passedAPIResponse, apiResponse)
    }
    
    func testAppCheckTokenResponseParsingError() async throws {
        let debugToken = UUID().uuidString
        let parsingError = NSError(domain: "testAppCheckTokenResponseParsingError", code: -1, userInfo: nil)
        
        let expectedRequestURL = "\(mockAPIService.baseURL)/projects/test_project_id/apps/test_app_id:exchangeDebugToken"
        let fakeResponseData = "fake response".data(using: .utf8)!
        let httpResponse = HTTPURLResponse(url: URL(string: expectedRequestURL)!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let apiResponse = _GACURLSessionDataResponse(response: httpResponse, httpBody: fakeResponseData)
        
        mockAPIService.sendRequestResult = .success(apiResponse)
        mockAPIService.appCheckTokenResult = .failure(parsingError)
        
        do {
            _ = try await debugAPIService.appCheckToken(debugToken: debugToken, limitedUse: false)
            XCTFail("Expected error to be thrown")
        } catch let error as NSError {
            XCTAssertEqual(error, parsingError)
        }
        
        XCTAssertEqual(mockAPIService.passedRequestURL?.absoluteString, expectedRequestURL)
        XCTAssertEqual(mockAPIService.passedHTTPMethod, "POST")
        XCTAssertEqual(mockAPIService.passedAdditionalHeaders?["Content-Type"], "application/json")
        try assertHTTPBody(mockAPIService.passedBody, debugToken: debugToken, limitedUse: false)
        XCTAssertEqual(mockAPIService.passedAPIResponse, apiResponse)
    }
    
    func testAppCheckTokenNetworkError() async throws {
        let debugToken = UUID().uuidString
        let networkError = NSError(domain: "testAppCheckTokenNetworkError", code: -1, userInfo: nil)
        
        mockAPIService.sendRequestResult = .failure(networkError)
        
        do {
            _ = try await debugAPIService.appCheckToken(debugToken: debugToken, limitedUse: false)
            XCTFail("Expected error to be thrown")
        } catch let error as NSError {
            XCTAssertEqual(error, networkError)
        }
        
        try assertHTTPBody(mockAPIService.passedBody, debugToken: debugToken, limitedUse: false)
    }
    
    // MARK: - Helpers
    
    func assertHTTPBody(_ body: Data?, debugToken: String, limitedUse: Bool) throws {
        let unwrappedBody = try XCTUnwrap(body)
        let decodedData = try JSONSerialization.jsonObject(with: unwrappedBody, options: []) as? [String: Any]
        let unwrappedDecodedData = try XCTUnwrap(decodedData)
        
        let decodeDebugToken = unwrappedDecodedData["debug_token"] as? String
        XCTAssertEqual(decodeDebugToken, debugToken)
        
        let decodedLimitedUse = unwrappedDecodedData["limited_use"] as? Bool
        XCTAssertEqual(decodedLimitedUse, limitedUse)
    }
}
