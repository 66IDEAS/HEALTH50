import SwiftUI
import UniformTypeIdentifiers

/// The whole app is this one scrolling screen. Anything that needs more room opens as a sheet.
struct MainView: View {
    @Environment(AppModel.self) private var model
    @State private var page: WebPage?

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(spacing: 0) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 31)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 15)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    .accessibilityLabel(Text(verbatim: "Health50"))
                    .accessibilityAddTraits(.isHeader)

                StatusCard()
                actions
                AutomaticExportSection()
                healthAccess
                privacyNote
                footer
            }
            .padding(.bottom, 24)
        }
        .background(Color.screen)
        .scrollBounceBehavior(.basedOnSize)
        .fileImporter(isPresented: $model.showFolderPicker, allowedContentTypes: [.folder]) { result in
            // The user picked a location first; a cancelled picker changes nothing.
            if case .success(let folder) = result {
                Task { await model.save(to: folder) }
            }
        }
        .sheet(isPresented: $model.showDriveSheet) { DriveSheet() }
        .sheet(isPresented: $model.showHealthSheet) { HealthAccessSheet() }
        .sheet(item: $page) { SafariView(url: $0.url).ignoresSafeArea() }
        .alert("auto.section", isPresented: $model.showNotificationExplainer) {
            Button("common.continue") { Task { await model.askForNotifications() } }
        } message: {
            Text("notify.explain")
        }
    }

    // MARK: Manual actions

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                model.showFolderPicker = true
            } label: {
                Label("action.saveToFiles", systemImage: "folder")
            }
            .buttonStyle(CapsuleButtonStyle(kind: .primary))

            if model.driveConnected {
                Button {
                    Task { await model.uploadNow() }
                } label: {
                    Label("action.uploadNow", systemImage: "icloud.and.arrow.up")
                }
                .buttonStyle(CapsuleButtonStyle(kind: .tinted))
            }
        }
        .disabled(model.isBusy)
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    // MARK: Health access

    private var healthAccess: some View {
        VStack(spacing: 0) {
            SectionTitle(text: "health.section")
            GroupCard {
                Button {
                    model.showHealthSheet = true
                } label: {
                    SettingRow(icon: .symbolOnWhite("heart.fill", .pink), label: "health.row") {
                        Text("health.manage").font(.system(size: 17)).foregroundStyle(.secondary)
                        Chevron()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            SectionFootnote(text: "health.footer")
        }
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "lock.fill").font(.system(size: 12)).padding(.top, 2).accessibilityHidden(true)
            Text("privacy.note").font(.system(size: 13))
            Spacer(minLength: 0)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 32)
        .padding(.top, 26)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button("common.privacyPolicy") { page = WebPage(url: AppModel.privacyURL) }
                Text(verbatim: "·").foregroundStyle(.tertiary)
                Button("common.support") { page = WebPage(url: AppModel.supportURL) }
            }
            Text("footer.version \(model.version)").foregroundStyle(.tertiary)
        }
        .font(.system(size: 13))
        .frame(maxWidth: .infinity)
        .padding(.top, 26)
    }
}

/// Everything about scheduled delivery: the switch, and below it the settings that unfold when it is on.
struct AutomaticExportSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            SectionTitle(text: "auto.section")
            GroupCard {
                SettingRow(icon: .symbol("clock.arrow.circlepath", .brandFill), label: "auto.switch") {
                    Toggle("auto.switch", isOn: Binding(get: { model.automaticExport }, set: { model.setAutomaticExport($0) }))
                        .labelsHidden()
                        .tint(.brandFill)
                }
                if model.automaticExport {
                    SettingRow(icon: .symbol("calendar", .red), label: "auto.every") {
                        Text("auto.interval \(model.intervalDays)").font(.system(size: 17)).foregroundStyle(.secondary)
                        Stepper("auto.every", value: $model.intervalDays, in: 1...365).labelsHidden()
                    }
                    Button {
                        model.driveSheetError = nil
                        model.showDriveSheet = true
                    } label: {
                        SettingRow(icon: .image("GoogleDrive"), label: "auto.drive") {
                            driveValue
                            Chevron()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    SettingRow(icon: .symbol("antenna.radiowaves.left.and.right", .green), label: "auto.cellular") {
                        Toggle("auto.cellular", isOn: $model.useCellular).labelsHidden().tint(.brandFill)
                    }
                }
            }
            .animation(.snappy, value: model.automaticExport)
            SectionFootnote(text: footnote)
            if model.automaticExport, model.notificationsDenied {
                SectionFootnote(text: "auto.footer.notificationsOff")
            }
        }
    }

    @ViewBuilder private var driveValue: some View {
        if case .reconnect = model.status {
            Text("common.reconnect").font(.system(size: 17, weight: .medium)).foregroundStyle(.orange)
        } else if model.driveConnected, let folder = model.driveFolder {
            Text(verbatim: folder).font(.system(size: 17)).foregroundStyle(.secondary).lineLimit(1)
        } else {
            Text("auto.drive.connect").font(.system(size: 17)).foregroundStyle(Color.accentColor)
        }
    }

    /// Small text under the card that explains the current situation in plain words.
    private var footnote: LocalizedStringKey {
        guard model.automaticExport else {
            return model.lastSuccess == nil ? "auto.footer.off" : "auto.footer.switchedOff"
        }
        switch model.status {
        case .reconnect(let last):
            if let last { return "auto.footer.attention \(Dates.relative(last))" }
            return "auto.footer.setup"
        case .waiting(.wifi, _):
            return "auto.footer.waiting"
        default:
            guard model.driveConnected else { return "auto.footer.setup" }
            let next = (model.lastSuccess ?? .now).addingTimeInterval(Double(model.intervalDays) * 86_400)
            return next > .now ? "auto.footer.next \(Dates.relative(next))" : "auto.footer.nextSoon"
        }
    }
}
