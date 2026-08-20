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

#if canImport(GoogleUtilities)
  import GoogleUtilities
#endif
import GoogleUtilities_UserDefaults

private let kDebugTokenEnvKey = "AppCheckDebugToken"
private let kFirebaseDebugTokenEnvKey = "FIRAAppCheckDebugToken"
private let kDebugTokenUserDefaultsKey = "AppCheckCoreDebugToken"
private let kDebugTokenRegisteredUserDefaultsKey = "AppCheckCoreDebugTokenRegistered"

@objc(GACAppCheckDebugProvider)
@objcMembers
public class AppCheckCoreDebugProvider: NSObject, AppCheckCoreProvider {
  private let apiService: AppCheckCoreDebugProviderAPIServiceProtocol
  private let debugTokenEnvValue: String?
  private let registeredUserDefaultsKey: String

  // Internal initializer
  init(apiService: AppCheckCoreDebugProviderAPIServiceProtocol,
       serviceName: String,
       resourceName: String,
       environment: [String: String]) {
    self.apiService = apiService
    registeredUserDefaultsKey = Self.registeredUserDefaultsKey(
      forServiceName: serviceName,
      resourceName: resourceName
    )
    debugTokenEnvValue = Self.environmentVariableDebugToken(
      registeredUserDefaultsKey: registeredUserDefaultsKey,
      environment: environment
    )
    super.init()
  }

  @objc(initWithServiceName:resourceName:baseURL:APIKey:requestHooks:)
  public convenience init(serviceName: String,
                          resourceName: String,
                          baseURL: String?,
                          apiKey: String,
                          requestHooks: [AppCheckCoreAPIRequestHook]?) {
    self.init(serviceName: serviceName,
              resourceName: resourceName,
              baseURL: baseURL,
              apiKey: apiKey,
              requestHooks: requestHooks,
              environment: ProcessInfo.processInfo.environment)
  }

  // Additional internal initializer for testing
  convenience init(serviceName: String,
                   resourceName: String,
                   baseURL: String?,
                   apiKey: String,
                   requestHooks: [AppCheckCoreAPIRequestHook]?,
                   environment: [String: String]) {
    let urlSession = URLSession(configuration: .ephemeral)
    let coreAPIService = AppCheckCoreAPIService(urlSession: urlSession,
                                                baseURL: baseURL,
                                                apiKey: apiKey,
                                                requestHooks: requestHooks,
                                                environment: environment)
    let debugAPIService = AppCheckCoreDebugProviderAPIService(apiService: coreAPIService,
                                                              resourceName: resourceName)
    self.init(apiService: debugAPIService,
              serviceName: serviceName,
              resourceName: resourceName,
              environment: environment)
  }

  public func localDebugToken() -> String {
    return Self.localDebugToken()
  }

  public func currentDebugToken() -> String {
    return debugTokenEnvValue ?? Self.localDebugToken()
  }

  // MARK: - AppCheckCoreProvider

  public func getToken() async throws -> AppCheckCoreToken {
    return try await withCheckedThrowingContinuation { continuation in
      self.getToken { token, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else if let token = token {
          continuation.resume(returning: token)
        } else {
          let wrappedError = NSError(
            domain: AppCheckCoreErrorDomain,
            code: AppCheckCoreErrorCode.unknown.rawValue,
            userInfo: nil
          )
          continuation.resume(throwing: wrappedError)
        }
      }
    }
  }

  public func getLimitedUseToken() async throws -> AppCheckCoreToken {
    return try await withCheckedThrowingContinuation { continuation in
      self.getLimitedUseToken { token, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else if let token = token {
          continuation.resume(returning: token)
        } else {
          let wrappedError = NSError(
            domain: AppCheckCoreErrorDomain,
            code: AppCheckCoreErrorCode.unknown.rawValue,
            userInfo: nil
          )
          continuation.resume(throwing: wrappedError)
        }
      }
    }
  }

  public func getToken(completion handler: @escaping (AppCheckCoreToken?, Error?) -> Void) {
    getToken(limitedUse: false, completion: handler)
  }

