import Foundation

@objc(GACAppCheckToken)
@objcMembers
public class AppCheckCoreToken: NSObject, @unchecked Sendable {
  public let token: String
  public let expirationDate: Date
  public let receivedAtDate: Date

  public init(token: String, expirationDate: Date, receivedAtDate: Date) {
    self.token = token
    self.expirationDate = expirationDate
    self.receivedAtDate = receivedAtDate
    super.init()
  }

  public convenience init(token: String, expirationDate: Date) {
    self.init(token: token, expirationDate: expirationDate, receivedAtDate: Date())
  }
}
