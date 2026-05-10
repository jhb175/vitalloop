import SwiftData
import SwiftUI

@main
struct BodyCoachApp: App {
    @State private var summaryStore = BodySummaryStore()
    @State private var persistenceStore = BodyCoachPersistenceStore()

    var body: some Scene {
        WindowGroup {
            BodyCoachRootView(store: summaryStore, persistenceStore: persistenceStore)
                .modelContainer(
                    for: [
                        UserGoal.self,
                        DailySummaryRecord.self,
                        SubjectiveCheckIn.self,
                        WeightEntry.self,
                        MealLogEntry.self
                    ]
                )
        }
    }
}
