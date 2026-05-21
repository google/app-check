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
@objc(GACRecaptchaEnterpriseProvider)
public final class AppCheckRecaptchaEnterpriseProvider: NSObject, AppCheckCoreProvider {
  // This action name should never change without coordination with the backend.
  private static let appCheckActionName = "app_check_ios"

  private let tokenGenerator: RecaptchaEnterpriseTokenGenerator?
  private let apiService: RecaptchaEnterpriseAPIService

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
  @objc public convenience init(siteKey: String, resourceName: String, APIKey: String,
                                requestHooks: [@convention(block) (NSMutableURLRequest) -> Void]? =
                                  nil) {
    let tokenGenerator: RecaptchaEnterpriseTokenGenerator?

    if let sdk = RecaptchaEnterpriseSDK(customAction: Self.appCheckActionName) {
      let backoffWrapper = GACAppCheckBackoffWrapper()

      tokenGenerator = RecaptchaEnterpriseTokenGenerator(
        siteKey: siteKey,
        recaptchaAction: sdk.action,
        recaptchaClass: sdk.recaptchaClass,
        backoffWrapper: backoffWrapper
      )
    } else {
      // Fail fast in Debug (-Onone) builds to alert the developer.
      // In Release (-O) builds, a nil tokenGenerator falls back to returning an error in getToken.
      assertionFailure(missingRecaptchaSDKMessage)
      tokenGenerator = nil
    }

    let urlSession = URLSession(configuration: .ephemeral)
    let appCheckAPIService = AppCheckCoreAPIService(urlSession: urlSession,
                                                    baseURL: nil,
                                                    apiKey: APIKey,
                                                    requestHooks: requestHooks)
    let apiService = RecaptchaEnterpriseAPIService(
      apiService: appCheckAPIService,
      resourceName: resourceName
    )

    self.init(tokenGenerator: tokenGenerator, apiService: apiService)
  }

  init(tokenGenerator: RecaptchaEnterpriseTokenGenerator?,
       apiService: RecaptchaEnterpriseAPIService) {
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
      return Promise(GACAppCheckErrorUtil.missingRecaptchaSDKError())
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

private struct RecaptchaEnterpriseSDK {
  // This symbol is specified in the RecaptchaEnterprise SDK.
  // See https://github.com/GoogleCloudPlatform/recaptcha-enterprise-mobile-sdk/blob/18.9.0/Sources/RecaptchaEnterprise/RecaptchaInteropBidings.swift
  private static let recaptchaActionClassName = "RecaptchaEnterprise.RCAAction"
  // This symbol is specified in the RecaptchaEnterprise SDK.
  // See https://github.com/GoogleCloudPlatform/recaptcha-enterprise-mobile-sdk/blob/18.9.0/Sources/RecaptchaEnterprise/RecaptchaInteropBidings.swift
  private static let recaptchaClassName = "RecaptchaEnterprise.RCARecaptcha"

  let action: RCAActionProtocol
  let recaptchaClass: RCARecaptchaProtocol.Type

  init?(customAction: String) {
    let actionObj: AnyClass? = NSClassFromString(Self.recaptchaActionClassName)
    let recaptchaObj: AnyClass? = NSClassFromString(Self.recaptchaClassName)

    guard let actionClass = actionObj as? RCAActionProtocol.Type,
          let recaptchaClass = recaptchaObj as? RCARecaptchaProtocol.Type else {
      return nil
    }

    action = actionClass.init(customAction: customAction)
    self.recaptchaClass = recaptchaClass
  }
}
