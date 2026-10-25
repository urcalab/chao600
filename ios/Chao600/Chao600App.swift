import SwiftUI

@main
struct Chao600App: App {
    @State private var model = BlockerModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .tint(Color(.accent))
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: Task { await model.refresh() }
            case .background: model.scheduleBackgroundRefresh()
            default: break
            }
        }
        .backgroundTask(.appRefresh(BlockerModel.refreshTaskID)) { [model] in
            await model.refresh()
            await model.scheduleBackgroundRefresh()
        }
    }
}
