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

@testable import AppCheckCore

private class MockAppCheckAPIService: NSObject, AppCheckCoreAPIServiceProtocol {
  var baseURL: String = "https://test.appcheck.url.com/alpha"

  var passedRequestURL: URL?
  var passedHTTPMethod: String?
  var passedBody: Data?
  var passedAdditionalHeaders: [String: String]?

  var sendRequestResult: Result<AppCheckCoreURLSessionDataResponse, Error>?
  var appCheckTokenResult: Result<AppCheckCoreToken, Error>?

  var passedAPIResponse: AppCheckCoreURLSessionDataResponse?

  func sendRequest(withURL requestURL: URL, httpMethod: String, body: Data?,
                   additionalHeaders: [String: String]?) async throws
    -> AppCheckCoreURLSessionDataResponse {
    passedRequestURL = requestURL
    passedHTTPMethod = httpMethod
    passedBody = body
    passedAdditionalHeaders = additionalHeaders
    if let result = sendRequestResult {
      switch result {
      case let .success(response): return response
      case let .failure(error): throw error
      }
    }
    throw NSError(domain: "MockAppCheckAPIService", code: -1, userInfo: nil)
  }

  func appCheckToken(withAPIResponse response: AppCheckCoreURLSessionDataResponse) async throws
    -> AppCheckCoreToken {
    passedAPIResponse = response
    if let result = appCheckTokenResult {
      switch result {
      case let .success(token): return token
      case let .failure(error): throw error
      }
    }
    throw NSError(domain: "MockAppCheckAPIService", code: -1, userInfo: nil)
  }
}

class AppCheckCoreDeviceCheckAPIServiceTests: XCTestCase {
  var apiService: AppCheckCoreDeviceCheckAPIService!
  private var mockAPIService: MockAppCheckAPIService!

  let kResourceName = "projects/project_id/apps/app_id"

  override func setUp() {
    super.setUp()
    mockAPIService = MockAppCheckAPIService()
    apiService = AppCheckCoreDeviceCheckAPIService(
      apiService: mockAPIService,
      resourceName: kResourceName
    )
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
    let expectedResult = AppCheckCoreToken(token: "app_check_token", expirationDate: Date())

    let expectedRequestURL =
      "\(mockAPIService.baseURL)/projects/project_id/apps/app_id:exchangeDeviceCheckToken"

    // Since we aren't using the fixture loader for the fake response, we'll just mock any response
    // data.
    let responseBody = "{}".data(using: .utf8)!
    let httpResponse = HTTPURLResponse(
      url: URL(string: expectedRequestURL)!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    )!
    let apiResponse = AppCheckCoreURLSessionDataResponse(
      response: httpResponse,
      httpBody: responseBody
    )

    mockAPIService.sendRequestResult = .success(apiResponse)
    mockAPIService.appCheckTokenResult = .success(expectedResult)

    let token = try await apiService.appCheckToken(
      deviceToken: deviceTokenData,
      limitedUse: limitedUse
    )

    XCTAssertEqual(token.token, expectedResult.token)
    XCTAssertEqual(token.expirationDate, expectedResult.expirationDate)

    XCTAssertEqual(mockAPIService.passedRequestURL?.absoluteString, expectedRequestURL)
    XCTAssertEqual(mockAPIService.passedHTTPMethod, "POST")
    XCTAssertEqual(mockAPIService.passedAdditionalHeaders?["Content-Type"], "application/json")
    try assertHTTPBody(
      mockAPIService.passedBody,
      deviceToken: deviceTokenData,
      limitedUse: limitedUse
    )
    XCTAssertEqual(mockAPIService.passedAPIResponse, apiResponse)
  }

  func testAppCheckTokenResponseParsingError() async throws {
    let deviceTokenData = "device_token".data(using: .utf8)!
    let parsingError = NSError(
      domain: "testAppCheckTokenResponseParsingError",
      code: -1,
      userInfo: nil
    )

    let expectedRequestURL =
      "\(mockAPIService.baseURL)/projects/project_id/apps/app_id:exchangeDeviceCheckToken"
    let responseBody = "{}".data(using: .utf8)!
    let httpResponse = HTTPURLResponse(
      url: URL(string: expectedRequestURL)!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    )!
    let apiResponse = AppCheckCoreURLSessionDataResponse(
      response: httpResponse,
      httpBody: responseBody
    )

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
    let decodedData = try JSONSerialization
      .jsonObject(with: unwrappedBody, options: []) as? [String: Any]
    let unwrappedDecodedData = try XCTUnwrap(decodedData)

    let base64EncodedDeviceToken = try XCTUnwrap(unwrappedDecodedData["device_token"] as? String)
    let decodedLimitedUse = try XCTUnwrap(unwrappedDecodedData["limited_use"] as? Bool)

    XCTAssertEqual(decodedLimitedUse, limitedUse)

    let decodedToken = try XCTUnwrap(Data(base64Encoded: base64EncodedDeviceToken))
    XCTAssertEqual(decodedToken, deviceToken)
  }
}
