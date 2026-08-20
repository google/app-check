/*
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

// Assuming GACAppCheckAPIRequestHook is a typealias.
// It was defined somewhere else as a block taking an NSMutableURLRequest.
// We'll define it locally if it's missing, but it should be available.
// typealias GACAppCheckAPIRequestHook = (NSMutableURLRequest) -> Void

private let kAPIKeyHeaderKey = "X-Goog-Api-Key"
private let kBundleIdKey = "X-Ios-Bundle-Identifier"
private let kProdBaseURL = "https://firebaseappcheck.googleapis.com/v1"

#if !NDEBUG
private let kStagingBaseURL = "https://staging-firebaseappcheck.sandbox.googleapis.com/v1"
private let kAppCheckUseStagingEnvKey = "_AppCheckUseStaging"
#endif

@objc(_GACAppCheckAPIServiceProtocol)
public protocol GACAppCheckAPIServiceProtocol: NSObjectProtocol {
    @objc var baseURL: String { get }

    @objc(sendRequestWithURL:HTTPMethod:body:additionalHeaders:completion:)
    func sendRequest(
        withURL requestURL: URL,
        httpMethod: String,
        body: Data?,
        additionalHeaders: [String: String]?
    ) async throws -> GACURLSessionDataResponse

    @objc(appCheckTokenWithAPIResponse:completion:)
    func appCheckToken(withAPIResponse response: GACURLSessionDataResponse) async throws -> GACAppCheckToken
}

@objc(_GACAppCheckAPIService)
public class GACAppCheckAPIService: NSObject, GACAppCheckAPIServiceProtocol {

    public let baseURL: String
    private let urlSession: URLSession
    private let apiKey: String?
    // Using Any for hook as it's typically `@convention(block) (NSMutableURLRequest) -> Void`
    private let requestHooks: [GACAppCheckAPIRequestHook]

    @objc(initWithURLSession:baseURL:APIKey:requestHooks:)
    public convenience init(
        urlSession: URLSession,
        baseURL: String?,
        apiKey: String?,
        requestHooks: [GACAppCheckAPIRequestHook]?
    ) {
        self.init(urlSession: urlSession, baseURL: baseURL, apiKey: apiKey, requestHooks: requestHooks, environment: ProcessInfo.processInfo.environment)
    }
    
    // Internal designated initializer
    init(
        urlSession: URLSession,
        baseURL: String?,
        apiKey: String?,
        requestHooks: [GACAppCheckAPIRequestHook]?,
        environment: [String: String]
    ) {
        self.urlSession = urlSession
        self.apiKey = apiKey
        self.requestHooks = requestHooks ?? []

        var resolvedBaseURL = baseURL

        #if !NDEBUG
        if resolvedBaseURL == nil {
            let useStaging = (environment[kAppCheckUseStagingEnvKey] as NSString?)?.boolValue ?? false
            if useStaging {
                resolvedBaseURL = kStagingBaseURL
                let logMessage = "App Check staging environment enabled. API calls will be routed to \(kStagingBaseURL)."
                // Assuming GACAppCheckLogInfo is available
                GACAppCheckLogInfo(AppCheckCoreMessageCode.stagingModeEnabled, logMessage)
            }
        }
        #endif

        self.baseURL = resolvedBaseURL ?? kProdBaseURL
        super.init()
    }

    @objc(sendRequestWithURL:HTTPMethod:body:additionalHeaders:completion:)
    public func sendRequest(
        withURL requestURL: URL,
        httpMethod: String,
        body: Data?,
        additionalHeaders: [String: String]?
    ) async throws -> GACURLSessionDataResponse {
        let request = try await self.request(withURL: requestURL, httpMethod: httpMethod, body: body, additionalHeaders: additionalHeaders)
        let response = try await self.sendURLRequest(request)
        return try await self.validateHTTPResponseStatusCode(response)
    }

    private func request(
        withURL requestURL: URL,
        httpMethod: String,
        body: Data?,
        additionalHeaders: [String: String]?
    ) async throws -> URLRequest {
        guard let mutableRequest = NSMutableURLRequest(url: requestURL) as NSMutableURLRequest? else {
            throw GACAppCheckErrorUtil.error(withFailureReason: "Failed to create URLRequest.")
        }
        
        mutableRequest.httpMethod = httpMethod
        mutableRequest.httpBody = body
        mutableRequest.cachePolicy = .reloadIgnoringLocalCacheData

        if let apiKey = self.apiKey {
            mutableRequest.setValue(apiKey, forHTTPHeaderField: kAPIKeyHeaderKey)
        }

        if let bundleID = Bundle.main.bundleIdentifier {
            mutableRequest.setValue(bundleID, forHTTPHeaderField: kBundleIdKey)
        }

        additionalHeaders?.forEach { key, value in
            mutableRequest.setValue(value, forHTTPHeaderField: key)
        }

        for hook in self.requestHooks {
            hook(mutableRequest)
        }

        return mutableRequest as URLRequest
    }

    private func sendURLRequest(_ request: URLRequest) async throws -> GACURLSessionDataResponse {
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GACAppCheckErrorUtil.apiError(withNetworkError: URLError(.badServerResponse))
            }
            return GACURLSessionDataResponse(response: httpResponse, httpBody: data)
        } catch {
            throw GACAppCheckErrorUtil.apiError(withNetworkError: error)
        }
    }

    private func validateHTTPResponseStatusCode(_ response: GACURLSessionDataResponse) async throws -> GACURLSessionDataResponse {
        let statusCode = response.httpResponse.statusCode
        if statusCode < 200 || statusCode >= 300 {
            let bodyString = String(data: response.httpBody ?? Data(), encoding: .utf8) ?? ""
            let logMessage = "Unexpected API response: \(response.httpResponse), body: \(bodyString)."
            GACAppCheckLogDebug(AppCheckCoreMessageCode.unexpectedHTTPCode, logMessage)
            throw GACAppCheckErrorUtil.apiError(with: response.httpResponse, data: response.httpBody)
        }
        return response
    }

    @objc(appCheckTokenWithAPIResponse:completion:)
    public func appCheckToken(withAPIResponse response: GACURLSessionDataResponse) async throws -> GACAppCheckToken {
        return try GACAppCheckToken(tokenExchangeResponse: response.httpBody ?? Data(), requestDate: Date())
    }
}
