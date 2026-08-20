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
        
        self.tokenRefresher.tokenRefreshHandler = { [weak self] completion in
            self?.periodicTokenRefresh(completion: completion)
        }
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
        
        self.tokenRefresher.tokenRefreshHandler = { [weak self] completion in
            self?.periodicTokenRefresh(completion: completion)
        }
    }

    private func periodicTokenRefresh(completion: @escaping AppCheckCoreTokenRefreshCompletion) {
        Task {
            do {
                let token = try await self.token(forcingRefresh: false)
                let refreshResult = AppCheckCoreTokenRefreshResult(status: .success,
                                                                 expirationDate: token.expirationDate,
                                                                 receivedAtDate: token.receivedAtDate)
                completion(refreshResult)
            } catch {
                let refreshResult = AppCheckCoreTokenRefreshResult(status: .failure,
                                                                 expirationDate: nil,
                                                                 receivedAtDate: nil)
                completion(refreshResult)
            }
        }
    }


    private var ongoingTask: Task<AppCheckCoreToken, Error>?
    private let lock = NSLock()
    private let kTokenExpirationThreshold: TimeInterval = 5 * 60 // 5 minutes

    public func token(forcingRefresh: Bool) async throws -> AppCheckCoreToken {
        lock.lock()
        // If not forcing refresh and there is an ongoing task, return it
        if let ongoing = ongoingTask {
            lock.unlock()
            return try await ongoing.value
        }

        // Create a new task and store it
        let task = Task { () -> AppCheckCoreToken in
            defer {
                self.lock.lock()
                self.ongoingTask = nil
                self.lock.unlock()
            }
            return try await self.createRetrieveOrRefreshToken(forcingRefresh: forcingRefresh)
        }
        self.ongoingTask = task
        lock.unlock()

        return try await task.value
    }

    private func createRetrieveOrRefreshToken(forcingRefresh: Bool) async throws -> AppCheckCoreToken {
        do {
            let token = try await getCachedValidToken(forcingRefresh: forcingRefresh)
            return token
        } catch {
            return try await refreshToken()
        }
    }

    private func getCachedValidToken(forcingRefresh: Bool) async throws -> AppCheckCoreToken {
        if forcingRefresh {
            throw AppCheckCoreErrorUtil.cachedTokenNotFound()
        }

        guard let token = try await self.storage.getToken() else {
            throw AppCheckCoreErrorUtil.cachedTokenNotFound()
        }

        let isTokenExpiredOrExpiresSoon = token.expirationDate.timeIntervalSinceNow < kTokenExpirationThreshold
        if isTokenExpiredOrExpiresSoon {
            throw AppCheckCoreErrorUtil.cachedTokenExpired()
        }

        return token
    }

    private func refreshToken() async throws -> AppCheckCoreToken {
        let token: AppCheckCoreToken = try await withCheckedThrowingContinuation { continuation in
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

        _ = try await self.storage.setToken(token)

        let refreshResult = AppCheckCoreTokenRefreshResult(status: .success,
                                                         expirationDate: token.expirationDate,
                                                         receivedAtDate: token.receivedAtDate)
        self.tokenRefresher.updateWithRefreshResult(refreshResult)
        
        if let tokenDelegate = self.tokenDelegate {
            tokenDelegate.tokenDidUpdate(token, serviceName: self.serviceName)
        }
        
        return token
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
