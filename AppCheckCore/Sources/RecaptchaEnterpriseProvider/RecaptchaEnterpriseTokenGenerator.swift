import Foundation
import RecaptchaInterop

final class RecaptchaEnterpriseTokenGenerator{
    
    private let siteKey:String;
    private let action:RCAActionProtocol;
    private let recaptchaClientTask:Task<RCARecaptchaClientProtocol?,Error>!;
    
    init(siteKey: String, action:RCAActionProtocol){
        self.siteKey = siteKey;
        self.action = action;
        self.recaptchaClientTask = Task {
            guard let recaptcha =
                        NSClassFromString("RecaptchaEnterprise.RCARecaptcha") as? RCARecaptchaProtocol.Type else{
                throw NSError(domain: "RecaptchaEnterprise", code: 1, userInfo: nil);
            }
            let client = try await recaptcha.fetchClient(withSiteKey: siteKey) ;
            return client
        }
    }
    
    func getRecaptchaToken() async throws ->String{
        let client=try await recaptchaClientTask!.value!;
        let token=try await client.execute(withAction: action);
        return token;
    }
    
    
}
