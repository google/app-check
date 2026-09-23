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

import Foundation
#if canImport(DeviceCheck)
  import DeviceCheck
#endif

@available(iOS 11.0, macOS 10.15, macCatalyst 13.0, tvOS 11.0, watchOS 9.0, *)
@objc(GACDeviceCheckProvider)
public class AppCheckCoreDeviceCheckProvider: NSObject, AppCheckCoreProvider {
  private let apiService: AppCheckCoreDeviceCheckAPIServiceProtocol
  private let deviceTokenGenerator: AppCheckCoreDeviceCheckTokenGenerator
  private let backoffWrapper: AppCheckCoreBackoffWrapperProtocol

  /// - Parameter requestHooks: Hooks invoked on each outgoing request. From Swift, pass
  ///   `[AppCheckCoreAPIRequestHook]`. From Objective-C, pass an `NSArray` of blocks with the
  ///   signature `void (^)(NSMutableURLRequest *)`; the signature is not checked at compile
  ///   time and a mismatch will crash when the hook is invoked.
  ///
  ///   Typed `[Any]?` rather than `[AppCheckCoreAPIRequestHook]?` deliberately: Swift cannot
  ///   bridge an `NSArray` into a Swift `Array` whose element is a function type, so the typed
  ///   signature traps at runtime for any non-nil array passed from Objective-C. Do not
  ///   "simplify" this type — see PR #111.
  @objc(initWithServiceName:resourceName:APIKey:requestHooks:)
  public init(serviceName: String, resourceName: String, apiKey: String,
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
    apiService = deviceCheckAPIService
    deviceTokenGenerator = DCDevice.current
    backoffWrapper = AppCheckCoreBackoffWrapper()
    super.init()
  }

  init(apiService: AppCheckCoreDeviceCheckAPIServiceProtocol,
       deviceTokenGenerator: AppCheckCoreDeviceCheckTokenGenerator,
       backoffWrapper: AppCheckCoreBackoffWrapperProtocol) {
    self.apiService = apiService
    self.deviceTokenGenerator = deviceTokenGenerator
    self.backoffWrapper = backoffWrapper
    super.init()
  }

  // MARK: - AppCheckCoreProvider

  public func getToken() async throws -> AppCheckCoreToken {
    return try await getToken(limitedUse: false)
  }

  public func getLimitedUseToken() async throws -> AppCheckCoreToken {
    return try await getToken(limitedUse: true)
  }

  public func getToken(completion handler: @escaping (AppCheckCoreToken?, Error?) -> Void) {
    Task {
      do {
        let token = try await getToken(limitedUse: false)
        AppCheckCore.deliverOnMainQueue(token, error: nil as Error?, to: handler)
      } catch {
        AppCheckCore.deliverOnMainQueue(nil, error: error, to: handler)
      }
    }
  }

  public func getLimitedUseToken(completion handler: @escaping (AppCheckCoreToken?, Error?)
    -> Void) {
    Task {
      do {
        let token = try await getToken(limitedUse: true)
        AppCheckCore.deliverOnMainQueue(token, error: nil as Error?, to: handler)
      } catch {
        AppCheckCore.deliverOnMainQueue(nil, error: error, to: handler)
      }
    }
  }

  // MARK: - Internal

  private func getToken(limitedUse: Bool) async throws -> AppCheckCoreToken {
    return try await backoffWrapper.applyBackoffToOperation({ [weak self] in
      guard let self = self else {
        throw AppCheckCoreErrorUtil.error(withFailureReason: "Self is nil")
      }
      return try await self.getTokenPromise(limitedUse: limitedUse)
    }, errorHandler: backoffWrapper.defaultAppCheckProviderErrorHandler())
  }

  private func getTokenPromise(limitedUse: Bool) async throws -> AppCheckCoreToken {
    guard deviceTokenGenerator.isSupported else {
      throw AppCheckCoreErrorUtil.unsupportedAttestationProvider("DeviceCheckProvider")
    }
    let deviceToken = try await deviceTokenGenerator.generateTokenAsync()
    return try await apiService.appCheckToken(deviceToken: deviceToken, limitedUse: limitedUse)
  }
}
