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

import CommonCrypto
import Foundation

@objc(GACAppCheckCryptoUtils)
public final class AppCheckCoreCryptoUtils: NSObject, Sendable {
  @objc(sha256HashFromData:) public static func sha256Hash(from dataToHash: Data) -> Data {
    var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    dataToHash.withUnsafeBytes {
      _ = CC_SHA256($0.baseAddress, CC_LONG(dataToHash.count), &hash)
    }
    return Data(hash)
  }
}
