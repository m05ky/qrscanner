import SwiftUI

enum TopLevel: Hashable {
    case scan, history, favorites, myQR, create, settings
}

enum Route: Hashable {
    case result(Int64)
    case createForm(String)
    case createResult
}

struct CreatedCode: Equatable {
    var text: String
    var format: CodeFormat
}

/// Navigation state plus the central handling of a decoded code.
final class AppModel: ObservableObject {
    let settings = AppSettings()
    let history = HistoryStore()

    @Published var top: TopLevel = .scan
    @Published var path: [Route] = []
    @Published var drawerOpen = false
    /// The code shown on the create-result screen.
    @Published var created: CreatedCode?

    // MARK: navigation

    func go(_ target: TopLevel) {
        drawerOpen = false
        path = []
        top = target
    }

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        if !path.isEmpty { path.removeLast() }
    }

    // MARK: scanning

    /// Handles a decoded code from the camera or from an image and returns the history row id.
    @discardableResult
    func onScanned(text: String, format: CodeFormat, navigate: Bool, capture: ScanCapture?) -> Int64 {
        if settings.beep { Actions.beep() }
        if settings.vibrate { Actions.vibrate() }
        if settings.copyToClipboard { Actions.copy(text, showToast: false) }

        let id: Int64
        if settings.addToHistory {
            id = history.add(content: text, format: format, keepDuplicates: settings.keepDuplicates, capture: capture)
        } else {
            id = HistoryStore.transientId
            history.setTransient(content: text, format: format, capture: capture)
        }

        let parsed = ContentParser.parse(text, format: format)
        var openTarget: String?
        if case .url(_, let url) = parsed {
            let target = ContentParser.openUrl(url)
            openTarget = target
            if settings.urlInfo {
                UrlInfo.fetchTitle(target) { [weak self] title in
                    self?.history.setInfo(id, title)
                }
            }
        }
        if navigate {
            drawerOpen = false
            path.append(.result(id))
            if let target = openTarget, settings.autoOpenUrls {
                Actions.openUrl(target, inApp: settings.inAppBrowser)
            }
        }
        return id
    }

    /// Scans a picked image and opens the result.
    func scanPicked(_ image: UIImage) {
        ImageScanner.scan(image) { [weak self] hit in
            guard let self = self else { return }
            if let hit = hit {
                self.onScanned(text: hit.text, format: hit.format, navigate: true, capture: hit.capture)
            } else {
                Actions.toast(L.t("no_code_in_image"))
            }
        }
    }

    func pickImage() {
        drawerOpen = false
        Actions.pickImage { [weak self] image in
            self?.scanPicked(image)
        }
    }
}
