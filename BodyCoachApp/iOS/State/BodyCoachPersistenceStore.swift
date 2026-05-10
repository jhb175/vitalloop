import Foundation
import Observation
import SwiftData
import BodyCoachCore

@MainActor
@Observable
final class BodyCoachPersistenceStore {
    private var modelContext: ModelContext?

    private(set) var latestSubjectiveCheckIn: WatchSubjectiveCheckInPayload?
    private(set) var currentGoal: UserGoal?
    private(set) var recentDailySummaries: [DailySummaryRecord] = []
    private(set) var recentSubjectiveCheckIns: [SubjectiveCheckIn] = []
    private(set) var recentWeightEntries: [WeightEntry] = []
    private(set) var recentMealLogs: [MealLogEntry] = []
    private(set) var lastPersistenceError: String?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadCurrentGoal()
        loadLatestSubjectiveCheckIn()
        loadRecentDailySummaries()
        loadRecentLogs()
    }

    func saveFatLossGoal(
        startWeightKg: Double?,
        targetWeightKg: Double?,
        targetDate: Date?,
        weeklyWeightLossTargetKg: Double?,
        preferredWorkoutMinutes: Int?,
        dietaryNotes: String,
        workScheduleNotes: String
    ) {
        guard let modelContext else {
            lastPersistenceError = "本地存储尚未就绪"
            return
        }

        do {
            let existingGoal = try currentGoal ?? latestGoal()
            let goal = existingGoal ?? UserGoal(goalType: .fatLoss)
            if existingGoal == nil {
                modelContext.insert(goal)
            }

            goal.goalType = .fatLoss
            goal.startWeightKg = startWeightKg
            goal.targetWeightKg = targetWeightKg
            goal.targetDate = targetDate
            goal.weeklyWeightLossTargetKg = weeklyWeightLossTargetKg
            goal.preferredWorkoutMinutes = preferredWorkoutMinutes
            goal.dietaryNotes = dietaryNotes
            goal.workScheduleNotes = workScheduleNotes
            goal.updatedAt = Date()

            try modelContext.save()
            currentGoal = goal
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = error.localizedDescription
        }
    }

    func loadCurrentGoal() {
        do {
            currentGoal = try latestGoal()
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = error.localizedDescription
        }
    }

    func save(checkIn: WatchSubjectiveCheckInPayload) {
        latestSubjectiveCheckIn = checkIn

        guard let modelContext else {
            lastPersistenceError = "本地存储尚未就绪"
            return
        }

        do {
            if let existing = try existingCheckIn(id: checkIn.id) {
                existing.capturedAt = checkIn.capturedAt
                existing.stress = SubjectiveCheckIn.clamped(checkIn.stress)
                existing.fatigue = SubjectiveCheckIn.clamped(checkIn.fatigue)
                existing.hunger = SubjectiveCheckIn.clamped(checkIn.hunger)
                existing.source = checkIn.source
            } else {
                modelContext.insert(SubjectiveCheckIn(checkIn: checkIn))
            }

            try modelContext.save()
            lastPersistenceError = nil
            loadRecentLogs()
        } catch {
            lastPersistenceError = error.localizedDescription
        }
    }

    func saveWeightEntry(weightKg: Double, note: String = "", source: String = "iPhone") {
        guard let modelContext else {
            lastPersistenceError = "本地存储尚未就绪"
            return
        }

        do {
            let entry = WeightEntry(weightKg: weightKg, source: source, note: note)
            modelContext.insert(entry)
            try modelContext.save()
            recentWeightEntries = try recentWeightEntryRecords(limit: 14)
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = error.localizedDescription
        }
    }

    func saveMealLog(kind: MealLogKind, note: String = "", source: String = "iPhone") {
        guard let modelContext else {
            lastPersistenceError = "本地存储尚未就绪"
            return
        }

        do {
            let entry = MealLogEntry(kind: kind, note: note, source: source)
            modelContext.insert(entry)
            try modelContext.save()
            recentMealLogs = try recentMealLogRecords(limit: 14)
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = error.localizedDescription
        }
    }

    func saveDailySummary(
        summary: DailyBodySummary,
        dataSource: BodySummaryDataSource,
        date: Date
    ) {
        guard let modelContext else {
            lastPersistenceError = "本地存储尚未就绪"
            return
        }

        do {
            let startOfDay = Calendar.current.startOfDay(for: date)
            let existingRecord = try existingDailySummary(on: startOfDay)
            let record = existingRecord ?? DailySummaryRecord(
                date: startOfDay,
                overallScore: summary.score.overall,
                statusRawValue: summary.score.status.rawValue,
                dataSourceRawValue: dataSource.rawValue,
                summaryText: summary.score.conciseExplanation,
                sleepScore: summary.score.sleep,
                recoveryScore: summary.score.recovery,
                activityScore: summary.score.activity,
                weightTrendScore: summary.score.weightTrend,
                dataCompleteness: summary.score.dataCompleteness
            )

            if existingRecord == nil {
                modelContext.insert(record)
            }

            record.updatedAt = Date()
            record.overallScore = summary.score.overall
            record.statusRawValue = summary.score.status.rawValue
            record.dataSourceRawValue = dataSource.rawValue
            record.summaryText = summary.score.conciseExplanation
            record.sleepScore = summary.score.sleep
            record.recoveryScore = summary.score.recovery
            record.activityScore = summary.score.activity
            record.weightTrendScore = summary.score.weightTrend
            record.dataCompleteness = summary.score.dataCompleteness

            try modelContext.save()
            recentDailySummaries = try recentDailySummaryRecords(limit: 14)
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = error.localizedDescription
        }
    }

    func loadLatestSubjectiveCheckIn() {
        guard let modelContext else {
            return
        }

        var descriptor = FetchDescriptor<SubjectiveCheckIn>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        do {
            latestSubjectiveCheckIn = try modelContext.fetch(descriptor).first.map(WatchSubjectiveCheckInPayload.init(record:))
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = error.localizedDescription
        }
    }

    func loadRecentDailySummaries(limit: Int = 14) {
        do {
            recentDailySummaries = try recentDailySummaryRecords(limit: limit)
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = error.localizedDescription
        }
    }

    func loadRecentLogs(limit: Int = 14) {
        do {
            recentSubjectiveCheckIns = try recentSubjectiveCheckInRecords(limit: limit)
            recentWeightEntries = try recentWeightEntryRecords(limit: limit)
            recentMealLogs = try recentMealLogRecords(limit: limit)
            latestSubjectiveCheckIn = recentSubjectiveCheckIns.first.map(WatchSubjectiveCheckInPayload.init(record:))
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = error.localizedDescription
        }
    }

    func deleteLocalData() {
        guard let modelContext else {
            lastPersistenceError = "本地存储尚未就绪"
            return
        }

        do {
            try deleteAll(UserGoal.self, in: modelContext)
            try deleteAll(DailySummaryRecord.self, in: modelContext)
            try deleteAll(SubjectiveCheckIn.self, in: modelContext)
            try deleteAll(WeightEntry.self, in: modelContext)
            try deleteAll(MealLogEntry.self, in: modelContext)
            try modelContext.save()
            latestSubjectiveCheckIn = nil
            currentGoal = nil
            recentDailySummaries = []
            recentSubjectiveCheckIns = []
            recentWeightEntries = []
            recentMealLogs = []
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = error.localizedDescription
        }
    }

    private func deleteAll<Model: PersistentModel>(_ modelType: Model.Type, in modelContext: ModelContext) throws {
        let descriptor = FetchDescriptor<Model>()
        let records = try modelContext.fetch(descriptor)
        records.forEach { modelContext.delete($0) }
    }

    private func existingCheckIn(id: UUID) throws -> SubjectiveCheckIn? {
        guard let modelContext else {
            return nil
        }

        var descriptor = FetchDescriptor<SubjectiveCheckIn>(
            predicate: #Predicate { record in
                record.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func latestGoal() throws -> UserGoal? {
        guard let modelContext else {
            return nil
        }

        var descriptor = FetchDescriptor<UserGoal>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func existingDailySummary(on startOfDay: Date) throws -> DailySummaryRecord? {
        guard let modelContext else {
            return nil
        }

        var descriptor = FetchDescriptor<DailySummaryRecord>(
            predicate: #Predicate { record in
                record.date == startOfDay
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func recentDailySummaryRecords(limit: Int) throws -> [DailySummaryRecord] {
        guard let modelContext else {
            return []
        }

        var descriptor = FetchDescriptor<DailySummaryRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    private func recentSubjectiveCheckInRecords(limit: Int) throws -> [SubjectiveCheckIn] {
        guard let modelContext else {
            return []
        }

        var descriptor = FetchDescriptor<SubjectiveCheckIn>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    private func recentWeightEntryRecords(limit: Int) throws -> [WeightEntry] {
        guard let modelContext else {
            return []
        }

        var descriptor = FetchDescriptor<WeightEntry>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    private func recentMealLogRecords(limit: Int) throws -> [MealLogEntry] {
        guard let modelContext else {
            return []
        }

        var descriptor = FetchDescriptor<MealLogEntry>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }
}

private extension SubjectiveCheckIn {
    convenience init(checkIn: WatchSubjectiveCheckInPayload) {
        self.init(
            id: checkIn.id,
            capturedAt: checkIn.capturedAt,
            stress: checkIn.stress,
            fatigue: checkIn.fatigue,
            hunger: checkIn.hunger,
            source: checkIn.source
        )
    }
}

private extension WatchSubjectiveCheckInPayload {
    init(record: SubjectiveCheckIn) {
        self.init(
            id: record.id,
            capturedAt: record.capturedAt,
            stress: record.stress,
            fatigue: record.fatigue,
            hunger: record.hunger,
            source: record.source
        )
    }
}
