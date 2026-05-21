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

#if SWIFT_PACKAGE
  import AppCheckCore
#endif
import Foundation
import Promises

private enum Constants {
  static let contentTypeKey = "Content-Type"
  static let jsonContentType = "application/json"
  static let recaptchaTokenField = "recaptcha_enterprise_token"
  static let limitedUseField = "limited_use"
  // This endpoint should never change without coordination with the backend.
  static let exchangeEndpoint = "exchangeRecaptchaEnterpriseToken"
  static let httpMethodPost = "POST"
}

@available(iOS 15.0, visionOS 1.0, *)
@available(macOS, unavailable)
@available(macCatalyst, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
final class RecaptchaEnterpriseAPIService: NSObject {
  private let apiService: AppCheckCoreAPIServiceProtocol
  private let resourceName: String

  init(apiService: AppCheckCoreAPIServiceProtocol, resourceName: String) {
    self.apiService = apiService
    self.resourceName = resourceName
  }

  func appCheckToken(with recaptchaToken: String,
                     limitedUse: Bool) -> Promise<AppCheckCoreToken> {
    let urlString = "\(apiService.baseURL)/\(resourceName):\(Constants.exchangeEndpoint)"
    guard let url = URL(string: urlString) else {
      return Promise(GACAppCheckErrorUtil
        .error(withFailureReason: "Invalid URL string: \(urlString)"))
    }

    return httpBody(with: recaptchaToken, limitedUse: limitedUse)
      .then { httpBody in
        Promise<GACURLSessionDataResponse>(self.apiService.sendRequest(with: url,
                                                                       httpMethod: Constants
                                                                         .httpMethodPost,
                                                                       body: httpBody,
                                                                       additionalHeaders: [Constants
                                                                         .contentTypeKey: Constants
                                                                         .jsonContentType]))
      }.then { response in
        Promise<AppCheckCoreToken>(self.apiService.appCheckToken(withAPIResponse: response))
      }
  }

  private func httpBody(with recaptchaToken: String,
                        limitedUse: Bool) -> Promise<Data> {
    guard !recaptchaToken.isEmpty else {
      return Promise(GACAppCheckErrorUtil
        .error(withFailureReason: "Recaptcha token cannot be empty"))
    }

    return Promise(on: backgroundQueue()) {
      let payload: [String: Any] = [
        Constants.recaptchaTokenField: recaptchaToken,
        Constants.limitedUseField: limitedUse,
      ]

      do {
        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        return jsonData
      } catch {
        throw GACAppCheckErrorUtil.jsonSerializationError(error)
      }
    }
  }

  private func backgroundQueue() -> DispatchQueue {
    return DispatchQueue.global(qos: .utility)
  }
}
