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

  init(dummy: Void = ()) {
    super.init()
  }

  static func fetchClient(withSiteKey siteKey: String,
                          completion: @escaping (RCARecaptchaClientProtocol?, Error?) -> Void) {
    if let error = mockError {
      completion(nil, error)
    } else {
      completion(mockClient, nil)
    }
  }
}

final class MockRecaptchaClient: NSObject, RCARecaptchaClientProtocol {
  var mockToken: String?
  var mockError: Error?

  init(dummy: Void = ()) {
    super.init()
  }

  func execute(withAction action: RCAActionProtocol,
               completion: @escaping (String?, Error?) -> Void) {
    if let error = mockError {
      completion(nil, error)
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

    let resolution: Any = (expectedError as NSError?) ??
      (expectedResponse ?? GACURLSessionDataResponse(
        response: HTTPURLResponse(),
        httpBody: Data()
      ))
    let promiseClass = NSClassFromString("FBLPromise") as! NSObject.Type
    let unmanaged = promiseClass.perform(NSSelectorFromString("resolvedWith:"), with: resolution)!
    return unmanaged.takeUnretainedValue() as! FBLPromise<GACURLSessionDataResponse>
  }

  func appCheckToken(withAPIResponse response: GACURLSessionDataResponse)
    -> FBLPromise<AppCheckCoreToken> {
    let resolution: Any = (expectedError as NSError?) ?? (expectedToken ?? AppCheckCoreToken(
      token: "dummy",
      expirationDate: Date()
    ))
    let promiseClass = NSClassFromString("FBLPromise") as! NSObject.Type
    let unmanaged = promiseClass.perform(NSSelectorFromString("resolvedWith:"), with: resolution)!
    return unmanaged.takeUnretainedValue() as! FBLPromise<AppCheckCoreToken>
  }
}
