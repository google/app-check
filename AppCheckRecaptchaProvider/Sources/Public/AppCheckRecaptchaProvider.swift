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
import RecaptchaInterop

/// Firebase App Check provider that verifies app integrity using the
/// [reCAPTCHA Enterprise](https://cloud.google.com/recaptcha/docs/instrument-ios-apps)
/// API. This class is available on all platforms for select OS versions. See
/// https://firebase.google.com/docs/ios/learn-more for more details.
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
  ///   - requestHooks: Hooks that will be invoked on requests through this service.
  // `@convention(block)` is required because the Swift compiler cannot automatically
  // bridge collections of closures (like an Array) to Objective-C blocks. This attribute
  // changes the closure's representation to match the Objective-C block heap layout.
  @objc public convenience init?(siteKey: String, resourceName: String, APIKey: String,
                                 requestHooks: [@convention(block) (NSMutableURLRequest) -> Void]? =
                                   nil) {
    self.init(
      siteKey: siteKey,
      resourceName: resourceName,
      APIKey: APIKey,
      requestHooks: requestHooks,
      actionName: Self.appCheckActionName
    )
  }

  @objc public convenience init?(siteKey: String, resourceName: String, APIKey: String,
                                 requestHooks: [@convention(block) (NSMutableURLRequest) -> Void]? =
                                   nil,
                                 actionName: String) {
    guard let sdk = RecaptchaEnterpriseSDKLoader(customAction: actionName) else {
      return nil
    }

    let backoffWrapper = _GACAppCheckBackoffWrapper()
    let tokenGenerator = RecaptchaTokenGenerator(
      siteKey: siteKey,
      recaptchaAction: sdk.action,
      recaptchaClass: sdk.recaptchaClass,
      backoffWrapper: backoffWrapper
    )

    let urlSession = URLSession(configuration: .ephemeral)
    let appCheckAPIService = _GACAppCheckAPIService(urlSession: urlSession,
                                                    baseURL: nil,
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

  @objc(getTokenWithCompletion:)
  public func getToken(completion handler: @escaping (AppCheckCoreToken?, (any Error)?) -> Void) {
    getToken(limitedUse: false)
      .then { token in
        handler(token, nil)
      }.catch { error in
        handler(nil, error)
      }
  }

  @objc(getLimitedUseTokenWithCompletion:)
  public func getLimitedUseToken(completion handler: @escaping (AppCheckCoreToken?, (any Error)?)
    -> Void) {
    getToken(limitedUse: true)
      .then { token in
        handler(token, nil)
      }.catch { error in
        handler(nil, error)
      }
  }

  private func getToken(limitedUse: Bool) -> Promise<AppCheckCoreToken> {
    guard let tokenGenerator else {
      return Promise(_GACAppCheckErrorUtil.missingRecaptchaSDKError())
    }
    return tokenGenerator.getRecaptchaToken()
      .then { recaptchaToken in
        self.apiService.appCheckToken(
          with: recaptchaToken,
          limitedUse: limitedUse
        )
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
