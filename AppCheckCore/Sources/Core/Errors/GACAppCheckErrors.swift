/*
 * Copyright 2021 Google LLC
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

/// Firebase app check error domain.
public let AppCheckCoreErrorDomain = "com.google.app_check_core"

@objc(GACAppCheckErrorCode)
public enum AppCheckCoreErrorCode: Int, Error {
    /// An unknown or non-actionable error.
    case unknown = 0
    
    /// A network connection error.
    case serverUnreachable = 1
    
    /// Invalid configuration error. Currently, an exception is thrown but this error is reserved
    /// for future implementations of invalid configuration detection.
    case invalidConfiguration = 2
    
    /// System keychain access error. Ensure that the app has proper keychain access.
    case keychain = 3
    
    /// Selected app attestation provider is not supported on the current platform or OS version.
    case unsupported = 4
}

@objc(GACAppCheckMessageCode)
public enum AppCheckCoreMessageCode: Int {
    case unknown = 1001
    
    // App Check
    case providerIsMissing = 2002
    case stagingModeEnabled = 2003
    case unexpectedHTTPCode = 3001
    
    // Debug Provider
    case localDebugToken = 4001
    case environmentVariableDebugToken = 4002
    case debugProviderFirebaseEnvironmentVariable = 4003
    case debugProviderFailedExchange = 4004
    
    // App Attest Provider
    case appAttestNotSupported = 7001
    case attestationRejected = 7002
    case assertionRejected = 7003
}
