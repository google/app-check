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

#if COCOAPODS
  import GoogleUtilities
#else
  import GoogleUtilities_UserDefaults
#endif

private let kDebugTokenEnvKey = "AppCheckDebugToken"
private let kFirebaseDebugTokenEnvKey = "FIRAAppCheckDebugToken"

/// The source of the debug token used by an `AppCheckCoreDebugProvider`.
///
/// New sources may be added in future versions; handle unknown values with
/// `@unknown default` in Swift or `default:` in Objective-C.
#if hasAttribute(nonexhaustive)
  @nonexhaustive
#endif
@objc(GACAppCheckDebugTokenSource)
public enum AppCheckCoreDebugTokenSource: Int {
  /// The token stored locally by the provider (generated on first use).
  case local = 0

  /// The `AppCheckDebugToken` or `FIRAAppCheckDebugToken` environment variable.
  case environmentVariable = 1

  /// The debug token passed to the provider's initializer.
  case provided = 2
}

@objc(GACAppCheckDebugProvider)
public class AppCheckCoreDebugProvider: NSObject, AppCheckCoreProvider {
  /// Storage key for the debug token in UserDefaults.
  /// Internal scope exists for testing purposes.
  /// Do not rename: retains the "GAC" prefix for compatibility with existing stored data from v11
  /// or lower.
  static let debugTokenUserDefaultsKey = "GACAppCheckDebugToken"

  /// Storage key prefix for registered debug tokens in UserDefaults.
  /// Internal scope exists for testing purposes.
  /// Do not rename: retains the "GAC" prefix for compatibility with existing stored data from v11
  /// or lower.
  static let debugTokenRegisteredUserDefaultsKeyPrefix = "GACAppCheckDebugTokenRegistered"

  private let apiService: AppCheckCoreDebugProviderAPIServiceProtocol
  private let debugTokenEnvValue: String?

  /// A debug token supplied by the caller at initialization, if any.
  ///
  /// Used when no debug token environment variable is set, and preferred over the locally
  /// generated token.
  private let providedDebugToken: String?

  private let registeredUserDefaultsKey: String

  /// The source of the debug token returned by `currentDebugToken()`.
  ///
  /// Determined at initialization: an environment variable takes priority over a provided token,
  /// which takes priority over the locally stored token.
  @objc public let debugTokenSource: AppCheckCoreDebugTokenSource

  // Internal initializer
  init(apiService: AppCheckCoreDebugProviderAPIServiceProtocol,
       serviceName: String,
       resourceName: String,
       environment: [String: String],
       debugToken: String? = nil) {
    self.apiService = apiService
    let registeredUserDefaultsKey = Self.registeredUserDefaultsKey(
      forServiceName: serviceName,
      resourceName: resourceName
    )
    self.registeredUserDefaultsKey = registeredUserDefaultsKey
    let debugTokenEnvValue = Self.environmentVariableDebugToken(environment: environment)
    self.debugTokenEnvValue = debugTokenEnvValue
    let providedDebugToken = debugToken.flatMap { $0.isEmpty ? nil : $0 }
    self.providedDebugToken = providedDebugToken
    if debugTokenEnvValue != nil {
      debugTokenSource = .environmentVariable
    } else if providedDebugToken != nil {
      debugTokenSource = .provided
    } else {
      debugTokenSource = .local
    }
    super.init()

    switch debugTokenSource {
    case .local:
      Self.logLocalDebugTokenIfNotRegistered(registeredUserDefaultsKey: registeredUserDefaultsKey)
    case .provided:
      AppCheckCoreLogger.log(
        code: .providedDebugToken,
        logLevel: .debug,
        message: """
        Using the debug token provided at initialization; the \(kDebugTokenEnvKey) and \
        \(kFirebaseDebugTokenEnvKey) environment variables are not set.
        """
      )
    case .environmentVariable:
      break // The environment variable debug token was already logged.
    }
  }

