import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            NavigationStack(path: $model.path) {
                TopLevelContent()
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: Route.self) { route in
                        destination(route)
                            .toolbar(.hidden, for: .navigationBar)
                    }
            }
            DrawerLayer()
            ToastOverlay()
        }
        .preferredColorScheme(settings.colorScheme)
        .tint(settings.accent)
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .result(let id):
            ResultView(id: id)
        case .createForm(let kind):
            CreateFormView(kind: kind)
        case .createResult:
            CreateResultView()
        }
    }
}

/// The screen chosen in the side menu.
struct TopLevelContent: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        switch model.top {
        case .scan:
            ScanView()
        case .history:
            HistoryView(favoritesOnly: false)
        case .favorites:
            HistoryView(favoritesOnly: true)
        case .myQR:
            MyQRView()
        case .create:
            CreateView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: side menu

private struct DrawerEntry: Identifiable {
    let id: String
    let target: TopLevel?
    let symbol: String
    let label: String
}

struct DrawerLayer: View {
    @EnvironmentObject var model: AppModel
    @State private var drag: CGFloat = 0

    private let width: CGFloat = 304

    private var offsetX: CGFloat {
        let base: CGFloat = model.drawerOpen ? 0 : -width
        return min(0, max(-width, base + drag))
    }

    private var scrimOpacity: Double {
        return Double(1 + offsetX / width) * 0.4
    }

    private func settle(open: Bool) {
        withAnimation(.easeOut(duration: 0.22)) {
            drag = 0
            model.drawerOpen = open
        }
    }

    private var openDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in drag = max(0, min(width, v.translation.width)) }
            .onEnded { v in settle(open: v.translation.width > width * 0.3 || v.predictedEndTranslation.width > width * 0.7) }
    }

    private var closeDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in drag = min(0, max(-width, v.translation.width)) }
            .onEnded { v in settle(open: !(v.translation.width < -width * 0.25 || v.predictedEndTranslation.width < -width * 0.6)) }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            if scrimOpacity > 0.001 {
                Color.black.opacity(scrimOpacity)
                    .ignoresSafeArea()
                    .onTapGesture { settle(open: false) }
                    .gesture(closeDrag)
            }
            DrawerView()
                .frame(width: width)
                .frame(maxHeight: .infinity)
                .background(Palette.background.ignoresSafeArea())
                .clipShape(RoundedCornerShape(radius: 28, corners: [.topRight, .bottomRight]))
                .offset(x: offsetX)
                .gesture(closeDrag)
            if !model.drawerOpen && model.path.isEmpty {
                // Swipe in from the left edge to open the menu
                Color.clear
                    .frame(width: 22)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 130)
                    .contentShape(Rectangle())
                    .gesture(openDrag)
            }
        }
        .allowsHitTesting(model.drawerOpen || drag != 0 || model.path.isEmpty)
    }
}

struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let p = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(p.cgPath)
    }
}

struct DrawerView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: AppSettings

    private var groups: [[DrawerEntry]] {
        return [
            [
                DrawerEntry(id: "scan", target: .scan, symbol: "qrcode.viewfinder", label: L.t("menu_scan")),
                DrawerEntry(id: "image", target: nil, symbol: "photo", label: L.t("menu_scan_image")),
            ],
            [
                DrawerEntry(id: "fav", target: .favorites, symbol: "star", label: L.t("menu_favorites")),
                DrawerEntry(id: "hist", target: .history, symbol: "clock.arrow.circlepath", label: L.t("menu_history")),
            ],
            [
                DrawerEntry(id: "myqr", target: .myQR, symbol: "person.crop.square", label: L.t("menu_my_qr")),
                DrawerEntry(id: "create", target: .create, symbol: "square.and.pencil", label: L.t("menu_create")),
            ],
            [
                DrawerEntry(id: "settings", target: .settings, symbol: "gearshape", label: L.t("menu_settings")),
            ],
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Image("AppLogo")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Text("QR Scanner")
                        .font(Typo.titleLarge)
                        .foregroundColor(Palette.onSurface)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 20)

                ForEach(Array(groups.enumerated()), id: \.offset) { gi, group in
                    if gi > 0 {
                        Hairline()
                            .padding(.horizontal, 28)
                            .padding(.vertical, 8)
                    }
                    ForEach(group) { entry in
                        item(entry)
                    }
                }
                Spacer(minLength: 24)
            }
        }
    }

    private func item(_ e: DrawerEntry) -> some View {
        let selected = e.target != nil && e.target == model.top
        return Button {
            if let t = e.target {
                withAnimation(.easeOut(duration: 0.22)) { model.go(t) }
            } else {
                model.pickImage()
            }
        } label: {
            HStack(spacing: 18) {
                Image(systemName: e.symbol)
                    .font(.system(size: 20))
                    .frame(width: 26)
                    .foregroundColor(selected ? settings.accent : Palette.onVariant)
                Text(e.label)
                    .font(Typo.titleMedium)
                    .foregroundColor(selected ? settings.accent : Palette.onSurface)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(selected ? settings.accent.opacity(0.16) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }
}
