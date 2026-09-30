import Foundation

/// Tells the time and schedules work after a delay. Injected into the core so tests control time.
@MainActor
public protocol NotchClock: AnyObject {
    var now: Date { get }
    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) -> any TimerHandle
}

/// A pending action scheduled on a `NotchClock`.
@MainActor
public protocol TimerHandle: AnyObject {
    func cancel()
}
