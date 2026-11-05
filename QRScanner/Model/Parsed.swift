import Foundation

struct WifiInfo {
    var ssid: String
    var password: String
    /// "WPA", "WEP" or "NONE"
    var encryption: String
    var hidden: Bool
}

struct ContactInfo {
    var name: String
    var org: String
    var phones: [String]
    var emails: [String]
    var address: String
    var website: String
    var note: String
}

struct EmailInfo {
    var to: String
    var subject: String
    var body: String
}

struct SmsInfo {
    var number: String
    var message: String
}

struct GeoInfo {
    var lat: Double
    var lng: Double
    var query: String
}

struct EventInfo {
    var title: String
    var start: String
    var end: String
    var location: String
    var description: String

    var startDate: Date? { return ContentParser.icalToDate(start) }
    var endDate: Date? { return ContentParser.icalToDate(end) }
    var allDay: Bool { return start.count == 8 }
}

/// Structured interpretation of a scanned string.
enum Parsed {
    case text(String)
    case url(raw: String, url: String)
    case wifi(WifiInfo)
    case contact(ContactInfo)
    case email(EmailInfo)
    case sms(SmsInfo)
    case geo(GeoInfo)
    case phone(String)
    case event(EventInfo)
    case product(String)

    var type: ContentType {
        switch self {
        case .text: return .text
        case .url: return .url
        case .wifi: return .wifi
        case .contact: return .contact
        case .email: return .email
        case .sms: return .sms
        case .geo: return .geo
        case .phone: return .phone
        case .event: return .event
        case .product: return .product
        }
    }
}

extension String {
    /// Text before the first occurrence of `c`, or the whole string.
    func substringBefore(_ c: Character) -> String {
        if let i = self.firstIndex(of: c) { return String(self[self.startIndex..<i]) }
        return self
    }

    /// Text after the first occurrence of `c`, or the whole string.
    func substringAfter(_ c: Character) -> String {
        if let i = self.firstIndex(of: c) { return String(self[self.index(after: i)...]) }
        return self
    }

    /// Text after the last occurrence of `c`, or the whole string.
    func substringAfterLast(_ c: Character) -> String {
        if let i = self.lastIndex(of: c) { return String(self[self.index(after: i)...]) }
        return self
    }

    func dropFirstChars(_ n: Int) -> String {
        return String(self.dropFirst(n))
    }
}

enum ContentParser {

    private static let emailPattern = "^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$"
    private static let urlPattern = "^(https?://|www\\.)\\S+$"

    private static func matches(_ pattern: String, _ text: String, caseInsensitive: Bool = false) -> Bool {
        var options: String.CompareOptions = [.regularExpression]
        if caseInsensitive { options.insert(.caseInsensitive) }
        return text.range(of: pattern, options: options) != nil
    }

    static func parse(_ raw: String, format: CodeFormat) -> Parsed {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = t.uppercased()
        if upper.hasPrefix("WIFI:") { return parseWifi(t) }
        if upper.hasPrefix("BEGIN:VCARD") { return parseVCard(t) }
        if upper.hasPrefix("MECARD:") { return parseMeCard(t) }
        if upper.hasPrefix("BEGIN:VEVENT") || upper.hasPrefix("BEGIN:VCALENDAR") { return parseEvent(t) }
        if upper.hasPrefix("MAILTO:") { return parseMailto(t) }
        if upper.hasPrefix("MATMSG:") { return parseMatmsg(t) }
        if upper.hasPrefix("SMSTO:") || upper.hasPrefix("SMS:") || upper.hasPrefix("MMSTO:") { return parseSms(t) }
        if upper.hasPrefix("GEO:") { return parseGeo(raw, t) }
        if upper.hasPrefix("TEL:") { return .phone(t.dropFirstChars(4).trimmingCharacters(in: .whitespaces)) }
        if matches(urlPattern, t, caseInsensitive: true) { return .url(raw: raw, url: t) }
        if format != .QR_CODE && matches(emailPattern, t) { return .email(EmailInfo(to: t, subject: "", body: "")) }
        if format.isProduct && !t.isEmpty && t.allSatisfy({ $0.isNumber }) { return .product(t) }
        return .text(raw)
    }

    /// URL with a scheme, suitable for opening.
    static func openUrl(_ url: String) -> String {
        return url.contains("://") ? url : "https://" + url
    }

    // MARK: Wi-Fi

