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

@objc(GACAppAttestStoredArtifact)
public final class AppCheckCoreAppAttestStoredArtifact: NSObject, NSSecureCoding {
  @objc public let keyID: String
  @objc public let artifact: Data
  @objc public let storageVersion: Int

  private static let kStorageVersion = 1
  private static let kKeyIDKey = "keyID"
  private static let kArtifactKey = "artifact"
  private static let kStorageVersionKey = "storageVersion"

  @objc public init(keyID: String, artifact: Data) {
    self.keyID = keyID
    self.artifact = artifact
    storageVersion = Self.kStorageVersion
    super.init()
  }

  // MARK: - NSSecureCoding

  public static var supportsSecureCoding: Bool {
    return true
  }

  public func encode(with coder: NSCoder) {
    coder.encode(keyID, forKey: Self.kKeyIDKey)
    coder.encode(artifact, forKey: Self.kArtifactKey)
    coder.encode(storageVersion, forKey: Self.kStorageVersionKey)
  }

  public init?(coder: NSCoder) {
    let storageVersion = coder.decodeInteger(forKey: Self.kStorageVersionKey)
    if storageVersion < Self.kStorageVersion {
      // Handle migration if needed
    }

    guard let keyID = coder.decodeObject(of: NSString.self, forKey: Self.kKeyIDKey) as? String,
          !keyID.isEmpty else {
      return nil
    }

    guard let artifact = coder.decodeObject(of: NSData.self, forKey: Self.kArtifactKey) as? Data,
          !artifact.isEmpty else {
      return nil
    }

    self.keyID = keyID
    self.artifact = artifact
    self.storageVersion = storageVersion
  }
}
