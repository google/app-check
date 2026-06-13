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

@objc(GACAppCheckProvider)
public protocol AppCheckCoreProvider: NSObjectProtocol {
  @objc(getTokenWithCompletion:)
  func getToken(completion handler: @escaping (AppCheckCoreToken?, NSError?) -> Void)

  @objc(getLimitedUseTokenWithCompletion:)
  func getLimitedUseToken(completion handler: @escaping (AppCheckCoreToken?, NSError?) -> Void)
}

public extension AppCheckCoreProvider {
  func getToken() async throws -> AppCheckCoreToken {
    try await withCheckedThrowingContinuation { continuation in
      self.getToken { token, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else if let token = token {
          continuation.resume(returning: token)
        } else {
          continuation
            .resume(throwing: AppCheckCoreErrorUtil
              .error(withFailureReason: "Provider returned nil token and nil error."))
        }
      }
    }
  }

  func getLimitedUseToken() async throws -> AppCheckCoreToken {
    try await withCheckedThrowingContinuation { continuation in
      self.getLimitedUseToken { token, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else if let token = token {
          continuation.resume(returning: token)
        } else {
          continuation
            .resume(throwing: AppCheckCoreErrorUtil
              .error(withFailureReason: "Provider returned nil token and nil error."))
        }
      }
    }
  }
}
