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
                    let err = NSError(domain: "AppCheckCoreDeviceCheckTokenGenerator", code: 0, userInfo: [NSLocalizedDescriptionKey: "No token and no error."])
                    continuation.resume(throwing: err)
                }
            }
        }
    }
}
