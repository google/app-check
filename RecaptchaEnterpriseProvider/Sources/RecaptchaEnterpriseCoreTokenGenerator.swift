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

final class RecaptchaEnterpriseTokenGenerator {
  // Corresponds to RecaptchaErrorNetworkError. These codes are not in the interop.
  // See https://docs.cloud.google.com/recaptcha/docs/reference/ios/client/api/Enums/RecaptchaErrorCode.html#recaptchaerrornetworkerror
  static let networkErrorCode = 1
  // Corresponds to RecaptchaErrorCodeInternalError. These codes are not in the interop.
  // See https://docs.cloud.google.com/recaptcha/docs/reference/ios/client/api/Enums/RecaptchaErrorCode.html#recaptchaerrorcodeinternalerror
  static let internalErrorCode = 100

  private let siteKey: String
  private let recaptchaAction: RCAActionProtocol

  private let recaptchaClient: Promise<RCARecaptchaClientProtocol>

  private let backoffWrapper: GACAppCheckBackoffWrapperProtocol?

  init(siteKey: String, recaptchaAction: RCAActionProtocol,
       recaptchaClass: RCARecaptchaProtocol.Type,
       backoffWrapper: GACAppCheckBackoffWrapperProtocol? = nil) {
    self.siteKey = siteKey
    self.recaptchaAction = recaptchaAction
    self.backoffWrapper = backoffWrapper
    recaptchaClient = Promise<RCARecaptchaClientProtocol> { fulfill, reject in
      recaptchaClass.fetchClient(withSiteKey: siteKey) { client, error in
        if let client {
          fulfill(client)
        } else {
          reject(error ?? GACAppCheckErrorUtil
            .error(withFailureReason: "Failed to fetch Recaptcha client"))
        }
      }
    }
  }

  func getRecaptchaToken() -> Promise<String> {
    guard let backoffWrapper else {
      return getRecaptchaTokenNoBackoff()
    }

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

      let fblPromise = backoffWrapper.applyBackoff(
        toOperation: operationProvider,
        errorHandler: errorHandler
      )

      return Promise<AnyObject>(fblPromise).then { result in
        // Force cast is safe because the operation provider above returns a String
        // (the token) fulfilled as AnyObject to satisfy FBLPromise interop.
        result as! String
      }
    }
  }

  // This fallback path is useful for testing when we don't want to involve the backoff wrapper.
  private func getRecaptchaTokenNoBackoff() -> Promise<String> {
    recaptchaClient.then { client in
      Promise<String> { fulfill, reject in
        client.execute(withAction: self.recaptchaAction) { token, error in
          if let token {
            fulfill(token)
          } else {
            reject(self.mapRecaptchaError(error))
          }
        }
      }
    }
  }

  private func mapRecaptchaError(_ error: Error?) -> Error {
    guard let error = error as NSError? else {
      return GACAppCheckErrorUtil.error(withFailureReason: "Failed to execute Recaptcha action")
    }

    // Map RecaptchaErrorNetworkError and RecaptchaErrorCodeInternalError.
    // See https://docs.cloud.google.com/recaptcha/docs/reference/ios/client/api/Enums/RecaptchaErrorCode.html
    if error.code == Self.networkErrorCode || error.code == Self.internalErrorCode {
      return GACAppCheckErrorUtil.apiError(withNetworkError: error)
    }

    // Preserve underlying error for others
    let userInfo: [String: Any] = [
      NSUnderlyingErrorKey: error,
      NSLocalizedFailureReasonErrorKey: error.userInfo[NSLocalizedFailureReasonErrorKey] as Any,
    ]
    return NSError(
      domain: AppCheckCoreErrorDomain,
      code: AppCheckCoreErrorCode.unknown.rawValue,
      userInfo: userInfo
    )
  }
}
