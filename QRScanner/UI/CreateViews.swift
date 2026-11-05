import SwiftUI

// MARK: create list

private struct Preset: Identifiable {
    let kind: String
    let titleKey: String
    let symbol: String
    var id: String { return kind }
}

private let presets: [Preset] = [
    Preset(kind: "url", titleKey: "create_url", symbol: "link"),
    Preset(kind: "text", titleKey: "create_text", symbol: "textformat"),
    Preset(kind: "contact", titleKey: "create_contact", symbol: "person.fill"),
    Preset(kind: "email", titleKey: "create_email", symbol: "envelope.fill"),
    Preset(kind: "sms", titleKey: "create_sms", symbol: "message.fill"),
    Preset(kind: "geo", titleKey: "create_coordinates", symbol: "mappin.and.ellipse"),
    Preset(kind: "phone", titleKey: "create_phone", symbol: "phone.fill"),
    Preset(kind: "event", titleKey: "create_event", symbol: "calendar"),
    Preset(kind: "wifi", titleKey: "create_wifi", symbol: "wifi"),
]

/// Icon of the "Other types" list: a PNG tile rendered from real ZXing output.
struct BarcodePreview: View {
    let format: CodeFormat

    var body: some View {
        Image(format.previewImageName)
            .resizable()
            .interpolation(.high)
            .frame(width: 48, height: 48)
            .accessibilityLabel(format.label)
    }
}

struct CreateView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(L.t("menu_create"), onMenu: {
                withAnimation(.easeOut(duration: 0.22)) { model.drawerOpen = true }
            })
            ScrollView {
                VStack(spacing: 0) {
                    SectionHeader(text: L.t("create_section_qr"))
                    RowCard {
                        IconRow(title: L.t("create_clipboard"), showDivider: true, action: {
                            if let text = Actions.readClipboard() {
                                model.created = CreatedCode(text: text, format: .QR_CODE)
                                model.push(.createResult)
                            } else {
                                Actions.toast(L.t("clipboard_empty"))
                            }
                        }, icon: { IconTile(symbol: "doc.on.clipboard") })
                        ForEach(presets) { p in
                            IconRow(title: L.t(p.titleKey), showDivider: true, action: {
                                model.push(.createForm(p.kind))
                            }, icon: { IconTile(symbol: p.symbol) })
                        }
                        IconRow(title: L.t("create_my_qr"), showDivider: false, action: {
                            model.go(.myQR)
                        }, icon: { IconTile(symbol: "person.fill") })
                    }

                    SectionHeader(text: L.t("create_section_other"))
                    RowCard {
                        let list = CodeFormat.otherTypes
                        ForEach(Array(list.enumerated()), id: \.offset) { i, f in
                            IconRow(title: f.label, showDivider: i != list.count - 1, action: {
                                model.push(.createForm(f.rawValue))
                            }, icon: { BarcodePreview(format: f) })
                        }
                    }
                    Color.clear.frame(height: 24)
                }
            }
        }
        .background(Palette.background.ignoresSafeArea())
    }
}

// MARK: create form

private struct FieldSpec: Identifiable {
    let key: String
    let labelKey: String
    var required = false
    var keyboard: UIKeyboardType = .default
    var multiline = false
    var id: String { return key }
}

