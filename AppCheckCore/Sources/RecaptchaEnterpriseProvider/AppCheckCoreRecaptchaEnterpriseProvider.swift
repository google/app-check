import Foundation
import AppCheckShared
import RecaptchaInterop

@objc(GACRecaptchaEnterpriseProvider)
final class AppCheckCoreRecaptchaEnterpriseProvider:NSObject, AppCheckCoreProvider{
    private let tokenGenerator: RecaptchaEnterpriseTokenGenerator!;
    
    init(siteKey:String){
       let recaptchaAction =
        NSClassFromString("RecaptchaEnterprise.RCAAction") as? RCAActionProtocol.Type;
        let action=recaptchaAction?.init(customAction: "fire_app_check")
        tokenGenerator=RecaptchaEnterpriseTokenGenerator(siteKey: siteKey,action:action!)
    }

    
    @objc(getTokenWithCompletion:)
    func getToken(completion handler: @escaping (AppCheckCoreToken?, (any Error)?) -> Void) {
        Task{
            do{
//                let token=try await getToken(limitedUse: false)
                handler(nil,nil)
            }catch{
                handler(nil,error)
            }
        }
    }

    @objc(getLimitedUseTokenWithCompletion:)
    func getLimitedUseToken(completion handler: @escaping (AppCheckCoreToken?, (any Error)?) -> Void) {
        Task{
            do{
//                let token=try await getToken(limitedUse: true)
                handler(nil,nil)
            }catch{
                handler(nil,error)
            }
        }
    }
    
//    private func getToken(limitedUse:Bool)async throws->AppCheckCoreToken{
//        let recaptchaToken=try await tokenGenerator.getRecaptchaToken()
////        return NSNull
//        return try await apiService.appCheckToken(withRecaptchaToken: recaptchaToken, limitedUse: limitedUse);
//        
//    }
}
