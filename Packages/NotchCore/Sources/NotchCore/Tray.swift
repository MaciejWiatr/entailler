import Foundation

/// The files parked in the Tray, as references to the originals, with the ones the user selected.
public struct Tray: Equatable, Sendable {
    /// In the order they were dropped in.
    public var files: [URL] = []
    public var selection: Set<URL> = []

    public init(files: [URL] = [], selection: Set<URL> = []) {
        self.files = files
        self.selection = selection
    }
}

/// How a click on a Tray item changes the selection.
public enum TraySelection: Sendable {
    /// A plain click selects only the item.
    case only
    /// ⌘-click adds the item to the selection, or takes it out.
    case toggle
    /// ⇧-click adds every item from the last one clicked to this one.
    case range
}
