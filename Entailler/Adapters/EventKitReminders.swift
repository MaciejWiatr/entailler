import AppKit
import EventKit
import NotchCore

/// The user's to-dos in Apple Reminders, through EventKit. Asks for access at launch the first
/// time Entailler runs.
@MainActor
final class EventKitReminders: ToDoSource {
    private let store = EKEventStore()
    private var observers: [any NSObjectProtocol] = []
    private var update: (@MainActor ([ToDo]?) -> Void)?
    /// Counts the reads, so a slow read that finishes after a later one doesn't overwrite it.
    private var latestRead = 0

    func start(_ update: @escaping @MainActor ([ToDo]?) -> Void) {
        self.update = update
        observers = [
            NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.read() }
            },
        ]
        guard EKEventStore.authorizationStatus(for: .reminder) == .notDetermined else {
            read()
            return
        }
        store.requestFullAccessToReminders { [weak self] _, _ in
            Task { @MainActor in self?.read() }
        }
    }

    func add(_ title: String, due: Date?, isDueAtTime: Bool) {
        guard hasAccess, let list = store.defaultCalendarForNewReminders() else { return }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = list
        if let due {
            // Reminders tells a day from a time of day by whether the components have an hour.
            let units: Set<Calendar.Component> = isDueAtTime
                ? [.calendar, .timeZone, .year, .month, .day, .hour, .minute]
                : [.calendar, .year, .month, .day]
            reminder.dueDateComponents = Calendar.current.dateComponents(units, from: due)
            // As Reminders does, a to-do due at a time reminds the user then.
            if isDueAtTime { reminder.addAlarm(EKAlarm(absoluteDate: due)) }
        }
        save(reminder)
    }

    func setDone(_ id: String, _ isDone: Bool) {
        guard hasAccess, let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        reminder.isCompleted = isDone
        save(reminder)
    }

    private var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }

    private func save(_ reminder: EKReminder) {
        do {
            try store.save(reminder, commit: true)
        } catch {
            NSLog("Entailler couldn't save a reminder: \(error)")
        }
        read()
    }

    /// Reads the to-dos not yet done from every list, and reports them.
    private func read() {
        guard hasAccess else {
            update?(nil)
            return
        }
        latestRead += 1
        let read = latestRead
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        store.fetchReminders(matching: predicate) { [weak self] reminders in
            let toDos = (reminders ?? []).map(ToDo.init)
            Task { @MainActor in
                guard let self, read == self.latestRead else { return }
                self.update?(toDos)
            }
        }
    }
}

private extension ToDo {
    init(_ reminder: EKReminder) {
        let due = reminder.dueDateComponents
        self.init(
            id: reminder.calendarItemIdentifier,
            title: reminder.title ?? "",
            due: due.flatMap { ($0.calendar ?? .current).date(from: $0) },
            isDueAtTime: due?.hour != nil,
            created: reminder.creationDate,
            list: reminder.calendar?.title ?? "",
            isDone: reminder.isCompleted
        )
    }
}
