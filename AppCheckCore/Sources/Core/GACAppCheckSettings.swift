import Foundation

@objc(GACAppCheckSettingsProtocol)
public protocol AppCheckCoreSettingsProtocol: NSObjectProtocol {
    @objc var isTokenAutoRefreshEnabled: Bool { get set }
}

@objc(GACAppCheckSettings)
@objcMembers
public class GACAppCheckSettings: NSObject, AppCheckCoreSettingsProtocol {
    @objc public var isTokenAutoRefreshEnabled: Bool = false
    
    public override init() {
        super.init()
    }
}
