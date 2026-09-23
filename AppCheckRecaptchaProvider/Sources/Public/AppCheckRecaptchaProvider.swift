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
import RecaptchaInterop

/// Firebase App Check provider that verifies app integrity using the
/// [reCAPTCHA
/// Enterprise](https://firebase.google.com/docs/app-check/ios/recaptcha-enterprise-provider)
/// API. This class's platform and OS availability matches reCAPTCHA
/// Enterprise's.
@available(iOS 15.0, visionOS 1.0, *)
@available(macOS, unavailable)
@available(macCatalyst, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
@objc(GACRecaptchaProvider)
public final class AppCheckRecaptchaProvider: NSObject, AppCheckCoreProvider {
  // This action name should never change without coordination with the backend.
  private static let appCheckActionName = "app_check_ios"

  @objc public static func isSupported() -> Bool {
    return RecaptchaEnterpriseSDKLoader.isLinked
  }

  private let tokenGenerator: RecaptchaTokenGenerator?
  private let apiService: RecaptchaAPIService

  /// The default initializer.
  /// - Parameters:
  ///   - siteKey: The reCAPTCHA site key.
  ///   - resourceName: The name of the resource protected by App Check; for a Firebase App this is
  ///     "projects/{project_id}/apps/{app_id}".
  ///   - APIKey: The Google Cloud Platform API key.
  ///   - requestHooks: Hooks invoked on each outgoing request. From Swift, pass
  ///     `[AppCheckCoreAPIRequestHook]`. From Objective-C, pass an `NSArray` of blocks with the
  ///     signature `void (^)(NSMutableURLRequest *)`; the signature is not checked at compile
  ///     time and a mismatch will crash when the hook is invoked.
  ///
  ///     Typed `[Any]?` rather than `[AppCheckCoreAPIRequestHook]?` deliberately: Swift cannot
  ///     bridge an `NSArray` into a Swift `Array` whose element is a function type, so the typed
  ///     signature traps at runtime for any non-nil array passed from Objective-C. Do not
  ///     "simplify" this type — see PR #111.
  @objc public convenience init?(siteKey: String, resourceName: String, APIKey: String,
                                 requestHooks: [Any]? = nil) {
    self.init(
      siteKey: siteKey,
      resourceName: resourceName,
      APIKey: APIKey,
      requestHooks: requestHooks,
      actionName: Self.appCheckActionName
    )
  }

  /// - Parameter requestHooks: Hooks invoked on each outgoing request. From Swift, pass
  ///   `[AppCheckCoreAPIRequestHook]`. From Objective-C, pass an `NSArray` of blocks with the
  ///   signature `void (^)(NSMutableURLRequest *)`; the signature is not checked at compile
  ///   time and a mismatch will crash when the hook is invoked.
  ///
  ///   Typed `[Any]?` rather than `[AppCheckCoreAPIRequestHook]?` deliberately: Swift cannot
  ///   bridge an `NSArray` into a Swift `Array` whose element is a function type, so the typed
  ///   signature traps at runtime for any non-nil array passed from Objective-C. Do not
  ///   "simplify" this type — see PR #111.
  @objc public convenience init?(siteKey: String, resourceName: String, APIKey: String,
                                 requestHooks: [Any]? = nil,
                                 actionName: String) {
    guard let sdk = RecaptchaEnterpriseSDKLoader(customAction: actionName) else {
      return nil
    }

    let backoffWrapper = AppCheckCoreBackoffWrapper()
    let tokenGenerator = RecaptchaTokenGenerator(
      siteKey: siteKey,
      recaptchaAction: sdk.action,
      recaptchaClass: sdk.recaptchaClass,
      backoffWrapper: backoffWrapper
    )

    let urlSession = URLSession(configuration: .ephemeral)
    let appCheckAPIService = AppCheckCoreAPIService(urlSession: urlSession,
                                                    baseURL: nil as String?,
                                                    apiKey: APIKey,
                                                    requestHooks: requestHooks)
    let apiService = RecaptchaAPIService(
      apiService: appCheckAPIService,
      resourceName: resourceName
    )

    self.init(tokenGenerator: tokenGenerator, apiService: apiService)
  }

  init(tokenGenerator: RecaptchaTokenGenerator?,
       apiService: RecaptchaAPIService) {
    self.tokenGenerator = tokenGenerator
    self.apiService = apiService
    super.init()
  }

  public func getToken() async throws -> AppCheckCoreToken {
    return try await getToken(limitedUse: false)
  }

  public func getLimitedUseToken() async throws -> AppCheckCoreToken {
    return try await getToken(limitedUse: true)
  }

  @objc(getTokenWithCompletion:)
  public func getToken(completion handler: @escaping (AppCheckCoreToken?, (any Error)?) -> Void) {
    Task {
      do {
        let token = try await getToken(limitedUse: false)
        Self.deliverOnMainQueue(token, error: nil as Error?, to: handler)
      } catch {
        Self.deliverOnMainQueue(nil, error: error, to: handler)
      }
    }
  }

  @objc(getLimitedUseTokenWithCompletion:)
  public func getLimitedUseToken(completion handler: @escaping (AppCheckCoreToken?, (any Error)?)
    -> Void) {
    Task {
      do {
        let token = try await getToken(limitedUse: true)
        Self.deliverOnMainQueue(token, error: nil as Error?, to: handler)
      } catch {
        Self.deliverOnMainQueue(nil, error: error, to: handler)
      }
    }
  }

  private func getToken(limitedUse: Bool) async throws -> AppCheckCoreToken {
    guard let tokenGenerator else {
      throw AppCheckCoreErrorUtil.missingRecaptchaSDKError()
    }
    let recaptchaToken = try await tokenGenerator.getRecaptchaToken()
    return try await apiService.appCheckToken(
      with: recaptchaToken,
      limitedUse: limitedUse
    )
  }

  private static func deliverOnMainQueue<T: Sendable, E: Sendable>(_ result: T,
                                                                   error: E?,
                                                                   to completion: @escaping (T, E?)
                                                                     -> Void) {
    nonisolated(unsafe) let completion = completion
    DispatchQueue.main.async {
      completion(result, error)
    }
  }
}

private struct RecaptchaEnterpriseSDKLoader {
  // These symbols are specified in the RecaptchaEnterprise SDK.
  // See https://github.com/GoogleCloudPlatform/recaptcha-enterprise-mobile-sdk/blob/18.9.0/Sources/RecaptchaEnterprise/RecaptchaInteropBidings.swift
  private static let actionClass =
    NSClassFromString("RecaptchaEnterprise.RCAAction") as? RCAActionProtocol.Type
  private static let recaptchaClass =
    NSClassFromString("RecaptchaEnterprise.RCARecaptcha") as? RCARecaptchaProtocol.Type

  static var isLinked: Bool {
    return actionClass != nil && recaptchaClass != nil
  }

  let action: RCAActionProtocol
  let recaptchaClass: RCARecaptchaProtocol.Type

  init?(customAction: String) {
    guard let actionClass = Self.actionClass,
          let recaptchaClass = Self.recaptchaClass else {
      return nil
    }

    action = actionClass.init(customAction: customAction)
    self.recaptchaClass = recaptchaClass
  }
}
