import Foundation

/// Builds the payload strings for the create presets.
enum ContentBuilder {

    private static func wifiEscape(_ s: String) -> String {
        var sb = ""
        for c in s {
            if c == "\\" || c == ";" || c == "," || c == ":" || c == "\"" { sb.append("\\") }
            sb.append(c)
        }
        return sb
    }

    /// `encryption` is "WPA", "WEP" or "NONE".
    static func wifi(ssid: String, password: String, encryption: String, hidden: Bool) -> String {
        var sb = "WIFI:"
        if encryption == "NONE" {
            sb += "T:nopass;"
        } else {
            sb += "T:" + encryption + ";"
        }
        sb += "S:" + wifiEscape(ssid) + ";"
        if encryption != "NONE" && !password.isEmpty { sb += "P:" + wifiEscape(password) + ";" }
        if hidden { sb += "H:true;" }
        sb += ";"
        return sb
    }

    private static func vEscape(_ s: String) -> String {
        return s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func isBlank(_ s: String) -> Bool {
        return s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func vcard(name: String, org: String = "", phone: String = "", email: String = "", address: String = "", website: String = "") -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var last = ""
        var first = trimmed
        if let i = trimmed.lastIndex(of: " ") {
            last = String(trimmed[trimmed.index(after: i)...])
            first = String(trimmed[trimmed.startIndex..<i])
        }
        var sb = "BEGIN:VCARD\nVERSION:3.0\n"
        sb += "N:" + vEscape(last) + ";" + vEscape(first) + ";;;\n"
        sb += "FN:" + vEscape(trimmed) + "\n"
        if !isBlank(org) { sb += "ORG:" + vEscape(org.trimmingCharacters(in: .whitespacesAndNewlines)) + "\n" }
        if !isBlank(phone) { sb += "TEL:" + vEscape(phone.trimmingCharacters(in: .whitespacesAndNewlines)) + "\n" }
        if !isBlank(email) { sb += "EMAIL:" + vEscape(email.trimmingCharacters(in: .whitespacesAndNewlines)) + "\n" }
        if !isBlank(address) { sb += "ADR:;;" + vEscape(address.trimmingCharacters(in: .whitespacesAndNewlines)) + ";;;;\n" }
        if !isBlank(website) { sb += "URL:" + vEscape(website.trimmingCharacters(in: .whitespacesAndNewlines)) + "\n" }
        sb += "END:VCARD"
        return sb
    }

    private static let pctAllowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789*-._")

    static func pct(_ s: String) -> String {
        return s.addingPercentEncoding(withAllowedCharacters: pctAllowed) ?? s
    }

    static func email(to: String, subject: String = "", body: String = "") -> String {
        var params: [String] = []
        if !subject.isEmpty { params.append("subject=" + pct(subject)) }
        if !body.isEmpty { params.append("body=" + pct(body)) }
        let tail = params.isEmpty ? "" : "?" + params.joined(separator: "&")
        return "mailto:" + to.trimmingCharacters(in: .whitespacesAndNewlines) + tail
    }

    static func sms(number: String, message: String = "") -> String {
        return "smsto:" + number.trimmingCharacters(in: .whitespacesAndNewlines) + ":" + message
    }

    static func phone(_ number: String) -> String {
        return "tel:" + number.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func geo(lat: Double, lng: Double) -> String {
        return "geo:" + trimNumber(lat) + "," + trimNumber(lng)
    }

    private static func trimNumber(_ d: Double) -> String {
        var s = String(format: "%.6f", d)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        if s == "-0" || s.isEmpty { return "0" }
        return s
    }

    /// Input format used by the event form: "yyyy-MM-dd HH:mm" (local time). Returns nil when invalid.
    static func toIcalLocal(_ input: String) -> String? {
        let inFmt = DateFormatter()
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        inFmt.dateFormat = "yyyy-MM-dd HH:mm"
        inFmt.isLenient = false
        guard let date = inFmt.date(from: input.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US_POSIX")
        out.dateFormat = "yyyyMMdd'T'HHmmss"
        return out.string(from: date)
    }

    static func event(title: String, startIcal: String, endIcal: String, location: String = "", description: String = "") -> String {
        var sb = "BEGIN:VCALENDAR\nVERSION:2.0\nBEGIN:VEVENT\n"
        sb += "SUMMARY:" + vEscape(title.trimmingCharacters(in: .whitespacesAndNewlines)) + "\n"
        sb += "DTSTART:" + startIcal + "\n"
        if !endIcal.isEmpty { sb += "DTEND:" + endIcal + "\n" }
        if !isBlank(location) { sb += "LOCATION:" + vEscape(location.trimmingCharacters(in: .whitespacesAndNewlines)) + "\n" }
        if !isBlank(description) { sb += "DESCRIPTION:" + vEscape(description.trimmingCharacters(in: .whitespacesAndNewlines)) + "\n" }
        sb += "END:VEVENT\nEND:VCALENDAR"
        return sb
    }
}
