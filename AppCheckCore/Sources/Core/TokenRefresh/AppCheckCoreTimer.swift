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
  func invalidate()
}

public typealias AppCheckCoreTimerProvider = (Date, DispatchQueue, @escaping () -> Void)
  -> AppCheckCoreTimerProtocol?

@objc(GACAppCheckTimer)
@objcMembers
public class AppCheckCoreTimer: NSObject, AppCheckCoreTimerProtocol {
  private var timer: DispatchSourceTimer?

  public static func timerProvider() -> AppCheckCoreTimerProvider {
    return { fireDate, queue, handler in
      AppCheckCoreTimer(fireDate: fireDate, dispatchQueue: queue, block: handler)
    }
  }

  public init?(fireDate: Date, dispatchQueue: DispatchQueue, block: @escaping () -> Void) {
    let timeInterval = fireDate.timeIntervalSinceNow
    // Negative or zero time interval should fire immediately, but this timer class
    // expects positive intervals or handles immediate via `dispatch_async` in the caller.

    let timer = DispatchSource.makeTimerSource(queue: dispatchQueue)

    if timeInterval <= 0 {
      timer.schedule(deadline: .now())
    } else {
      timer.schedule(deadline: .now() + timeInterval)
    }

    timer.setEventHandler(handler: block)
    timer.resume()

    self.timer = timer
    super.init()
  }

  public func invalidate() {
    timer?.cancel()
    timer = nil
  }

  deinit {
    invalidate()
  }
}
