import SwiftUI

/// UserDefaults-backed settings that SwiftUI observes.
final class AppSettings: ObservableObject {

    /// Accent colors offered in settings (same order as the swatch grid).
    static let palette: [UInt32] = [
        0xFF0069FF, 0xFFD50000, 0xFFF4511E, 0xFFF6BF26, 0xFF0B8043, 0xFF33B679,
        0xFF039BE5, 0xFF3F51B5, 0xFF7986CB, 0xFF8E24AA, 0xFFE67C73, 0xFF82C8FF,
    ]

    /// Search engines offered for "Search web".
    static let engineNames: [String] = ["Google", "Bing", "DuckDuckGo", "Ecosia", "Startpage", "Brave"]

    static let countries: [String] = [
        "", "US", "GB", "DE", "AT", "CH", "FR", "ES", "IT", "NL", "BE", "PL", "SE", "NO", "DK", "FI",
        "PT", "IE", "CA", "AU", "BR", "IN", "JP", "TR",
    ]

    // Appearance
    @Published var colorIndex: Int { didSet { UserDefaults.standard.set(colorIndex, forKey: "color_index") } }
    /// 0 system, 1 light, 2 dark
    @Published var theme: Int { didSet { UserDefaults.standard.set(theme, forKey: "theme") } }

    // Scan feedback / behaviour
    @Published var beep: Bool { didSet { UserDefaults.standard.set(beep, forKey: "beep") } }
    @Published var vibrate: Bool { didSet { UserDefaults.standard.set(vibrate, forKey: "vibrate") } }
    @Published var copyToClipboard: Bool { didSet { UserDefaults.standard.set(copyToClipboard, forKey: "copy_clipboard") } }
    @Published var urlInfo: Bool { didSet { UserDefaults.standard.set(urlInfo, forKey: "url_info") } }
    @Published var batchMode: Bool { didSet { UserDefaults.standard.set(batchMode, forKey: "batch_mode") } }
    @Published var autofocus: Bool { didSet { UserDefaults.standard.set(autofocus, forKey: "autofocus") } }
    @Published var tapFocus: Bool { didSet { UserDefaults.standard.set(tapFocus, forKey: "tap_focus") } }
    @Published var keepDuplicates: Bool { didSet { UserDefaults.standard.set(keepDuplicates, forKey: "keep_duplicates") } }
    @Published var customUrl: String { didSet { UserDefaults.standard.set(customUrl, forKey: "custom_url") } }
    @Published var inAppBrowser: Bool { didSet { UserDefaults.standard.set(inAppBrowser, forKey: "in_app_browser") } }
    @Published var addToHistory: Bool { didSet { UserDefaults.standard.set(addToHistory, forKey: "add_history") } }
    @Published var autoOpenUrls: Bool { didSet { UserDefaults.standard.set(autoOpenUrls, forKey: "auto_open_urls") } }
    @Published var searchEngine: Int { didSet { UserDefaults.standard.set(searchEngine, forKey: "search_engine2") } }
    @Published var searchCountry: String { didSet { UserDefaults.standard.set(searchCountry, forKey: "search_country") } }

    // "My QR" contact card
    @Published var myName: String { didSet { UserDefaults.standard.set(myName, forKey: "my_name") } }
    @Published var myOrg: String { didSet { UserDefaults.standard.set(myOrg, forKey: "my_org") } }
    @Published var myPhone: String { didSet { UserDefaults.standard.set(myPhone, forKey: "my_phone") } }
    @Published var myEmail: String { didSet { UserDefaults.standard.set(myEmail, forKey: "my_email") } }
    @Published var myAddress: String { didSet { UserDefaults.standard.set(myAddress, forKey: "my_address") } }
    @Published var myWebsite: String { didSet { UserDefaults.standard.set(myWebsite, forKey: "my_website") } }

    private static func int(_ key: String, _ fallback: Int) -> Int {
        if let v = UserDefaults.standard.object(forKey: key) as? Int { return v }
        return fallback
    }

    private static func bool(_ key: String, _ fallback: Bool) -> Bool {
        if let v = UserDefaults.standard.object(forKey: key) as? Bool { return v }
        return fallback
    }

    private static func string(_ key: String, _ fallback: String) -> String {
        if let v = UserDefaults.standard.string(forKey: key) { return v }
        return fallback
    }

    init() {
        colorIndex = AppSettings.int("color_index", 0)
        theme = AppSettings.int("theme", 0)
        beep = AppSettings.bool("beep", false)
        vibrate = AppSettings.bool("vibrate", false)
        copyToClipboard = AppSettings.bool("copy_clipboard", false)
        urlInfo = AppSettings.bool("url_info", false)
        batchMode = AppSettings.bool("batch_mode", false)
        autofocus = AppSettings.bool("autofocus", true)
        tapFocus = AppSettings.bool("tap_focus", true)
        keepDuplicates = AppSettings.bool("keep_duplicates", true)
        customUrl = AppSettings.string("custom_url", "")
        inAppBrowser = AppSettings.bool("in_app_browser", true)
        addToHistory = AppSettings.bool("add_history", true)
        autoOpenUrls = AppSettings.bool("auto_open_urls", false)
        searchEngine = AppSettings.int("search_engine2", 0)
        searchCountry = AppSettings.string("search_country", "")
        myName = AppSettings.string("my_name", "")
        myOrg = AppSettings.string("my_org", "")
        myPhone = AppSettings.string("my_phone", "")
        myEmail = AppSettings.string("my_email", "")
        myAddress = AppSettings.string("my_address", "")
        myWebsite = AppSettings.string("my_website", "")
    }
}
