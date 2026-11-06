import SafariServices
import SwiftUI

extension Color {
    /// Brand blue for filled buttons, switches and tiles. White content sits on top in both appearances.
    static let brandFill = Color(red: 0x2E / 255, green: 0x62 / 255, blue: 0xE8 / 255)
    /// Lighter brand blue, the gradient partner and the accent on dark backgrounds.
    static let brandLight = Color(red: 0x7A / 255, green: 0x99 / 255, blue: 0xF5 / 255)
    static let card = Color(.secondarySystemGroupedBackground)
    static let screen = Color(.systemGroupedBackground)
}

// MARK: Layout

extension View {
    /// Keeps the content of a sheet at a comfortable width and centres it where the sheet is wider.
    func readableWidth(_ limit: CGFloat = 560) -> some View {
        frame(maxWidth: limit).frame(maxWidth: .infinity)
    }
}

// MARK: Buttons

/// Full-width capsule button. `.primary` is filled blue, `.tinted` is light blue with blue text.
struct CapsuleButtonStyle: ButtonStyle {
    enum Kind { case primary, tinted, plain }
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        CapsuleLabel(configuration: configuration, kind: kind)
    }

    private struct CapsuleLabel: View {
        let configuration: Configuration
        let kind: Kind
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 17, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, minHeight: kind == .plain ? 44 : 52)
                .foregroundStyle(kind == .primary ? Color.white : Color.accentColor)
                .background {
                    switch kind {
                    case .primary:
                        Capsule().fill(LinearGradient(colors: [.brandLight, .brandFill], startPoint: UnitPoint(x: 0.5, y: -0.9), endPoint: UnitPoint(x: 0.5, y: 0.62)))
                            .shadow(color: Color.brandFill.opacity(isEnabled ? 0.35 : 0), radius: 8, y: 5)
                    case .tinted:
                        Capsule().fill(Color.accentColor.opacity(0.14))
                    case .plain:
                        Color.clear
                    }
                }
                .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.38)
                .contentShape(Capsule())
        }
    }
}

/// Small capsule button inside the status card ("Reconnect", "Try again").
struct PillButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .frame(minHeight: 44)
            .background(Capsule().fill(color))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: Rows

/// The small rounded icon at the start of a settings row.
struct IconTile: View {
    enum Content { case symbol(String, Color), image(String), symbolOnWhite(String, Color) }
    let content: Content

    var body: some View {
        Group {
            switch content {
            case .symbol(let name, let color):
                tile(color) { Image(systemName: name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white) }
            case .image(let name):
                tile(.white) { Image(name).resizable().scaledToFit().frame(width: 18, height: 18) }
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.black.opacity(0.14), lineWidth: 0.5))
            case .symbolOnWhite(let name, let color):
                tile(.white) { Image(systemName: name).font(.system(size: 15, weight: .semibold)).foregroundStyle(color) }
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.black.opacity(0.14), lineWidth: 0.5))
            }
        }
        .accessibilityHidden(true)
    }

    private func tile(_ color: Color, @ViewBuilder content: () -> some View) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(color)
            .frame(width: 30, height: 30)
            .overlay(content())
    }
}

/// One row of a grouped card: icon, label and whatever sits at the end.
struct SettingRow<Trailing: View>: View {
    let icon: IconTile.Content?
    let label: LocalizedStringKey
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            if let icon { IconTile(content: icon) }
            Text(label).font(.system(size: 17)).frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
    }
}

/// White rounded card that holds rows, with separators between them.
struct GroupCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(rows) { row in
                    row
                    if row.id != rows.last?.id {
                        Divider().padding(.leading, 58).padding(.trailing, 16)
                    }
                }
            }
        }
        .background(Color.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.horizontal, 16)
    }
}

struct SectionTitle: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.top, 26)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

struct SectionFootnote: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.top, 8)
    }
}

struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}

// MARK: In-app browser

struct WebPage: Identifiable {
    let url: URL
    var id: URL { url }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
