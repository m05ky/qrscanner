import Foundation

/// Optional feature: fetches the <title> of a scanned web page. Only runs when the user enables it.
enum UrlInfo {
    static func fetchTitle(_ urlString: String, completion: @escaping (String) -> Void) {
        guard let url = URL(string: urlString), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.setValue("Mozilla/5.0 (iPhone) QRScanner", forHTTPHeaderField: "User-Agent")
        request.setValue("bytes=0-65535", forHTTPHeaderField: "Range")
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else { return }
            let head = data.prefix(65536)
            let html = String(decoding: head, as: UTF8.self)
            if let title = parseTitle(html), !title.isEmpty {
                DispatchQueue.main.async { completion(title) }
            }
        }.resume()
    }

    static func parseTitle(_ html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "<title[^>]*>(.*?)</title>", options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return nil }
        let ns = html as NSString
        guard let m = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: ns.length)), m.numberOfRanges > 1 else { return nil }
        var t = ns.substring(with: m.range(at: 1))
        t = t.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        t = t.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        return String(t.prefix(200))
    }
}
