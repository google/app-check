import Foundation

private let kPlaceholderTokenValue = "eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ=="

@objc(GACAppCheckTokenResult)
@objcMembers
public class AppCheckCoreTokenResult: NSObject {
    @objc public let token: AppCheckCoreToken
    @objc public let error: Error?
    
    @objc public init(token: AppCheckCoreToken, error: Error?) {
        self.token = token
        self.error = error
        super.init()
    }
    
    @objc public convenience init(token: AppCheckCoreToken) {
        self.init(token: token, error: nil)
    }
    
    @objc public convenience init(error: Error) {
        let placeholder = AppCheckCoreTokenResult.placeholderToken()
        self.init(token: placeholder, error: error)
    }

    @objc public static func placeholderToken() -> AppCheckCoreToken {
        return AppCheckCoreToken(token: kPlaceholderTokenValue, expirationDate: Date.distantPast)
    }
}
