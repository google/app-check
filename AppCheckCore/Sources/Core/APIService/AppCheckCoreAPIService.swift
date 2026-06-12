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

public typealias AppCheckCoreAPIRequestHook = @convention(block) (NSMutableURLRequest) -> Void

@objc(_GACAppCheckAPIServiceProtocol)
public protocol AppCheckCoreAPIServiceProtocol: NSObjectProtocol, Sendable {
  @objc var baseURL: String { get }

  @objc(sendRequestWithURL:HTTPMethod:body:additionalHeaders:)
  func sendRequestObjC(with requestURL: URL,
                       httpMethod: String,
                       body: Data?,
                       additionalHeaders: [String: String]?)
    -> FBLPromise<AppCheckCoreURLSessionDataResponse>

  @objc(appCheckTokenWithAPIResponse:)
  func appCheckTokenObjC(withAPIResponse response: AppCheckCoreURLSessionDataResponse)
    -> FBLPromise<AppCheckCoreToken>
}

public extension AppCheckCoreAPIServiceProtocol {
  func sendRequest(with requestURL: URL,
                   httpMethod: String,
                   body: Data?,
                   additionalHeaders: [String: String]?)
    -> Promise<AppCheckCoreURLSessionDataResponse> {
    let promise = sendRequestObjC(
      with: requestURL,
      httpMethod: httpMethod,
      body: body,
      additionalHeaders: additionalHeaders
    )
    return Promise<AppCheckCoreURLSessionDataResponse>(promise)
  }

  func appCheckToken(withAPIResponse response: AppCheckCoreURLSessionDataResponse)
    -> Promise<AppCheckCoreToken> {
    let promise = appCheckTokenObjC(withAPIResponse: response)
    return Promise<AppCheckCoreToken>(promise)
  }
}

