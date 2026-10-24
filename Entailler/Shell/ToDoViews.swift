import AppKit
import NotchCore
import SwiftUI

/// The Nook's To-Dos view: the user's to-dos from Apple Reminders, each ticked off with its
/// circle, over a field that adds a new one to the default list. A date written in the new
/// to-do, such as "tomorrow 5pm", becomes its due date. The arrow keys highlight a to-do, and
/// Return with nothing typed ticks it off.
struct ToDoListView: View {
    nonisolated static let height: CGFloat = CalendarMonthView.height

    /// `nil` without Reminders access.
    let toDos: [ToDo]?
    let setDone: (String, Bool) -> Void
    let add: (String) -> Void
    let quickAdd: (String) -> QuickAdd?

    /// The to-do the arrow keys moved to, if any.
    @State private var highlighted: String?

    var body: some View {
        if let toDos {
            VStack(alignment: .leading, spacing: 8) {
                list(toDos)
                NewToDoField(add: add, quickAdd: quickAdd) {
                    guard let toDo = toDos.first(where: { $0.id == highlighted }) else { return }
                    setDone(toDo.id, !toDo.isDone)
                }
            }
            .onKeyDown { event in moveHighlight(event, in: toDos) }
        } else {
            AccessDeniedView()
        }
    }

    private func list(_ toDos: [ToDo]) -> some View {
        // Ticks a minute, so "Today" and overdue to-dos keep up with the clock.
        TimelineView(.everyMinute) { context in
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 2) {
                        if toDos.isEmpty {
                            Text("Nothing to do")
                                .font(.system(size: 12))
                                .foregroundStyle(.gray)
                                .frame(height: ToDoRow.height)
                        }
                        ForEach(toDos, id: \.id) { toDo in
                            ToDoRow(
                                toDo: toDo,
                                now: context.date,
                                showsList: showsLists(toDos),
                                isHighlighted: toDo.id == highlighted
                            ) {
                                setDone(toDo.id, !toDo.isDone)
                            }
                            .id(toDo.id)
                            .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.spring(duration: 0.3, bounce: 0.2), value: toDos)
                }
                .scrollIndicators(.never)
                .onChange(of: highlighted) { _, id in
                    guard let id else { return }
                    withAnimation(.spring(duration: 0.3, bounce: 0)) { proxy.scrollTo(id) }
                }
            }
        }
    }

    /// ↓ highlights the next to-do and ↑ the one before; ↑ from the first goes back to the field.
    private func moveHighlight(_ event: NSEvent, in toDos: [ToDo]) -> Bool {
        guard event.heldModifiers.isEmpty, event.keyCode == 125 || event.keyCode == 126 else { return false }
        let index = toDos.firstIndex { $0.id == highlighted }
        let next = switch (event.keyCode, index) {
        case (125, nil): 0
        case (125, let index?): min(index + 1, toDos.count - 1)
        case (_, let index?) where index > 0: index - 1
        default: -1
        }
        withAnimation(.spring(duration: 0.2, bounce: 0)) {
            highlighted = toDos.indices.contains(next) ? toDos[next].id : nil
        }
        return true
    }

    /// Each to-do names its list only when they come from more than one.
    private func showsLists(_ toDos: [ToDo]) -> Bool {
        Set(toDos.map(\.list)).count > 1
    }
}

/// A to-do's circle, title and due date. The circle ticks it off, or unticks it.
private struct ToDoRow: View {
    static let height: CGFloat = 22

    let toDo: ToDo
    let now: Date
    let showsList: Bool
    let isHighlighted: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: toggle) {
                Image(systemName: toDo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(toDo.isDone ? Color.orange : .gray)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(toDo.isDone ? "Mark as not done" : "Mark as done")
            Text(toDo.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(toDo.isDone ? .gray : .white)
                .strikethrough(toDo.isDone, color: .gray)
                .lineLimit(1)
            Spacer(minLength: 0)
            if showsList {
                Text(toDo.list)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.gray)
                    .lineLimit(1)
            }
            if let due = toDo.due {
                dueText(due, isDueAtTime: toDo.isDueAtTime, now: now)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(isOverdue(due) && !toDo.isDone ? .red : .gray)
            }
        }
        .frame(height: Self.height)
        .padding(.horizontal, 6)
        .background(isHighlighted ? Color.white.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 6))
    }

    /// A to-do due on a day is overdue once that day is over.
    private func isOverdue(_ due: Date) -> Bool {
        toDo.isDueAtTime ? due < now : due < Calendar.current.startOfDay(for: now)
    }
}

/// When a to-do is due, relative to `now`: "Today", "Tomorrow 17:00", "15 Oct".
private func dueText(_ due: Date, isDueAtTime: Bool, now: Date) -> Text {
    let calendar = Calendar.current
    let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: due)).day ?? 0
    let time = Text(due, format: .dateTime.hour().minute())
    let day: Text = switch days {
    case -1: Text("Yesterday")
    case 0: isDueAtTime ? time : Text("Today")
    case 1: Text("Tomorrow")
    default: Text(due, format: .dateTime.day().month(.abbreviated))
    }
    return isDueAtTime && days != 0 ? Text("\(day) \(time)") : day
}

/// A field that adds a to-do on Return, then empties itself for the next one. It has the
/// keyboard as soon as it appears. While a date is
/// written in it, the due date it makes shows at the field's end.
private struct NewToDoField: View {
    let add: (String) -> Void
    let quickAdd: (String) -> QuickAdd?
    /// Return with nothing typed.
    let submitEmpty: () -> Void

    @State private var title = ""
    @FocusState private var isFocused: Bool

    private var due: (date: Date, isDueAtTime: Bool)? {
        quickAdd(title).flatMap { toDo in toDo.due.map { ($0, toDo.isDueAtTime) } }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.gray)
                .frame(width: 18)
            TextField("", text: $title, prompt: Text("New To-Do").foregroundStyle(.gray))
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .focused($isFocused)
                .onSubmit {
                    guard !title.allSatisfy(\.isWhitespace) else {
                        submitEmpty()
                        return
                    }
                    add(title)
                    title = ""
                }
                // Ready to type into as soon as the To-Dos view opens. When the window already has
                // the keyboard, the field can only take it once it's in place, a moment after it
                // appears; otherwise the window takes the keyboard just after.
                .task { isFocused = true }
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
                    isFocused = true
                }
            if let due {
                Label {
                    dueText(due.date, isDueAtTime: due.isDueAtTime, now: .now)
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(.black)
                .padding(.horizontal, 7)
                .frame(height: 18)
                .background(Color.orange, in: Capsule())
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.25, bounce: 0.2), value: due?.date)
        .frame(height: 24)
        .padding(.horizontal, 6)
        .background(.white.opacity(0.08), in: Capsule())
    }
}

private struct AccessDeniedView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("No Reminders access", systemImage: "checklist")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Text("Entailler can't show your to-dos until you allow it in System Settings.")
                .font(.system(size: 11))
                .foregroundStyle(.gray)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Privacy Settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")!)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
