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

private let kAPIKeyHeaderKey = "X-Goog-Api-Key"
private let kBundleIdKey = "X-Ios-Bundle-Identifier"
private let kProdBaseURL = "https://firebaseappcheck.googleapis.com/v1"

#if DEBUG
  private let kStagingBaseURL = "https://staging-firebaseappcheck.sandbox.googleapis.com/v1"
  private let kAppCheckUseStagingEnvKey = "_AppCheckUseStaging"
#endif

package protocol AppCheckCoreAPIServiceProtocol: NSObjectProtocol {
  var baseURL: String { get }

  func sendRequest(withURL requestURL: URL,
                   httpMethod: String,
                   body: Data?,
                   additionalHeaders: [String: String]?) async throws
    -> AppCheckCoreURLSessionDataResponse

  func appCheckToken(withAPIResponse response: AppCheckCoreURLSessionDataResponse) throws
    -> AppCheckCoreToken
}

package class AppCheckCoreAPIService: NSObject,
  AppCheckCoreAPIServiceProtocol {
  package let baseURL: String
  private let urlSession: URLSession
  private let apiKey: String?
  // Using Any for hook as it's typically `@convention(block) (NSMutableURLRequest) -> Void`
  private let requestHooks: [AppCheckCoreAPIRequestHook]

  package convenience init(urlSession: URLSession,
                           baseURL: String?,
                           apiKey: String?,
                           requestHooks: [Any]?) {
    self.init(
      urlSession: urlSession,
      baseURL: baseURL,
      apiKey: apiKey,
      requestHooks: requestHooks,
      environment: ProcessInfo.processInfo.environment
    )
  }

  // Internal designated initializer
  package init(urlSession: URLSession,
               baseURL: String?,
               apiKey: String?,
               requestHooks: [Any]?,
               environment: [String: String]) {
    self.urlSession = urlSession
    self.apiKey = apiKey
    self.requestHooks = requestHooks?.compactMap { $0 as? AppCheckCoreAPIRequestHook } ?? []

    var resolvedBaseURL = baseURL

    #if DEBUG
      if resolvedBaseURL == nil {
        let useStaging = (environment[kAppCheckUseStagingEnvKey] as NSString?)?.boolValue ?? false
        if useStaging {
          resolvedBaseURL = kStagingBaseURL
          let logMessage =
            "App Check staging environment enabled. API calls will be routed to \(kStagingBaseURL)."
          AppCheckCoreLogger.log(code: .stagingModeEnabled, logLevel: .info, message: logMessage)
        }
      }
    #endif

    self.baseURL = resolvedBaseURL ?? kProdBaseURL
    super.init()
  }

  public func sendRequest(withURL requestURL: URL,
                          httpMethod: String,
                          body: Data?,
                          additionalHeaders: [String: String]?) async throws
    -> AppCheckCoreURLSessionDataResponse {
    let request = try self.request(
      withURL: requestURL,
      httpMethod: httpMethod,
      body: body,
      additionalHeaders: additionalHeaders
    )
    let response = try await sendURLRequest(request)
    return try validateHTTPResponseStatusCode(response)
  }

  private func request(withURL requestURL: URL,
                       httpMethod: String,
                       body: Data?,
                       additionalHeaders: [String: String]?) throws -> URLRequest {
    let mutableRequest = NSMutableURLRequest(url: requestURL)

    mutableRequest.httpMethod = httpMethod
    mutableRequest.httpBody = body
    mutableRequest.cachePolicy = .reloadIgnoringLocalCacheData

    if let apiKey = apiKey {
      mutableRequest.setValue(apiKey, forHTTPHeaderField: kAPIKeyHeaderKey)
    }

    if let bundleID = Bundle.main.bundleIdentifier {
      mutableRequest.setValue(bundleID, forHTTPHeaderField: kBundleIdKey)
    }

    additionalHeaders?.forEach { key, value in
      mutableRequest.setValue(value, forHTTPHeaderField: key)
    }

    for hook in requestHooks {
      hook(mutableRequest)
    }

    return mutableRequest as URLRequest
  }

  private func sendURLRequest(_ request: URLRequest) async throws
    -> AppCheckCoreURLSessionDataResponse {
    do {
      let requestDate = Date()
      let data: Data
      let response: URLResponse

      if #available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *) {
        (data, response) = try await urlSession.data(for: request)
      } else {
        (data, response) = try await withCheckedThrowingContinuation { continuation in
          let task = urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
              continuation.resume(throwing: error)
            } else if let data = data, let response = response {
              continuation.resume(returning: (data, response))
            } else {
              continuation.resume(throwing: URLError(.badServerResponse))
            }
          }
          task.resume()
        }
      }

      guard let httpResponse = response as? HTTPURLResponse else {
        throw AppCheckCoreErrorUtil.apiError(withNetworkError: URLError(.badServerResponse))
      }
      return AppCheckCoreURLSessionDataResponse(
        response: httpResponse,
        httpBody: data,
        requestDate: requestDate
      )
    } catch {
      throw AppCheckCoreErrorUtil.apiError(withNetworkError: error)
    }
  }

  private func validateHTTPResponseStatusCode(_ response: AppCheckCoreURLSessionDataResponse) throws
    -> AppCheckCoreURLSessionDataResponse {
    let statusCode = response.httpResponse.statusCode
    if statusCode < 200 || statusCode >= 300 {
      let bodyString = String(data: response.httpBody ?? Data(), encoding: .utf8) ?? ""
      let logMessage = "Unexpected API response: \(response.httpResponse), body: \(bodyString)."
      AppCheckCoreLogger.log(code: .unexpectedHTTPCode, logLevel: .debug, message: logMessage)
      throw AppCheckCoreErrorUtil.apiError(with: response.httpResponse, data: response.httpBody)
    }
    return response
  }

  public func appCheckToken(withAPIResponse response: AppCheckCoreURLSessionDataResponse) throws
    -> AppCheckCoreToken {
    return try AppCheckCoreToken(
      tokenExchangeResponse: response.httpBody ?? Data(),
      requestDate: response.requestDate
    )
  }
}
