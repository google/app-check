import Foundation
#if canImport(DeviceCheck)
import DeviceCheck
#endif

@objc(AppCheckCoreDeviceCheckProvider)
public class AppCheckCoreDeviceCheckProvider: NSObject, AppCheckCoreProvider {
    
    private let apiService: AppCheckCoreDeviceCheckAPIServiceProtocol
    private let deviceTokenGenerator: AppCheckCoreDeviceCheckTokenGenerator
    private let backoffWrapper: AppCheckBackoffWrapperProtocol
    
    @objc
    public init(serviceName: String, resourceName: String, apiKey: String, requestHooks: [AppCheckCoreAPIRequestHook]?) {
        let session = URLSession(configuration: .ephemeral)
        let coreAPIService = AppCheckCoreAPIService(
            urlSession: session,
            baseURL: nil,
            apiKey: apiKey,
            requestHooks: requestHooks
        )
        let deviceCheckAPIService = AppCheckCoreDeviceCheckAPIService(
            apiService: coreAPIService,
            resourceName: resourceName
        )
        self.apiService = deviceCheckAPIService
        self.deviceTokenGenerator = DCDevice.current
        self.backoffWrapper = AppCheckCoreBackoffWrapper()
        super.init()
    }
    
    init(apiService: AppCheckCoreDeviceCheckAPIServiceProtocol,
         deviceTokenGenerator: AppCheckCoreDeviceCheckTokenGenerator,
         backoffWrapper: AppCheckBackoffWrapperProtocol) {
        self.apiService = apiService
        self.deviceTokenGenerator = deviceTokenGenerator
        self.backoffWrapper = backoffWrapper
        super.init()
    }

    // MARK: - AppCheckCoreProvider

    @objc
    public func getToken() async throws -> AppCheckCoreToken {
        return try await withCheckedThrowingContinuation { continuation in
            self.getToken { token, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let token = token {
                    continuation.resume(returning: token)
                } else {
                    let wrappedError = NSError(domain: AppCheckCoreErrorDomain, code: AppCheckCoreErrorCode.unknown.rawValue, userInfo: nil)
                    continuation.resume(throwing: wrappedError)
                }
            }
        }
    }

    public func getLimitedUseToken() async throws -> AppCheckCoreToken {
        return try await withCheckedThrowingContinuation { continuation in
            self.getLimitedUseToken { token, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let token = token {
                    continuation.resume(returning: token)
                } else {
                    let wrappedError = NSError(domain: AppCheckCoreErrorDomain, code: AppCheckCoreErrorCode.unknown.rawValue, userInfo: nil)
                    continuation.resume(throwing: wrappedError)
                }
            }
        }
    }

    public func getToken(completion handler: @escaping (AppCheckCoreToken?, Error?) -> Void) {
        Task {
            do {
                let token = try await getToken(limitedUse: false)
                handler(token, nil)
            } catch {
                handler(nil, error)
            }
        }
    }

    @objc
    public func getLimitedUseToken(completion handler: @escaping (AppCheckCoreToken?, Error?) -> Void) {
        Task {
            do {
                let token = try await getToken(limitedUse: true)
                handler(token, nil)
            } catch {
                handler(nil, error)
            }
        }
    }

    // MARK: - Internal

    private func getToken(limitedUse: Bool) async throws -> AppCheckCoreToken {
        let result = try await backoffWrapper.applyBackoffToOperation({ [weak self] () -> Any in
            guard let self = self else {
                throw AppCheckCoreErrorUtil.error(withFailureReason: "Self is nil")
            }
            return try await self.getTokenPromise(limitedUse: limitedUse)
        }, errorHandler: backoffWrapper.defaultAppCheckProviderErrorHandler())
        
        guard let token = result as? AppCheckCoreToken else {
            throw AppCheckCoreErrorUtil.error(withFailureReason: "Internal error: promise resolved with invalid type")
        }
        return token
    }
    
    private func getTokenPromise(limitedUse: Bool) async throws -> AppCheckCoreToken {
        guard deviceTokenGenerator.isSupported else {
            throw AppCheckCoreErrorUtil.unsupportedAttestationProvider("DeviceCheckProvider")
        }
        let deviceToken = try await deviceTokenGenerator.generateTokenAsync()
        return try await apiService.appCheckToken(deviceToken: deviceToken, limitedUse: limitedUse)
    }
}
