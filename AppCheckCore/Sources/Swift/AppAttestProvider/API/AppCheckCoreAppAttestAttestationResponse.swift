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

@objc(GACAppAttestAttestationResponse)
public final class AppCheckCoreAppAttestAttestationResponse: NSObject, Sendable {
  @objc public let artifact: Data
  @objc public let token: AppCheckCoreToken

  @objc public init(artifact: Data, token: AppCheckCoreToken) {
    self.artifact = artifact
    self.token = token
    super.init()
  }

  @objc(initWithResponseData:requestDate:error:)
  public convenience init(responseData: Data, requestDate: Date) throws {
    if responseData.isEmpty {
      throw AppCheckCoreErrorUtil
        .error(
          withFailureReason: "Failed to parse the initial handshake response. Empty server response body."
        )
    }

    let responseDict: [String: Any]
    do {
      responseDict = try JSONSerialization
        .jsonObject(with: responseData, options: []) as? [String: Any] ?? [:]
    } catch {
      throw AppCheckCoreErrorUtil.JSONSerializationError(error)
    }

    guard let artifactBase64String = responseDict["artifact"] as? String,
          let artifactData = Data(base64Encoded: artifactBase64String) else {
      throw AppCheckCoreErrorUtil.appAttestAttestationResponseError(withMissingField: "artifact")
    }

    guard let appCheckTokenDict = responseDict["appCheckToken"] as? [String: Any] else {
      throw AppCheckCoreErrorUtil
        .appAttestAttestationResponseError(withMissingField: "appCheckToken")
    }

    let appCheckToken = try AppCheckCoreToken(
      responseDict: appCheckTokenDict,
      requestDate: requestDate
    )

    self.init(artifact: artifactData, token: appCheckToken)
  }
}
