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

  @objc public func getToken(completion handler: @escaping (AppCheckCoreToken?, NSError?) -> Void) {
    getToken(limitedUse: false, completion: handler)
  }

  @objc public func getLimitedUseToken(completion handler: @escaping (AppCheckCoreToken?, NSError?)
    -> Void) {
    getToken(limitedUse: true, completion: handler)
  }

  private func getToken(limitedUse: Bool,
                        completion handler: @escaping (AppCheckCoreToken?, NSError?) -> Void) {
    Task {
      do {
        let token: AppCheckCoreToken
        if let wrapper = backoffWrapper as? AppCheckCoreBackoffWrapper {
          token = try await wrapper.applyBackoff(
            to: {
              try await self.getTokenPromise(limitedUse: limitedUse)
            },
            errorHandler: { err in
              let code = wrapper.defaultAppCheckProviderErrorHandler()(err as NSError)
              return AppCheckCoreBackoffType(rawValue: code) ?? .none
            }
          )
        } else {
          let promise = self.backoffWrapper.applyBackoffToOperation(
            {
              let promise = FBLPromise<AnyObject>.__pending()
              Task {
                do {
                  let token = try await self.getTokenPromise(limitedUse: limitedUse)
                  promise.__fulfill(token)
                } catch {
                  promise.__reject(error as NSError)
                }
              }
              return promise
            },
            errorHandler: { err in
              self.backoffWrapper.defaultAppCheckProviderErrorHandler()(err)
            }
          )

          let resultToken = try await withCheckedThrowingContinuation { continuation in
            promise.__onQueue(.promises, then: { val in
              if let token = val as? AppCheckCoreToken {
                continuation.resume(returning: token)
              } else {
                continuation
                  .resume(throwing: AppCheckCoreErrorUtil
                    .error(withFailureReason: "Invalid token type returned from promise."))
              }
              return nil
            }).__onQueue(.promises, catch: { err in
              continuation.resume(throwing: err)
            })
          }
          token = resultToken
        }

        handler(token, nil)
      } catch {
        handler(nil, error as NSError)
      }
    }
  }

  private func getTokenPromise(limitedUse: Bool) async throws -> AppCheckCoreToken {
    let deviceToken = try await generateDeviceToken()
    return try await apiService.appCheckToken(withDeviceToken: deviceToken, limitedUse: limitedUse)
  }

  private func generateDeviceToken() async throws -> Data {
    try await isDeviceCheckSupported()
    return try await withCheckedThrowingContinuation { continuation in
      deviceTokenGenerator.generateToken { token, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else if let token = token {
          continuation.resume(returning: token)
        } else {
          continuation
            .resume(throwing: AppCheckCoreErrorUtil
              .error(withFailureReason: "DeviceCheck returned nil token and nil error."))
        }
      }
    }
  }

  private func isDeviceCheckSupported() async throws {
    if deviceTokenGenerator.isSupported {
      return
    } else {
      throw AppCheckCoreErrorUtil.unsupportedAttestationProvider("DeviceCheckProvider")
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
