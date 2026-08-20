import Foundation

@objc(AppCheckCoreDeviceCheckAPIServiceProtocol)
protocol AppCheckCoreDeviceCheckAPIServiceProtocol: NSObjectProtocol {
    @objc func appCheckToken(deviceToken: Data, limitedUse: Bool) async throws -> AppCheckCoreToken
}

@objc(AppCheckCoreDeviceCheckAPIService)
class AppCheckCoreDeviceCheckAPIService: NSObject, AppCheckCoreDeviceCheckAPIServiceProtocol {
    private let apiService: AppCheckCoreAPIServiceProtocol
    private let resourceName: String

    @objc
    init(apiService: AppCheckCoreAPIServiceProtocol, resourceName: String) {
        self.apiService = apiService
        self.resourceName = resourceName
        super.init()
    }

    @objc
    func appCheckToken(deviceToken: Data, limitedUse: Bool) async throws -> AppCheckCoreToken {
        guard !deviceToken.isEmpty else {
            throw AppCheckCoreErrorUtil.error(withFailureReason: "DeviceCheck token must not be empty.")
        }

        let base64EncodedToken = deviceToken.base64EncodedString()
        let payload: [String: Any] = [
            "device_token": base64EncodedToken,
            "limited_use": limitedUse
        ]

        let payloadJSON: Data
        do {
            payloadJSON = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            throw AppCheckCoreErrorUtil.jsonSerializationError(error)
        }

        let urlString = "\(apiService.baseURL)/\(resourceName):exchangeDeviceCheckToken"
        guard let url = URL(string: urlString) else {
            throw AppCheckCoreErrorUtil.error(withFailureReason: "Invalid URL.")
        }

        let response = try await apiService.sendRequest(
            withURL: url,
            httpMethod: "POST",
            body: payloadJSON,
            additionalHeaders: ["Content-Type": "application/json"]
        )

        return try await apiService.appCheckToken(withAPIResponse: response)
    }
}
