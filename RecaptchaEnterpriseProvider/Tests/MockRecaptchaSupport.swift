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
import FBLPromises
import Foundation
import Promises
@testable import RecaptchaEnterpriseProvider
import RecaptchaInterop

class MockRCAAction: NSObject, RCAActionProtocol {
  var action: String { return customAction }

  // The following properties are required by RCAActionProtocol but not used in these tests.
  static var login: RCAActionProtocol { return MockRCAAction(customAction: "login") }
  static var signup: RCAActionProtocol { return MockRCAAction(customAction: "signup") }

  let customAction: String

  required init(customAction: String) {
    self.customAction = customAction
    super.init()
  }
}

final class MockRecaptcha: NSObject, RCARecaptchaProtocol {
  static var mockClient: MockRecaptchaClient?
  static var mockError: Error?

  // This initializer bypasses the unavailable `init()` in the protocol.
  // The unlabeled `Void` parameter carries no data and is purely to change the signature.
  init(_: Void = ()) {
    super.init()
  }

  static func fetchClient(withSiteKey siteKey: String,
                          completion: @escaping (RCARecaptchaClientProtocol?, Error?) -> Void) {
    if let mockError {
      completion(nil, mockError)
    } else {
      completion(mockClient, nil)
    }
  }
}

final class MockRecaptchaClient: NSObject, RCARecaptchaClientProtocol {
  var mockToken: String?
  var mockError: Error?

  // This initializer bypasses the unavailable `init()` in the protocol.
  // The unlabeled `Void` parameter carries no data and is purely to change the signature.
  init(_: Void = ()) {
    super.init()
  }

  func execute(withAction action: RCAActionProtocol,
               completion: @escaping (String?, Error?) -> Void) {
    if let mockError {
      completion(nil, mockError)
    } else {
      completion(mockToken, nil)
    }
  }

  func execute(withAction action: RCAActionProtocol, withTimeout timeout: Double,
               completion: @escaping (String?, Error?) -> Void) {
    execute(withAction: action, completion: completion)
  }
}

class MockAppCheckCoreAPIService: NSObject, AppCheckCoreAPIServiceProtocol {
  var baseURL: String = "https://test.com"

  struct RequestData {
    let url: URL?
    let httpMethod: String?
    let body: Data?
    let additionalHeaders: [String: String]?
  }

  var lastRequest: RequestData?
  var expectedResponse: GACURLSessionDataResponse?
  var expectedToken: AppCheckCoreToken?
  var expectedError: Error?

  func sendRequest(with url: URL, httpMethod: String, body: Data?,
                   additionalHeaders: [String: String]?) -> FBLPromise<GACURLSessionDataResponse> {
    lastRequest = RequestData(
      url: url,
      httpMethod: httpMethod,
      body: body,
      additionalHeaders: additionalHeaders
    )

    let promise = Promise<GACURLSessionDataResponse>.pending()

    if let expectedError {
      promise.reject(expectedError)
    } else {
      let response = expectedResponse ?? GACURLSessionDataResponse(
        response: HTTPURLResponse(),
        httpBody: Data()
      )
      promise.fulfill(response)
    }

    return promise.asObjCPromise()
  }

  func appCheckToken(withAPIResponse response: GACURLSessionDataResponse)
    -> FBLPromise<AppCheckCoreToken> {
    let promise = Promise<AppCheckCoreToken>.pending()

    if let expectedError {
      promise.reject(expectedError)
    } else {
      let token = expectedToken ?? AppCheckCoreToken(
        token: "placeholder_app_check_token",
        expirationDate: Date()
      )
      promise.fulfill(token)
    }

    return promise.asObjCPromise()
  }
}

class MockBackoffWrapper: NSObject, GACAppCheckBackoffWrapperProtocol {
  var applyBackoffCalled = false
  var shouldReturnError = false
  var mockError: NSError?
  var mockResult: Any?
  var capturedErrorHandler: GACAppCheckBackoffErrorHandler?

  func applyBackoff(toOperation operationProvider: @escaping GACAppCheckBackoffOperationProvider,
                    errorHandler: @escaping GACAppCheckBackoffErrorHandler)
    -> FBLPromise<AnyObject> {
    applyBackoffCalled = true
    capturedErrorHandler = errorHandler
    if shouldReturnError {
      let error = mockError ?? NSError(domain: "MockBackoffWrapper", code: -1, userInfo: nil)
      let swiftPromise = Promise<AnyObject>(error as Error)
      return swiftPromise.asObjCPromise()
    }
    if let mockResult {
      let swiftPromise = Promise<AnyObject>(mockResult as AnyObject)
      return swiftPromise.asObjCPromise()
    }
    return operationProvider()
  }

  func defaultAppCheckProviderErrorHandler() -> GACAppCheckBackoffErrorHandler {
    return { error in .typeExponential }
  }
}
