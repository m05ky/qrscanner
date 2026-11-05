import Foundation

/// Folders used by the app. Everything stays in the app's private container.
enum Storage {
    static func appSupport() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static func caches() -> URL {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    /// Creates the folder when needed and returns it.
    static func folder(_ parent: URL, _ name: String) -> URL {
        let url = parent.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
