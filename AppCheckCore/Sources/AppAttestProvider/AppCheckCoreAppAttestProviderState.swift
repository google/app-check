/*
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

@objc(GACAppAttestAttestationState)
public enum AppCheckCoreAppAttestAttestationState: Int {
  case unsupported
  case supportedInitial
  case keyGenerated
  case keyRegistered
}

@objc(GACAppAttestProviderState)
@objcMembers
public class AppCheckCoreAppAttestProviderState: NSObject {
  public let state: AppCheckCoreAppAttestAttestationState
  public let appAttestUnsupportedError: Error?
  public let appAttestKeyID: String?
  public let attestationArtifact: Data?

  @objc(initUnsupportedWithError:)
  public init(unsupportedWithError error: Error) {
    self.state = .unsupported
    self.appAttestUnsupportedError = error
    self.appAttestKeyID = nil
    self.attestationArtifact = nil
    super.init()
  }

  @objc(initWithSupportedInitialState)
  public init(supportedInitialState: Void = ()) {
    self.state = .supportedInitial
    self.appAttestUnsupportedError = nil
    self.appAttestKeyID = nil
    self.attestationArtifact = nil
    super.init()
  }

  @objc(initWithGeneratedKeyID:)
  public init(generatedKeyID keyID: String) {
    self.state = .keyGenerated
    self.appAttestKeyID = keyID
    self.appAttestUnsupportedError = nil
    self.attestationArtifact = nil
    super.init()
  }

  @objc(initWithRegisteredKeyID:artifact:)
  public init(registeredKeyID keyID: String, artifact: Data) {
    self.state = .keyRegistered
    self.appAttestKeyID = keyID
    self.attestationArtifact = artifact
    self.appAttestUnsupportedError = nil
    super.init()
  }
}
