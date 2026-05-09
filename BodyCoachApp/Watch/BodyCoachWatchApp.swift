import SwiftUI

@main
struct BodyCoachWatchApp: App {
    @State private var summaryStore = WatchSummaryStore()

    var body: some Scene {
        WindowGroup {
            WatchRootView(store: summaryStore)
                .task {
                    summaryStore.activate()
                }
        }
    }
}
