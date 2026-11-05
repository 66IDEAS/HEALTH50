import SwiftUI

/// The one explanation screen on first launch, before the iOS Health permission sheet.
struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @State private var page: WebPage?
    @State private var working = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    Image("AppIconImage")
                        .resizable()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 21.5, style: .continuous))
                        .shadow(color: .black.opacity(0.3), radius: 16, y: 12)
                        .padding(.top, 44)
                        .accessibilityHidden(true)

                    Image("LogoBy")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 258)
                        .padding(.top, 22)
                        .accessibilityLabel(Text(verbatim: "Health50 by 66IDEAS"))
                        .accessibilityAddTraits(.isHeader)

                    VStack(alignment: .leading, spacing: 24) {
                        feature("curlybraces", "welcome.feature.json.title", "welcome.feature.json.text")
                        feature("lock.fill", "welcome.feature.private.title", "welcome.feature.private.text")
                        feature("eye", "welcome.feature.readonly.title", "welcome.feature.readonly.text")
                    }
                    .padding(.horizontal, 36)
                    .padding(.top, 36)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

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
        .background(Color.screen)
        .sheet(item: $page) { SafariView(url: $0.url).ignoresSafeArea() }
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
