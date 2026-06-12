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

@objc(GACAppCheckTimerProtocol)
public protocol AppCheckCoreTimerProtocol: NSObjectProtocol {
  @objc func invalidate()
}

public typealias AppCheckCoreTimerProvider = @Sendable (Date, DispatchQueue,
                                                        @escaping @Sendable () -> Void)
  -> AppCheckCoreTimerProtocol?

@objc(GACAppCheckTimer)
public final class AppCheckCoreTimer: NSObject, AppCheckCoreTimerProtocol, @unchecked Sendable {
  private let timer: DispatchSourceTimer

  @objc public static func timerProvider()
    -> @Sendable (Date, DispatchQueue, @escaping () -> Void) -> AppCheckCoreTimerProtocol? {
    return { fireDate, queue, handler in
      AppCheckCoreTimer(fireDate: fireDate, dispatchQueue: queue, block: handler)
    }
  }

  @objc public init?(fireDate date: Date, dispatchQueue: DispatchQueue,
                     block: @escaping () -> Void) {
    let scheduleInSec = date.timeIntervalSinceNow
    guard scheduleInSec > 0 else {
      return nil
    }

    let timer = DispatchSource.makeTimerSource(queue: dispatchQueue)
    self.timer = timer
    super.init()

    timer.schedule(deadline: .now() + scheduleInSec, repeating: .never)

    weak var weakSelf: AppCheckCoreTimer? = self
    timer.setEventHandler {
      guard let strongSelf = weakSelf else { return }
      strongSelf.invalidate()
      block()
    }
    timer.resume()
  }

  deinit {
    invalidate()
  }

  @objc public func invalidate() {
    timer.cancel()
  }
}
