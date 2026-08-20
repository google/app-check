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

import Foundation

@objc(AppCheckCoreDeviceCheckAPIServiceProtocol)
protocol AppCheckCoreDeviceCheckAPIServiceProtocol: NSObjectProtocol {
  @objc func appCheckToken(deviceToken: Data, limitedUse: Bool) async throws -> AppCheckCoreToken
}

@objc(AppCheckCoreDeviceCheckAPIService)
class AppCheckCoreDeviceCheckAPIService: NSObject, AppCheckCoreDeviceCheckAPIServiceProtocol {
  private let apiService: AppCheckCoreAPIServiceProtocol
  private let resourceName: String

  @objc
  init(apiService: AppCheckCoreAPIServiceProtocol, resourceName: String) {
    self.apiService = apiService
    self.resourceName = resourceName
    super.init()
  }

  @objc
  func appCheckToken(deviceToken: Data, limitedUse: Bool) async throws -> AppCheckCoreToken {
    guard !deviceToken.isEmpty else {
      throw AppCheckCoreErrorUtil.error(withFailureReason: "DeviceCheck token must not be empty.")
    }

    let base64EncodedToken = deviceToken.base64EncodedString()
    let payload: [String: Any] = [
      "device_token": base64EncodedToken,
      "limited_use": limitedUse,
    ]

    let payloadJSON: Data
    do {
      payloadJSON = try JSONSerialization.data(withJSONObject: payload)
    } catch {
      throw AppCheckCoreErrorUtil.jsonSerializationError(error)
    }

    let urlString = "\(apiService.baseURL)/\(resourceName):exchangeDeviceCheckToken"
    guard let url = URL(string: urlString) else {
      throw AppCheckCoreErrorUtil.error(withFailureReason: "Invalid URL.")
    }

    let response = try await apiService.sendRequest(
      withURL: url,
      httpMethod: "POST",
      body: payloadJSON,
      additionalHeaders: ["Content-Type": "application/json"]
    )

    return try await apiService.appCheckToken(withAPIResponse: response)
  }
}
