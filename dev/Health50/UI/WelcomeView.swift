import SwiftUI

/// The one explanation screen on first launch, before the iOS Health permission sheet.
struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @State private var page: WebPage?
    @State private var working = false
    /// True on short screens, such as the cover display of an iPhone Duo or a phone in landscape.
    @State private var compact = false
    /// True on wide screens, such as the open iPhone Duo: the screen is then split into two columns.
    @State private var wide = false

    var body: some View {
        Group {
            if wide {
                // Two columns that fill the screen: the brand on the left, everything to read and do on the right.
                HStack(spacing: 0) {
                    brand(small: false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    VStack(spacing: 0) {
                        // Level with the brand where there is room, scrolling where there is not.
                        ViewThatFits(in: .vertical) {
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                features(small: false, fill: true)
                                Spacer(minLength: 0)
                            }
                            ScrollView {
                                features(small: true, fill: true).padding(.top, 16)
                            }
                            .scrollBounceBehavior(.basedOnSize)
                        }
                        bottom
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 0) {
                            brand(small: compact).padding(.top, compact ? 16 : 44)
                            features(small: compact).padding(.top, compact ? 20 : 36)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    bottom
                }
            }
        }
        .background(Color.screen)
        .onGeometryChange(for: Bool.self) { $0.size.height < 700 } action: { compact = $0 }
        .onGeometryChange(for: Bool.self) { $0.size.width >= 700 } action: { wide = $0 }
        .sheet(item: $page) { SafariView(url: $0.url).ignoresSafeArea() }
    }

    private func brand(small: Bool) -> some View {
        VStack(spacing: small ? 14 : 22) {
            Image("AppIconImage")
                .resizable()
                .frame(width: small ? 72 : 96, height: small ? 72 : 96)
                .clipShape(RoundedRectangle(cornerRadius: small ? 16 : 21.5, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 16, y: 12)
                .accessibilityHidden(true)

            Image("LogoBy")
                .resizable()
                .scaledToFit()
                .frame(width: small ? 210 : 258)
                .accessibilityLabel(Text(verbatim: "Health50 by 66IDEAS"))
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func features(small: Bool, fill: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: small ? 14 : 24) {
            feature("curlybraces", "welcome.feature.json.title", "welcome.feature.json.text")
            feature("lock.fill", "welcome.feature.private.title", "welcome.feature.private.text")
            feature("eye", "welcome.feature.readonly.title", "welcome.feature.readonly.text")
        }
        .frame(maxWidth: fill ? .infinity : nil, alignment: .leading)
        .padding(.horizontal, 36)
        .padding(.bottom, small ? 12 : 24)
    }

    private var bottom: some View {
        VStack(spacing: 10) {
            Text("welcome.note")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            Button("common.privacyPolicy") { page = WebPage(url: AppModel.privacyURL) }
                .font(.system(size: 13))
                .padding(.bottom, 6)
            Button("common.continue") {
                working = true
                Task { await model.finishOnboarding(); working = false }
            }
            .buttonStyle(CapsuleButtonStyle(kind: .primary))
            .disabled(working)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private func feature(_ symbol: String, _ title: LocalizedStringKey, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 36)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(text).font(.system(size: 15)).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
