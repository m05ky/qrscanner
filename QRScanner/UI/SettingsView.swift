import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: AppSettings

    @State private var showCustom = false
    @State private var customText = ""
    @State private var showPrivacy = false

    private var themeNames: [String] {
        return [L.t("theme_system"), L.t("theme_light"), L.t("theme_dark")]
    }

    private func countryName(_ code: String) -> String {
        if code.isEmpty { return L.t("country_auto") }
        return Locale.current.localizedString(forRegionCode: code) ?? code
    }

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(L.t("menu_settings"), onMenu: {
                withAnimation(.easeOut(duration: 0.22)) { model.drawerOpen = true }
            })
            ScrollView {
                VStack(spacing: 0) {
                    colorSection
                    menuRow(title: L.t("set_theme"), subtitle: themeNames[min(max(settings.theme, 0), 2)]) {
                        Picker("", selection: $settings.theme) {
                            ForEach(0..<3, id: \.self) { i in Text(themeNames[i]).tag(i) }
                        }
                    }
                    toggleRow(L.t("set_beep"), nil, $settings.beep)
                    toggleRow(L.t("set_vibrate"), nil, $settings.vibrate)
                    toggleRow(L.t("set_copy_clipboard"), nil, $settings.copyToClipboard)
                    toggleRow(L.t("set_url_info"), L.t("set_url_info_desc"), $settings.urlInfo)
                    toggleRow(L.t("set_batch"), L.t("set_batch_desc"), $settings.batchMode)
                    toggleRow(L.t("set_autofocus"), nil, $settings.autofocus)
                    toggleRow(L.t("set_tap_focus"), L.t("set_tap_focus_desc"), $settings.tapFocus, enabled: settings.autofocus)
                    toggleRow(L.t("set_keep_duplicates"), nil, $settings.keepDuplicates)
                    clickRow(L.t("set_custom_action"), settings.customUrl.isEmpty ? L.t("set_custom_action_desc") : settings.customUrl) {
                        customText = settings.customUrl
                        showCustom = true
                    }
                    toggleRow(L.t("set_in_app_browser"), nil, $settings.inAppBrowser)
                    toggleRow(L.t("set_add_history"), nil, $settings.addToHistory)
                    toggleRow(L.t("set_auto_open"), L.t("set_auto_open_desc"), $settings.autoOpenUrls)
                    clickRow(L.t("set_privacy"), nil) { showPrivacy = true }
                    menuRow(title: L.t("set_search_engine"), subtitle: AppSettings.engineNames[min(max(settings.searchEngine, 0), AppSettings.engineNames.count - 1)]) {
                        Picker("", selection: $settings.searchEngine) {
                            ForEach(0..<AppSettings.engineNames.count, id: \.self) { i in
                                Text(AppSettings.engineNames[i]).tag(i)
                            }
                        }
                    }
                    menuRow(title: L.t("set_search_country"), subtitle: countryName(settings.searchCountry)) {
                        Picker("", selection: $settings.searchCountry) {
                            ForEach(AppSettings.countries, id: \.self) { code in
                                Text(countryName(code)).tag(code)
                            }
                        }
                    }
                    Color.clear.frame(height: 24)
                }
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .alert(L.t("set_custom_action"), isPresented: $showCustom) {
            TextField("https://example.com/?q={CODE}", text: $customText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            Button(L.t("my_qr_save")) {
                settings.customUrl = customText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            Button(L.t("cancel"), role: .cancel) {}
        } message: {
            Text(L.t("set_custom_action_desc"))
        }
        .alert(L.t("set_privacy"), isPresented: $showPrivacy) {
            Button(L.t("ok"), role: .cancel) {}
        } message: {
            Text(L.t("privacy_text"))
        }
    }

    // MARK: pieces

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L.t("set_color_scheme"))
                .font(Typo.titleMedium)
                .foregroundColor(Palette.onSurface)
                .padding(.leading, 20)
                .padding(.top, 24)
                .padding(.bottom, 14)
            let all = Array(AppSettings.palette.enumerated())
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(Array(all[(row * 6)..<(row * 6 + 6)]), id: \.offset) { item in
                        swatch(index: item.offset, value: item.element)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
            }
        }
    }

    private func swatch(index: Int, value: UInt32) -> some View {
        let color = Color(UIColor(rgb: value & 0xFFFFFF))
        return Button {
            settings.colorIndex = index
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color)
                if settings.colorIndex == index {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(swatchForeground(value))
                }
            }
            .frame(height: 52)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func swatchForeground(_ value: UInt32) -> Color {
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return lum > 0.6 ? Color.black.opacity(0.8) : Color.white
    }

    private func toggleRow(_ title: String, _ desc: String?, _ value: Binding<Bool>, enabled: Bool = true) -> some View {
        Toggle(isOn: value) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typo.titleMedium)
                    .foregroundColor(enabled ? Palette.onSurface : Palette.onVariant)
                if let desc = desc {
                    Text(desc)
                        .font(Typo.bodyMedium)
                        .foregroundColor(Palette.onVariant)
                }
            }
        }
        .tint(settings.accent)
        .disabled(!enabled)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func clickRow(_ title: String, _ subtitle: String?, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowLabel(title, subtitle)
        }
        .buttonStyle(.plain)
    }

    private func rowLabel(_ title: String, _ subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Typo.titleMedium)
                .foregroundColor(Palette.onSurface)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(Typo.bodyMedium)
                    .foregroundColor(Palette.onVariant)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }

    private func menuRow<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            rowLabel(title, subtitle)
        }
    }
}
