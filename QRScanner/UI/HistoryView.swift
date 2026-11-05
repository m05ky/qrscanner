import SwiftUI

private struct DayGroup: Identifiable {
    let dayStart: Date
    let items: [ScanEntry]
    var id: Double { return dayStart.timeIntervalSince1970 }
}

private func group(_ list: [ScanEntry]) -> [DayGroup] {
    let cal = Calendar.current
    var out: [DayGroup] = []
    var curStart: Date?
    var cur: [ScanEntry] = []
    for e in list {
        let d = cal.startOfDay(for: e.date)
        if d != curStart {
            if let s = curStart, !cur.isEmpty { out.append(DayGroup(dayStart: s, items: cur)) }
            curStart = d
            cur = []
        }
        cur.append(e)
    }
    if let s = curStart, !cur.isEmpty { out.append(DayGroup(dayStart: s, items: cur)) }
    return out
}

private func previewText(_ p: Parsed) -> String {
    switch p {
    case .text(let raw):
        return raw
    case .product(let code):
        return code
    case .url(_, let url):
        return url
    case .wifi(let w):
        var s = L.t("wifi_network") + ": " + w.ssid + "\n" + L.t("wifi_type") + ": " + w.encryption
        if !w.password.isEmpty { s += "\n" + L.t("wifi_password") + ": " + w.password }
        return s
    case .contact(let c):
        let parts = [c.address, c.phones.first ?? "", c.emails.first ?? ""].filter { !$0.isEmpty }
        return parts.joined(separator: "\n")
    case .email(let e):
        return [e.to, e.subject].filter { !$0.isEmpty }.joined(separator: "\n")
    case .sms(let s):
        return [s.number, s.message].filter { !$0.isEmpty }.joined(separator: "\n")
    case .geo(let g):
        return "\(g.lat), \(g.lng)"
    case .phone(let n):
        return n
    case .event(let e):
        return e.title
    }
}

struct HistoryView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var history: HistoryStore
    let favoritesOnly: Bool

    @State private var onlyFav = false
    @State private var confirmAll = false
    @State private var confirmDay: DayGroup?

    private var shown: [ScanEntry] {
        if favoritesOnly || onlyFav { return history.entries.filter { $0.favorite } }
        return history.entries
    }

    private var rows: [ExportRow] {
        return shown.map { ExportRow(time: $0.date, format: $0.format.label, type: String(describing: $0.parsed.type).uppercased(), content: $0.content, favorite: $0.favorite) }
    }

    var body: some View {
        let list = shown
        let groups = group(list)
        VStack(spacing: 0) {
            AppTopBar(L.t(favoritesOnly ? "menu_favorites" : "menu_history"), onMenu: {
                withAnimation(.easeOut(duration: 0.22)) { model.drawerOpen = true }
            }, trailing: {
                if !favoritesOnly {
                    BarIconButton(
                        symbol: onlyFav ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle",
                        label: L.t(onlyFav ? "history_filter_all" : "history_filter_favorites")
                    ) { onlyFav.toggle() }
                }
                menu(list)
            })

            if list.isEmpty {
                Spacer()
                Text(L.t(favoritesOnly || onlyFav ? "favorites_empty" : "history_empty"))
                    .font(Typo.bodyLarge)
                    .foregroundColor(Palette.onVariant)
                    .multilineTextAlignment(.center)
                    .padding(32)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groups) { g in
                            dayHeader(g)
                            ForEach(Array(g.items.enumerated()), id: \.element.id) { idx, e in
                                EntryRow(entry: e, first: idx == 0, last: idx == g.items.count - 1)
                            }
                        }
                        Color.clear.frame(height: 24)
                    }
                }
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .alert(L.t("confirm_delete_title"), isPresented: $confirmAll) {
            Button(L.t("confirm_ok"), role: .destructive) {
                history.deleteMany(list.map { $0.id })
            }
            Button(L.t("cancel"), role: .cancel) {}
        } message: {
            Text(L.t("confirm_delete_all"))
        }
        .alert(L.t("confirm_delete_title"), isPresented: Binding(get: { confirmDay != nil }, set: { if !$0 { confirmDay = nil } })) {
            Button(L.t("confirm_ok"), role: .destructive) {
                if let g = confirmDay { history.deleteMany(g.items.map { $0.id }) }
                confirmDay = nil
            }
            Button(L.t("cancel"), role: .cancel) { confirmDay = nil }
        } message: {
            Text(L.t("history_delete_day"))
        }
    }

    private func menu(_ list: [ScanEntry]) -> some View {
        Menu {
            Button {
                if !list.isEmpty { confirmAll = true }
            } label: {
                Label(L.t("history_delete_all"), systemImage: "trash")
            }
            Button {
                Actions.shareTextFile(Export.csv(rows), fileName: "history.csv")
            } label: {
                Label(L.t("history_export_share_csv"), systemImage: "square.and.arrow.up")
            }
            Button {
                Actions.exportTextFile(Export.txt(rows), fileName: "history.txt")
            } label: {
                Label(L.t("history_save_txt"), systemImage: "arrow.down.doc")
            }
            Button {
                Actions.exportTextFile(Export.csv(rows), fileName: "history.csv")
            } label: {
                Label(L.t("history_save_csv"), systemImage: "arrow.down.doc")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 44, height: 48)
        }
    }

    private func dayLabel(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return L.t("history_today") }
        if cal.isDateInYesterday(day) { return L.t("history_yesterday") }
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f.string(from: day)
    }

    private func dayHeader(_ g: DayGroup) -> some View {
        HStack {
            Text(dayLabel(g.dayStart).uppercased())
                .font(Typo.labelMedium)
                .tracking(1.2)
                .foregroundColor(Palette.onVariant)
                .padding(.leading, 4)
            Spacer()
            Button {
                confirmDay = g
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18))
                    .foregroundColor(Palette.onVariant)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(L.t("history_delete_day"))
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .padding(.top, 12)
    }
}

