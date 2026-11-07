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
    /// 0 = closed, 1 = open. Follows the finger while dragging, then a spring carries on from the release speed.
    @State private var progress: CGFloat = 0
    @State private var targetOpen = false
    @State private var dragStart: CGFloat?
    @State private var lastX: CGFloat = 0
    @State private var lastTime: Date = Date()
    @State private var velocity: CGFloat = 0

    private let width: CGFloat = 304

    /// Moves the menu to open / closed. `velocity` is in menu widths per second (positive = opening).
    private func settle(open: Bool, velocity: CGFloat) {
        targetOpen = open
        let target: CGFloat = open ? 1 : 0
        let distance = target - progress
        let relative: Double = abs(distance) > 0.001 ? Double(velocity / distance) : 0
        let stiffness = 320.0
        withAnimation(.interpolatingSpring(mass: 1, stiffness: stiffness, damping: 2 * stiffness.squareRoot(), initialVelocity: relative)) {
            progress = target
        }
        if model.drawerOpen != open { model.drawerOpen = open }
    }

    private var menuDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                if dragStart == nil {
                    dragStart = progress
                    lastX = v.translation.width
                    lastTime = v.time
                    velocity = 0
                }
                let start = dragStart ?? 0
                let next = min(1, max(0, start + v.translation.width / width))
                // No animation here: this also cancels a spring that is still running, so the menu can be caught.
                var tx = Transaction()
                tx.disablesAnimations = true
                withTransaction(tx) { progress = next }
                let dt = CGFloat(v.time.timeIntervalSince(lastTime))
                if dt > 0.004 {
                    let instant = (v.translation.width - lastX) / width / dt
                    velocity = velocity * 0.6 + instant * 0.4
                    lastX = v.translation.width
                    lastTime = v.time
                }
            }
            .onEnded { _ in
                dragStart = nil
                let projected = progress + velocity * 0.18
                settle(open: projected > 0.5, velocity: velocity)
            }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            if progress > 0.001 {
                Color.black.opacity(0.4 * Double(progress))
                    .ignoresSafeArea()
                    .onTapGesture { settle(open: false, velocity: 0) }
                    .gesture(menuDrag)
            }
            DrawerView()
                .frame(width: width)
                .frame(maxHeight: .infinity)
                .background(Palette.background.ignoresSafeArea())
                .clipShape(RoundedCornerShape(radius: 28, corners: [.topRight, .bottomRight]))
                .offset(x: -(1 - progress) * width)
                .gesture(menuDrag)
            if progress < 0.001 && model.path.isEmpty {
                // Swipe in from the left edge to open the menu
                Color.clear
                    .frame(width: 22)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 130)
                    .contentShape(Rectangle())
                    .gesture(menuDrag)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .allowsHitTesting(model.drawerOpen || progress > 0.001 || model.path.isEmpty)
        .onChange(of: model.drawerOpen) { open in
            if open != targetOpen { settle(open: open, velocity: 0) }
        }
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
                model.go(t)
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
