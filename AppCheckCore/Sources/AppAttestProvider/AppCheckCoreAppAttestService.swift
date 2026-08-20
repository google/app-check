import Foundation
import DeviceCheck

@objc(GACAppAttestService)
public protocol AppCheckCoreAppAttestService: NSObjectProtocol {
    @objc var isSupported: Bool { get }
    
    @objc(generateKeyWithCompletionHandler:)
    func generateKey(completionHandler: @escaping @Sendable (String?, Error?) -> Void)
    
    @objc(attestKey:clientDataHash:completionHandler:)
    func attestKey(_ keyId: String, clientDataHash: Data, completionHandler: @escaping @Sendable (Data?, Error?) -> Void)
    
    @objc(generateAssertion:clientDataHash:completionHandler:)
    func generateAssertion(_ keyId: String, clientDataHash: Data, completionHandler: @escaping @Sendable (Data?, Error?) -> Void)
}

@available(iOS 14.0, macOS 11.0, tvOS 15.0, watchOS 9.0, *)
extension DCAppAttestService: AppCheckCoreAppAttestService {}
