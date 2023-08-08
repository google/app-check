//
// Copyright 2021 Google LLC
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
//

// MARK: This file is used to evaluate the experience of using Firebase APIs in Swift.

import Foundation

import AppCheckCore

final class AppCheckAPITests {
  func usage() {
    let serviceName = "AppCheckAPITests"
    let resourceName = "projects/test-project-id/google-app-id"
    let appGroupID = "TeamIDPrefix.com.google.appcheck"
    let apiKey = "test-api-key"

    // MARK: - AppAttestProvider

    #if os(iOS) || os(tvOS) || os(watchOS)
      if #available(iOS 14.0, tvOS 15.0, watchOS 9.0, *) {
        // TODO(andrewheard): Add `requestHooks` in API tests.
        if let provider = AppCheckCoreAppAttestProvider(
          serviceName: serviceName,
          resourceName: resourceName,
          baseURL: nil,
          apiKey: apiKey,
          keychainAccessGroup: nil,
          requestHooks: nil
        ) {
          provider.getToken { token, error in
            // ...
          }
        }
      }
    #endif // os(iOS) || os(tvOS) || os(watchOS)

    // MARK: - AppCheckCore

    // Retrieving an AppCheck instance
    let appCheck = AppCheckCore(
      serviceName: serviceName,
      resourceName: resourceName,
      appCheckProvider: DummyAppCheckProvider(),
      settings: DummyAppCheckSettings(),
      tokenDelegate: DummyAppCheckTokenDelegate(),
      keychainAccessGroup: appGroupID
    )

    // Get token
    appCheck.token(forcingRefresh: false) { token, error in
      if let _ /* error */ = error {
        // ...
      } else if let _ /* token */ = token {
        // ...
      }
    }

    // Get token (async/await)
    if #available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 7.0, *) {
      // async/await is only available on iOS 13+
      Task {
        do {
          try await appCheck.token(forcingRefresh: false)
        } catch {
          // ...
        }
      }
    }

    // MARK: - `AppCheckDebugProvider`

    // `AppCheckDebugProvider` initializer
    // TODO(andrewheard): Add `requestHooks` in API tests.
    let debugProvider = AppCheckCoreDebugProvider(
      serviceName: serviceName,
      resourceName: resourceName,
      apiKey: apiKey,
      requestHooks: nil
    )
    // Get token
    debugProvider.getToken { token, error in
      if let _ /* error */ = error {
        // ...
      } else if let _ /* token */ = token {
        // ...
      }
    }

    // Get token (async/await)
    if #available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 7.0, *) {
      // async/await is only available on iOS 13+
      Task {
        do {
          _ = try await debugProvider.getToken()
        } catch {
          // ...
        }
      }
    }

    _ = debugProvider.localDebugToken()
    _ = debugProvider.currentDebugToken()

    // MARK: - AppCheckToken

    let token = AppCheckCoreToken(token: "token", expirationDate: Date.distantFuture)
    _ = token.token
    _ = token.expirationDate

    // MARK: - AppCheckErrors

    appCheck.token(forcingRefresh: false) { _, error in
      if let error = error {
        switch error {
        case AppCheckCoreErrorCode.unknown:
          break
        case AppCheckCoreErrorCode.serverUnreachable:
          break
        case AppCheckCoreErrorCode.invalidConfiguration:
          break
        case AppCheckCoreErrorCode.keychain:
          break
        case AppCheckCoreErrorCode.unsupported:
          break
        default:
          break
        }
      }
      // ...
    }

    // MARK: - AppCheckProvider

    // A protocol implemented by:
    // - `AppAttestDebugProvider`
    // - `AppCheckDebugProvider`
    // - `DeviceCheckProvider`

    // MARK: - DeviceCheckProvider

    // `DeviceCheckProvider` initializer
    #if !os(watchOS)
      if #available(iOS 11.0, macOS 10.15, macCatalyst 13.0, tvOS 11.0, *) {
        // TODO(andrewheard): Add `requestHooks` in API tests.
        let deviceCheckProvider = AppCheckCoreDeviceCheckProvider(
          serviceName: serviceName,
          resourceName: resourceName,
          apiKey: apiKey,
          requestHooks: nil
        )
        // Get token
        deviceCheckProvider.getToken { token, error in
          if let _ /* error */ = error {
            // ...
          } else if let _ /* token */ = token {
            // ...
          }
        }
        // Get token (async/await)
        if #available(iOS 13.0, tvOS 13.0, *) {
          // async/await is only available on iOS 13+
          Task {
            do {
              _ = try await deviceCheckProvider.getToken()
            } catch AppCheckCoreErrorCode.unsupported {
              // ...
            } catch {
              // ...
            }
          }
        }
      }
    #endif // !os(watchOS)

    // MARK: - AppCheckCoreLogger

    // Set the log level for App Check Core
    AppCheckCoreLogger.logLevel = .debug
  }
}

class DummyAppCheckProvider: NSObject, AppCheckCoreProvider {
  func getToken(completion handler: @escaping (AppCheckCoreToken?, Error?) -> Void) {
    handler(AppCheckCoreToken(token: "token", expirationDate: .distantFuture), nil)
  }
}

class DummyAppCheckSettings: NSObject, AppCheckCoreSettingsProtocol {
  var isTokenAutoRefreshEnabled: Bool = true
}

class DummyAppCheckTokenDelegate: NSObject, AppCheckCoreTokenDelegate {
  func tokenDidUpdate(_ token: AppCheckCoreToken, serviceName: String) {}
}
