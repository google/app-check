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

@objc(GACAppCheckBackoffType)
public enum AppCheckCoreBackoffType: UInt {
  case none
  case oneDay
  case exponential
}

public typealias AppCheckCoreBackoffErrorHandler = (Error) -> AppCheckCoreBackoffType
public typealias AppCheckCoreDateProvider = () -> Date

public protocol AppCheckCoreBackoffWrapperProtocol: NSObjectProtocol {
  func applyBackoffToOperation<T>(_ operationProvider: @escaping () async throws -> T,
                                  errorHandler: @escaping (Error)
                                    -> AppCheckCoreBackoffType) async throws -> T

  func defaultAppCheckProviderErrorHandler() -> (Error) -> AppCheckCoreBackoffType
}

private let k24Hours: TimeInterval = 24 * 60 * 60
private let kMaxJitterCoefficient = 0.5
private let kMaxExponentialBackoffInterval: TimeInterval = 4 * 60 * 60

private class AppCheckCoreBackoffOperationFailure: NSObject {
  let finishDate: Date
  let error: Error
  let backoffType: AppCheckCoreBackoffType
  let retryCount: Int

  init(finishDate: Date, error: Error, backoffType: AppCheckCoreBackoffType, retryCount: Int) {
    self.finishDate = finishDate
    self.error = error
    self.backoffType = backoffType
    self.retryCount = retryCount
    super.init()
  }

  static func nextRetryFailure(with previousFailure: AppCheckCoreBackoffOperationFailure?,
                               finishDate: Date, error: Error,
                               backoffType: AppCheckCoreBackoffType)
    -> AppCheckCoreBackoffOperationFailure {
    return AppCheckCoreBackoffOperationFailure(
      finishDate: finishDate,
      error: error,
      backoffType: backoffType,
      retryCount: (previousFailure?.retryCount ?? 0) + 1
    )
  }
}

public class AppCheckCoreBackoffWrapper: NSObject, AppCheckCoreBackoffWrapperProtocol {
  private let dateProvider: AppCheckCoreDateProvider
  private var lastFailure: AppCheckCoreBackoffOperationFailure?
  private let lock = NSLock()

  @objc
  override public convenience init() {
    self.init(dateProvider: AppCheckCoreBackoffWrapper.currentDateProvider())
  }

  @objc(initWithDateProvider:)
  public init(dateProvider: @escaping AppCheckCoreDateProvider) {
    self.dateProvider = dateProvider
    super.init()
  }

  @objc
  public static func currentDateProvider() -> AppCheckCoreDateProvider {
    return { Date() }
  }

  public func applyBackoffToOperation<T>(_ operationProvider: @escaping () async throws -> T,
                                         errorHandler: @escaping (Error)
                                           -> AppCheckCoreBackoffType) async throws -> T {
    if !isNextOperationAllowed() {
      guard let failure = lastFailure else {
        throw AppCheckCoreErrorUtil.error(withFailureReason: "Too many attempts.")
      }
      let reason =
        "Too many attempts. Underlying error: \((failure.error as NSError).localizedDescription)"
      throw AppCheckCoreErrorUtil.error(withFailureReason: reason)
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
        lastFailure = AppCheckCoreBackoffOperationFailure.nextRetryFailure(
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

  private func exponentialBackoffInterval(for failure: AppCheckCoreBackoffOperationFailure)
    -> TimeInterval {
    let baseBackoff = pow(2.0, Double(failure.retryCount - 1))
    let maxRandom = 1000.0
    let randomNumber = Double(arc4random_uniform(UInt32(maxRandom))) / maxRandom
    let jitterCoefficient = 1.0 + randomNumber * kMaxJitterCoefficient
    let backoffIntervalWithJitter = baseBackoff * jitterCoefficient
    return min(backoffIntervalWithJitter, kMaxExponentialBackoffInterval)
  }

  @objc
  public func defaultAppCheckProviderErrorHandler() -> (Error) -> AppCheckCoreBackoffType {
    return { error in
      guard let httpError = error as? AppCheckCoreHTTPError else {
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