  /// Creates a debug provider that uses the environment variable, stored, or newly generated
  /// debug token.
  ///
  /// - Parameters:
  ///   - serviceName: The name of the service (e.g. the Firebase app name) using the provider.
  ///   - resourceName: The App Check resource name, `projects/{project}/apps/{app}`.
  ///   - baseURL: The App Check API base URL, or `nil` for the default.
  ///   - apiKey: The API key used to call the App Check API.
  ///   - requestHooks: Hooks invoked on each outgoing request. From Swift, pass
  ///     `[AppCheckCoreAPIRequestHook]`. From Objective-C, pass an `NSArray` of blocks with the
  ///     signature `void (^)(NSMutableURLRequest *)`; the signature is not checked at compile
  ///     time and a mismatch will crash when the hook is invoked.
  ///
  ///     Typed `[Any]?` rather than `[AppCheckCoreAPIRequestHook]?` deliberately: Swift cannot
  ///     bridge an `NSArray` into a Swift `Array` whose element is a function type, so the typed
  ///     signature traps at runtime for any non-nil array passed from Objective-C. Do not
  ///     "simplify" this type — see PR #111.
  @objc(initWithServiceName:resourceName:baseURL:APIKey:requestHooks:)
  public convenience init(serviceName: String,
                          resourceName: String,
                          baseURL: String?,
                          apiKey: String,
                          requestHooks: [Any]?) {
    self.init(serviceName: serviceName,
              resourceName: resourceName,
              baseURL: baseURL,
              apiKey: apiKey,
              requestHooks: requestHooks,
              debugToken: nil)
  }

  /// Creates a debug provider that prefers the given debug token over the locally stored or
  /// generated one.
  ///
  /// - Parameters:
  ///   - serviceName: The name of the service (e.g. the Firebase app name) using the provider.
  ///   - resourceName: The App Check resource name, `projects/{project}/apps/{app}`.
  ///   - baseURL: The App Check API base URL, or `nil` for the default.
  ///   - apiKey: The API key used to call the App Check API.
  ///   - requestHooks: See `init(serviceName:resourceName:baseURL:apiKey:requestHooks:)`.
  ///   - debugToken: A debug token resolved by the caller, for example one provisioned by the
  ///     Firebase CLI and read from the host machine. The token is used when neither the
  ///     `AppCheckDebugToken` nor the `FIRAAppCheckDebugToken` environment variable is set, and
  ///     takes priority over a debug token previously stored or newly generated by this provider.
  ///     Pass `nil` or an empty string to fall back to the stored or generated token.
  @objc(initWithServiceName:resourceName:baseURL:APIKey:requestHooks:debugToken:)
  public convenience init(serviceName: String,
                          resourceName: String,
                          baseURL: String?,
                          apiKey: String,
                          requestHooks: [Any]?,
                          debugToken: String?) {
    self.init(serviceName: serviceName,
              resourceName: resourceName,
              baseURL: baseURL,
              apiKey: apiKey,
              requestHooks: requestHooks,
              environment: ProcessInfo.processInfo.environment,
              debugToken: debugToken)
  }

