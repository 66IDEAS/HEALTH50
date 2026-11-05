import SwiftUI

@main
struct Health50App: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Background runs must be registered before the app finishes launching.
        AutoExport.register()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if model.hasOnboarded {
                    MainView()
                } else {
                    WelcomeView()
                }
            }
            .environment(model)
            .task { await model.refresh() }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active: Task { await model.refresh() }
                case .background: AutoExport.schedule()
                default: break
                }
            }
        }
    }
}
