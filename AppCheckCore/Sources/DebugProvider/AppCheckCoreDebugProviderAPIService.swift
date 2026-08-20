import Foundation

@objc(AppCheckCoreDebugProviderAPIServiceProtocol)
protocol AppCheckCoreDebugProviderAPIServiceProtocol: NSObjectProtocol {
    @objc func appCheckToken(debugToken: String, limitedUse: Bool) async throws -> AppCheckCoreToken
}

@objc(AppCheckCoreDebugProviderAPIService)
class AppCheckCoreDebugProviderAPIService: NSObject, AppCheckCoreDebugProviderAPIServiceProtocol {
    private let apiService: AppCheckCoreAPIServiceProtocol
    private let resourceName: String
    
    private static let contentTypeKey = "Content-Type"
    private static let jsonContentType = "application/json"
    private static let debugTokenField = "debug_token"
    private static let limitedUseField = "limited_use"
    
    @objc init(apiService: AppCheckCoreAPIServiceProtocol, resourceName: String) {
        self.apiService = apiService
        self.resourceName = resourceName
        super.init()
    }
    
    @objc func appCheckToken(debugToken: String, limitedUse: Bool) async throws -> AppCheckCoreToken {
        let urlString = "\(apiService.baseURL)/\(resourceName):exchangeDebugToken"
        guard let url = URL(string: urlString) else {
            throw AppCheckCoreErrorUtil.error(withFailureReason: "Invalid URL: \(urlString)")
        }
        
        let httpBody = try self.httpBody(debugToken: debugToken, limitedUse: limitedUse)
        
        let response = try await apiService.sendRequest(withURL: url,
                                                        httpMethod: "POST",
                                                        body: httpBody,
                                                        additionalHeaders: [Self.contentTypeKey: Self.jsonContentType])
        
        return try await apiService.appCheckToken(withAPIResponse: response)
    }
    
    private func httpBody(debugToken: String, limitedUse: Bool) throws -> Data {
        if debugToken.isEmpty {
            throw AppCheckCoreErrorUtil.error(withFailureReason: "Debug token must not be empty.")
        }
        
        let payload: [String: Any] = [
            Self.debugTokenField: debugToken,
            Self.limitedUseField: limitedUse
        ]
        
        do {
            return try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            throw AppCheckCoreErrorUtil.jsonSerializationError(error)
        }
    }
}
