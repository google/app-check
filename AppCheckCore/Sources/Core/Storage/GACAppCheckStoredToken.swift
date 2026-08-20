import Foundation

@objc(GACAppCheckStoredToken)
@objcMembers
public class GACAppCheckStoredToken: NSObject, NSSecureCoding {
    private let kTokenKey = "token"
    private let kExpirationDateKey = "expirationDate"
    private let kReceivedAtDateKey = "receivedAtDate"
    private let kStorageVersionKey = "storageVersion"

    private let kStorageVersion: Int = 2

    @objc public var token: String?
    @objc public var expirationDate: Date?
    @objc public var receivedAtDate: Date?

    @objc public var storageVersion: Int {
        return kStorageVersion
    }

    public static var supportsSecureCoding: Bool {
        return true
    }
    
    public override init() {
        super.init()
    }

    public func encode(with coder: NSCoder) {
        coder.encode(token, forKey: kTokenKey)
        coder.encode(expirationDate, forKey: kExpirationDateKey)
        coder.encode(receivedAtDate, forKey: kReceivedAtDateKey)
        coder.encode(storageVersion, forKey: kStorageVersionKey)
    }

    public required init?(coder: NSCoder) {
        super.init()
        let decodedStorageVersion = coder.decodeInteger(forKey: kStorageVersionKey)
        if decodedStorageVersion > kStorageVersion {
            // TODO: Log a message.
        }

        token = coder.decodeObject(of: NSString.self, forKey: kTokenKey) as String?
        expirationDate = coder.decodeObject(of: NSDate.self, forKey: kExpirationDateKey) as Date?
        receivedAtDate = coder.decodeObject(of: NSDate.self, forKey: kReceivedAtDateKey) as Date?
    }
}

extension GACAppCheckStoredToken {
    @objc public func update(with token: AppCheckCoreToken) {
        self.token = token.token
        self.expirationDate = token.expirationDate
        self.receivedAtDate = token.receivedAtDate
    }

    @objc public func appCheckToken() -> AppCheckCoreToken? {
        guard let token = self.token,
              let expirationDate = self.expirationDate,
              let receivedAtDate = self.receivedAtDate else {
            return nil
        }
        return AppCheckCoreToken(token: token, expirationDate: expirationDate, receivedAtDate: receivedAtDate)
    }
}
