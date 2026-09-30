import Foundation
import NotchCore

/// The real clock: tells the wall-clock time and runs scheduled actions on the main actor after
/// a real delay.
@MainActor
final class SystemClock: NotchClock {
    var now: Date { Date() }

    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) -> any TimerHandle {
        TaskTimer(Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            action()
        })
    }
}

private final class TaskTimer: TimerHandle {
    private let task: Task<Void, Never>

    init(_ task: Task<Void, Never>) {
        self.task = task
    }

    func cancel() {
        task.cancel()
    }
}
