import Foundation

private let kPlaceholderTokenValue = "eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ=="

@objc(GACAppCheckTokenResult)
@objcMembers
public class AppCheckCoreTokenResult: NSObject {
  public let token: AppCheckCoreToken
  public let error: Error?

  public init(token: AppCheckCoreToken, error: Error?) {
    self.token = token
    self.error = error
    super.init()
  }

  public convenience init(token: AppCheckCoreToken) {
    self.init(token: token, error: nil)
  }

  public convenience init(error: Error) {
    let placeholder = AppCheckCoreTokenResult.placeholderToken()
    self.init(token: placeholder, error: error)
  }

  public static func placeholderToken() -> AppCheckCoreToken {
    return AppCheckCoreToken(token: kPlaceholderTokenValue, expirationDate: Date.distantPast)
  }
}
