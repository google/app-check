import Foundation

@objc(GACAppCheckTokenRefreshStatus)
public enum AppCheckCoreTokenRefreshStatus: Int {
  case never = 0
  case success = 1
  case failure = 2
}

@objc(GACAppCheckTokenRefreshResult)
@objcMembers
public class AppCheckCoreTokenRefreshResult: NSObject {
  public let status: AppCheckCoreTokenRefreshStatus
  public let tokenExpirationDate: Date?
  public let tokenReceivedAtDate: Date?

  public init(status: AppCheckCoreTokenRefreshStatus,
              expirationDate tokenExpirationDate: Date?,
              receivedAtDate tokenReceivedAtDate: Date?) {
    self.status = status
    self.tokenExpirationDate = tokenExpirationDate
    self.tokenReceivedAtDate = tokenReceivedAtDate
    super.init()
  }

  public convenience init(statusNever: ()) {
    self.init(status: .never, expirationDate: nil, receivedAtDate: nil)
  }

  public convenience init(statusFailure: ()) {
    self.init(status: .failure, expirationDate: nil, receivedAtDate: nil)
  }

  public convenience init(statusSuccessAndExpirationDate tokenExpirationDate: Date,
                          receivedAtDate tokenReceivedAtDate: Date) {
    self.init(
      status: .success,
      expirationDate: tokenExpirationDate,
      receivedAtDate: tokenReceivedAtDate
    )
  }
}
