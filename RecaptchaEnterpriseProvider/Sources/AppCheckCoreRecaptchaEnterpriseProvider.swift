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
import RecaptchaInterop
import Promises

@objc(GACRecaptchaEnterpriseProvider)
public final class AppCheckCoreRecaptchaEnterpriseProvider:NSObject, AppCheckCoreProvider{
    private let tokenGenerator: RecaptchaEnterpriseTokenGenerator!;
    private let apiService: RecaptchaEnterpriseAPIService;
    
    public  init(siteKey:String,resourceName:String,APIKey: String,requestHooks:[(@convention(block) (NSMutableURLRequest) -> Void)]? = nil){
       let recaptchaAction =
        NSClassFromString("RecaptchaEnterprise.RCAAction") as? RCAActionProtocol.Type
        let action=recaptchaAction?.init(customAction: "fire_app_check")
        tokenGenerator=RecaptchaEnterpriseTokenGenerator(siteKey: siteKey,action:action!)
      
        let urlSession=URLSession(configuration: .ephemeral)
        let appCheckAPIService=AppCheckCoreAPIService(urlSession: urlSession,
                                                       baseURL:nil,
                                                       apiKey: APIKey,
                                                       requestHooks: requestHooks)
        self.apiService=RecaptchaEnterpriseAPIService(APIService: appCheckAPIService, resourceName: resourceName)
    }

    
    @objc(getTokenWithCompletion:)
    public func getToken(completion handler: @escaping (AppCheckCoreToken?, (any Error)?) -> Void) {
        getToken(limitedUse: false)
            .then{token in
                handler(token,nil)
            }.catch{error in
                handler(nil,error)
            }
    }

    @objc(getLimitedUseTokenWithCompletion:)
  public  func getLimitedUseToken(completion handler: @escaping (AppCheckCoreToken?, (any Error)?) -> Void) {
      getToken(limitedUse: true)
          .then{token in
              handler(token,nil)
          }.catch{error in
              handler(nil,error)
          }
    }
    
    private func getToken(limitedUse:Bool)->Promise<AppCheckCoreToken>{
        return tokenGenerator.getRecaptchaToken()
            .then{recaptchaToken in
                return self.apiService.appCheckToken(withRecaptchaToken: recaptchaToken, limitedUse: limitedUse)}
    }
}
