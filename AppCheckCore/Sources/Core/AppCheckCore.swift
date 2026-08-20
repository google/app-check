import Foundation

public typealias AppCheckCoreTokenHandler = (AppCheckCoreTokenResult) -> Void

@objc(GACAppCheck)
@objcMembers
public class AppCheckCore: NSObject {
    @objc public let serviceName: String
    @objc public let appCheckProvider: AppCheckCoreProvider
    @objc public let settings: AppCheckCoreSettingsProtocol
    @objc public weak var tokenDelegate: AppCheckCoreTokenDelegate?
    @objc public let storage: AppCheckCoreStorageProtocol
    @objc public let tokenRefresher: AppCheckCoreTokenRefresherProtocol

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
        let tokenKey = "app_check_token.\(serviceName).\(resourceName)"
        self.storage = AppCheckCoreStorage(tokenKey: tokenKey, accessGroup: keychainAccessGroup)
        let refreshResult = AppCheckCoreTokenRefreshResult(status: .never, expirationDate: nil, receivedAtDate: nil)
        self.tokenRefresher = AppCheckCoreTokenRefresher(refreshResult: refreshResult, settings: settings)
        super.init()
    }
    
    @objc internal init(serviceName: String,
                        appCheckProvider: AppCheckCoreProvider,
                        storage: AppCheckCoreStorageProtocol,
                        tokenRefresher: AppCheckCoreTokenRefresherProtocol,
                        settings: AppCheckCoreSettingsProtocol,
                        tokenDelegate: AppCheckCoreTokenDelegate?) {
        self.serviceName = serviceName
        self.appCheckProvider = appCheckProvider
        self.storage = storage
        self.tokenRefresher = tokenRefresher
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
    public func token(forcingRefresh: Bool, completion: @escaping AppCheckCoreTokenHandler) {
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
