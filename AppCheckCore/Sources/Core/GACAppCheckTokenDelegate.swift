import Foundation

@objc(GACAppCheckTokenDelegate)
public protocol AppCheckCoreTokenDelegate: NSObjectProtocol {
    @objc(tokenDidUpdate:serviceName:)
    func tokenDidUpdate(_ token: AppCheckCoreToken, serviceName: String)
}
