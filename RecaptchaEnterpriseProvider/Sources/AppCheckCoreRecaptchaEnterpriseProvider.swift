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

@objc(GACRecaptchaEnterpriseProvider)
public final class AppCheckCoreRecaptchaEnterpriseProvider: NSObject, AppCheckCoreProvider {
  private static let recaptchaActionClassName = "RecaptchaEnterprise.RCAAction"
  private static let appCheckActionName = "app_check_ios"
  private static let providerName = "RecaptchaEnterprise"

  private let tokenGenerator: RecaptchaEnterpriseTokenGenerator?
  private let apiService: RecaptchaEnterpriseAPIService

  @objc public convenience init(siteKey: String, resourceName: String, APIKey: String,
                                requestHooks: [@convention(block) (NSMutableURLRequest) -> Void]? =
                                  nil) {
    let recaptchaAction =
      NSClassFromString(Self.recaptchaActionClassName) as? RCAActionProtocol.Type
    if recaptchaAction == nil {
      // Fail fast in Debug (-Onone) builds to alert the developer.
      // In Release (-O) builds, this falls back to returning an error in getToken.
      assertionFailure(
        "The reCAPTCHA Enterprise SDK is not linked. See https://cloud.google.com/recaptcha/docs/instrument-ios-apps#prepare-environment"
      )
    }
    let action = recaptchaAction?.init(customAction: Self.appCheckActionName)

    let tokenGenerator: RecaptchaEnterpriseTokenGenerator?
    if let action {
      let backoffWrapper = GACAppCheckBackoffWrapper()
      tokenGenerator = RecaptchaEnterpriseTokenGenerator(
        siteKey: siteKey,
        recaptchaAction: action,
        backoffWrapper: backoffWrapper
      )
    } else {
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
          withRecaptchaToken: recaptchaToken,
          limitedUse: limitedUse
        )
      }
  }
}
