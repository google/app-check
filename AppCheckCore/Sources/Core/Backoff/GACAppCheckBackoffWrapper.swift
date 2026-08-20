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

@objc(GACAppCheckBackoffType)
public enum AppCheckBackoffType: UInt {
    case none
    case oneDay
    case exponential
}

public typealias GACAppCheckBackoffErrorHandler = (Error) -> AppCheckBackoffType
public typealias AppCheckDateProvider = () -> Date

public protocol AppCheckBackoffWrapperProtocol: NSObjectProtocol {
    func applyBackoffToOperation(
        _ operationProvider: @escaping () async throws -> Any,
        errorHandler: @escaping (Error) -> AppCheckBackoffType
    ) async throws -> Any

    func defaultAppCheckProviderErrorHandler() -> (Error) -> AppCheckBackoffType
}

private let k24Hours: TimeInterval = 24 * 60 * 60
private let kMaxJitterCoefficient = 0.5
private let kMaxExponentialBackoffInterval: TimeInterval = 4 * 60 * 60

private class AppCheckBackoffOperationFailure: NSObject {
    let finishDate: Date
    let error: Error
    let backoffType: AppCheckBackoffType
    let retryCount: Int

    init(finishDate: Date, error: Error, backoffType: AppCheckBackoffType, retryCount: Int) {
        self.finishDate = finishDate
        self.error = error
        self.backoffType = backoffType
        self.retryCount = retryCount
        super.init()
    }

    static func nextRetryFailure(with previousFailure: AppCheckBackoffOperationFailure?, finishDate: Date, error: Error, backoffType: AppCheckBackoffType) -> AppCheckBackoffOperationFailure {
        return AppCheckBackoffOperationFailure(
            finishDate: finishDate,
            error: error,
            backoffType: backoffType,
            retryCount: (previousFailure?.retryCount ?? 0) + 1
        )
    }
}

public class GACAppCheckBackoffWrapper: NSObject, AppCheckBackoffWrapperProtocol {
    private let dateProvider: AppCheckDateProvider
    private var lastFailure: AppCheckBackoffOperationFailure?
    private let lock = NSLock()

    @objc
    public override convenience init() {
        self.init(dateProvider: GACAppCheckBackoffWrapper.currentDateProvider())
    }

    @objc(initWithDateProvider:)
    public init(dateProvider: @escaping AppCheckDateProvider) {
        self.dateProvider = dateProvider
        super.init()
    }

    @objc
    public static func currentDateProvider() -> AppCheckDateProvider {
        return { Date() }
    }

    public func applyBackoffToOperation(
        _ operationProvider: @escaping () async throws -> Any,
        errorHandler: @escaping (Error) -> AppCheckBackoffType
    ) async throws -> Any {
        if !isNextOperationAllowed() {
            guard let failure = lastFailure else {
                throw GACAppCheckErrorUtil.error(withFailureReason: "Too many attempts.")
            }
            let reason = "Too many attempts. Underlying error: \((failure.error as NSError).localizedDescription)"
            throw GACAppCheckErrorUtil.error(withFailureReason: reason)
        }

        do {
            let result = try await operationProvider()
            lock.withLock {
                lastFailure = nil
            }
            return result
        } catch {
            let backoffType = errorHandler(error)
            lock.withLock {
                lastFailure = AppCheckBackoffOperationFailure.nextRetryFailure(
                    with: lastFailure,
                    finishDate: dateProvider(),
                    error: error,
                    backoffType: backoffType
                )
            }
            throw error
        }
    }

    private func isNextOperationAllowed() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let failure = lastFailure else { return true }

        switch failure.backoffType {
        case .none:
            return true
        case .oneDay:
            return hasTimeIntervalPassedSinceLastFailure(k24Hours)
        case .exponential:
            return hasTimeIntervalPassedSinceLastFailure(exponentialBackoffInterval(for: failure))
        @unknown default:
            return true
        }
    }

    private func hasTimeIntervalPassedSinceLastFailure(_ timeInterval: TimeInterval) -> Bool {
        guard let failureDate = lastFailure?.finishDate else { return true }
        let timeSinceFailure = dateProvider().timeIntervalSince(failureDate)
        return timeSinceFailure >= timeInterval
    }

    private func exponentialBackoffInterval(for failure: AppCheckBackoffOperationFailure) -> TimeInterval {
        let baseBackoff = pow(2.0, Double(failure.retryCount))
        let maxRandom = 1000.0
        let randomNumber = Double(arc4random_uniform(UInt32(maxRandom))) / maxRandom
        let jitterCoefficient = 1.0 + randomNumber * kMaxJitterCoefficient
        let backoffIntervalWithJitter = baseBackoff * jitterCoefficient
        return min(backoffIntervalWithJitter, kMaxExponentialBackoffInterval)
    }

    @objc
    public func defaultAppCheckProviderErrorHandler() -> (Error) -> AppCheckBackoffType {
        return { error in
            guard let httpError = error as? GACAppCheckHTTPError else {
                return .none
            }

            let statusCode = httpError.httpResponse.statusCode

            if statusCode < 400 {
                return .none
            }

            if statusCode == 400 || statusCode == 404 {
                return .oneDay
            }

            if statusCode == 403 || statusCode == 429 || statusCode == 503 {
                return .exponential
            }

            return .exponential
        }
    }
}
