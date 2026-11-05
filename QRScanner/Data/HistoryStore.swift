import Foundation

struct ScanEntry: Identifiable, Codable, Equatable {
    var id: Int64
    var content: String
    var formatRaw: String
    /// seconds since 1970
    var time: Double
    var favorite: Bool
    /// Optional extra info, e.g. the title of a scanned web page.
    var info: String
    /// True when the frame / code pictures of this scan are stored (see ScanImages).
    var hasImages: Bool

    var format: CodeFormat { return CodeFormat(rawValue: formatRaw) ?? .QR_CODE }
    var date: Date { return Date(timeIntervalSince1970: time) }
    var parsed: Parsed { return ContentParser.parse(content, format: format) }
}

/// Small JSON-file store; the data set is tiny so everything is kept in memory.
final class HistoryStore: ObservableObject {
    static let transientId: Int64 = -1

    @Published private(set) var entries: [ScanEntry] = []
    /// Scan shown on the result screen while history is switched off (id = transientId).
    @Published var transient: ScanEntry?

    private var nextId: Int64 = 1
    private let fileURL: URL

    init() {
        fileURL = Storage.appSupport().appendingPathComponent("history.json")
        load()
    }

    // MARK: persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([ScanEntry].self, from: data) else { return }
        entries = sorted(list)
        nextId = (list.map { $0.id }.max() ?? 0) + 1
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func sorted(_ list: [ScanEntry]) -> [ScanEntry] {
        return list.sorted { a, b in
            if a.time != b.time { return a.time > b.time }
            return a.id > b.id
        }
    }

    private func commit(_ list: [ScanEntry]) {
        entries = sorted(list)
        save()
    }

    // MARK: access

    func get(_ id: Int64) -> ScanEntry? {
        if id == HistoryStore.transientId { return transient }
        return entries.first { $0.id == id }
    }

    /// Stores a scan. When `keepDuplicates` is false and the same code is already stored, that row is moved to the
    /// top instead of adding a new one. `capture` replaces the pictures of an existing duplicate. Returns the row id.
    @discardableResult
    func add(content: String, format: CodeFormat, keepDuplicates: Bool, capture: ScanCapture?) -> Int64 {
        let now = Date().timeIntervalSince1970
        var list = entries
        if !keepDuplicates, let idx = list.firstIndex(where: { $0.content == content && $0.formatRaw == format.rawValue }) {
            list[idx].time = now
            if let c = capture, ScanImages.save(id: list[idx].id, capture: c) { list[idx].hasImages = true }
            let id = list[idx].id
            commit(list)
            return id
        }
        let id = nextId
        nextId += 1
        var entry = ScanEntry(id: id, content: content, formatRaw: format.rawValue, time: now, favorite: false, info: "", hasImages: false)
        if let c = capture, ScanImages.save(id: id, capture: c) { entry.hasImages = true }
        list.append(entry)
        commit(list)
        return id
    }

    /// Keeps the scan for the result screen only (history switched off); its pictures go to the caches folder.
    func setTransient(content: String, format: CodeFormat, capture: ScanCapture?) {
        var stored = false
        if let c = capture { stored = ScanImages.save(id: HistoryStore.transientId, capture: c) }
        if !stored { ScanImages.delete(id: HistoryStore.transientId) }
        transient = ScanEntry(
            id: HistoryStore.transientId, content: content, formatRaw: format.rawValue,
            time: Date().timeIntervalSince1970, favorite: false, info: "", hasImages: stored
        )
    }

    func setFavorite(_ id: Int64, _ favorite: Bool) {
        if id == HistoryStore.transientId {
            transient?.favorite = favorite
            return
        }
        var list = entries
        if let i = list.firstIndex(where: { $0.id == id }) {
            list[i].favorite = favorite
            commit(list)
        }
    }

    func setInfo(_ id: Int64, _ info: String) {
        if id == HistoryStore.transientId {
            transient?.info = info
            return
        }
        var list = entries
        if let i = list.firstIndex(where: { $0.id == id }) {
            list[i].info = info
            commit(list)
        }
    }

    func delete(_ id: Int64) {
        ScanImages.delete(id: id)
        commit(entries.filter { $0.id != id })
    }

    func deleteMany(_ ids: [Int64]) {
        if ids.isEmpty { return }
        let doomed = Set(ids)
        for id in ids { ScanImages.delete(id: id) }
        commit(entries.filter { !doomed.contains($0.id) })
    }

    func deleteAll(onlyNonFavorites: Bool = false) {
        if onlyNonFavorites {
            for e in entries where !e.favorite { ScanImages.delete(id: e.id) }
            commit(entries.filter { $0.favorite })
        } else {
            ScanImages.deleteAll()
            commit([])
        }
    }
}
