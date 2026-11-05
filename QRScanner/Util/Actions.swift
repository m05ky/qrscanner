import UIKit
import SafariServices
import ContactsUI
import EventKit
import EventKitUI
import Photos
import PhotosUI
import AudioToolbox

/// System actions: opening links, sharing, contacts, calendar, clipboard, pickers, feedback.
enum Actions {

    // MARK: presenting UIKit controllers

    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        var vc = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? scene?.windows.first?.rootViewController
        while let presented = vc?.presentedViewController {
            vc = presented
        }
        return vc
    }

    static func present(_ controller: UIViewController) {
        DispatchQueue.main.async {
            topViewController()?.present(controller, animated: true)
        }
    }

    static func toast(_ text: String) {
        ToastCenter.shared.show(text)
    }

    // MARK: clipboard & sharing

    static func copy(_ text: String, showToast: Bool = true) {
        UIPasteboard.general.string = text
        if showToast { toast(L.t("copied")) }
    }

    static func readClipboard() -> String? {
        guard let s = UIPasteboard.general.string, !s.isEmpty else { return nil }
        return s
    }

    static func shareItems(_ items: [Any]) {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        present(vc)
    }

    static func shareText(_ text: String) {
        shareItems([text])
    }

    static func shareImage(_ image: UIImage, name: String = "qr-code") {
        guard let data = image.pngData() else {
            toast(L.t("save_failed"))
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name + ".png")
        do {
            try data.write(to: url, options: .atomic)
            shareItems([url])
        } catch {
            toast(L.t("save_failed"))
        }
    }

    private static func writeTemp(_ text: String, _ fileName: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    static func shareTextFile(_ text: String, fileName: String) {
        guard let url = writeTemp(text, fileName) else {
            toast(L.t("save_failed"))
            return
        }
        shareItems([url])
    }

    /// Lets the user pick where to store the file (Files app).
    static func exportTextFile(_ text: String, fileName: String) {
        guard let url = writeTemp(text, fileName) else {
            toast(L.t("save_failed"))
            return
        }
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        present(picker)
    }

    static func saveImage(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            _ = PHAssetChangeRequest.creationRequestForAsset(from: image)
        }, completionHandler: { ok, _ in
            toast(L.t(ok ? "saved" : "save_failed"))
        })
    }

    // MARK: browsing & searching

    static func openUrl(_ url: String, inApp: Bool) {
        let full = url.contains("://") ? url : "https://" + url
        guard let target = URL(string: full) ?? URL(string: full.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            toast(L.t("no_app_found"))
            return
        }
        let scheme = target.scheme?.lowercased() ?? ""
        if inApp && (scheme == "http" || scheme == "https") {
            DispatchQueue.main.async {
                let vc = SFSafariViewController(url: target)
                topViewController()?.present(vc, animated: true)
            }
            return
        }
        open(target)
    }

    static func open(_ url: URL) {
        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:]) { ok in
                if !ok { toast(L.t("no_app_found")) }
            }
        }
    }

    static func openString(_ s: String) {
        if let u = URL(string: s) { open(u) } else { toast(L.t("no_app_found")) }
    }

    static func encode(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    /// Index into `AppSettings.engineNames`.
    static func searchUrl(engine: Int, country: String, query: String) -> String {
        let q = encode(query)
        let cc = country.lowercased()
        switch engine {
        case 1: return "https://www.bing.com/search?q=" + q + (cc.isEmpty ? "" : "&cc=" + cc)
        case 2: return "https://duckduckgo.com/?q=" + q
        case 3: return "https://www.ecosia.org/search?q=" + q
        case 4: return "https://www.startpage.com/do/search?q=" + q
        case 5: return "https://search.brave.com/search?q=" + q
        default: return "https://www.google.com/search?q=" + q + (cc.isEmpty ? "" : "&gl=" + cc)
        }
    }

    static func searchWeb(_ query: String, engine: Int, country: String, inApp: Bool) {
        openUrl(searchUrl(engine: engine, country: country, query: query), inApp: inApp)
    }

    // MARK: phone / mail / sms / maps

    static func dial(_ number: String) {
        let digits = number.filter { $0.isNumber || $0 == "+" || $0 == "*" || $0 == "#" }
        openString("tel:" + digits)
    }

    static func sendEmail(to: String, subject: String, body: String) {
        var s = "mailto:" + to
        var query: [String] = []
        if !subject.isEmpty { query.append("subject=" + encode(subject)) }
        if !body.isEmpty { query.append("body=" + encode(body)) }
        if !query.isEmpty { s += "?" + query.joined(separator: "&") }
        openString(s)
    }

    static func sendSms(number: String, message: String) {
        var s = "sms:" + number.filter { $0.isNumber || $0 == "+" }
        if !message.isEmpty { s += "&body=" + encode(message) }
        openString(s)
    }

    static func showMap(lat: Double, lng: Double, label: String) {
        var s = "https://maps.apple.com/?ll=\(lat),\(lng)"
        if !label.isEmpty { s += "&q=" + encode(label) }
        openString(s)
    }

    static func showMapForAddress(_ address: String) {
        openString("https://maps.apple.com/?q=" + encode(address))
    }

    // MARK: contacts & calendar

    private final class ContactDelegate: NSObject, CNContactViewControllerDelegate {
        static let shared = ContactDelegate()

        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            (viewController.navigationController ?? viewController).dismiss(animated: true)
        }
    }

    private static func showNewContact(_ c: CNMutableContact) {
        DispatchQueue.main.async {
            let vc = CNContactViewController(forNewContact: c)
            vc.delegate = ContactDelegate.shared
            topViewController()?.present(UINavigationController(rootViewController: vc), animated: true)
        }
    }

    static func addContact(_ info: ContactInfo) {
        let c = CNMutableContact()
        let name = info.name.trimmingCharacters(in: .whitespaces)
        if let space = name.lastIndex(of: " ") {
            c.givenName = String(name[name.startIndex..<space])
            c.familyName = String(name[name.index(after: space)...])
        } else {
            c.givenName = name
        }
        c.organizationName = info.org
        c.phoneNumbers = info.phones.map { CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: $0)) }
        c.emailAddresses = info.emails.map { CNLabeledValue(label: CNLabelHome, value: $0 as NSString) }
        if !info.address.isEmpty {
            let a = CNMutablePostalAddress()
            a.street = info.address
            c.postalAddresses = [CNLabeledValue(label: CNLabelHome, value: a)]
        }
        if !info.website.isEmpty {
            c.urlAddresses = [CNLabeledValue(label: CNLabelURLAddressHomePage, value: info.website as NSString)]
        }
        showNewContact(c)
    }

    static func addPhoneToContacts(_ number: String) {
        let c = CNMutableContact()
        c.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: number))]
        showNewContact(c)
    }

    private final class EventDelegate: NSObject, EKEventEditViewDelegate {
        static let shared = EventDelegate()

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            controller.dismiss(animated: true)
        }
    }

    static func addEvent(_ e: EventInfo) {
        let store = EKEventStore()
        let show: (Bool) -> Void = { granted in
            DispatchQueue.main.async {
                if !granted {
                    toast(L.t("no_app_found"))
                    return
                }
                let ev = EKEvent(eventStore: store)
                ev.title = e.title
                ev.location = e.location
                ev.notes = e.description
                let start = e.startDate ?? Date()
                ev.startDate = start
                ev.isAllDay = e.allDay
                if let end = e.endDate, end >= start {
                    ev.endDate = end
                } else {
                    ev.endDate = start.addingTimeInterval(e.allDay ? 0 : 3600)
                }
                if let cal = store.defaultCalendarForNewEvents { ev.calendar = cal }
                let vc = EKEventEditViewController()
                vc.eventStore = store
                vc.event = ev
                vc.editViewDelegate = EventDelegate.shared
                topViewController()?.present(vc, animated: true)
            }
        }
        if #available(iOS 17.0, *) {
            store.requestWriteOnlyAccessToEvents { granted, _ in show(granted) }
        } else {
            store.requestAccess(to: .event) { granted, _ in show(granted) }
        }
    }

    // MARK: Wi-Fi

    /// Joining a network from an app needs a special entitlement that sideloaded apps cannot have, so the
    /// password is copied and the Settings app is opened.
    static func connectWifi(_ w: WifiInfo) {
        if !w.password.isEmpty { copy(w.password, showToast: false) }
        toast(L.t("wifi_failed"))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if let u = URL(string: "App-Prefs:root=WIFI") {
                UIApplication.shared.open(u, options: [:]) { ok in
                    if !ok, let s = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(s, options: [:], completionHandler: nil)
                    }
                }
            }
        }
    }

    // MARK: picking an image

    private final class ImagePicker: NSObject, PHPickerViewControllerDelegate {
        static var current: ImagePicker?
        let completion: (UIImage) -> Void

        init(completion: @escaping (UIImage) -> Void) {
            self.completion = completion
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider else {
                ImagePicker.current = nil
                return
            }
            if !provider.canLoadObject(ofClass: UIImage.self) {
                ImagePicker.current = nil
                Actions.toast(L.t("no_code_in_image"))
                return
            }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                DispatchQueue.main.async {
                    ImagePicker.current = nil
                    if let image = object as? UIImage {
                        self.completion(image)
                    } else {
                        Actions.toast(L.t("no_code_in_image"))
                    }
                }
            }
        }
    }

    /// Opens the system photo picker for a single image.
    static func pickImage(_ completion: @escaping (UIImage) -> Void) {
        DispatchQueue.main.async {
            var config = PHPickerConfiguration()
            config.filter = .images
            config.selectionLimit = 1
            let picker = PHPickerViewController(configuration: config)
            let delegate = ImagePicker(completion: completion)
            ImagePicker.current = delegate
            picker.delegate = delegate
            topViewController()?.present(picker, animated: true)
        }
    }

    // MARK: scan feedback

    static func beep() {
        AudioServicesPlaySystemSound(1057)
    }

    static func vibrate() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}