private struct EntryRow: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var history: HistoryStore
    let entry: ScanEntry
    let first: Bool
    let last: Bool

    private var shape: RoundedCornerShape {
        var corners: UIRectCorner = []
        if first { corners.formUnion([.topLeft, .topRight]) }
        if last { corners.formUnion([.bottomLeft, .bottomRight]) }
        return RoundedCornerShape(radius: 20, corners: corners)
    }

    private var stamp: String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .medium
        return f.string(from: entry.date)
    }

    var body: some View {
        let parsed = entry.parsed
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    model.push(.result(entry.id))
                } label: {
                    HStack(spacing: 16) {
                        IconTile(symbol: parsed.type.symbol, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(parsed.type.title)
                                .font(Typo.titleMedium)
                                .foregroundColor(Palette.onSurface)
                            Text(stamp + ", " + entry.format.label)
                                .font(Typo.bodySmall)
                                .foregroundColor(Palette.onVariant)
                            if case .contact(let c) = parsed, !c.name.isEmpty {
                                Text(c.name)
                                    .font(Typo.font(14, .semibold))
                                    .foregroundColor(Palette.onSurface)
                            }
                            Text(previewText(parsed))
                                .font(Typo.bodyMedium)
                                .foregroundColor(Palette.onVariant)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                                .padding(.top, 2)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)
                    .padding(.leading, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button {
                    history.setFavorite(entry.id, !entry.favorite)
                } label: {
                    Image(systemName: entry.favorite ? "star.fill" : "star")
                        .font(.system(size: 20))
                        .foregroundColor(entry.favorite ? Palette.star : Palette.onVariant)
                        .frame(width: 40, height: 44)
                }
                .accessibilityLabel(L.t("act_favorite"))
                Menu {
                    Button {
                        Actions.shareText(entry.content)
                    } label: {
                        Label(L.t("act_share"), systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        history.delete(entry.id)
                    } label: {
                        Label(L.t("history_delete"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18))
                        .foregroundColor(Palette.onVariant)
                        .frame(width: 40, height: 44)
                }
            }
            .padding(.trailing, 4)
            .background(Palette.surface)
            .clipShape(shape)
            if !last {
                Hairline().background(Palette.surface)
            }
        }
        .padding(.horizontal, 12)
    }
}
