import UIKit

/// Stores the two pictures of a scan as JPEG files: `<id>_frame.jpg` (frame with the code outlined) and
/// `<id>_code.jpg` (cropped code). Saved scans live in Application Support; the scan shown while history is
/// switched off goes to the caches folder.
enum ScanImages {
    enum Kind: String {
        case frame
        case code
    }

    private static func dir(_ id: Int64) -> URL {
        if id == HistoryStore.transientId {
            return Storage.folder(Storage.caches(), "scan-transient")
        }
        return Storage.folder(Storage.appSupport(), "scans")
    }

    private static func file(_ id: Int64, _ kind: Kind) -> URL {
        let name = id == HistoryStore.transientId ? "current" : String(id)
        return dir(id).appendingPathComponent("\(name)_\(kind.rawValue).jpg")
    }

    /// Writes both pictures; returns true when both were stored.
    @discardableResult
    static func save(id: Int64, capture: ScanCapture) -> Bool {
        guard let frame = capture.frame.jpegData(compressionQuality: 0.82),
              let code = capture.code.jpegData(compressionQuality: 0.9) else { return false }
        do {
            try frame.write(to: file(id, .frame), options: .atomic)
            try code.write(to: file(id, .code), options: .atomic)
            return true
        } catch {
            delete(id: id)
            return false
        }
    }

    static func load(id: Int64, kind: Kind) -> UIImage? {
        let url = file(id, kind)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    static func delete(id: Int64) {
        try? FileManager.default.removeItem(at: file(id, .frame))
        try? FileManager.default.removeItem(at: file(id, .code))
    }

    static func deleteAll() {
        let url = Storage.appSupport().appendingPathComponent("scans", isDirectory: true)
        try? FileManager.default.removeItem(at: url)
    }
}