private func fieldsFor(_ kind: String) -> [FieldSpec] {
    switch kind {
    case "url":
        return [FieldSpec(key: "url", labelKey: "field_url", required: true, keyboard: .URL)]
    case "text":
        return [FieldSpec(key: "text", labelKey: "field_text", required: true, multiline: true)]
    case "contact":
        return [
            FieldSpec(key: "name", labelKey: "field_name", required: true),
            FieldSpec(key: "org", labelKey: "field_org"),
            FieldSpec(key: "phone", labelKey: "field_phone", keyboard: .phonePad),
            FieldSpec(key: "email", labelKey: "field_email", keyboard: .emailAddress),
            FieldSpec(key: "address", labelKey: "field_address"),
            FieldSpec(key: "website", labelKey: "field_website", keyboard: .URL),
        ]
    case "email":
        return [
            FieldSpec(key: "email", labelKey: "field_email", required: true, keyboard: .emailAddress),
            FieldSpec(key: "subject", labelKey: "field_subject"),
            FieldSpec(key: "message", labelKey: "field_message", multiline: true),
        ]
    case "sms":
        return [
            FieldSpec(key: "phone", labelKey: "field_phone", required: true, keyboard: .phonePad),
            FieldSpec(key: "message", labelKey: "field_message", multiline: true),
        ]
    case "geo":
        return [
            FieldSpec(key: "lat", labelKey: "field_latitude", required: true, keyboard: .numbersAndPunctuation),
            FieldSpec(key: "lng", labelKey: "field_longitude", required: true, keyboard: .numbersAndPunctuation),
        ]
    case "phone":
        return [FieldSpec(key: "phone", labelKey: "field_phone", required: true, keyboard: .phonePad)]
    case "event":
        return [
            FieldSpec(key: "title", labelKey: "field_title", required: true),
            FieldSpec(key: "start", labelKey: "field_start", required: true, keyboard: .numbersAndPunctuation),
            FieldSpec(key: "end", labelKey: "field_end", keyboard: .numbersAndPunctuation),
            FieldSpec(key: "location", labelKey: "field_location"),
            FieldSpec(key: "description", labelKey: "field_description", multiline: true),
        ]
    case "wifi":
        return [
            FieldSpec(key: "ssid", labelKey: "field_ssid", required: true),
            FieldSpec(key: "password", labelKey: "field_password"),
        ]
    default:
        let f = CodeFormat.fromLabel(kind)
        let numeric = f == .EAN_8 || f == .EAN_13 || f == .UPC_A || f == .UPC_E || f == .ITF
        let multi = !(f?.is1D ?? false)
        return [FieldSpec(key: "content", labelKey: "field_content", required: true, keyboard: numeric ? .numberPad : .default, multiline: multi)]
    }
}

private func titleKeyFor(_ kind: String) -> String? {
    switch kind {
    case "url": return "create_url"
    case "text": return "create_text"
    case "contact": return "create_contact"
    case "email": return "create_email"
    case "sms": return "create_sms"
    case "geo": return "create_coordinates"
    case "phone": return "create_phone"
    case "event": return "create_event"
    case "wifi": return "create_wifi"
    default: return nil
    }
}

