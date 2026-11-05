import SwiftUI

/// The ring is the main visual element: closed when up to date, a progress ring while exporting,
/// orange when the user must act, red when a manual export failed.
struct RingView: View {
    enum Kind: Equatable {
        case idle(symbol: String)
        case closed(symbol: String, color: Color?)
        case open(symbol: String)
        case progress(Double)
    }

    let kind: Kind

    private var fraction: Double {
        switch kind {
        case .idle: 0
        case .closed: 1
        case .open: 0.72
        case .progress(let value): max(0.02, min(value, 1))
        }
    }

    private var tint: Color? {
        if case .closed(_, let color) = kind { color } else { nil }
    }

    private var hasGlow: Bool {
        switch kind {
        case .closed, .progress: true
        default: false
        }
    }

    var body: some View {
        ZStack {
            if hasGlow {
                Circle()
                    .fill(Color.card)
                    .padding(10)
                    .shadow(color: (tint ?? .brandFill).opacity(0.34), radius: 13, y: 10)
            }
            Circle().stroke(Color(.tertiarySystemFill), lineWidth: 9)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    tint.map { AnyShapeStyle($0) }
                        ?? AnyShapeStyle(LinearGradient(colors: [.brandLight, .brandFill], startPoint: .topLeading, endPoint: .bottomTrailing)),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.3), value: fraction)
            center
        }
        .padding(4.5)
        .frame(width: 96, height: 96)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var center: some View {
        switch kind {
        case .idle(let symbol), .open(let symbol):
            Image(systemName: symbol).font(.system(size: 32, weight: .semibold)).foregroundStyle(Color.accentColor)
        case .closed(let symbol, let color):
            Image(systemName: symbol).font(.system(size: 34, weight: .bold)).foregroundStyle(color ?? Color.accentColor)
        case .progress(let value):
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(Int((value * 100).rounded()))").font(.system(size: 22, weight: .bold)).monospacedDigit()
                Text(verbatim: "%").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            }
        }
    }
}

/// The card under the title that shows the current state at a glance.
struct StatusCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            RingView(kind: ring).padding(.bottom, 14)
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                line.font(.system(size: 15)).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.top, 4)
            }
            pill
            note
            button
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
    }

    private var ring: RingView.Kind {
        switch model.status {
        case .ready: .idle(symbol: "square.and.arrow.up")
        case .upToDate, .saved: .closed(symbol: "checkmark", color: nil)
        case .reconnect, .noData: .closed(symbol: "exclamationmark", color: .orange)
        case .exporting(let progress, _): .progress(progress)
        case .failed: .closed(symbol: "xmark", color: .red)
        case .waiting: .open(symbol: "clock.arrow.circlepath")
        }
    }

    private var title: LocalizedStringKey {
        switch model.status {
        case .ready: "status.ready.title"
        case .upToDate: "status.upToDate.title"
        case .reconnect: "status.attention.drive.title"
        case .exporting: "status.exporting.title"
        case .saved: "status.saved.title"
        case .failed: "status.failed.title"
        case .waiting: "status.waiting.title"
        case .noData: "status.noData.title"
        }
    }

    private var lines: [Text] {
        switch model.status {
        case .ready:
            [Text("status.ready.text")]
        case .upToDate(let date):
            [Text("status.lastDelivery \(Dates.relative(date))")]
        case .reconnect(let last):
            [last.map { Text("status.attention.drive.text \(Dates.day($0))") } ?? Text("notify.reconnect.body")]
        case .exporting(_, let upload):
            [Text(upload ? "status.uploading.text" : "status.exporting.text")]
        case .saved(_, _, let date):
            [Text(verbatim: Dates.standalone(date))]
        case .failed(let reason, _):
            [Text(Self.text(for: reason))]
        case .waiting(let reason, let last):
            [Text(Self.text(for: reason))] + (last.map { [Text("status.lastDelivery \(Dates.relative($0))")] } ?? [])
        case .noData:
            [Text("status.noData.text")]
        }
    }

    static func text(for reason: FailReason) -> LocalizedStringKey {
        switch reason {
        case .storage: "status.failed.reason.storage"
        case .upload: "status.failed.reason.upload"
        case .save: "status.failed.reason.save"
        case .generic: "status.failed.reason.generic"
        }
    }

    static func text(for reason: WaitReason) -> LocalizedStringKey {
        switch reason {
        case .wifi: "status.waiting.reason.wifi"
        case .locked: "status.waiting.reason.locked"
        case .system: "status.waiting.reason.system"
        }
    }

    @ViewBuilder private var pill: some View {
        switch model.status {
        case .upToDate, .waiting:
            if let folder = model.driveFolder {
                Pill { Image("GoogleDrive").resizable().scaledToFit().frame(width: 15, height: 14) } text: {
                    Text(verbatim: "\(String(localized: "drive.myDrive")) / \(folder)")
                }
            }
        case .saved(let folder, let bytes, _):
            Pill { Image(systemName: "folder").font(.system(size: 12, weight: .semibold)) } text: {
                Text(verbatim: "\(folder) · \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))")
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder private var note: some View {
        if case .saved = model.status {
            Text("status.saved.note")
                .font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.top, 12)
        }
    }

    @ViewBuilder private var button: some View {
        switch model.status {
        case .reconnect:
            Button("common.reconnect") { model.driveSheetError = nil; model.showDriveSheet = true }
                .buttonStyle(PillButtonStyle(color: .orange)).padding(.top, 16)
        case .failed(_, let retry):
            Button("common.tryAgain") { Task { await model.retry(retry) } }
                .buttonStyle(PillButtonStyle(color: .red)).padding(.top, 16)
        case .noData:
            Button("status.noData.button") { model.showHealthSheet = true }
                .buttonStyle(PillButtonStyle(color: .orange)).padding(.top, 16)
        default:
            EmptyView()
        }
    }
}

private struct Pill<Icon: View>: View {
    @ViewBuilder var icon: Icon
    @ViewBuilder var text: Text

    var body: some View {
        HStack(spacing: 7) {
            icon
            text.font(.system(size: 13, weight: .medium)).lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .frame(height: 30)
        .background(Color(.tertiarySystemFill), in: Capsule())
        .padding(.top, 12)
    }
}
