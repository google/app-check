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

public typealias AppCheckCoreTokenRefreshCompletion = @Sendable (AppCheckCoreTokenRefreshResult)
  -> Void
public typealias AppCheckCoreTokenRefreshBlock =
  @Sendable (@escaping AppCheckCoreTokenRefreshCompletion) -> Void

@objc(GACAppCheckTokenRefresherProtocol)
public protocol AppCheckCoreTokenRefresherProtocol: NSObjectProtocol {
  @objc var tokenRefreshHandler: ((@escaping (AppCheckCoreTokenRefreshResult) -> Void) -> Void)? {
    get set
  }
  @objc func updateWithRefreshResult(_ refreshResult: AppCheckCoreTokenRefreshResult)
}

@objc(GACAppCheckTokenRefresher)
public final class AppCheckCoreTokenRefresher: NSObject, AppCheckCoreTokenRefresherProtocol,
  @unchecked Sendable {
  private let refreshQueue = DispatchQueue(label: "com.firebase.GACAppCheckTokenRefresher")
  private let settings: AppCheckCoreSettingsProtocol
  private let timerProvider: AppCheckCoreTimerProvider
  private var timer: AppCheckCoreTimerProtocol?
  private var retryCount: Int = 0
  private var lock = os_unfair_lock()

  private var _tokenRefreshHandler: ((@escaping (AppCheckCoreTokenRefreshResult) -> Void) -> Void)?
  private var initialRefreshResult: AppCheckCoreTokenRefreshResult?

  @objc public var tokenRefreshHandler: ((@escaping (AppCheckCoreTokenRefreshResult) -> Void)
    -> Void)? {
    get {
      os_unfair_lock_lock(&lock)
      defer { os_unfair_lock_unlock(&lock) }
      return _tokenRefreshHandler
    }
    set {
      os_unfair_lock_lock(&lock)
      let initialResult: AppCheckCoreTokenRefreshResult?
      if _tokenRefreshHandler == nil, newValue != nil {
        initialResult = self.initialRefreshResult
        self.initialRefreshResult = nil
      } else {
        initialResult = nil
      }
      _tokenRefreshHandler = newValue
      os_unfair_lock_unlock(&lock)

      if let initialResult = initialResult {
        self.schedule(with: initialResult)
      }
    }
  }

  @objc public init(refreshResult: AppCheckCoreTokenRefreshResult,
                    timerProvider: @escaping AppCheckCoreTimerProvider,
                    settings: AppCheckCoreSettingsProtocol) {
    initialRefreshResult = refreshResult
    self.timerProvider = timerProvider
    self.settings = settings
    super.init()
  }

  @objc public convenience init(refreshResult: AppCheckCoreTokenRefreshResult,
                                settings: AppCheckCoreSettingsProtocol) {
    self.init(
      refreshResult: refreshResult,
      timerProvider: AppCheckCoreTimer.timerProvider(),
      settings: settings
    )
  }

  deinit {
    cancelTimer()
  }

  @objc public func updateWithRefreshResult(_ refreshResult: AppCheckCoreTokenRefreshResult) {
    os_unfair_lock_lock(&lock)
    switch refreshResult.status {
    case .never, .success:
      retryCount = 0
    case .failure:
      retryCount += 1
    }
    os_unfair_lock_unlock(&lock)
    schedule(with: refreshResult)
  }

  private func refresh() {
    guard let handler = tokenRefreshHandler else { return }
    guard settings.isTokenAutoRefreshEnabled else { return }

    handler { [weak self] refreshResult in
      self?.updateWithRefreshResult(refreshResult)
    }
  }

  private func schedule(with refreshResult: AppCheckCoreTokenRefreshResult) {
    if settings.isTokenAutoRefreshEnabled {
      let refreshDate = nextRefreshDate(with: refreshResult)
      scheduleRefresh(at: refreshDate)
    }
  }

  private func scheduleRefresh(at refreshDate: Date) {
    cancelTimer()
    let scheduleInSec = refreshDate.timeIntervalSinceNow

    let refreshHandler: @Sendable () -> Void = { [weak self] in
      self?.refresh()
    }

    if scheduleInSec <= 0 {
      refreshQueue.async(execute: refreshHandler)
      return
    }

    let newTimer = timerProvider(refreshDate, refreshQueue, refreshHandler)
    os_unfair_lock_lock(&lock)
    timer = newTimer
    os_unfair_lock_unlock(&lock)
  }

  private func cancelTimer() {
    let timerToInvalidate: AppCheckCoreTimerProtocol?
    os_unfair_lock_lock(&lock)
    timerToInvalidate = timer
    timer = nil
    os_unfair_lock_unlock(&lock)
    timerToInvalidate?.invalidate()
  }

  private func nextRefreshDate(with refreshResult: AppCheckCoreTokenRefreshResult) -> Date {
    switch refreshResult.status {
    case .success:
      guard let expirationDate = refreshResult.tokenExpirationDate,
            let receivedAtDate = refreshResult.tokenReceivedAtDate else {
        return Date()
      }
      let timeToLive = max(expirationDate.timeIntervalSince(receivedAtDate), 0)
      let targetRefreshSinceReceivedDate = timeToLive * 0.5 + 5 * 60
      let targetRefreshDate = receivedAtDate.addingTimeInterval(targetRefreshSinceReceivedDate)
      let refreshDate = targetRefreshDate < expirationDate ? targetRefreshDate : expirationDate

      let minimumInterval: TimeInterval = 60
      if refreshDate.timeIntervalSinceNow < minimumInterval {
        return Date().addingTimeInterval(minimumInterval)
      }
      return refreshDate

    case .failure:
      os_unfair_lock_lock(&lock)
      let currentRetry = retryCount
      os_unfair_lock_unlock(&lock)
      let backoffTime = Self.backoffTime(forRetryCount: currentRetry)
      return Date().addingTimeInterval(backoffTime)

    case .never:
      return Date()
    }
  }

  private static func backoffTime(forRetryCount retryCount: Int) -> TimeInterval {
    if retryCount == 0 {
      return 0
    }
    let initialBackoff: TimeInterval = 30
    let maximumBackoff: TimeInterval = 16 * 60
    let exponentialInterval = initialBackoff * pow(2.0, Double(retryCount - 1)) +
      randomMilliseconds()
    return min(exponentialInterval, maximumBackoff)
  }

  private static func randomMilliseconds() -> TimeInterval {
    let randomMillis = abs(Int(arc4random() % 1000))
    return Double(randomMillis) * 0.001
  }
}