struct CreateFormView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: AppSettings
    let kind: String

    @State private var values: [String: String] = [:]
    @State private var errors: Set<String> = []
    @State private var encodeError: String?
    @State private var encryption = "WPA"
    @State private var hidden = false

    private var barcodeFormat: CodeFormat? { return CodeFormat.fromLabel(kind) }

    private var title: String {
        if let k = titleKeyFor(kind) { return L.t(k) }
        return barcodeFormat?.label ?? kind
    }

    private func binding(_ key: String) -> Binding<String> {
        return Binding(get: { values[key] ?? "" }, set: { values[key] = $0 })
    }

    private func hint(for spec: FieldSpec) -> String? {
        if spec.key == "start" || spec.key == "end" { return L.t("field_date_hint") }
        if spec.key == "content", let f = barcodeFormat { return L.t("hint_" + f.rawValue) }
        return nil
    }

    private func errorText(for spec: FieldSpec) -> String? {
        if !errors.contains(spec.key) { return nil }
        return (values[spec.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L.t("error_required") : L.t("error_invalid")
    }

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title, onBack: { model.pop() })
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(fieldsFor(kind)) { spec in
                        FormField(
                            label: L.t(spec.labelKey),
                            text: binding(spec.key),
                            keyboard: spec.keyboard,
                            multiline: spec.multiline,
                            error: errorText(for: spec),
                            hint: hint(for: spec),
                            lowercase: spec.keyboard == .URL || spec.keyboard == .emailAddress || spec.key == "content"
                        )
                    }
                    if kind == "wifi" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L.t("field_encryption"))
                                .font(Typo.font(13, .medium))
                                .foregroundColor(Palette.onVariant)
                            Picker("", selection: $encryption) {
                                Text(L.t("enc_wpa")).tag("WPA")
                                Text(L.t("enc_wep")).tag("WEP")
                                Text(L.t("enc_none")).tag("NONE")
                            }
                            .pickerStyle(.segmented)
                        }
                        Toggle(isOn: $hidden) {
                            Text(L.t("field_hidden"))
                                .font(Typo.bodyLarge)
                                .foregroundColor(Palette.onSurface)
                        }
                        .tint(settings.accent)
                    }
                    if let e = encodeError {
                        Text(e)
                            .font(Typo.bodyMedium)
                            .foregroundColor(Color.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    AccentButton(title: L.t("create_button")) { submit() }
                        .padding(.top, 4)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Palette.background.ignoresSafeArea())
    }

    private func trimmed(_ key: String) -> String {
        return (values[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        var bad = Set<String>()
        for f in fieldsFor(kind) {
            if f.required && trimmed(f.key).isEmpty { bad.insert(f.key) }
        }
        var payload = ""
        let format = barcodeFormat ?? .QR_CODE
        if bad.isEmpty {
            let raw = { (k: String) -> String in return self.values[k] ?? "" }
            switch kind {
            case "url":
                let u = trimmed("url")
                payload = (u.contains("://") || u.hasPrefix("mailto:") || u.hasPrefix("tel:")) ? u : "https://" + u
            case "text":
                payload = raw("text")
            case "contact":
                payload = ContentBuilder.vcard(name: trimmed("name"), org: trimmed("org"), phone: trimmed("phone"), email: trimmed("email"), address: trimmed("address"), website: trimmed("website"))
            case "email":
                payload = ContentBuilder.email(to: trimmed("email"), subject: trimmed("subject"), body: raw("message"))
            case "sms":
                payload = ContentBuilder.sms(number: trimmed("phone"), message: raw("message"))
            case "phone":
                payload = ContentBuilder.phone(trimmed("phone"))
            case "geo":
                let lat = Double(trimmed("lat").replacingOccurrences(of: ",", with: "."))
                let lng = Double(trimmed("lng").replacingOccurrences(of: ",", with: "."))
                if lat == nil || lat! < -90 || lat! > 90 { bad.insert("lat") }
                if lng == nil || lng! < -180 || lng! > 180 { bad.insert("lng") }
                if bad.isEmpty, let la = lat, let ln = lng { payload = ContentBuilder.geo(lat: la, lng: ln) }
            case "event":
                let s = ContentBuilder.toIcalLocal(trimmed("start"))
                let endText = trimmed("end")
                let e: String? = endText.isEmpty ? "" : ContentBuilder.toIcalLocal(endText)
                if s == nil { bad.insert("start") }
                if e == nil { bad.insert("end") }
                if bad.isEmpty, let s = s, let e = e {
                    payload = ContentBuilder.event(title: trimmed("title"), startIcal: s, endIcal: e, location: trimmed("location"), description: raw("description"))
                }
            case "wifi":
                payload = ContentBuilder.wifi(ssid: trimmed("ssid"), password: raw("password"), encryption: encryption, hidden: hidden)
            default:
                payload = CodeGenerator.normalize(format, raw("content"))
            }
        }
        errors = bad
        encodeError = nil
        if !bad.isEmpty { return }
        // Make sure the content really fits the chosen symbology before leaving the form.
        if (try? CodeGenerator.image(payload, format: format, size: 300)) == nil {
            encodeError = L.f("error_cannot_encode", format.label)
            return
        }
        model.created = CreatedCode(text: payload, format: format)
        model.push(.createResult)
    }
}

// MARK: create result

struct CreateResultView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(model.created?.format.label ?? "", onBack: { model.pop() })
            if let c = model.created {
                GeneratedCodeView(text: c.text, format: c.format)
            } else {
                Spacer()
            }
        }
        .background(Palette.background.ignoresSafeArea())
    }
}
