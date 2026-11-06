import SwiftUI

/// Google Drive setup: sign-in first, then account, export folder and disconnect.
struct DriveSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var askFolderName = false
    @State private var folderName = ""
    @State private var confirmDisconnect = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                Group { if model.driveConnected { connected } else { signIn } }
                    .readableWidth()
            }
            .background(Color.screen)
            .navigationTitle("auto.drive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.driveConnected {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("common.done") { model.finishDriveSetup() }.fontWeight(.semibold)
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.close", systemImage: "xmark") { dismiss() }
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.62), .large])
        .presentationDragIndicator(.visible)
        .alert("drive.folder.new.title", isPresented: $askFolderName) {
            TextField("drive.folder.new.title", text: $folderName)
            Button("common.cancel", role: .cancel) {}
            Button("common.done") { Task { await model.chooseFolder(named: folderName) } }
        } message: {
            Text("drive.folder.new.text")
        }
        .alert("drive.disconnect.confirm.title", isPresented: $confirmDisconnect) {
            Button("common.cancel", role: .cancel) {}
            Button("drive.disconnect", role: .destructive) { Task { await model.disconnect() } }
        } message: {
            Text("drive.disconnect.confirm.text")
        }
    }

    private var signIn: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white)
                .frame(width: 64, height: 64)
                .overlay(Image("GoogleDrive").resizable().scaledToFit().frame(width: 38, height: 34))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 6)
                .padding(.top, 8)
                .accessibilityHidden(true)
            Text("drive.intro.title")
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.top, 16)
            Text("drive.intro.text")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)

            Button {
                Task { await model.signIn() }
            } label: {
                HStack(spacing: 10) {
                    if model.signingIn {
                        ProgressView()
                    } else {
                        Image("GoogleG").resizable().scaledToFit().frame(width: 20, height: 20)
                    }
                    Text("drive.signIn").font(.system(size: 17, weight: .semibold)).foregroundStyle(Color(white: 0.12))
                }
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Capsule().fill(.white))
                .overlay(Capsule().strokeBorder(Color(white: 0.46), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(model.signingIn)
            .padding(.top, 24)

            if let error = model.driveSheetError {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }
            Text("drive.intro.note")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
                .padding(.horizontal, 12)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private var connected: some View {
        VStack(spacing: 0) {
            GroupCard {
                SettingRow(icon: .image("GoogleG"), label: "drive.account") {
                    Text(verbatim: model.driveEmail ?? "").font(.system(size: 17)).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle).layoutPriority(1)
                }
            }
            .padding(.top, 8)

            SectionTitle(text: "drive.folder.section")
            GroupCard {
                HStack(spacing: 12) {
                    IconTile(content: .symbol("folder.fill", .brandFill))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: model.driveFolder ?? AppModel.defaultFolderName).font(.system(size: 17))
                        Text("drive.myDrive").font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.accentColor)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 62)
                .accessibilityElement(children: .combine)

                Button {
                    folderName = model.driveFolder ?? AppModel.defaultFolderName
                    askFolderName = true
                } label: {
                    HStack {
                        Text("drive.folder.choose").font(.system(size: 17)).foregroundStyle(Color.accentColor)
                        Spacer()
                        Chevron()
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            SectionFootnote(text: "drive.folder.footer")

            if let error = model.driveSheetError {
                Text(error).font(.system(size: 13)).foregroundStyle(.red).padding(.top, 12).padding(.horizontal, 32)
            }

            GroupCard {
                Button(role: .destructive) {
                    confirmDisconnect = true
                } label: {
                    Text("drive.disconnect")
                        .font(.system(size: 17))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 26)
            .padding(.bottom, 24)
        }
    }
}

/// Guidance for changing what Health50 may read. iOS does not let an app open its own permission list.
struct HealthAccessSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white)
                        .frame(width: 64, height: 64)
                        .overlay(Image(systemName: "heart.fill").font(.system(size: 32)).foregroundStyle(.pink))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 6)
                        .padding(.top, 8)
                        .accessibilityHidden(true)
                    Text("healthSheet.heading")
                        .font(.system(size: 22, weight: .bold))
                        .multilineTextAlignment(.center)
                        .padding(.top, 16)
                    Text("healthSheet.text")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                        .padding(.horizontal, 28)

                    SectionTitle(text: "healthSheet.steps.section")
                    GroupCard {
                        step(1, "healthSheet.step1")
                        step(2, "healthSheet.step2")
                        step(3, "healthSheet.step3")
                    }

                    VStack(spacing: 4) {
                        Button("healthSheet.open") { model.openHealthApp() }
                            .buttonStyle(CapsuleButtonStyle(kind: .primary))
                        if model.hasTypesToReview {
                            Button("healthSheet.review") { Task { await model.reviewNewTypes() } }
                                .buttonStyle(CapsuleButtonStyle(kind: .plain))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }
                .readableWidth()
            }
            .background(Color.screen)
            .navigationTitle("health.row")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.fraction(0.72), .large])
        .presentationDragIndicator(.visible)
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: "\(number)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 30, height: 30)
                .background(Color.accentColor.opacity(0.15), in: Circle())
            Text(text).font(.system(size: 17)).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }
}
