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

import DeviceCheck
import Foundation

@objc(GACAppAttestService)
public protocol AppCheckCoreAppAttestService: NSObjectProtocol {
  @objc var isSupported: Bool { get }

  @objc(generateKeyWithCompletionHandler:)
  func generateKey(completionHandler: @escaping @Sendable (String?, Error?) -> Void)

  @objc(attestKey:clientDataHash:completionHandler:)
  func attestKey(_ keyId: String, clientDataHash: Data,
                 completionHandler: @escaping @Sendable (Data?, Error?) -> Void)

  @objc(generateAssertion:clientDataHash:completionHandler:)
  func generateAssertion(_ keyId: String, clientDataHash: Data,
                         completionHandler: @escaping @Sendable (Data?, Error?) -> Void)
}

@available(iOS 14.0, macOS 11.0, tvOS 15.0, watchOS 9.0, *)
extension DCAppAttestService: AppCheckCoreAppAttestService {}
