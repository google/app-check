// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import AppCheckCoreProvider
import Promises

fileprivate enum Constants {
  static let contentTypeKey = "Content-Type"
  static let jsonContentType = "application/json"
  static let recaptchaTokenField = "recaptcha_enterprise_token"
  static let limitedUseField = "limited_use"
}

@objc(GARecaptchaEnterpriseAPIService)
final class RecaptchaEnterpriseAPIService: NSObject{
    private var APIService: AppCheckCoreAPIServiceProtocol?=nil
    private let resourceName: String
    
    init(APIService: AppCheckCoreAPIServiceProtocol, resourceName: String){
       self.APIService = APIService
        self.resourceName = resourceName
    }
    
    func appCheckToken(
        withRecaptchaToken recaptchaToken: String,
        limitedUse: Bool
    )->Promise<AppCheckCoreToken>{
        let urlString="\(APIService!.baseURL)/\(resourceName):exchangeRecaptchaEnterpriseToken"
        guard let url=URL(string: urlString) else{
            return Promise(GACAppCheckErrorUtil.error(withFailureReason: "Invalid URL string"))
        }
        
        return httpBody(withRecaptchaToken: recaptchaToken, limitedUse: limitedUse)
            .then{httpBody in
             Promise<GACURLSessionDataResponse>(   self.APIService!.sendRequest(with:url,
                                             httpMethod: "POST",
                                             body:httpBody,
                                             additionalHeaders: [Constants.contentTypeKey: Constants.jsonContentType]))
            }.then{response in
               Promise<AppCheckCoreToken>( self.APIService!.appCheckToken(withAPIResponse: response))}
    }
    
    private func httpBody(withRecaptchaToken recaptchaToken: String, limitedUse: Bool)->Promise<Data>{
        guard !recaptchaToken.isEmpty else{
            return Promise(GACAppCheckErrorUtil.error(withFailureReason:"Recaptcha token cannot be empty"))
        }
        
        return Promise(on:backgroundQueue()){
            
            let payload: [String: Any] = [
                Constants.recaptchaTokenField: recaptchaToken,
                Constants.limitedUseField: limitedUse
            ]
            
            do{
                let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
                return jsonData
            }catch{
                throw GACAppCheckErrorUtil.jsonSerializationError(error)
            }
        }
    }
    
    private func backgroundQueue()->DispatchQueue{
        return DispatchQueue.global(qos:.utility)
    }
}
