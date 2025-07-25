import Foundation
import AppCheckShared
import FBLPromises

fileprivate enum Constants {
  static let contentTypeKey = "Content-Type"
  static let jsonContentType = "application/json"
  static let deviceTokenField = "device_token"
  static let limitedUseField = "limited_use"
}

@objc(GARecaptchaEnterpriseAPIService)
final class RecaptchaEnterpriseAPIService: NSObject{
    private var APIService: AppCheckCoreAPIServiceProtocol?=nil
    private let resourceName: String
    
    init(APIService: AppCheckCoreAPIServiceProtocol, resourceName: String){
       self.APIService = APIService
        self.resourceName = resourceName
        super.init()
    }
    
    func appCheckToken(
        withRecaptchaToken recaptchaToken: Data,
        limitedUse: Bool
    )async throws->AppCheckCoreToken{
        let URLString = "\(APIService!.baseURL)/\(resourceName):exchangeDeviceCheckToken"
        guard let url = URL(string: URLString)else{
            throw GACAppCheckErrorUtil.error(withFailureReason: "Invalid URL")
        }
        
        let httpBody=try await httpBody(withRecaptchaToken: recaptchaToken, limitedUse: limitedUse)
        let response = try await APIService!.sendRequest(
                    url: url,
                    httpMethod: "POST",
                    body: httpBody,
                    additionalHeaders: [Constants.contentTypeKey: Constants.jsonContentType]
                )
        
        let token = try await APIService.appCheckToken(withAPIResponse: response)
               return token
    }
//    
    private func httpBody(withRecaptchaToken recaptchaToken: Data, limitedUse: Bool) async throws -> Data {
            guard !recaptchaToken.isEmpty else {
                throw GACAppCheckErrorUtil.error(withFailureReason: "Recaptcha token must not be empty.")
            }

            return try await withCheckedThrowingContinuation { continuation in
                backgroundQueue().async {
                    let base64EncodedToken = recaptchaToken.base64EncodedString()
                    let payload: [String: Any] = [
                        Constants.deviceTokenField: base64EncodedToken,
                        Constants.limitedUseField: limitedUse
                    ]
                    do {
                        let payloadJSON = try JSONSerialization.data(withJSONObject: payload, options: [])
                        continuation.resume(returning: payloadJSON)
                    } catch {
                        continuation.resume(throwing: GACAppCheckErrorUtil.jsonSerializationError(error))
                    }
                }
            }
        }
    
    private func backgroundQueue()->DispatchQueue{
        return DispatchQueue.global(qos: .utility)
    }
}
