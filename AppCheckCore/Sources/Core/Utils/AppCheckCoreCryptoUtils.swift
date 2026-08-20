import Foundation
import CommonCrypto

@objc(GACAppCheckCryptoUtils)
@objcMembers
public class AppCheckCoreCryptoUtils: NSObject {
    @objc(sha256HashFromData:)
    public static func sha256Hash(from dataToHash: Data) -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        dataToHash.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(dataToHash.count), &digest)
        }
        return Data(digest)
    }
}
