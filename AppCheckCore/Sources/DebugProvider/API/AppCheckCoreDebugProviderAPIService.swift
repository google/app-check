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

import FBLPromises
import Foundation
import Promises

@objc(GACAppCheckDebugProviderAPIServiceProtocol)
public protocol AppCheckCoreDebugProviderAPIServiceProtocol: NSObjectProtocol, Sendable {
  @objc(appCheckTokenWithDebugToken:limitedUse:)
  func appCheckTokenObjC(withDebugToken debugToken: String, limitedUse: Bool)
    -> FBLPromise<AppCheckCoreToken>
}

public extension AppCheckCoreDebugProviderAPIServiceProtocol {
  func appCheckToken(withDebugToken debugToken: String,
                     limitedUse: Bool) -> Promise<AppCheckCoreToken> {
    let promise = appCheckTokenObjC(withDebugToken: debugToken, limitedUse: limitedUse)
    return Promise<AppCheckCoreToken>(promise)
  }
}

@objc(GACAppCheckDebugProviderAPIService)
public final class AppCheckCoreDebugProviderAPIService: NSObject,
  AppCheckCoreDebugProviderAPIServiceProtocol, @unchecked Sendable {
  private let apiService: AppCheckCoreAPIServiceProtocol
  private let resourceName: String

  @objc(initWithAPIService:resourceName:)
  public init(apiService: AppCheckCoreAPIServiceProtocol, resourceName: String) {
    self.apiService = apiService
    self.resourceName = resourceName
    super.init()
  }

  public func appCheckToken(withDebugToken debugToken: String,
                            limitedUse: Bool) -> Promise<AppCheckCoreToken> {
    guard !debugToken.isEmpty else {
      return Promise(AppCheckCoreErrorUtil
        .error(withFailureReason: "Debug token must not be empty."))
    }

    let urlString = "\(apiService.baseURL)/\(resourceName):exchangeDebugToken"
    guard let url = URL(string: urlString) else {
      return Promise(AppCheckCoreErrorUtil.error(withFailureReason: "Invalid URL: \(urlString)"))
    }

    let bodyDict: [String: Any] = [
      "debug_token": debugToken,
      "limited_use": limitedUse,
    ]

    let httpBody: Data
    do {
      httpBody = try JSONSerialization.data(withJSONObject: bodyDict, options: [])
    } catch {
      return Promise(AppCheckCoreErrorUtil.JSONSerializationError(error))
    }

    return apiService.sendRequest(
      with: url,
      httpMethod: "POST",
      body: httpBody,
      additionalHeaders: ["Content-Type": "application/json"]
    ).then { response -> Promise<AppCheckCoreToken> in
      return self.apiService.appCheckToken(withAPIResponse: response)
    }
  }

  @objc(appCheckTokenWithDebugToken:limitedUse:)
  public func appCheckTokenObjC(withDebugToken debugToken: String,
                                limitedUse: Bool) -> FBLPromise<AppCheckCoreToken> {
    return appCheckToken(withDebugToken: debugToken, limitedUse: limitedUse).asObjCPromise()
  }
}
