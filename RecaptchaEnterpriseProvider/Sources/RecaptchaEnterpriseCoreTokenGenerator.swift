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
  private let action: RCAActionProtocol

  private let recaptchaPromise: Promise<RCARecaptchaClientProtocol>

  init(siteKey: String, action: RCAActionProtocol) {
    self.siteKey = siteKey
    self.action = action
    recaptchaPromise = Promise<RCARecaptchaClientProtocol> { fulfill, reject in
      guard let recaptcha =
        NSClassFromString("RecaptchaEnterprise.RCARecaptcha") as? RCARecaptchaProtocol
          .Type else {
        throw GACAppCheckErrorUtil.unsupportedAttestationProvider("RecaptchaEnterprise")
      }
      recaptcha.fetchClient(withSiteKey: siteKey) { client, error in
        if let client = client {
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
    recaptchaPromise.then { client in
      Promise<String> { fulfill, reject in
        client.execute(withAction: self.action) { token, error in
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