    private static func parseWifi(_ t: String) -> Parsed {
        let fields = splitEscaped(t.dropFirstChars(5), sep: ";")
        var type = ""
        var ssid = ""
        var pass = ""
        var hidden = false
        for f in fields {
            guard let i = f.firstIndex(of: ":") else { continue }
            let key = String(f[f.startIndex..<i]).uppercased()
            let value = unescape(String(f[f.index(after: i)...]))
            switch key {
            case "T": type = value
            case "S": ssid = value
            case "P": pass = value
            case "H": hidden = value.lowercased() == "true"
            default: break
            }
        }
        let enc: String
        if type.lowercased() == "nopass" || (type.isEmpty && pass.isEmpty) {
            enc = "NONE"
        } else if type.uppercased().hasPrefix("WEP") {
            enc = "WEP"
        } else {
            enc = "WPA"
        }
        return .wifi(WifiInfo(ssid: ssid, password: pass, encryption: enc, hidden: hidden))
    }

    // MARK: Contacts

    private static func unfold(_ text: String) -> [String] {
        var out: [String] = []
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        for line in normalized.components(separatedBy: "\n") {
            if (line.hasPrefix(" ") || line.hasPrefix("\t")) && !out.isEmpty {
                out[out.count - 1] = out[out.count - 1] + String(line.dropFirst())
            } else {
                out.append(line)
            }
        }
        return out
    }

