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

@available(iOS 15.0, visionOS 1.0, *)
@available(macOS, unavailable)
@available(macCatalyst, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
final class RecaptchaTokenGenerator {
  static let networkErrorCode = 1
  static let internalErrorCode = 100

  private let recaptchaAction: RCAActionProtocol

  private let recaptchaClientTask: Task<RCARecaptchaClientProtocol, Error>

  private let backoffWrapper: AppCheckBackoffWrapperProtocol

  init(siteKey: String, recaptchaAction: RCAActionProtocol,
       recaptchaClass: RCARecaptchaProtocol.Type,
       backoffWrapper: AppCheckBackoffWrapperProtocol) {
    self.recaptchaAction = recaptchaAction
    self.backoffWrapper = backoffWrapper
    
    recaptchaClientTask = Task {
      try await withCheckedThrowingContinuation { continuation in
        recaptchaClass.fetchClient(withSiteKey: siteKey) { client, error in
          if let client {
            continuation.resume(returning: client)
          } else {
            continuation.resume(throwing: error ?? AppCheckCoreErrorUtil
              .error(withFailureReason: "Failed to fetch Recaptcha client"))
          }
        }
      }
    }
  }

  func getRecaptchaToken() async throws -> String {
    let client = try await recaptchaClientTask.value
    
    let operationProvider: () async throws -> Any = {
      try await withCheckedThrowingContinuation { continuation in
        let recaptchaAction = self.recaptchaAction
        client.execute(withAction: recaptchaAction) { token, error in
          if let token {
            continuation.resume(returning: token as Any)
          } else {
            continuation.resume(throwing: Self.mapRecaptchaError(error))
          }
        }
      }
    }

    let errorHandler: (Error) -> AppCheckBackoffType = { error in
      let nsError = error as NSError
      if nsError.domain == AppCheckCoreErrorDomain && nsError.code == AppCheckCoreErrorCode
        .serverUnreachable.rawValue {
        return .exponential
      }
      return .none
    }

    let result = try await self.backoffWrapper.applyBackoffToOperation(
       operationProvider,
      errorHandler: errorHandler
    )

    guard let token = result as? String else {
      throw AppCheckCoreErrorUtil
        .error(
          withFailureReason: "Unexpected result type from reCAPTCHA token exchange: \\(type(of: result)). Expected String."
        )
    }
    return token
  }

  private static func mapRecaptchaError(_ error: Error?) -> Error {
    guard let error = error as NSError? else {
      return AppCheckCoreErrorUtil.error(withFailureReason: "Failed to execute Recaptcha action")
    }

    if error.code == Self.networkErrorCode || error.code == Self.internalErrorCode {
      return AppCheckCoreErrorUtil.apiError(withNetworkError: error)
    }

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
