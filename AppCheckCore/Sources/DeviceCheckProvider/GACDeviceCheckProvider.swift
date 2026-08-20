import Foundation
#if canImport(DeviceCheck)
import DeviceCheck
#endif

@objc(GACDeviceCheckProvider)
public class AppCheckCoreDeviceCheckProvider: NSObject, GACAppCheckProvider {
    
    private let apiService: GACDeviceCheckAPIServiceProtocol
    private let deviceTokenGenerator: GACDeviceCheckTokenGenerator
    private let backoffWrapper: _GACAppCheckBackoffWrapperProtocol
    
    @objc
    public init(serviceName: String, resourceName: String, apiKey: String, requestHooks: [GACAppCheckAPIRequestHook]?) {
        let session = URLSession(configuration: .ephemeral)
        let coreAPIService = _GACAppCheckAPIService(
            urlSession: session,
            baseURL: nil,
            apiKey: apiKey,
            requestHooks: requestHooks
        )
        let deviceCheckAPIService = GACDeviceCheckAPIService(
            apiService: coreAPIService,
            resourceName: resourceName
        )
        self.apiService = deviceCheckAPIService
        self.deviceTokenGenerator = DCDevice.current
        self.backoffWrapper = _GACAppCheckBackoffWrapper()
        super.init()
    }
    
    init(apiService: GACDeviceCheckAPIServiceProtocol,
         deviceTokenGenerator: GACDeviceCheckTokenGenerator,
         backoffWrapper: _GACAppCheckBackoffWrapperProtocol) {
        self.apiService = apiService
        self.deviceTokenGenerator = deviceTokenGenerator
        self.backoffWrapper = backoffWrapper
        super.init()
    }

    // MARK: - GACAppCheckProvider

    @objc
    public func getToken(completion handler: @escaping (GACAppCheckToken?, Error?) -> Void) {
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
    public func getLimitedUseToken(completion handler: @escaping (GACAppCheckToken?, Error?) -> Void) {
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

    private func getToken(limitedUse: Bool) async throws -> GACAppCheckToken {
        let result = try await backoffWrapper.applyBackoffToOperation({ [weak self] () -> Any in
            guard let self = self else {
                throw _GACAppCheckErrorUtil.error(withFailureReason: "Self is nil")
            }
            return try await self.getTokenPromise(limitedUse: limitedUse)
        }, errorHandler: backoffWrapper.defaultAppCheckProviderErrorHandler())
        
        guard let token = result as? GACAppCheckToken else {
            throw _GACAppCheckErrorUtil.error(withFailureReason: "Internal error: promise resolved with invalid type")
        }
        return token
    }
    
    private func getTokenPromise(limitedUse: Bool) async throws -> GACAppCheckToken {
        guard deviceTokenGenerator.isSupported else {
            throw _GACAppCheckErrorUtil.unsupportedAttestationProvider("DeviceCheckProvider")
        }
        let deviceToken = try await deviceTokenGenerator.generateTokenAsync()
        return try await apiService.appCheckToken(deviceToken: deviceToken, limitedUse: limitedUse)
    }
}
