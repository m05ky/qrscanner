import SwiftUI

/// Accent colored top bar with a menu (or back) button, a centered title and optional trailing buttons.
struct AppTopBar<Trailing: View>: View {
    @EnvironmentObject var settings: AppSettings
    let title: String
    var onMenu: (() -> Void)?
    var onBack: (() -> Void)?
    let trailing: Trailing

    init(_ title: String, onMenu: (() -> Void)? = nil, onBack: (() -> Void)? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.onMenu = onMenu
        self.onBack = onBack
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            Text(title)
                .font(Typo.titleLarge)
                .lineLimit(1)
                .padding(.horizontal, 96)
            HStack(spacing: 0) {
                if let onBack = onBack {
                    barButton("chevron.left", label: L.t("back"), action: onBack)
                } else if let onMenu = onMenu {
                    barButton("line.3.horizontal", label: L.t("open_menu"), action: onMenu)
                }
                Spacer()
                trailing
            }
            .padding(.horizontal, 4)
        }
        .foregroundColor(settings.onAccent)
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .background(settings.accent.ignoresSafeArea(edges: .top))
    }

    private func barButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 48, height: 48)
        }
        .accessibilityLabel(label)
    }
}

extension AppTopBar where Trailing == EmptyView {
    init(_ title: String, onMenu: (() -> Void)? = nil, onBack: (() -> Void)? = nil) {
        self.init(title, onMenu: onMenu, onBack: onBack, trailing: { EmptyView() })
    }
}

/// Round bar button used in the trailing slot of AppTopBar.
struct BarIconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 44, height: 48)
        }
        .accessibilityLabel(label)
    }
}

struct SectionHeader: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(Typo.labelMedium)
            .tracking(1.2)
            .foregroundColor(Palette.onVariant)
            .padding(.leading, 20)
            .padding(.trailing, 16)
            .padding(.top, 24)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Rounded card that holds rows separated by hairlines.
struct RowCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) { content }
            .frame(maxWidth: .infinity)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 12)
    }
}

/// Rounded tonal tile that holds an SF Symbol.
struct IconTile: View {
    let symbol: String
    var size: CGFloat = 44
    var tint: Color = Palette.onSurface

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).fill(Palette.variant)
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundColor(tint)
        }
        .frame(width: size, height: size)
    }
}

struct Hairline: View {
    var leading: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Palette.outline)
            .frame(height: 1)
            .padding(.leading, leading)
    }
}

/// One icon + title row of the create lists. The icon slot is always 48 pt wide.
struct IconRow<Icon: View>: View {
    let title: String
    let showDivider: Bool
    let action: () -> Void
    let icon: Icon

    init(title: String, showDivider: Bool, action: @escaping () -> Void, @ViewBuilder icon: () -> Icon) {
        self.title = title
        self.showDivider = showDivider
        self.action = action
        self.icon = icon()
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 16) {
                    icon.frame(width: 48, height: 48)
                    Text(title)
                        .font(Typo.titleMedium)
                        .foregroundColor(Palette.onSurface)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 68)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showDivider { Hairline(leading: 80) }
        }
    }
}

/// Filled accent button.
struct AccentButton: View {
    @EnvironmentObject var settings: AppSettings
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typo.font(16, .semibold))
                .foregroundColor(settings.onAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(settings.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
