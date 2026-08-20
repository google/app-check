import Foundation

public typealias AppCheckCoreTokenHandler = (AppCheckCoreTokenResult) -> Void

@objc(GACAppCheck)
@objcMembers
public class AppCheckCore: NSObject {
    @objc public let serviceName: String
    @objc public let appCheckProvider: AppCheckCoreProvider
    @objc public let settings: AppCheckCoreSettingsProtocol
    @objc public weak var tokenDelegate: AppCheckCoreTokenDelegate?
    // Placeholders for Storage and TokenRefresher until migrated
    // private let storage: Any
    // private let tokenRefresher: Any

    @objc public init(serviceName: String,
                      resourceName: String,
                      appCheckProvider: AppCheckCoreProvider,
                      settings: AppCheckCoreSettingsProtocol,
                      tokenDelegate: AppCheckCoreTokenDelegate?,
                      keychainAccessGroup: String?) {
        self.serviceName = serviceName
        self.appCheckProvider = appCheckProvider
        self.settings = settings
        self.tokenDelegate = tokenDelegate
        super.init()
    }

    public func token(forcingRefresh: Bool) async throws -> AppCheckCoreToken {
        return try await withCheckedThrowingContinuation { continuation in
            // Basic async adaptation, bypassing Promises
            if forcingRefresh {
                self.appCheckProvider.getToken { token, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let token = token {
                        continuation.resume(returning: token)
                    } else {
                        continuation.resume(throwing: AppCheckCoreErrorCode.unknown)
                    }
                }
            } else {
                // Return cached token implementation placeholder
                self.appCheckProvider.getToken { token, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let token = token {
                        continuation.resume(returning: token)
                    } else {
                        continuation.resume(throwing: AppCheckCoreErrorCode.unknown)
                    }
                }
            }
        }
    }

    @objc(tokenForcingRefresh:completion:)
    public func tokenForcingRefresh(_ forcingRefresh: Bool, completion: @escaping AppCheckCoreTokenHandler) {
        Task {
            do {
                let token = try await self.token(forcingRefresh: forcingRefresh)
                completion(AppCheckCoreTokenResult(token: token))
            } catch {
                completion(AppCheckCoreTokenResult(error: error))
            }
        }
    }

    public func limitedUseToken() async throws -> AppCheckCoreToken {
        return try await withCheckedThrowingContinuation { continuation in
            self.appCheckProvider.getLimitedUseToken { token, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let token = token {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: AppCheckCoreErrorCode.unknown)
                }
            }
        }
    }

    @objc(limitedUseTokenWithCompletion:)
    public func limitedUseToken(completion: @escaping AppCheckCoreTokenHandler) {
        Task {
            do {
                let token = try await self.limitedUseToken()
                completion(AppCheckCoreTokenResult(token: token))
            } catch {
                completion(AppCheckCoreTokenResult(error: error))
            }
        }
    }
}
