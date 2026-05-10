import SwiftData

enum BodyCoachSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [
            UserGoal.self,
            DailySummaryRecord.self,
            SubjectiveCheckIn.self,
            WeightEntry.self,
            MealLogEntry.self
        ]
    }
}

enum BodyCoachSchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            BodyCoachSchemaV1.self
        ]
    }

    static var stages: [MigrationStage] {
        []
    }
}

