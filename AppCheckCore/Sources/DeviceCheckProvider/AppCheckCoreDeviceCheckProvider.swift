// Copyright 2026 Google LLC
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

import FBLPromises
import Foundation
import Promises
#if canImport(DeviceCheck)
  import DeviceCheck
#endif

@objc(GACDeviceCheckTokenGenerator)
public protocol AppCheckCoreDeviceCheckTokenGenerator: NSObjectProtocol {
  @objc var isSupported: Bool { get }
  @objc func generateToken(completionHandler completion: @escaping (Data?, Error?) -> Void)
}

#if canImport(DeviceCheck)
  extension DCDevice: AppCheckCoreDeviceCheckTokenGenerator {}
#endif

@objc(GACDeviceCheckProvider)
public final class AppCheckCoreDeviceCheckProvider: NSObject, AppCheckCoreProvider,
  @unchecked Sendable {
  private let apiService: AppCheckCoreDeviceCheckAPIServiceProtocol
  private let deviceTokenGenerator: AppCheckCoreDeviceCheckTokenGenerator
  private let backoffWrapper: AppCheckCoreBackoffWrapperProtocol

  @objc(initWithAPIService:deviceTokenGenerator:backoffWrapper:)
  public init(apiService: AppCheckCoreDeviceCheckAPIServiceProtocol,
              deviceTokenGenerator: AppCheckCoreDeviceCheckTokenGenerator,
              backoffWrapper: AppCheckCoreBackoffWrapperProtocol) {
    self.apiService = apiService
    self.deviceTokenGenerator = deviceTokenGenerator
    self.backoffWrapper = backoffWrapper
    super.init()
  }

  @objc public convenience init(apiService: AppCheckCoreDeviceCheckAPIServiceProtocol) {
    let backoffWrapper = AppCheckCoreBackoffWrapper()
    #if canImport(DeviceCheck)
      let generator = DCDevice.current
    #else
      let generator = DummyDeviceCheckTokenGenerator()
    #endif
    self.init(
      apiService: apiService,
      deviceTokenGenerator: generator,
      backoffWrapper: backoffWrapper
    )
  }

  @objc public convenience init(serviceName: String,
                                resourceName: String,
                                apiKey: String,
                                requestHooks: [Any]?) {
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
    self.init(apiService: deviceCheckAPIService)
  }

  // MARK: - AppCheckCoreProvider

  @objc public func getToken(completion handler: @escaping (AppCheckCoreToken?, Error?) -> Void) {
    getToken(limitedUse: false, completion: handler)
  }

  @objc public func getLimitedUseToken(completion handler: @escaping (AppCheckCoreToken?, Error?)
    -> Void) {
    getToken(limitedUse: true, completion: handler)
  }

  private func getToken(limitedUse: Bool,
                        completion handler: @escaping (AppCheckCoreToken?, Error?) -> Void) {
    let errorHandler: (Error) -> AppCheckCoreBackoffType = { error in
      let nsError = error as NSError
      let code = self.backoffWrapper.defaultAppCheckProviderErrorHandler()(nsError)
      return AppCheckCoreBackoffType(rawValue: code) ?? .none
    }

    let tokenPromise: Promise<AppCheckCoreToken>
    if let wrapper = backoffWrapper as? AppCheckCoreBackoffWrapper {
      tokenPromise = wrapper.applyBackoff(
        to: {
          self.getTokenPromise(limitedUse: limitedUse)
        },
        errorHandler: errorHandler
      )
    } else {
      let fblPromise = backoffWrapper.applyBackoffToOperation(
        {
          let swiftPromise = self.getTokenPromise(limitedUse: limitedUse)
          return swiftPromise.asObjCPromise()
        },
        errorHandler: { err in
          self.backoffWrapper.defaultAppCheckProviderErrorHandler()(err)
        }
      )
      tokenPromise = Promise<AnyObject>(fblPromise).then { val -> Promise<AppCheckCoreToken> in
        if let token = val as? AppCheckCoreToken {
          return Promise(token)
        } else {
          throw AppCheckCoreErrorUtil
            .error(withFailureReason: "Invalid token type returned from promise.")
        }
      }
    }

    tokenPromise
      .then { token in
        handler(token, nil)
      }
      .catch { error in
        handler(nil, error)
      }
  }

  private func getTokenPromise(limitedUse: Bool) -> Promise<AppCheckCoreToken> {
    return generateDeviceToken().then { deviceToken -> Promise<AppCheckCoreToken> in
      return self.apiService.appCheckToken(withDeviceToken: deviceToken, limitedUse: limitedUse)
    }
  }

  private func generateDeviceToken() -> Promise<Data> {
    return isDeviceCheckSupported().then { _ -> Promise<Data> in
      return Promise<Data> { fulfill, reject in
        self.deviceTokenGenerator.generateToken { token, error in
          if let error = error {
            reject(error)
          } else if let token = token {
            fulfill(token)
          } else {
            reject(AppCheckCoreErrorUtil
              .error(withFailureReason: "DeviceCheck returned nil token and nil error."))
          }
        }
      }
    }
  }

  private func isDeviceCheckSupported() -> Promise<Void> {
    if deviceTokenGenerator.isSupported {
      return Promise(())
    } else {
      let error = AppCheckCoreErrorUtil.unsupportedAttestationProvider("DeviceCheckProvider")
      return Promise(error)
    }
  }
}

#if !canImport(DeviceCheck)
  private final class DummyDeviceCheckTokenGenerator: NSObject,
    AppCheckCoreDeviceCheckTokenGenerator {
    var isSupported: Bool { return false }
    func generateToken(completionHandler completion: @escaping (Data?, Error?) -> Void) {
      completion(nil, AppCheckCoreErrorUtil.unsupportedAttestationProvider("DeviceCheckProvider"))
    }
  }
#endif
