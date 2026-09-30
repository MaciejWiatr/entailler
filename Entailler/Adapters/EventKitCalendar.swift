import AppKit
import EventKit
import NotchCore

/// Events from all of the user's calendars, through EventKit. Asks for access at launch the
/// first time Entailler runs.
@MainActor
final class EventKitCalendar: CalendarSource {
    private let store = EKEventStore()
    private var observers: [any NSObjectProtocol] = []

    func start(_ update: @escaping @MainActor (CalendarAccess) -> Void) {
        let report = { @MainActor in
            update(EKEventStore.authorizationStatus(for: .event) == .fullAccess ? .granted : .denied)
        }
        // Besides event changes, the core also looks again when the day changes or the clock
        // jumps, such as after the Mac wakes, since its timers don't follow the wall clock.
        let center = NotificationCenter.default
        observers = [
            (center, Notification.Name.EKEventStoreChanged),
            (center, .NSCalendarDayChanged),
            (center, .NSSystemClockDidChange),
            (center, .NSSystemTimeZoneDidChange),
            (NSWorkspace.shared.notificationCenter, NSWorkspace.didWakeNotification),
        ].map { center, name in
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { report() }
            }
        }
        guard EKEventStore.authorizationStatus(for: .event) == .notDetermined else {
            report()
            return
        }
        store.requestFullAccessToEvents { _, _ in
            Task { @MainActor in report() }
        }
    }

    func events(in interval: DateInterval) -> [CalendarEvent] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: nil)
        return store.events(matching: predicate).map { event in
            CalendarEvent(
                id: event.eventIdentifier ?? event.calendarItemIdentifier,
                title: event.title ?? "",
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                url: event.url,
                location: event.location,
                notes: event.notes
            )
        }
    }
}
