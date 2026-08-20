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

  private let lock = NSLock()

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
      _tokenRefreshHandler = newValue

      if newValue != nil, let initialResult = initialRefreshResult {
        initialRefreshResult = nil
        lock.unlock()
        schedule(with: initialResult)
      } else {
        lock.unlock()
      }
    }
  }

  @objc(updateWithRefreshResult:)
  public func updateWithRefreshResult(_ refreshResult: AppCheckCoreTokenRefreshResult) {
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

      var refreshDate = targetRefreshDate
        .compare(expirationDate) == .orderedAscending ? targetRefreshDate : expirationDate

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
