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

private let kKeyIDKey = "keyID"
private let kArtifactKey = "artifact"
private let kStorageVersionKey = "storageVersion"

private let kStorageVersion = 1

@objc(GACAppAttestStoredArtifact)
public class AppCheckCoreAppAttestStoredArtifact: NSObject, NSSecureCoding {
  @objc public let keyID: String
  @objc public let artifact: Data

  @objc public var storageVersion: Int {
    return kStorageVersion
  }

  @objc(initWithKeyID:artifact:)
  public init(keyID: String, artifact: Data) {
    self.keyID = keyID
    self.artifact = artifact
    super.init()
  }

  public static var supportsSecureCoding: Bool {
    return true
  }

  public func encode(with coder: NSCoder) {
    coder.encode(keyID, forKey: kKeyIDKey)
    coder.encode(artifact, forKey: kArtifactKey)
    coder.encode(storageVersion, forKey: kStorageVersionKey)
  }

  public required init?(coder: NSCoder) {
    let storageVersion = coder.decodeInteger(forKey: kStorageVersionKey)

    if storageVersion < kStorageVersion {
      // Handle migration here when new versions are added
    }

    guard let decodedKeyID = coder.decodeObject(of: NSString.self, forKey: kKeyIDKey) as String?,
          !decodedKeyID.isEmpty else {
      return nil
    }

    guard let decodedArtifact = coder.decodeObject(of: NSData.self, forKey: kArtifactKey) as Data?,
          !decodedArtifact.isEmpty else {
      return nil
    }

    keyID = decodedKeyID
    artifact = decodedArtifact
    super.init()
  }
}
