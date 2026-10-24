import Foundation
import NotchCore

/// Keeps the Tray as bookmarks in the user defaults. A bookmark follows its file when it's moved
/// or renamed, so a Tray item only goes once its file is deleted or moved to the Trash.
@MainActor
final class BookmarkTrayStore: TrayStore {
    private static let key = "trayBookmarks"
    /// The bookmark of each file in the Tray, by where the file was last found.
    private var bookmarks: [URL: Data] = [:]

    func load() -> [URL] {
        let saved = UserDefaults.standard.array(forKey: Self.key) as? [Data] ?? []
        return saved.compactMap { bookmark in
            guard let file = Self.resolve(bookmark) else { return nil }
            bookmarks[file] = bookmark
            return file
        }
    }

    func save(_ files: [URL]) {
        var saved: [URL: Data] = [:]
        for file in files {
            guard let bookmark = bookmarks[file] ?? (try? file.bookmarkData()) else { continue }
            saved[file] = bookmark
        }
        bookmarks = saved
        UserDefaults.standard.set(files.compactMap { saved[$0] }, forKey: Self.key)
    }

    func locate(_ file: URL) -> URL? {
        let now = bookmarks[file].flatMap(Self.resolve) ?? file
        guard FileManager.default.fileExists(atPath: now.path), !Self.isInTrash(now) else { return nil }
        if now != file { bookmarks[now] = bookmarks[file] }
        return now
    }

    private static func resolve(_ bookmark: Data) -> URL? {
        var isStale = false
        return try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting], bookmarkDataIsStale: &isStale)
    }

    /// The Trash is `~/.Trash` on the startup disk and `.Trashes` on other volumes.
    private static func isInTrash(_ file: URL) -> Bool {
        file.pathComponents.contains { $0 == ".Trash" || $0 == ".Trashes" }
    }
}