    private static func vValue(_ s: String) -> String {
        return s.replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    private static func joinedParts(_ value: String) -> String {
        let parts = splitEscaped(value, sep: ";").map { vValue($0).trimmingCharacters(in: .whitespaces) }
        return parts.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    private static func parseVCard(_ t: String) -> Parsed {
        var fn = ""
        var n = ""
        var org = ""
        var adr = ""
        var url = ""
        var note = ""
        var phones: [String] = []
        var emails: [String] = []
        for line in unfold(t) {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let head = String(line[line.startIndex..<colon])
            let key = head.substringBefore(";").uppercased().substringAfterLast(".")
            let value = String(line[line.index(after: colon)...])
            switch key {
            case "FN":
                fn = vValue(value).trimmingCharacters(in: .whitespaces)
            case "N":
                let p = splitEscaped(value, sep: ";").map { vValue($0).trimmingCharacters(in: .whitespaces) }
                let family = p.count > 0 ? p[0] : ""
                let given = p.count > 1 ? p[1] : ""
                n = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
            case "ORG":
                org = joinedParts(value)
            case "TEL":
                if !value.trimmingCharacters(in: .whitespaces).isEmpty { phones.append(vValue(value).trimmingCharacters(in: .whitespaces)) }
            case "EMAIL":
                if !value.trimmingCharacters(in: .whitespaces).isEmpty { emails.append(vValue(value).trimmingCharacters(in: .whitespaces)) }
            case "ADR":
                adr = joinedParts(value)
            case "URL":
                if url.isEmpty { url = vValue(value).trimmingCharacters(in: .whitespaces) }
            case "NOTE":
                note = vValue(value).trimmingCharacters(in: .whitespaces)
            default:
                break
            }
        }
        let name = fn.isEmpty ? n : fn
        return .contact(ContactInfo(name: name, org: org, phones: phones, emails: emails, address: adr, website: url, note: note))
    }

    private static func parseMeCard(_ t: String) -> Parsed {
        var name = ""
        var adr = ""
        var url = ""
        var note = ""
        var phones: [String] = []
        var emails: [String] = []
        for f in splitEscaped(t.dropFirstChars(7), sep: ";") {
            guard let i = f.firstIndex(of: ":") else { continue }
            let key = String(f[f.startIndex..<i]).uppercased()
            let value = unescape(String(f[f.index(after: i)...])).trimmingCharacters(in: .whitespaces)
            switch key {
            case "N":
                let parts = value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                name = parts.reversed().filter { !$0.isEmpty }.joined(separator: " ")
            case "TEL": phones.append(value)
            case "EMAIL": emails.append(value)
            case "ADR":
                let parts = value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                adr = parts.filter { !$0.isEmpty }.joined(separator: ", ")
            case "URL": url = value
            case "NOTE": note = value
            default: break
            }
        }
        return .contact(ContactInfo(name: name, org: "", phones: phones, emails: emails, address: adr, website: url, note: note))
    }

    // MARK: Events

    private static func parseEvent(_ t: String) -> Parsed {
        var title = ""
        var start = ""
        var end = ""
        var location = ""
        var desc = ""
        for line in unfold(t) {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[line.startIndex..<colon]).substringBefore(";").uppercased()
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            switch key {
            case "SUMMARY": title = vValue(value)
            case "DTSTART": start = value
            case "DTEND": end = value
            case "LOCATION": location = vValue(value)
            case "DESCRIPTION": desc = vValue(value)
            default: break
            }
        }
        return .event(EventInfo(title: title, start: start, end: end, location: location, description: desc))
    }

    /// Converts iCalendar "20260101T120000Z" / "20260101T120000" / "20260101" to a date.
    static func icalToDate(_ value: String) -> Date? {
        if value.trimmingCharacters(in: .whitespaces).isEmpty { return nil }
        let utc = value.hasSuffix("Z")
        let v = utc ? String(value.dropLast()) : value
        let pattern: String
        switch v.count {
        case 8: pattern = "yyyyMMdd"
        case 15: pattern = "yyyyMMdd'T'HHmmss"
        default: return nil
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = pattern
        f.isLenient = false
        if utc || v.count == 8 { f.timeZone = TimeZone(identifier: "UTC") }
        return f.date(from: v)
    }

    // MARK: Mail / SMS / Geo

    private static func pctDecode(_ s: String) -> String {
        let prepared = s.replacingOccurrences(of: "+", with: "%2B")
        return prepared.removingPercentEncoding ?? s
    }

    private static func queryParams(_ q: String) -> [String: String] {
        var map: [String: String] = [:]
        for part in q.components(separatedBy: "&") {
            if part.isEmpty { continue }
            guard let i = part.firstIndex(of: "=") else { continue }
            let key = String(part[part.startIndex..<i]).lowercased()
            map[key] = pctDecode(String(part[part.index(after: i)...]))
        }
        return map
    }

    private static func parseMailto(_ t: String) -> Parsed {
        let rest = t.dropFirstChars(7)
        let to = pctDecode(rest.substringBefore("?"))
        var params: [String: String] = [:]
        if rest.contains("?") { params = queryParams(rest.substringAfter("?")) }
        return .email(EmailInfo(to: to, subject: params["subject"] ?? "", body: params["body"] ?? ""))
    }

    private static func parseMatmsg(_ t: String) -> Parsed {
        var to = ""
        var sub = ""
        var body = ""
        for f in splitEscaped(t.dropFirstChars(7), sep: ";") {
            guard let i = f.firstIndex(of: ":") else { continue }
            let v = unescape(String(f[f.index(after: i)...]))
            switch String(f[f.startIndex..<i]).uppercased() {
            case "TO": to = v
            case "SUB": sub = v
            case "BODY": body = v
            default: break
            }
        }
        return .email(EmailInfo(to: to, subject: sub, body: body))
    }

    private static func parseSms(_ t: String) -> Parsed {
        let rest = t.substringAfter(":")
        if rest.contains("?") {
            let number = rest.substringBefore("?")
            let body = queryParams(rest.substringAfter("?"))["body"] ?? ""
            return .sms(SmsInfo(number: number, message: body))
        }
        if let i = rest.firstIndex(of: ":") {
            return .sms(SmsInfo(number: String(rest[rest.startIndex..<i]), message: String(rest[rest.index(after: i)...])))
        }
        return .sms(SmsInfo(number: rest, message: ""))
    }

    private static func parseGeo(_ raw: String, _ t: String) -> Parsed {
        let rest = t.dropFirstChars(4)
        let coords = rest.substringBefore("?").substringBefore(";").components(separatedBy: ",")
        let lat: Double? = coords.count > 0 ? Double(coords[0].trimmingCharacters(in: .whitespaces)) : nil
        let lng: Double? = coords.count > 1 ? Double(coords[1].trimmingCharacters(in: .whitespaces)) : nil
        guard let la = lat, let ln = lng else { return .text(raw) }
        var q = ""
        if rest.contains("?") { q = queryParams(rest.substringAfter("?"))["q"] ?? "" }
        return .geo(GeoInfo(lat: la, lng: ln, query: q))
    }

    // MARK: helpers

    /// Splits on `sep` but keeps backslash-escaped separators inside the pieces (escapes preserved).
    static func splitEscaped(_ s: String, sep: Character) -> [String] {
        var out: [String] = []
        var cur = ""
        let chars = Array(s)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\\" && i + 1 < chars.count {
                cur.append(c)
                cur.append(chars[i + 1])
                i += 2
                continue
            }
            if c == sep {
                out.append(cur)
                cur = ""
            } else {
                cur.append(c)
            }
            i += 1
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }

    static func unescape(_ s: String) -> String {
        var sb = ""
        let chars = Array(s)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\\" && i + 1 < chars.count {
                sb.append(chars[i + 1])
                i += 2
            } else {
                sb.append(c)
                i += 1
            }
        }
        return sb
    }
}
