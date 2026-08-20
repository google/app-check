import Foundation

@objc(GACDeviceCheckAPIServiceProtocol)
protocol GACDeviceCheckAPIServiceProtocol: NSObjectProtocol {
    @objc func appCheckToken(deviceToken: Data, limitedUse: Bool) async throws -> GACAppCheckToken
}

@objc(GACDeviceCheckAPIService)
class GACDeviceCheckAPIService: NSObject, GACDeviceCheckAPIServiceProtocol {
    private let apiService: _GACAppCheckAPIServiceProtocol
    private let resourceName: String

    @objc
    init(apiService: _GACAppCheckAPIServiceProtocol, resourceName: String) {
        self.apiService = apiService
        self.resourceName = resourceName
        super.init()
    }

    @objc
    func appCheckToken(deviceToken: Data, limitedUse: Bool) async throws -> GACAppCheckToken {
        guard !deviceToken.isEmpty else {
            throw _GACAppCheckErrorUtil.error(withFailureReason: "DeviceCheck token must not be empty.")
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
            throw _GACAppCheckErrorUtil.jsonSerializationError(error)
        }

        let urlString = "\(apiService.baseURL)/\(resourceName):exchangeDeviceCheckToken"
        guard let url = URL(string: urlString) else {
            throw _GACAppCheckErrorUtil.error(withFailureReason: "Invalid URL.")
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