@objc(_GACAppCheckAPIService)
public final class AppCheckCoreAPIService: NSObject, AppCheckCoreAPIServiceProtocol,
  @unchecked Sendable {
  @objc public let baseURL: String
  private let urlSession: URLSession
  private let apiKey: String?
  private let requestHooks: [AppCheckCoreAPIRequestHook]

  private static let prodBaseURL = "https://firebaseappcheck.googleapis.com/v1"
  #if DEBUG
    private static let stagingBaseURL = "https://staging-firebaseappcheck.sandbox.googleapis.com/v1"
    private static let appCheckUseStagingEnvKey = "_AppCheckUseStaging"
  #endif

  @objc(initWithURLSession:baseURL:APIKey:requestHooks:)
  public init(urlSession session: URLSession,
              baseURL: String?,
              apiKey: String?,
              requestHooks: [Any]?) {
    urlSession = session
    self.apiKey = apiKey
    if let hooks = requestHooks {
      self.requestHooks = hooks.map { hook in
        unsafeBitCast(hook as AnyObject, to: AppCheckCoreAPIRequestHook.self)
      }
    } else {
      self.requestHooks = []
    }

    var resolvedBaseURL = baseURL
    #if DEBUG
      if resolvedBaseURL == nil {
        let useStaging = ProcessInfo.processInfo
          .environment[Self.appCheckUseStagingEnvKey] == "true" || ProcessInfo.processInfo
          .environment[Self.appCheckUseStagingEnvKey] == "YES"
        if useStaging {
          resolvedBaseURL = Self.stagingBaseURL
          let logMessage =
            "App Check staging environment enabled. API calls will be routed to \(Self.stagingBaseURL)."
          GACAppCheckLog(
            code: .loggerAppCheckMessageCodeStagingModeEnabled,
            logLevel: .info,
            message: logMessage as NSString
          )
        }
      }
    #endif

    self.baseURL = resolvedBaseURL ?? Self.prodBaseURL
    super.init()
  }

  // Swift-native async/await implementation
  public func sendRequest(with requestURL: URL,
                          httpMethod: String,
                          body: Data?,
                          additionalHeaders: [String: String]?) async throws
    -> AppCheckCoreURLSessionDataResponse {
    let promise = sendRequestObjC(
      with: requestURL,
      httpMethod: httpMethod,
      body: body,
      additionalHeaders: additionalHeaders
    )
    return try await withCheckedThrowingContinuation { continuation in
      Promise(promise).then { response in
        continuation.resume(returning: response)
      }.catch { error in
        continuation.resume(throwing: error)
      }
    }
  }

  private func createRequest(with requestURL: URL,
                             httpMethod: String,
                             body: Data?,
                             additionalHeaders: [String: String]?) throws -> URLRequest {
    var request = URLRequest(url: requestURL)
    request.httpMethod = httpMethod
    request.httpBody = body
    request.cachePolicy = .reloadIgnoringLocalCacheData

    if let apiKey = apiKey {
      request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
    }

    if let bundleId = Bundle.main.bundleIdentifier {
      request.setValue(bundleId, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
    }

    additionalHeaders?.forEach { key, value in
      request.setValue(value, forHTTPHeaderField: key)
    }

    for hook in requestHooks {
      if let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest {
        hook(mutableRequest)
        request = mutableRequest as URLRequest
      }
    }

    return request
  }

  private func validate(_ response: AppCheckCoreURLSessionDataResponse) throws
    -> AppCheckCoreURLSessionDataResponse {
    let statusCode = response.httpResponse.statusCode
    if statusCode < 200 || statusCode >= 300 {
      let bodyString = String(data: response.httpBody ?? Data(), encoding: .utf8) ?? ""
      let logMessage = "Unexpected API response: \(response.httpResponse), body: \(bodyString)."
      GACAppCheckLog(
        code: .loggerAppCheckMessageCodeUnexpectedHTTPCode,
        logLevel: .debug,
        message: logMessage as NSString
      )
      throw AppCheckCoreErrorUtil.APIError(
        withHTTPResponse: response.httpResponse,
        data: response.httpBody
      )
    }
    return response
  }

  public func appCheckToken(withAPIResponse response: AppCheckCoreURLSessionDataResponse) throws
    -> AppCheckCoreToken {
    guard let body = response.httpBody else {
      throw AppCheckCoreErrorUtil.error(withFailureReason: "Response body was empty.")
    }
    let token = try AppCheckCoreToken(tokenExchangeResponse: body, requestDate: Date())
    return token
  }

  // MARK: - Objective-C Compatibility Bridge

  @objc(sendRequestWithURL:HTTPMethod:body:additionalHeaders:)
  public func sendRequestObjC(with requestURL: URL,
                              httpMethod: String,
                              body: Data?,
                              additionalHeaders: [String: String]?)
    -> FBLPromise<AppCheckCoreURLSessionDataResponse> {
    do {
      let request = try createRequest(
        with: requestURL,
        httpMethod: httpMethod,
        body: body,
        additionalHeaders: additionalHeaders
      )
      let fblPromise = urlSession.gac_dataTaskPromise(with: request)
      let promise = Promise<AppCheckCoreURLSessionDataResponse>(fblPromise)
        .recover { networkError -> AppCheckCoreURLSessionDataResponse in
          throw AppCheckCoreErrorUtil.APIError(withNetworkError: networkError)
        }.then { response in
          try self.validate(response)
        }
      return promise.asObjCPromise()
    } catch {
      let errorPromise = FBLPromise<AppCheckCoreURLSessionDataResponse>.__pending()
      errorPromise.__reject(error as NSError)
      return errorPromise
    }
  }

  @objc(appCheckTokenWithAPIResponse:)
  public func appCheckTokenObjC(withAPIResponse response: AppCheckCoreURLSessionDataResponse)
    -> FBLPromise<AppCheckCoreToken> {
    do {
      let token = try appCheckToken(withAPIResponse: response)
      return Promise(token).asObjCPromise()
    } catch {
      return Promise<AppCheckCoreToken>(error).asObjCPromise()
    }
  }
}
