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

final class RecaptchaEnterpriseTokenGenerator {
  private let siteKey: String
  private let recaptchaAction: RCAActionProtocol

  private let recaptchaClient: Promise<RCARecaptchaClientProtocol>

  init(siteKey: String, recaptchaAction: RCAActionProtocol,
       recaptchaClass: RCARecaptchaProtocol.Type? = nil) {
    self.siteKey = siteKey
    self.recaptchaAction = recaptchaAction
    recaptchaClient = Promise<RCARecaptchaClientProtocol> { fulfill, reject in
      let recaptcha = recaptchaClass ??
        NSClassFromString("RecaptchaEnterprise.RCARecaptcha") as? RCARecaptchaProtocol.Type
      guard let recaptcha else {
        throw GACAppCheckErrorUtil.unsupportedAttestationProvider("RecaptchaEnterprise")
      }
      recaptcha.fetchClient(withSiteKey: siteKey) { client, error in
        if let client {
          fulfill(client)
        } else {
          reject(error ?? GACAppCheckErrorUtil
            .error(withFailureReason: "Failed to fetch Recaptcha client"))
        }
      }
    }
  }

  // TODO(ncooke3): Investigate whether we need a backoff mechanism.
  func getRecaptchaToken() -> Promise<String> {
    recaptchaClient.then { client in
      Promise<String> { fulfill, reject in
        client.execute(withAction: self.recaptchaAction) { token, error in
          if let token = token {
            fulfill(token)
          } else {
            reject(error ?? GACAppCheckErrorUtil
              .error(withFailureReason: "Failed to execute Recaptcha action"))
          }
        }
      }
    }
  }
}
