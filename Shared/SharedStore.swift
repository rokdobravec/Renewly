import Foundation

/// Locations and settings shared between the app and its widget through the App Group.
enum SharedStore {
    static let appGroup = "group.com.rokdobravec.renewly"

    /// Defaults the widget can read; the app mirrors the settings it needs into them.
    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    /// The SwiftData store, kept in the App Group container so the widget can open it.
    static var storeURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? URL.applicationSupportDirectory
        let directory = base.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "Renewly.store")
    }

    /// Moves a store created before the App Group existed (the SwiftData default location) into the shared container.
    static func migrateLegacyStoreIfNeeded() {
        let manager = FileManager.default
        let legacy = URL.applicationSupportDirectory.appending(path: "default.store")
        let target = storeURL
        guard legacy != target,
              manager.fileExists(atPath: legacy.path(percentEncoded: false)),
              !manager.fileExists(atPath: target.path(percentEncoded: false)) else { return }
        // SQLite keeps recent writes in the -wal file, so move the sidecars along with the store.
        for suffix in ["", "-shm", "-wal"] {
            let source = URL(filePath: legacy.path(percentEncoded: false) + suffix)
            guard manager.fileExists(atPath: source.path(percentEncoded: false)) else { continue }
            try? manager.moveItem(at: source, to: URL(filePath: target.path(percentEncoded: false) + suffix))
        }
    }
}

enum AppSettings {
    static let currencyKey = "currencyCode"
    static var defaultCurrency: String { Locale.current.currency?.identifier ?? "USD" }

    /// The currency the user picked, as mirrored into the shared defaults for the widget.
    static var sharedCurrency: String { SharedStore.defaults.string(forKey: currencyKey) ?? defaultCurrency }
}

extension Double {
    func currency(_ code: String) -> String {
        formatted(.currency(code: code))
    }
}
