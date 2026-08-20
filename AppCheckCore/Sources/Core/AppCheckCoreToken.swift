import Foundation

@objc(GACAppCheckToken)
@objcMembers
public class AppCheckCoreToken: NSObject, @unchecked Sendable {
    @objc public let token: String
    @objc public let expirationDate: Date
    @objc public let receivedAtDate: Date
    
    @objc public init(token: String, expirationDate: Date, receivedAtDate: Date) {
        self.token = token
        self.expirationDate = expirationDate
        self.receivedAtDate = receivedAtDate
        super.init()
    }
    
    @objc public convenience init(token: String, expirationDate: Date) {
        self.init(token: token, expirationDate: expirationDate, receivedAtDate: Date())
    }
}
