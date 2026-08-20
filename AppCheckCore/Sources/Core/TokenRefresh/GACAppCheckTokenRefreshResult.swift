import Foundation

@objc(GACAppCheckTokenRefreshStatus)
public enum GACAppCheckTokenRefreshStatus: Int {
    case never = 0
    case success = 1
    case failure = 2
}

@objc(GACAppCheckTokenRefreshResult)
@objcMembers
public class GACAppCheckTokenRefreshResult: NSObject {
    @objc public let status: GACAppCheckTokenRefreshStatus
    @objc public let tokenExpirationDate: Date?
    @objc public let tokenReceivedAtDate: Date?

    @objc public init(status: GACAppCheckTokenRefreshStatus,
                      expirationDate tokenExpirationDate: Date?,
                      receivedAtDate tokenReceivedAtDate: Date?) {
        self.status = status
        self.tokenExpirationDate = tokenExpirationDate
        self.tokenReceivedAtDate = tokenReceivedAtDate
        super.init()
    }

    @objc public convenience init(statusNever: ()) {
        self.init(status: .never, expirationDate: nil, receivedAtDate: nil)
    }

    @objc public convenience init(statusFailure: ()) {
        self.init(status: .failure, expirationDate: nil, receivedAtDate: nil)
    }

    @objc public convenience init(statusSuccessAndExpirationDate tokenExpirationDate: Date,
                                  receivedAtDate tokenReceivedAtDate: Date) {
        self.init(status: .success, expirationDate: tokenExpirationDate, receivedAtDate: tokenReceivedAtDate)
    }
}
