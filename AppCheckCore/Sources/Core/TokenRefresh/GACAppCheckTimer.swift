import Foundation

@objc(GACAppCheckTimerProtocol)
public protocol GACAppCheckTimerProtocol: NSObjectProtocol {
    func invalidate()
}

public typealias GACTimerProvider = (Date, DispatchQueue, @escaping () -> Void) -> GACAppCheckTimerProtocol?

@objc(GACAppCheckTimer)
@objcMembers
public class GACAppCheckTimer: NSObject, GACAppCheckTimerProtocol {
    private var timer: DispatchSourceTimer?

    @objc public static func timerProvider() -> GACTimerProvider {
        return { fireDate, queue, handler in
            return GACAppCheckTimer(fireDate: fireDate, dispatchQueue: queue, block: handler)
        }
    }

    @objc public init?(fireDate: Date, dispatchQueue: DispatchQueue, block: @escaping () -> Void) {
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

    @objc public func invalidate() {
        timer?.cancel()
        timer = nil
    }
    
    deinit {
        invalidate()
    }
}
