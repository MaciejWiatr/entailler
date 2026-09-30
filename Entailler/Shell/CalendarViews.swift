import AppKit
import NotchCore
import SwiftUI

/// The Calendar Widget on Home: today's all-day events on one line, today's remaining events,
/// then tomorrow's first. Clicking an event opens it in Calendar; a meeting gets a Join button.
struct CalendarWidgetView: View {
    let calendar: CalendarWidget

    var body: some View {
        switch calendar {
        case .accessDenied:
            AccessDeniedView()
        case .agenda(let agenda):
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 4) {
                    if !agenda.allDay.isEmpty {
                        AllDayLine(events: agenda.allDay)
                    }
                    if agenda.today.isEmpty {
                        Text("Nothing else today")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                            .frame(height: EventRow.height)
                    }
                    ForEach(agenda.today, id: \.self) { event in
                        EventRow(event: event)
                    }
                    if let tomorrow = agenda.tomorrow {
                        Text("Tomorrow")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.gray)
                            .padding(.top, 2)
                        EventRow(event: tomorrow)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.never)
        }
    }
}

private struct AllDayLine: View {
    let events: [CalendarEvent]

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 10))
            Text(events.map(\.title).joined(separator: " · "))
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(.gray)
    }
}

/// An event's start time and title, and a Join button if it has a meeting link.
private struct EventRow: View {
    static let height: CGFloat = 20

    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 8) {
            Button {
                openInCalendar(event)
            } label: {
                HStack(spacing: 8) {
                    Text(event.start, format: .dateTime.hour().minute())
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.gray)
                    Text(event.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the event in Calendar")
            if let link = event.joinLink {
                Button("Join") {
                    NSWorkspace.shared.open(link)
                }
                .buttonStyle(JoinButtonStyle())
            }
        }
        .frame(height: Self.height)
    }
}

private struct JoinButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .frame(height: 18)
            .background(.green, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct AccessDeniedView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("No calendar access", systemImage: "calendar.badge.exclamationmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Text("Entailler can't show your events until you allow it in System Settings.")
                .font(.system(size: 11))
                .foregroundStyle(.gray)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Privacy Settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Opens `event` in Calendar.
private func openInCalendar(_ event: CalendarEvent) {
    let id = event.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? event.id
    guard let url = URL(string: "ical://ekevent/\(id)?method=show&options=more") else { return }
    NSWorkspace.shared.open(url)
}

/// The minutes left until an upcoming event starts, counting down beside the Notch.
struct EventCountdown: View {
    let start: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text("\(minutesLeft(at: context.date))m")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))
        }
    }

    /// Rounded up, so the last minute reads 1m rather than 0m.
    private func minutesLeft(at date: Date) -> Int {
        max(1, Int((start.timeIntervalSince(date) / 60).rounded(.up)))
    }
}