  // Additional internal initializer for testing
  convenience init(serviceName: String,
                   resourceName: String,
                   baseURL: String?,
                   apiKey: String,
                   requestHooks: [Any]?,
                   environment: [String: String],
                   debugToken: String? = nil) {
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
              environment: environment,
              debugToken: debugToken)
  }

  @objc public func localDebugToken() -> String {
    return Self.localDebugToken()
  }

  @objc public func currentDebugToken() -> String {
    return debugTokenEnvValue ?? providedDebugToken ?? Self.localDebugToken()
  }

  /// Whether `currentDebugToken()` falls through to the locally stored or generated token.
  private var usesLocalDebugToken: Bool {
    return debugTokenSource == .local
  }

  // MARK: - AppCheckCoreProvider

  public func getToken() async throws -> AppCheckCoreToken {
    return try await getToken(limitedUse: false)
  }

  public func getLimitedUseToken() async throws -> AppCheckCoreToken {
    return try await getToken(limitedUse: true)
  }

  @objc(getTokenWithCompletion:)
  public func getToken(completion handler: @escaping (AppCheckCoreToken?, Error?) -> Void) {
    getToken(limitedUse: false, completion: handler)
  }

  @objc(getLimitedUseTokenWithCompletion:)
  public func getLimitedUseToken(completion handler: @escaping (AppCheckCoreToken?, Error?)
    -> Void) {
    getToken(limitedUse: true, completion: handler)
  }

  // MARK: - Internal

  private func getToken(limitedUse: Bool) async throws -> AppCheckCoreToken {
    do {
      let token = try await apiService.appCheckToken(
        debugToken: currentDebugToken(),
        limitedUse: limitedUse
      )
      // Only the locally generated token is tracked as registered: if an environment variable or
      // provided token is later removed, the local token's registration instructions must still
      // be logged.
      if usesLocalDebugToken {
        GULUserDefaults.standard().setObject(true, forKey: registeredUserDefaultsKey)
      }
      return token
    } catch {
      let logMessage = "Failed to exchange debug token to app check token: \(error)"
      AppCheckCoreLogger.log(
        code: .debugProviderFailedExchange,
        logLevel: .debug,
        message: logMessage
      )

      let nsError = error as NSError
      let isServerReachable = nsError.domain != AppCheckCoreErrorDomain ||
        nsError.code != AppCheckCoreErrorCode.serverUnreachable.rawValue
      // As on success, only the local token's registration is tracked: a rejected environment
      // variable or provided token says nothing about whether the local token is registered.
      if usesLocalDebugToken, isServerReachable {
        GULUserDefaults.standard().removeObject(forKey: registeredUserDefaultsKey)
      }
      throw error
    }
  }

  private func getToken(limitedUse: Bool,
                        completion handler: @escaping (AppCheckCoreToken?, Error?) -> Void) {
    Task {
      do {
        let token = try await getToken(limitedUse: limitedUse)
        AppCheckCore.deliverOnMainQueue(token, error: nil as Error?, to: handler)
      } catch {
        AppCheckCore.deliverOnMainQueue(nil, error: error, to: handler)
      }
    }
  }

  private static func localDebugToken() -> String {
    if let token = GULUserDefaults.standard().string(forKey: debugTokenUserDefaultsKey) {
      return token
    } else {
      let token = UUID().uuidString
      GULUserDefaults.standard().setObject(token, forKey: debugTokenUserDefaultsKey)
      return token
    }
  }

  /// Internal scope exists for testing purposes.
  static func registeredUserDefaultsKey(forServiceName serviceName: String,
                                        resourceName: String) -> String {
    let safeServiceName = serviceName.isEmpty ? "default" : serviceName
    var safeResourceName = resourceName.replacingOccurrences(of: "/", with: "_")
    if safeResourceName.isEmpty {
      safeResourceName = "default"
    }
    return "\(debugTokenRegisteredUserDefaultsKeyPrefix)_\(safeServiceName)_\(safeResourceName)"
  }

  private static func environmentVariableDebugToken(environment: [String: String]) -> String? {
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
      return nil
    }
  }

  /// Logs the locally stored debug token unless it has previously been exchanged successfully.
  ///
  /// As a side effect, generates and persists the local token if none is stored yet.
  private static func logLocalDebugTokenIfNotRegistered(registeredUserDefaultsKey: String) {
    let isRegistered = GULUserDefaults.standard().bool(forKey: registeredUserDefaultsKey)
    if !isRegistered {
      let message = "App Check debug token: '\(Self.localDebugToken())'."
      AppCheckCoreLogger.log(code: .localDebugToken, logLevel: .warning, message: message)
    }
  }
}
