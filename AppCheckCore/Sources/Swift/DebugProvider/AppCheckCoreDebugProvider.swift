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
import GoogleUtilities_UserDefaults

@objc(GACAppCheckDebugProvider)
public final class AppCheckCoreDebugProvider: NSObject, AppCheckCoreProvider, @unchecked Sendable {
  private let apiService: AppCheckCoreDebugProviderAPIServiceProtocol
  private let debugTokenEnvValue: String?
  @objc let registeredUserDefaultsKey: String

  private static let debugTokenEnvKey = "AppCheckDebugToken"
  private static let firebaseDebugTokenEnvKey = "FIRAAppCheckDebugToken"
  private static let debugTokenUserDefaultsKey = "GACAppCheckDebugToken"
  private static let debugTokenRegisteredUserDefaultsKey = "GACAppCheckDebugTokenRegistered"

  @objc(initWithAPIService:serviceName:resourceName:)
  public init(apiService: AppCheckCoreDebugProviderAPIServiceProtocol,
              serviceName: String,
              resourceName: String) {
    self.apiService = apiService
    let key = Self.registeredUserDefaultsKey(
      forServiceName: serviceName,
      resourceName: resourceName
    )
    registeredUserDefaultsKey = key
    debugTokenEnvValue = Self.environmentVariableDebugToken(registeredUserDefaultsKey: key)
    super.init()
  }

  @objc public init(serviceName: String,
                    resourceName: String,
                    baseURL: String?,
                    apiKey: String,
                    requestHooks: [Any]?) {
    let session = URLSession(configuration: .ephemeral)
    let coreAPIService = AppCheckCoreAPIService(
      urlSession: session,
      baseURL: baseURL,
      apiKey: apiKey,
      requestHooks: requestHooks
    )
    let debugAPIService = AppCheckCoreDebugProviderAPIService(
      apiService: coreAPIService,
      resourceName: resourceName
    )
    apiService = debugAPIService
    let key = Self.registeredUserDefaultsKey(
      forServiceName: serviceName,
      resourceName: resourceName
    )
    registeredUserDefaultsKey = key
    debugTokenEnvValue = Self.environmentVariableDebugToken(registeredUserDefaultsKey: key)
    super.init()
  }

  @objc public func currentDebugToken() -> String {
    return debugTokenEnvValue ?? localDebugToken()
  }

  @objc public func localDebugToken() -> String {
    return Self.localDebugTokenStatic()
  }

  // MARK: - AppCheckCoreProvider

  @objc public func getToken(completion handler: @escaping (AppCheckCoreToken?, NSError?) -> Void) {
    getToken(limitedUse: false, completion: handler)
  }

  @objc public func getLimitedUseToken(completion handler: @escaping (AppCheckCoreToken?, NSError?)
    -> Void) {
    getToken(limitedUse: true, completion: handler)
  }

  private func getToken(limitedUse: Bool,
                        completion handler: @escaping (AppCheckCoreToken?, NSError?) -> Void) {
    Task {
      do {
        let debugToken = currentDebugToken()
        let appCheckToken = try await apiService.appCheckToken(
          withDebugToken: debugToken,
          limitedUse: limitedUse
        )
        GULUserDefaults.standard().setBool(true, forKey: registeredUserDefaultsKey)
        handler(appCheckToken, nil)
      } catch {
        let nsError = error as NSError
        let logMessage = "Failed to exchange debug token to app check token: \(error)"
        GACAppCheckLog(
          code: .loggerAppCheckMessageDebugProviderFailedExchange,
          logLevel: .debug,
          message: logMessage as NSString
        )

        if nsError.domain != AppCheckCoreErrorDomain || nsError.code != AppCheckCoreErrorCode
          .serverUnreachable.rawValue {
          GULUserDefaults.standard().removeObject(forKey: registeredUserDefaultsKey)
        }
        handler(nil, nsError)
      }
    }
  }

  // MARK: - Helpers

  private static func localDebugTokenStatic() -> String {
    return storedDebugToken() ?? generateAndStoreDebugToken()
  }

  private static func storedDebugToken() -> String? {
    return GULUserDefaults.standard().string(forKey: debugTokenUserDefaultsKey)
  }

  private static func generateAndStoreDebugToken() -> String {
    let token = UUID().uuidString
    GULUserDefaults.standard().setObject(token, forKey: debugTokenUserDefaultsKey)
    return token
  }

  @objc(registeredUserDefaultsKeyForServiceName:resourceName:)
  static func registeredUserDefaultsKey(forServiceName serviceName: String?,
                                        resourceName: String?) -> String {
    let safeServiceName: String
    if let name = serviceName, !name.isEmpty {
      safeServiceName = name
    } else {
      safeServiceName = "default"
    }

    let safeResourceName: String
    if let name = resourceName?.replacingOccurrences(of: "/", with: "_"), !name.isEmpty {
      safeResourceName = name
    } else {
      safeResourceName = "default"
    }

    return "\(debugTokenRegisteredUserDefaultsKey)_\(safeServiceName)_\(safeResourceName)"
  }

  private static func environmentVariableDebugToken(registeredUserDefaultsKey: String) -> String? {
    let environment = ProcessInfo.processInfo.environment
    var envVariableValue = environment[debugTokenEnvKey]
    var firebaseEnvVariableValue = environment[firebaseDebugTokenEnvKey]

    if envVariableValue?.isEmpty == true {
      envVariableValue = nil
    }
    if firebaseEnvVariableValue?.isEmpty == true {
      firebaseEnvVariableValue = nil
    }

    if let envVal = envVariableValue, let firebaseVal = firebaseEnvVariableValue {
      let logMessage =
        "The environment variables \(debugTokenEnvKey) and \(firebaseDebugTokenEnvKey) are both set; using the debug token specified in \(debugTokenEnvKey) and ignoring the value of \(firebaseDebugTokenEnvKey)."
      GACAppCheckLog(
        code: .loggerAppCheckMessageDebugProviderFirebaseEnvironmentVariable,
        logLevel: .warning,
        message: logMessage as NSString
      )
      return envVal
    } else if let envVal = envVariableValue {
      let logMessage =
        "Using the debug token specified in the environment variable \(debugTokenEnvKey)."
      GACAppCheckLog(
        code: .loggerAppCheckMessageEnvironmentVariableDebugToken,
        logLevel: .debug,
        message: logMessage as NSString
      )
      return envVal
    } else if let firebaseVal = firebaseEnvVariableValue {
      let logMessage =
        "Using the debug token specified in the environment variable \(firebaseDebugTokenEnvKey)."
      GACAppCheckLog(
        code: .loggerAppCheckMessageDebugProviderFirebaseEnvironmentVariable,
        logLevel: .debug,
        message: logMessage as NSString
      )
      return firebaseVal
    } else {
      let isRegistered = GULUserDefaults.standard().bool(forKey: registeredUserDefaultsKey)
      if !isRegistered {
        let logMessage = "App Check debug token: '\(localDebugTokenStatic())'."
        GACAppCheckLog(
          code: .loggerAppCheckMessageLocalDebugToken,
          logLevel: .warning,
          message: logMessage as NSString
        )
      }
      return nil
    }
  }
}
