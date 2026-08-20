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

private let kResponseFieldAppCheckTokenDict = "appCheckToken"
private let kResponseFieldArtifact = "artifact"

@objc(GACAppAttestAttestationResponse)
public class AppCheckCoreAppAttestAttestationResponse: NSObject {
  @objc public let artifact: Data
  @objc public let token: AppCheckCoreToken

  @objc(initWithArtifact:token:)
  public init(artifact: Data, token: AppCheckCoreToken) {
    self.artifact = artifact
    self.token = token
    super.init()
  }

  @objc(initWithResponseData:requestDate:error:)
  public init(responseData: Data, requestDate: Date) throws {
    if responseData.isEmpty {
      throw AppCheckCoreErrorUtil
        .error(
          withFailureReason: "Failed to parse the initial handshake response. Empty server response body."
        )
    }

    let responseDict = try JSONSerialization
      .jsonObject(with: responseData, options: []) as? [String: Any]

    guard let responseDict = responseDict else {
      throw AppCheckCoreErrorUtil.jsonSerializationError(NSError(
        domain: NSCocoaErrorDomain,
        code: 0,
        userInfo: nil
      ))
    }

    guard let artifactBase64String = responseDict[kResponseFieldArtifact] as? String,
          let artifactData = Data(base64Encoded: artifactBase64String) else {
      throw AppCheckCoreErrorUtil
        .appAttestAttestationResponseError(withMissingField: kResponseFieldArtifact)
    }

    guard let appCheckTokenDict = responseDict[kResponseFieldAppCheckTokenDict] as? [String: Any]
    else {
      throw AppCheckCoreErrorUtil
        .appAttestAttestationResponseError(withMissingField: kResponseFieldAppCheckTokenDict)
    }

    // Assuming AppCheckCoreToken has this initializer available in Swift now.
    // If not, we use the method that handles API response.
    // We'll throw if it fails to initialize.
    // Assuming there is a throwing initializer or we just use `init(responseDict:requestDate:)`
    let appCheckToken = try AppCheckCoreToken(
      responseDict: appCheckTokenDict,
      requestDate: requestDate
    )

    artifact = artifactData
    token = appCheckToken
    super.init()
  }
}
