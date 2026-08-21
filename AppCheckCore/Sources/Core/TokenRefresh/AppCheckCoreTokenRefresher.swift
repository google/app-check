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

public typealias AppCheckCoreTokenRefreshCompletion = (AppCheckCoreTokenRefreshResult) -> Void
public typealias AppCheckCoreTokenRefreshBlock = (@escaping AppCheckCoreTokenRefreshCompletion)
  -> Void

@objc(GACAppCheckTokenRefresherProtocol)
public protocol AppCheckCoreTokenRefresherProtocol: NSObjectProtocol {
  @objc var tokenRefreshHandler: AppCheckCoreTokenRefreshBlock? { get set }
  @objc func updateWithRefreshResult(_ refreshResult: AppCheckCoreTokenRefreshResult)
}

@objc(GACAppCheckTokenRefresher)
@objcMembers
public class AppCheckCoreTokenRefresher: NSObject, AppCheckCoreTokenRefresherProtocol {
  private let kInitialBackoffTimeInterval: TimeInterval = 30
  private let kMaximumBackoffTimeInterval: TimeInterval = 16 * 60
  private let kMinimumAutoRefreshTimeInterval: TimeInterval = 60 // 1 min.
  private let kAutoRefreshFraction: Double = 0.5

  private let refreshQueue = DispatchQueue(label: "com.firebase.AppCheckCoreTokenRefresher")
  private let timerProvider: AppCheckCoreTimerProvider
  private let settings: AppCheckCoreSettingsProtocol

  private var timer: AppCheckCoreTimerProtocol?
  private var retryCount: Int = 0
  private var initialRefreshResult: AppCheckCoreTokenRefreshResult?
  private var _tokenRefreshHandler: AppCheckCoreTokenRefreshBlock?

  private let lock = NSRecursiveLock()

  public init(refreshResult: AppCheckCoreTokenRefreshResult,
              timerProvider: @escaping AppCheckCoreTimerProvider,
              settings: AppCheckCoreSettingsProtocol) {
    initialRefreshResult = refreshResult
    self.timerProvider = timerProvider
    self.settings = settings
    super.init()
  }

  public convenience init(refreshResult: AppCheckCoreTokenRefreshResult,
                          settings: AppCheckCoreSettingsProtocol) {
    self.init(refreshResult: refreshResult,
              timerProvider: AppCheckCoreTimer.timerProvider(),
              settings: settings)
  }

  deinit {
    cancelTimer()
  }

  public var tokenRefreshHandler: AppCheckCoreTokenRefreshBlock? {
    get {
      lock.lock()
      defer { lock.unlock() }
      return _tokenRefreshHandler
    }
    set {
      lock.lock()
      defer { lock.unlock() }
      _tokenRefreshHandler = newValue

      if newValue != nil, let initialResult = initialRefreshResult {
        initialRefreshResult = nil
        schedule(with: initialResult)
      }
    }
  }

  @objc(updateWithRefreshResult:)
  public func updateWithRefreshResult(_ refreshResult: AppCheckCoreTokenRefreshResult) {
    lock.lock()
    defer { lock.unlock() }

    switch refreshResult.status {
    case .never, .success:
      retryCount = 0
    case .failure:
      retryCount += 1
    @unknown default:
      break
    }

    schedule(with: refreshResult)
  }

  private func refresh() {
    guard let handler = tokenRefreshHandler, settings.isTokenAutoRefreshEnabled else {
      return
    }

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
    lock.lock()
    defer { lock.unlock() }

    cancelTimer()

    let scheduleInSec = refreshDate.timeIntervalSinceNow

    if scheduleInSec <= 0 {
      refreshQueue.async { [weak self] in
        self?.refresh()
      }
      return
    }

    timer = timerProvider(refreshDate, refreshQueue) { [weak self] in
      self?.refresh()
    }
  }

  private func cancelTimer() {
    lock.lock()
    defer { lock.unlock() }

    timer?.invalidate()
    timer = nil
  }

  private func nextRefreshDate(with refreshResult: AppCheckCoreTokenRefreshResult) -> Date {
    switch refreshResult.status {
    case .success:
      guard let expirationDate = refreshResult.tokenExpirationDate,
            let receivedAtDate = refreshResult.tokenReceivedAtDate else {
        return Date()
      }

      var timeToLive = expirationDate.timeIntervalSince(receivedAtDate)
      timeToLive = max(timeToLive, 0)

      let targetRefreshSinceReceivedDate = timeToLive * kAutoRefreshFraction + 5 * 60
      let targetRefreshDate = receivedAtDate.addingTimeInterval(targetRefreshSinceReceivedDate)

      var refreshDate = min(targetRefreshDate, expirationDate)

      if refreshDate.timeIntervalSinceNow < kMinimumAutoRefreshTimeInterval {
        refreshDate = Date(timeIntervalSinceNow: kMinimumAutoRefreshTimeInterval)
      }
      return refreshDate

    case .failure:
      let backoffTime = AppCheckCoreTokenRefresher.backoffTime(forRetryCount: retryCount)
      return Date(timeIntervalSinceNow: backoffTime)

    case .never:
      return Date()

    @unknown default:
      return Date()
    }
  }

  private static func backoffTime(forRetryCount retryCount: Int) -> TimeInterval {
    if retryCount == 0 {
      return 0
    }

    let exponentialInterval = 30.0 * pow(2.0, Double(retryCount - 1)) + randomMilliseconds()
    return min(exponentialInterval, 16.0 * 60.0)
  }

  private static func randomMilliseconds() -> TimeInterval {
    let random_millis = abs(Int32.random(in: 0 ... 999))
    return Double(random_millis) * 0.001
  }
}
