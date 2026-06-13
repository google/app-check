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

@objc(GACAppCheckBackoffType)
public enum AppCheckCoreBackoffType: Int, Sendable {
  case none = 0
  case oneDay = 1
  case exponential = 2
}

@objc(_GACAppCheckBackoffWrapperProtocol)
public protocol AppCheckCoreBackoffWrapperProtocol: NSObjectProtocol {
  @objc func applyBackoffToOperation(_ operationProvider: @escaping () -> FBLPromise<AnyObject>,
                                     errorHandler: @escaping (NSError) -> Int)
    -> FBLPromise<AnyObject>

  @objc func defaultAppCheckProviderErrorHandler() -> (NSError) -> Int
}

@objc(_GACAppCheckBackoffWrapper)
public final class AppCheckCoreBackoffWrapper: NSObject, AppCheckCoreBackoffWrapperProtocol,
  @unchecked Sendable {
  private let dateProvider: @Sendable () -> Date
  private var lastFailure: AppCheckCoreBackoffOperationFailure?
  private var lock = os_unfair_lock()

  private final class AppCheckCoreBackoffOperationFailure: Sendable {
    let finishDate: Date
    let error: Error
    let backoffType: AppCheckCoreBackoffType
    let retryCount: Int

    init(finishDate: Date, error: Error, backoffType: AppCheckCoreBackoffType, retryCount: Int) {
      self.finishDate = finishDate
      self.error = error
      self.backoffType = backoffType
      self.retryCount = retryCount
    }

    static func nextRetryFailure(previousFailure: AppCheckCoreBackoffOperationFailure?,
                                 finishDate: Date,
                                 error: Error,
                                 backoffType: AppCheckCoreBackoffType)
      -> AppCheckCoreBackoffOperationFailure {
      let newRetryCount = (previousFailure?.retryCount ?? -1) + 1
      return AppCheckCoreBackoffOperationFailure(
        finishDate: finishDate,
        error: error,
        backoffType: backoffType,
        retryCount: newRetryCount
      )
    }
  }

  @objc override public init() {
    dateProvider = { Date() }
    super.init()
  }

  public init(dateProvider: @escaping @Sendable () -> Date) {
    self.dateProvider = dateProvider
    super.init()
  }

  @objc public init(dateProvider: @escaping () -> Date) {
    self.dateProvider = dateProvider
    super.init()
  }

  @objc public static func currentDateProvider() -> () -> Date {
    return { Date() }
  }

  public func applyBackoff<T: Sendable>(to operation: @escaping @Sendable () async throws -> T,
                                        errorHandler: @escaping @Sendable (Error)
                                          -> AppCheckCoreBackoffType) async throws -> T {
    if !isNextOperationAllowed() {
      let failureError = getLockState { lastFailure?.error } ?? AppCheckCoreErrorUtil
        .error(withFailureReason: "Too many attempts.")
      let reason = "Too many attempts. Underlying error: \(failureError.localizedDescription)"
      throw AppCheckCoreErrorUtil.error(withFailureReason: reason)
    }

    do {
      let result = try await operation()
      setLockState { self.lastFailure = nil }
      return result
    } catch {
      let type = errorHandler(error)
      setLockState {
        self.lastFailure = AppCheckCoreBackoffOperationFailure.nextRetryFailure(
          previousFailure: self.lastFailure,
          finishDate: self.dateProvider(),
          error: error,
          backoffType: type
        )
      }
      throw error
    }
  }

  @objc public func applyBackoffToOperation(_ operationProvider: @escaping () -> FBLPromise<
    AnyObject
  >,
  errorHandler: @escaping (NSError) -> Int) -> FBLPromise<AnyObject> {
    if !isNextOperationAllowed() {
      let failureError = getLockState { lastFailure?.error } ?? AppCheckCoreErrorUtil
        .error(withFailureReason: "Too many attempts.")
      let reason = "Too many attempts. Underlying error: \(failureError.localizedDescription)"
      let backoffError = AppCheckCoreErrorUtil.error(withFailureReason: reason)
      return Promise<AnyObject>(backoffError).asObjCPromise()
    }

    let opPromise = operationProvider()

    let promise = Promise<AnyObject>(opPromise).then { val in
      self.setLockState { self.lastFailure = nil }
      return val
    }.recover { error in
      let typeInt = errorHandler(error as NSError)
      let type = AppCheckCoreBackoffType(rawValue: typeInt) ?? .none
      self.setLockState {
        self.lastFailure = AppCheckCoreBackoffOperationFailure.nextRetryFailure(
          previousFailure: self.lastFailure,
          finishDate: self.dateProvider(),
          error: error,
          backoffType: type
        )
      }
      throw error
    }

    return promise.asObjCPromise()
  }

  @objc public func defaultAppCheckProviderErrorHandler() -> (NSError) -> Int {
    return { error in
      guard let httpError = error as? GACAppCheckHTTPError else {
        return AppCheckCoreBackoffType.none.rawValue
      }

      let statusCode = httpError.httpResponse.statusCode
      if statusCode < 400 {
        return AppCheckCoreBackoffType.none.rawValue
      }
      if statusCode == 400 || statusCode == 404 {
        return AppCheckCoreBackoffType.oneDay.rawValue
      }
      return AppCheckCoreBackoffType.exponential.rawValue
    }
  }

  private func isNextOperationAllowed() -> Bool {
    os_unfair_lock_lock(&lock)
    defer { os_unfair_lock_unlock(&lock) }

    guard let failure = lastFailure else {
      return true
    }

    switch failure.backoffType {
    case .none:
      return true
    case .oneDay:
      return hasTimeIntervalPassedSinceLastFailure(24 * 60 * 60, failure: failure)
    case .exponential:
      let interval = exponentialBackoffInterval(for: failure)
      return hasTimeIntervalPassedSinceLastFailure(interval, failure: failure)
    }
  }

  private func hasTimeIntervalPassedSinceLastFailure(_ timeInterval: TimeInterval,
                                                     failure: AppCheckCoreBackoffOperationFailure)
    -> Bool {
    let timeSinceFailure = dateProvider().timeIntervalSince(failure.finishDate)
    return timeSinceFailure >= timeInterval
  }

  private func exponentialBackoffInterval(for failure: AppCheckCoreBackoffOperationFailure)
    -> TimeInterval {
    let baseBackoff = pow(2.0, Double(failure.retryCount))
    let maxRandom = 1000.0
    let randomNumber = Double(arc4random_uniform(UInt32(maxRandom))) / maxRandom
    let jitterCoefficient = 1.0 + randomNumber * 0.5
    let backoffIntervalWithJitter = baseBackoff * jitterCoefficient
    let maxExponentialBackoffInterval = 4.0 * 60.0 * 60.0
    return min(backoffIntervalWithJitter, maxExponentialBackoffInterval)
  }

  private func getLockState<V>(_ block: () -> V) -> V {
    os_unfair_lock_lock(&lock)
    defer { os_unfair_lock_unlock(&lock) }
    return block()
  }

  private func setLockState(_ block: () -> Void) {
    os_unfair_lock_lock(&lock)
    defer { os_unfair_lock_unlock(&lock) }
    block()
  }
}
