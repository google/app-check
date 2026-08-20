import Foundation

public typealias AppCheckCoreAPIRequestHook = @convention(block) (NSMutableURLRequest) -> Void

@objc(GACAppCheckProvider)
public protocol AppCheckCoreProvider: NSObjectProtocol {
    @objc(getTokenWithCompletion:)
    func getToken(completion: @escaping (AppCheckCoreToken?, Error?) -> Void)

    @objc(getLimitedUseTokenWithCompletion:)
    func getLimitedUseToken(completion: @escaping (AppCheckCoreToken?, Error?) -> Void)
}
