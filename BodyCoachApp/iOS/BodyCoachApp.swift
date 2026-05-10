import SwiftData
import SwiftUI

@main
struct BodyCoachApp: App {
    @State private var summaryStore = BodySummaryStore()
    @State private var persistenceStore = BodyCoachPersistenceStore()
    @State private var reminderStore = BodyCoachReminderStore()
    private let modelContainer = BodyCoachApp.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            BodyCoachRootView(store: summaryStore, persistenceStore: persistenceStore, reminderStore: reminderStore)
                .modelContainer(modelContainer)
        }
    }

    private static func makeModelContainer() -> ModelContainer {
        do {
            return try ModelContainer(
                for: Schema(versionedSchema: BodyCoachSchemaV1.self),
                migrationPlan: BodyCoachSchemaMigrationPlan.self
            )
        } catch {
            fatalError("Unable to create VitalLoop local store: \(error.localizedDescription)")
        }
    }
}
