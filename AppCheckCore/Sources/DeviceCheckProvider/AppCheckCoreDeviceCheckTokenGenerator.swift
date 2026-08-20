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

@objc(AppCheckCoreDeviceCheckTokenGenerator)
public protocol AppCheckCoreDeviceCheckTokenGenerator: NSObjectProtocol {
  @objc var isSupported: Bool { get }

  @objc(generateTokenWithCompletionHandler:)
  func generateToken(completionHandler: @escaping @Sendable (Data?, Error?) -> Void)
}

extension AppCheckCoreDeviceCheckTokenGenerator {
  func generateTokenAsync() async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
      self.generateToken { token, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else if let token = token {
          continuation.resume(returning: token)
        } else {
          let err = NSError(
            domain: "AppCheckCoreDeviceCheckTokenGenerator",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "No token and no error."]
          )
          continuation.resume(throwing: err)
        }
      }
    }
  }
}
