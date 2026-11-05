import Foundation

struct ExportRow {
    let time: Date
    let format: String
    let type: String
    let content: String
    let favorite: Bool
}

enum Export {
    private static func csvField(_ s: String) -> String {
        let needsQuotes = s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r")
        let body = s.replacingOccurrences(of: "\"", with: "\"\"")
        return needsQuotes ? "\"" + body + "\"" : body
    }

    private static func stamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }

    static func csv(_ rows: [ExportRow]) -> String {
        var out = "date,format,type,content,favorite\r\n"
        for r in rows {
            out += stamp(r.time) + "," + csvField(r.format) + "," + csvField(r.type) + "," + csvField(r.content) + ","
            out += (r.favorite ? "1" : "0") + "\r\n"
        }
        return out
    }

    static func txt(_ rows: [ExportRow]) -> String {
        var out = ""
        for r in rows {
            out += stamp(r.time) + "  [" + r.format + "]\n" + r.content + "\n\n"
        }
        return out
    }
}
