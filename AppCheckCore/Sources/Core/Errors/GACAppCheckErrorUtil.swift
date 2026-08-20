/*
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
#if canImport(DeviceCheck)
import DeviceCheck
#endif

public let kGACAppCheckMissingRecaptchaSDKMessage = "The reCAPTCHA Enterprise SDK is not linked. See https://firebase.google.com/docs/app-check/ios/recaptcha-enterprise-provider#prepare-environment"

public func GACAppCheckSetErrorToPointer(_ error: Error, _ pointer: NSErrorPointer) {
    if let pointer = pointer {
        pointer.pointee = error as NSError
    }
}

@objc(_GACAppCheckErrorUtil)
public class GACAppCheckErrorUtil: NSObject {

    @objc
    public static func publicDomainError(with error: Error) -> Error {
        let nsError = error as NSError
        if nsError.domain == AppCheckCoreErrorDomain {
            return nsError
        }
        return unknownError(with: nsError)
    }

    // MARK: - Internal errors

    @objc
    public static func cachedTokenNotFound() -> Error {
        return appCheckError(withCode: .unknown, failureReason: "Cached token not found.", underlyingError: nil)
    }

    @objc
    public static func cachedTokenExpired() -> Error {
        return appCheckError(withCode: .unknown, failureReason: "Cached token expired.", underlyingError: nil)
    }

    @objc
    public static func keychainError(with error: Error) -> Error {
        let nsError = error as NSError
        // kGULKeychainUtilsErrorDomain from GULKeychainUtils
        if nsError.domain == "com.google.utilities.keychain" {
            return appCheckError(withCode: .keychain, failureReason: "Keychain access error.", underlyingError: nsError)
        }
        return unknownError(with: nsError)
    }

    @objc
    public static func apiError(with httpResponse: HTTPURLResponse, data: Data?) -> GACAppCheckHTTPError {
        return GACAppCheckHTTPError(httpResponse: httpResponse, data: data)
    }

    @objc
    public static func apiError(withNetworkError networkError: Error) -> Error {
        return appCheckError(withCode: .serverUnreachable, failureReason: "API request error.", underlyingError: networkError)
    }

    @objc
    public static func appCheckTokenResponseError(withMissingField fieldName: String) -> Error {
        let failureReason = "Unexpected app check token response format. Field `\(fieldName)` is missing."
        return appCheckError(withCode: .unknown, failureReason: failureReason, underlyingError: nil)
    }

    @objc
    public static func appAttestAttestationResponseError(withMissingField fieldName: String) -> Error {
        let failureReason = "Unexpected attestation response format. Field `\(fieldName)` is missing."
        return appCheckError(withCode: .unknown, failureReason: failureReason, underlyingError: nil)
    }

    @objc
    public static func jsonSerializationError(_ error: Error?) -> Error {
        return appCheckError(withCode: .unknown, failureReason: "JSON serialization error.", underlyingError: error)
    }

    @objc
    public static func error(withFailureReason failureReason: String) -> Error {
        return appCheckError(withCode: .unknown, failureReason: failureReason, underlyingError: nil)
    }

    @objc
    public static func unsupportedAttestationProvider(_ providerName: String) -> Error {
        let failureReason = "The attestation provider \(providerName) is not supported on current platform and OS version."
        return appCheckError(withCode: .unsupported, failureReason: failureReason, underlyingError: nil)
    }

    @objc
    public static func missingRecaptchaSDKError() -> Error {
        return appCheckError(withCode: .unsupported, failureReason: kGACAppCheckMissingRecaptchaSDKMessage, underlyingError: nil)
    }

    // MARK: - App Attest Errors

    @objc
    public static func appAttestKeyIDNotFound() -> Error {
        return appCheckError(withCode: .unknown, failureReason: "App attest key ID not found.", underlyingError: nil)
    }

    @objc
    public static func appAttestGenerateKeyFailed(with error: Error) -> Error {
        let failureReason = "Failed to generate a new cryptographic key for use with the App Attest service (`generateKeyWithCompletionHandler:`); \(errorDescription(withDeviceCheckError: error as NSError))."
        return appCheckError(withCode: .unknown, failureReason: failureReason, underlyingError: error)
    }

    @objc
    public static func appAttestAttestKeyFailed(with error: Error, keyId: String, clientDataHash: Data) -> Error {
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let failureReason = "Failed to attest the validity of the generated cryptographic key (`attestKey:clientDataHash:completionHandler:`); keyId.length = \(keyId.count), clientDataHash = \(clientDataHash.base64EncodedString()), systemVersion = \(systemVersion); \(errorDescription(withDeviceCheckError: error as NSError))."
        return appCheckError(withCode: .unknown, failureReason: failureReason, underlyingError: error)
    }

    @objc
    public static func appAttestGenerateAssertionFailed(with error: Error, keyId: String, clientDataHash: Data) -> Error {
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let failureReason = "Failed to create a block of data that demonstrates the legitimacy of the app instance (`generateAssertion:clientDataHash:completionHandler:`); keyId.length = \(keyId.count), clientDataHash = \(clientDataHash.base64EncodedString()), systemVersion = \(systemVersion); \(errorDescription(withDeviceCheckError: error as NSError))."
        return appCheckError(withCode: .unknown, failureReason: failureReason, underlyingError: error)
    }

    // MARK: - Helpers

    @objc
    public static func unknownError(with error: Error) -> Error {
        let nsError = error as NSError
        let failureReason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String
        return appCheckError(withCode: .unknown, failureReason: failureReason, underlyingError: nsError)
    }

    @objc
    public static func appCheckError(withCode code: AppCheckCoreErrorCode, failureReason: String?, underlyingError: Error?) -> Error {
        var userInfo: [String: Any] = [:]
        userInfo[NSUnderlyingErrorKey] = underlyingError
        userInfo[NSLocalizedFailureReasonErrorKey] = failureReason
        
        return NSError(domain: AppCheckCoreErrorDomain, code: code.rawValue, userInfo: userInfo)
    }

    @objc
    public static func errorDescription(withDeviceCheckError error: NSError) -> String {
        #if canImport(DeviceCheck) && !os(watchOS)
        if #available(macOS 10.15, iOS 11.0, tvOS 11.0, watchOS 9.0, *) {
            if error.domain == DCErrorDomain {
                let errorCode = DCError.Code(rawValue: error.code)
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
                default:
                    return "Unknown DCError(\(error.code)) - \(error.localizedDescription)"
                }
            }
        }
        #endif
        return "Unknown Error { domain: \(error.domain), code: \(error.code) } - \(error.localizedDescription)"
    }
}
