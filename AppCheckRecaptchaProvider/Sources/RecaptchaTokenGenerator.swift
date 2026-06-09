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
import FBLPromises
import Foundation
import Promises
import RecaptchaInterop

@available(iOS 15.0, visionOS 1.0, *)
@available(macOS, unavailable)
@available(macCatalyst, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
final class RecaptchaTokenGenerator {
  // Corresponds to RecaptchaErrorNetworkError. These codes are not in the interop.
  // See https://docs.cloud.google.com/recaptcha/docs/reference/ios/client/api/Enums/RecaptchaErrorCode.html#recaptchaerrornetworkerror
  static let networkErrorCode = 1
  // Corresponds to RecaptchaErrorCodeInternalError. These codes are not in the interop.
  // See https://docs.cloud.google.com/recaptcha/docs/reference/ios/client/api/Enums/RecaptchaErrorCode.html#recaptchaerrorcodeinternalerror
  static let internalErrorCode = 100

  private let recaptchaAction: RCAActionProtocol

  private let recaptchaClient: Promise<RCARecaptchaClientProtocol>

  private let backoffWrapper: _GACAppCheckBackoffWrapperProtocol

  init(siteKey: String, recaptchaAction: RCAActionProtocol,
       recaptchaClass: RCARecaptchaProtocol.Type,
       backoffWrapper: _GACAppCheckBackoffWrapperProtocol) {
    self.recaptchaAction = recaptchaAction
    self.backoffWrapper = backoffWrapper
    // Note: `fetchClient` is called only once and its result (including
    // failure) is cached. reCAPTCHA engineers have confirmed that
    // `fetchClient` handles transient errors internally and only fails on
    // permanent integration errors (e.g., invalid site key). Therefore,
    // retrying `fetchClient` on failure is unnecessary and not recommended.
    recaptchaClient = Promise<RCARecaptchaClientProtocol> { fulfill, reject in
      recaptchaClass.fetchClient(withSiteKey: siteKey) { client, error in
        if let client {
          fulfill(client)
        } else {
          reject(error ?? _GACAppCheckErrorUtil
            .error(withFailureReason: "Failed to fetch Recaptcha client"))
        }
      }
    }
  }

  func getRecaptchaToken() -> Promise<String> {
    return recaptchaClient.then { client in
      let operationProvider: GACAppCheckBackoffOperationProvider = {
        let swiftPromise = Promise<AnyObject> { fulfill, reject in
          client.execute(withAction: self.recaptchaAction) { token, error in
            if let token {
              fulfill(token as AnyObject)
            } else {
              reject(self.mapRecaptchaError(error))
            }
          }
        }
        return swiftPromise.asObjCPromise()
      }

      let errorHandler: GACAppCheckBackoffErrorHandler = { error in
        let nsError = error as NSError
        if nsError.domain == AppCheckCoreErrorDomain && nsError.code == AppCheckCoreErrorCode
          .serverUnreachable.rawValue {
          return .typeExponential
        }
        return .typeNone
      }

      let fblPromise = self.backoffWrapper.applyBackoff(
        toOperation: operationProvider,
        errorHandler: errorHandler
      )

      return Promise<AnyObject>(fblPromise).then { result in
        guard let token = result as? String else {
          throw _GACAppCheckErrorUtil
            .error(
              withFailureReason: "Unexpected result type from reCAPTCHA token exchange: \(type(of: result)). Expected String."
            )
        }
        return token
      }
    }
  }

  private func mapRecaptchaError(_ error: Error?) -> Error {
    guard let error = error as NSError? else {
      return _GACAppCheckErrorUtil.error(withFailureReason: "Failed to execute Recaptcha action")
    }

    // Map RecaptchaErrorNetworkError and RecaptchaErrorCodeInternalError.
    // See https://docs.cloud.google.com/recaptcha/docs/reference/ios/client/api/Enums/RecaptchaErrorCode.html
    if error.code == Self.networkErrorCode || error.code == Self.internalErrorCode {
      return _GACAppCheckErrorUtil.apiError(withNetworkError: error)
    }

    // Preserve underlying error for others
    var userInfo: [String: Any] = [NSUnderlyingErrorKey: error]
    if let reason = error.userInfo[NSLocalizedFailureReasonErrorKey] {
      userInfo[NSLocalizedFailureReasonErrorKey] = reason
    }
    return NSError(
      domain: AppCheckCoreErrorDomain,
      code: AppCheckCoreErrorCode.unknown.rawValue,
      userInfo: userInfo
    )
  }
}
