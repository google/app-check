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

import DeviceCheck
import Foundation
import GoogleUtilities_Environment

public let missingRecaptchaSDKMessage: String =
  "The reCAPTCHA Enterprise SDK is not linked. See https://cloud.google.com/recaptcha/docs/instrument-ios-apps#prepare-environment"

@_cdecl("GACAppCheckSetErrorToPointer")
public func GACAppCheckSetErrorToPointer(error: NSError, pointer: UnsafeMutablePointer<NSError?>?) {
  if let pointer = pointer {
    pointer.pointee = error
  }
}

@objc(_GACAppCheckErrorUtil)
public final class AppCheckCoreErrorUtil: NSObject {
  @objc public static func publicDomainError(with error: Error) -> Error {
    let nsError = error as NSError
    if nsError.domain == AppCheckCoreErrorDomain {
      return error
    }
    return unknownError(with: error)
  }

  // MARK: - Internal errors

  @objc public static func cachedTokenNotFound() -> Error {
    return appCheckError(
      withCode: .unknown,
      failureReason: "Cached token not found.",
      underlyingError: nil
    )
  }

  @objc public static func cachedTokenExpired() -> Error {
    return appCheckError(
      withCode: .unknown,
      failureReason: "Cached token expired.",
      underlyingError: nil
    )
  }

  @objc(keychainErrorWithError:) public static func keychainError(with error: Error) -> Error {
    let nsError = error as NSError
    if nsError.domain == "com.google.GoogleUtilities.KeychainUtils" {
      return appCheckError(
        withCode: .keychain,
        failureReason: "Keychain access error.",
        underlyingError: error
      )
    }
    return unknownError(with: error)
  }

  @objc public static func APIError(withHTTPResponse response: HTTPURLResponse,
                                    data: Data?) -> GACAppCheckHTTPError {
    return GACAppCheckHTTPError(httpResponse: response, data: data)
  }

  @objc public static func APIError(withNetworkError networkError: Error) -> Error {
    return appCheckError(
      withCode: .serverUnreachable,
      failureReason: "API request error.",
      underlyingError: networkError
    )
  }

  @objc public static func appCheckTokenResponseError(withMissingField fieldName: String) -> Error {
    let failureReason =
      "Unexpected app check token response format. Field `\(fieldName)` is missing."
    return appCheckError(withCode: .unknown, failureReason: failureReason, underlyingError: nil)
  }

  @objc public static func appAttestAttestationResponseError(withMissingField fieldName: String)
    -> Error {
    let failureReason = "Unexpected attestation response format. Field `\(fieldName)` is missing."
    return appCheckError(withCode: .unknown, failureReason: failureReason, underlyingError: nil)
  }

  @objc public static func JSONSerializationError(_ error: Error) -> Error {
    return appCheckError(
      withCode: .unknown,
      failureReason: "JSON serialization error.",
      underlyingError: error
    )
  }

  @objc public static func unsupportedAttestationProvider(_ providerName: String) -> Error {
    let failureReason =
      "The attestation provider \(providerName) is not supported on current platform and OS version."
    return appCheckError(withCode: .unsupported, failureReason: failureReason, underlyingError: nil)
  }

  @objc public static func missingRecaptchaSDKError() -> Error {
    return appCheckError(
      withCode: .unsupported,
      failureReason: missingRecaptchaSDKMessage,
      underlyingError: nil
    )
  }

  @objc public static func error(withFailureReason failureReason: String) -> Error {
    return appCheckError(withCode: .unknown, failureReason: failureReason, underlyingError: nil)
  }

  // MARK: - App Attest

  @objc public static func appAttestKeyIDNotFound() -> Error {
    return appCheckError(
      withCode: .unknown,
      failureReason: "App attest key ID not found.",
      underlyingError: nil
    )
  }

  @objc public static func appAttestGenerateKeyFailed(withError error: Error) -> Error {
    let failureReason =
      "Failed to generate a new cryptographic key for use with the App Attest service (`generateKeyWithCompletionHandler:`); \(errorDescription(withDeviceCheckError: error))."
    return appCheckError(withCode: .unknown, failureReason: failureReason, underlyingError: error)
  }

  @objc public static func appAttestAttestKeyFailed(withError error: Error, keyId: String,
                                                    clientDataHash: Data) -> Error {
    let base64Hash = clientDataHash.base64EncodedString()
    let systemVersion = GULAppEnvironmentUtil.systemVersion()
    let failureReason =
      "Failed to attest the validity of the generated cryptographic key (`attestKey:clientDataHash:completionHandler:`); keyId.length = \(keyId.count), clientDataHash = \(base64Hash), systemVersion = \(systemVersion); \(errorDescription(withDeviceCheckError: error))."
    return appCheckError(withCode: .unknown, failureReason: failureReason, underlyingError: error)
  }

  @objc public static func appAttestGenerateAssertionFailed(withError error: Error, keyId: String,
                                                            clientDataHash: Data) -> Error {
    let base64Hash = clientDataHash.base64EncodedString()
    let systemVersion = GULAppEnvironmentUtil.systemVersion()
    let failureReason =
      "Failed to create a block of data that demonstrates the legitimacy of the app instance (`generateAssertion:clientDataHash:completionHandler:`); keyId.length = \(keyId.count), clientDataHash = \(base64Hash), systemVersion = \(systemVersion); \(errorDescription(withDeviceCheckError: error))."
    return appCheckError(withCode: .unknown, failureReason: failureReason, underlyingError: error)
  }

  // MARK: - Helpers

  @objc public static func unknownError(with error: Error) -> Error {
    let nsError = error as NSError
    let failureReason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String
    return appCheckError(withCode: .unknown, failureReason: failureReason, underlyingError: error)
  }

  @objc public static func appCheckError(withCode code: AppCheckCoreErrorCode,
                                         failureReason: String?,
                                         underlyingError: Error?) -> Error {
    var userInfo: [String: Any] = [:]
    if let underlyingError = underlyingError {
      userInfo[NSUnderlyingErrorKey] = underlyingError
    }
    if let failureReason = failureReason {
      userInfo[NSLocalizedFailureReasonErrorKey] = failureReason
    }
    return NSError(domain: AppCheckCoreErrorDomain, code: code.rawValue, userInfo: userInfo)
  }

  private static func errorDescription(withDeviceCheckError error: Error) -> String {
    let nsError = error as NSError
    #if !os(watchOS)
      if #available(iOS 14.0, macOS 11.3, tvOS 15.0, *) {
        if nsError.domain == DCError.errorDomain {
          guard let errorCode = DCError.Code(rawValue: nsError.code) else {
            return "Unknown DCError(\(nsError.code)) - \(nsError.localizedDescription)"
          }
          switch errorCode {
          case .featureUnsupported:
            return "DCErrorFeatureUnsupported - DeviceCheck is unavailable on this device"
          case .invalidInput:
            return "DCErrorInvalidInput - An error code that indicates when your app provides data that isn’t formatted correctly"
          case .invalidKey:
            return "DCErrorInvalidKey - An error caused by a failed attempt to use the App Attest key"
          case .serverUnavailable:
            return "DCErrorServerUnavailable - An error that indicates a failed attempt to contact the App Attest service during an attestation"
          case .unknownSystemFailure:
            return "DCErrorUnknownSystemFailure - A failure has occurred, such as the failure to generate a token"
          @unknown default:
            return "Unknown DCError(\(nsError.code)) - \(nsError.localizedDescription)"
          }
        }
      }
    #endif
    return "Unknown Error { domain: \(nsError.domain), code: \(nsError.code) } - \(nsError.localizedDescription)"
  }
}
