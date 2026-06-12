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

@objc(GACAppAttestAttestationState)
public enum AppCheckCoreAppAttestAttestationState: Int, Sendable {
  case unsupported
  case supportedInitial
  case keyGenerated
  case keyRegistered
}

@objc(GACAppAttestProviderState)
public final class AppCheckCoreAppAttestProviderState: NSObject, Sendable {
  @objc public let state: AppCheckCoreAppAttestAttestationState
  @objc public let appAttestUnsupportedError: Error?
  @objc public let appAttestKeyID: String?
  @objc public let attestationArtifact: Data?

  @objc public init(unsupportedWithError error: Error) {
    state = .unsupported
    appAttestUnsupportedError = error
    appAttestKeyID = nil
    attestationArtifact = nil
    super.init()
  }

  @objc public init(supportedInitialState: Void = ()) {
    state = .supportedInitial
    appAttestUnsupportedError = nil
    appAttestKeyID = nil
    attestationArtifact = nil
    super.init()
  }

  @objc public init(generatedKeyID keyID: String) {
    state = .keyGenerated
    appAttestUnsupportedError = nil
    appAttestKeyID = keyID
    attestationArtifact = nil
    super.init()
  }

  @objc public init(registeredKeyID keyID: String, artifact: Data) {
    state = .keyRegistered
    appAttestUnsupportedError = nil
    appAttestKeyID = keyID
    attestationArtifact = artifact
    super.init()
  }
}
