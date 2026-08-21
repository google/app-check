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

// Assuming AppCheckCoreAPIRequestHook is a typealias.
// It was defined somewhere else as a block taking an NSMutableURLRequest.
// We'll define it locally if it's missing, but it should be available.
// typealias AppCheckCoreAPIRequestHook = (NSMutableURLRequest) -> Void

private let kAPIKeyHeaderKey = "X-Goog-Api-Key"
private let kBundleIdKey = "X-Ios-Bundle-Identifier"
private let kProdBaseURL = "https://firebaseappcheck.googleapis.com/v1"

#if !NDEBUG
  private let kStagingBaseURL = "https://staging-firebaseappcheck.sandbox.googleapis.com/v1"
  private let kAppCheckUseStagingEnvKey = "_AppCheckUseStaging"
#endif

@objc(GACAppCheckAPIServiceProtocol)
public protocol AppCheckCoreAPIServiceProtocol: NSObjectProtocol {
  @objc var baseURL: String { get }

  @objc(sendRequestWithURL:HTTPMethod:body:additionalHeaders:completion:)
  func sendRequest(withURL requestURL: URL,
                   httpMethod: String,
                   body: Data?,
                   additionalHeaders: [String: String]?) async throws
    -> AppCheckCoreURLSessionDataResponse

  @objc(appCheckTokenWithAPIResponse:completion:)
  func appCheckToken(withAPIResponse response: AppCheckCoreURLSessionDataResponse) async throws
    -> AppCheckCoreToken
}

@objc(GACAppCheckAPIService)
public class AppCheckCoreAPIService: NSObject, AppCheckCoreAPIServiceProtocol {
  public let baseURL: String
  private let urlSession: URLSession
  private let apiKey: String?
  // Using Any for hook as it's typically `@convention(block) (NSMutableURLRequest) -> Void`
  private let requestHooks: [AppCheckCoreAPIRequestHook]

  @objc(initWithURLSession:baseURL:APIKey:requestHooks:)
  public convenience init(urlSession: URLSession,
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
  init(urlSession: URLSession,
       baseURL: String?,
       apiKey: String?,
       requestHooks: [Any]?,
       environment: [String: String]) {
    self.urlSession = urlSession
    self.apiKey = apiKey
    self.requestHooks = requestHooks?.compactMap { $0 as? AppCheckCoreAPIRequestHook } ?? []

    var resolvedBaseURL = baseURL

    #if !NDEBUG
      if resolvedBaseURL == nil {
        let useStaging = (environment[kAppCheckUseStagingEnvKey] as NSString?)?.boolValue ?? false
        if useStaging {
          resolvedBaseURL = kStagingBaseURL
          let logMessage =
            "App Check staging environment enabled. API calls will be routed to \(kStagingBaseURL)."
          // Assuming AppCheckCoreLogger is available
          AppCheckCoreLogger.log(code: .stagingModeEnabled, logLevel: .info, message: logMessage)
        }
      }
    #endif

    self.baseURL = resolvedBaseURL ?? kProdBaseURL
    super.init()
  }

  @objc(sendRequestWithURL:HTTPMethod:body:additionalHeaders:completion:)
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
      let (data, response) = try await urlSession.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
        throw AppCheckCoreErrorUtil.apiError(withNetworkError: URLError(.badServerResponse))
      }
      return AppCheckCoreURLSessionDataResponse(response: httpResponse, httpBody: data)
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

  @objc(appCheckTokenWithAPIResponse:completion:)
  public func appCheckToken(withAPIResponse response: AppCheckCoreURLSessionDataResponse) async throws
    -> AppCheckCoreToken {
    return try AppCheckCoreToken(
      tokenExchangeResponse: response.httpBody ?? Data(),
      requestDate: Date()
    )
  }
}
