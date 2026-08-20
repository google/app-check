import Foundation

@objc(GACAppCheckSettingsProtocol)
public protocol AppCheckCoreSettingsProtocol: NSObjectProtocol {
  @objc var isTokenAutoRefreshEnabled: Bool { get set }
}

@objc(GACAppCheckSettings)
@objcMembers
public class AppCheckCoreSettings: NSObject, AppCheckCoreSettingsProtocol {
  public var isTokenAutoRefreshEnabled: Bool = false

  override public init() {
    super.init()
  }
}