  public func getLimitedUseToken(completion handler: @escaping (AppCheckCoreToken?, Error?)
    -> Void) {
    getToken(limitedUse: true, completion: handler)
  }

  // MARK: - Internal

  private func getToken(limitedUse: Bool,
                        completion handler: @escaping (AppCheckCoreToken?, Error?) -> Void) {
    Task {
      do {
        let token = try await apiService.appCheckToken(
          debugToken: currentDebugToken(),
          limitedUse: limitedUse
        )
        GULUserDefaults.standard().setObject(true, forKey: registeredUserDefaultsKey)
        handler(token, nil)
      } catch {
        let logMessage = "Failed to exchange debug token to app check token: \(error)"
        AppCheckCoreLogger.log(
          code: .debugProviderFailedExchange,
          logLevel: .debug,
          message: logMessage
        )

        let nsError = error as NSError
        if nsError.domain == AppCheckCoreErrorDomain && nsError.code == AppCheckCoreErrorCode
          .serverUnreachable.rawValue {
          // Do nothing
        } else {
          GULUserDefaults.standard().removeObject(forKey: registeredUserDefaultsKey)
        }
        handler(nil, error)
      }
    }
  }

  private static func localDebugToken() -> String {
    if let token = GULUserDefaults.standard().string(forKey: kDebugTokenUserDefaultsKey) {
      return token
    } else {
      let token = UUID().uuidString
      GULUserDefaults.standard().setObject(token, forKey: kDebugTokenUserDefaultsKey)
      return token
    }
  }

  private static func registeredUserDefaultsKey(forServiceName serviceName: String,
                                                resourceName: String) -> String {
    let safeServiceName = serviceName.isEmpty ? "default" : serviceName
    var safeResourceName = resourceName.replacingOccurrences(of: "/", with: "_")
    if safeResourceName.isEmpty {
      safeResourceName = "default"
    }
    return "\(kDebugTokenRegisteredUserDefaultsKey)_\(safeServiceName)_\(safeResourceName)"
  }

  private static func environmentVariableDebugToken(registeredUserDefaultsKey: String,
                                                    environment: [String: String]) -> String? {
    let envVariableValue = environment[kDebugTokenEnvKey]?
      .isEmpty == false ? environment[kDebugTokenEnvKey] : nil
    let firebaseEnvVariableValue = environment[kFirebaseDebugTokenEnvKey]?
      .isEmpty == false ? environment[kFirebaseDebugTokenEnvKey] : nil

    if let env = envVariableValue, let _ = firebaseEnvVariableValue {
      let message =
        "The environment variables \(kDebugTokenEnvKey) and \(kFirebaseDebugTokenEnvKey) are both set; using the debug token specified in \(kDebugTokenEnvKey) and ignoring the value of \(kFirebaseDebugTokenEnvKey)."
      AppCheckCoreLogger.log(
        code: .debugProviderFirebaseEnvironmentVariable,
        logLevel: .warning,
        message: message
      )
      return env
    } else if let env = envVariableValue {
      let message =
        "Using the debug token specified in the environment variable \(kDebugTokenEnvKey)."
      AppCheckCoreLogger.log(
        code: .environmentVariableDebugToken,
        logLevel: .debug,
        message: message
      )
      return env
    } else if let firebaseEnv = firebaseEnvVariableValue {
      let message =
        "Using the debug token specified in the environment variable \(kFirebaseDebugTokenEnvKey)."
      AppCheckCoreLogger.log(
        code: .debugProviderFirebaseEnvironmentVariable,
        logLevel: .debug,
        message: message
      )
      return firebaseEnv
    } else {
      let isRegistered = GULUserDefaults.standard().bool(forKey: registeredUserDefaultsKey)
      if !isRegistered {
        let message = "App Check debug token: '\(Self.localDebugToken())'."
        AppCheckCoreLogger.log(code: .localDebugToken, logLevel: .warning, message: message)
      }
      return nil
    }
  }
}
