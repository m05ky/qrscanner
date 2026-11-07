import SwiftUI

private struct ActionItem: Identifiable {
    let id: Int
    let symbol: String
    let label: String
    let run: () -> Void
}

struct ResultView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var history: HistoryStore
    let id: Int64

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(L.t("menu_scan"), onBack: { model.pop() })
            if let entry = history.get(id) {
                ResultBody(entry: entry)
            } else {
                Spacer()
            }
        }
        .background(Palette.background.ignoresSafeArea())
    }
}

private struct ResultBody: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var history: HistoryStore
    let entry: ScanEntry

    @State private var showRaw = false
    @State private var codeImage: UIImage?
    @State private var frameImage: UIImage?
    @State private var cropImage: UIImage?

    private var whenText: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: entry.date)
    }

    var body: some View {
        let parsed = entry.parsed
        ScrollView {
            VStack(spacing: 0) {
                if frameImage != nil || cropImage != nil {
                    capturedImages
                }
                header(parsed)
                Hairline()
                content(parsed)
                Hairline()
                actionGrid(parsed)
                if let img = codeImage {
                    Image(uiImage: img)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Palette.outline, lineWidth: 1))
                        .frame(maxWidth: 320)
                        .padding(16)
                }
            }
        }
        .onAppear { loadImages() }
    }

    private func loadImages() {
        if codeImage == nil {
            codeImage = CodeGenerator.imageOrNil(entry.content, format: entry.format, size: 700)
        }
        if entry.hasImages {
            frameImage = ScanImages.load(id: entry.id, kind: .frame)
            cropImage = ScanImages.load(id: entry.id, kind: .code)
        }
    }

    // MARK: pictures taken at scan time

    private var capturedImages: some View {
        HStack(spacing: 12) {
            if let f = frameImage {
                tile(f, background: Palette.surface, label: L.t("result_frame"), padding: 0)
                    .frame(maxWidth: .infinity)
            }
            if let c = cropImage {
                tile(c, background: Palette.surface, label: L.t("result_code"), padding: 6)
                    .frame(width: 128)
            }
        }
        .frame(height: 200)
        .padding(12)
    }

    private func tile(_ image: UIImage, background: Color, label: String, padding: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            background
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .padding(padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(label)
                .font(Typo.font(11, .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.outline, lineWidth: 1))
    }

    // MARK: header

    private func header(_ parsed: Parsed) -> some View {
        HStack(spacing: 0) {
            IconTile(symbol: parsed.type.symbol, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(parsed.type.title)
                    .font(Typo.titleLarge)
                    .foregroundColor(Palette.onSurface)
                Text(whenText + ", " + entry.format.label)
                    .font(Typo.bodyMedium)
                    .foregroundColor(Palette.onVariant)
            }
            .padding(.leading, 16)
            Spacer(minLength: 8)
            Button {
                showRaw.toggle()
            } label: {
                Image(systemName: "textformat")
                    .font(.system(size: 20))
                    .foregroundColor(showRaw ? settings.accent : Palette.onVariant)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(L.t("act_toggle_text"))
            Button {
                history.setFavorite(entry.id, !entry.favorite)
            } label: {
                Image(systemName: entry.favorite ? "star.fill" : "star")
                    .font(.system(size: 21))
                    .foregroundColor(entry.favorite ? Palette.star : Palette.onVariant)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(L.t("act_favorite"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Palette.surface)
    }

    // MARK: content

    private func big(_ s: String, bold: Bool = false, dim: Bool = false) -> some View {
        Text(s)
            .font(Typo.font(20, bold ? .bold : .regular))
            .foregroundColor(dim ? Palette.onVariant : Palette.onSurface)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mid(_ s: String, dim: Bool = true) -> some View {
        Text(s)
            .font(Typo.font(17))
            .foregroundColor(dim ? Palette.onVariant : Palette.onSurface)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dateText(_ d: Date, allDay: Bool) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = allDay ? .none : .short
        return f.string(from: d)
    }

    private func content(_ parsed: Parsed) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if showRaw {
                big(entry.content)
            } else {
                parsedContent(parsed)
            }
            if !entry.info.isEmpty {
                Text(L.t("url_info_title") + ": " + entry.info)
                    .font(Typo.font(15))
                    .foregroundColor(Palette.onVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
            }
        }
        .textSelection(.enabled)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface)
    }

    @ViewBuilder
    private func parsedContent(_ p: Parsed) -> some View {
        switch p {
        case .text(let raw):
            big(raw)
        case .product(let code):
            big(code)
        case .url(_, let url):
            Button {
                Actions.openUrl(ContentParser.openUrl(url), inApp: settings.inAppBrowser)
            } label: {
                Text(url)
                    .font(Typo.font(20))
                    .underline()
                    .foregroundColor(settings.accent)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        case .wifi(let w):
            big(L.t("wifi_network") + ": " + w.ssid)
            big(L.t("wifi_type") + ": " + w.encryption)
            if !w.password.isEmpty { big(L.t("wifi_password") + ": " + w.password) }
        case .contact(let c):
            if !c.name.isEmpty { big(c.name, bold: true) }
            if !c.org.isEmpty { big(c.org, dim: true) }
            if !c.address.isEmpty { big(c.address) }
            ForEach(Array(c.phones.enumerated()), id: \.offset) { _, n in big(n) }
            ForEach(Array(c.emails.enumerated()), id: \.offset) { _, m in big(m) }
            if !c.website.isEmpty { big(c.website) }
            if !c.note.isEmpty { mid(c.note) }
        case .email(let e):
            big(e.to)
            if !e.subject.isEmpty { big(e.subject, bold: true) }
            if !e.body.isEmpty { mid(e.body) }
        case .sms(let s):
            big(s.number)
            if !s.message.isEmpty { mid(s.message) }
        case .phone(let n):
            big(n)
        case .geo(let g):
            big("\(g.lat), \(g.lng)")
            if !g.query.isEmpty { mid(g.query) }
        case .event(let e):
            if !e.title.isEmpty { big(e.title, bold: true) }
            if let s = e.startDate { big(dateText(s, allDay: e.allDay)) }
            if let end = e.endDate { big(dateText(end, allDay: e.allDay)) }
            if !e.location.isEmpty { big(e.location) }
            if !e.description.isEmpty { mid(e.description) }
        }
    }

    // MARK: actions

    private func actions(_ p: Parsed) -> [ActionItem] {
        var list: [ActionItem] = []
        let raw = entry.content
        let inApp = settings.inAppBrowser
        func add(_ symbol: String, _ label: String, _ run: @escaping () -> Void) {
            list.append(ActionItem(id: list.count, symbol: symbol, label: label, run: run))
        }
        let engine = settings.searchEngine
        let country = settings.searchCountry
        switch p {
        case .text(let t):
            add("magnifyingglass", L.t("act_search_web")) { Actions.searchWeb(t, engine: engine, country: country, inApp: inApp) }
        case .product(let code):
            add("magnifyingglass", L.t("act_search_web")) { Actions.searchWeb(code, engine: engine, country: country, inApp: inApp) }
        case .url(_, let url):
            add("safari", L.t("act_open")) { Actions.openUrl(ContentParser.openUrl(url), inApp: inApp) }
        case .wifi(let w):
            add("wifi", L.t("act_connect")) { Actions.connectWifi(w) }
            if !w.password.isEmpty {
                add("lock.fill", L.t("act_copy_password")) { Actions.copy(w.password) }
            }
        case .contact(let c):
            add("person.badge.plus", L.t("act_add_contact")) { Actions.addContact(c) }
            if !c.address.isEmpty {
                add("map", L.t("act_show_map")) { Actions.showMapForAddress(c.address) }
            }
            if let n = c.phones.first {
                add("phone.fill", L.t("act_call")) { Actions.dial(n) }
            }
            if let m = c.emails.first {
                add("envelope.fill", L.t("act_send_email")) { Actions.sendEmail(to: m, subject: "", body: "") }
            }
        case .email(let e):
            add("envelope.fill", L.t("act_send_email")) { Actions.sendEmail(to: e.to, subject: e.subject, body: e.body) }
        case .sms(let s):
            add("message.fill", L.t("act_send_sms")) { Actions.sendSms(number: s.number, message: s.message) }
        case .geo(let g):
            add("map", L.t("act_show_map")) { Actions.showMap(lat: g.lat, lng: g.lng, label: g.query) }
        case .phone(let n):
            add("phone.fill", L.t("act_call")) { Actions.dial(n) }
            add("person.badge.plus", L.t("act_add_contact")) { Actions.addPhoneToContacts(n) }
        case .event(let e):
            add("calendar.badge.plus", L.t("act_add_event")) { Actions.addEvent(e) }
        }
        add("square.and.arrow.up", L.t("act_share")) { Actions.shareText(raw) }
        add("doc.on.doc", L.t("act_copy")) { Actions.copy(raw) }
        let custom = settings.customUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty {
            add("globe", L.t("act_custom")) {
                let url = custom.replacingOccurrences(of: "{CODE}", with: Actions.encode(raw))
                Actions.openUrl(url, inApp: inApp)
            }
        }
        return list
    }

    private func actionGrid(_ p: Parsed) -> some View {
        let items = actions(p)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 4)
        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(items) { a in
                Button(action: a.run) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().fill(settings.accent.opacity(0.14))
                            Image(systemName: a.symbol)
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(settings.accent)
                        }
                        .frame(width: 52, height: 52)
                        Text(a.label)
                            .font(Typo.font(13, .medium))
                            .foregroundColor(Palette.onVariant)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 2)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}
