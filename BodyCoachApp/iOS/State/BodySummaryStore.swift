import BodyCoachCore
import Foundation
import Observation
import WatchConnectivity

@MainActor
@Observable
final class BodySummaryStore {
    private let healthKitClient: HealthKitClient
    private let scorer: BodyCoachScorer
    private let watchSyncService: WatchSyncService
    private var persistenceStore: BodyCoachPersistenceStore?

    private(set) var summary: DailyBodySummary
    private(set) var dashboardSnapshot: BodyDashboardSnapshot
    private(set) var dashboardTrends: BodyDashboardTrends
    private(set) var permissionState: HealthPermissionState = .notRequested
    private(set) var dataSource: BodySummaryDataSource = .sample
    private(set) var lastUpdated: Date?
    private(set) var latestSubjectiveCheckIn: WatchSubjectiveCheckInPayload?
    var currentGoal: UserGoal? {
        persistenceStore?.currentGoal
    }
    var watchSyncDiagnostics: WatchSyncDiagnostics {
        WatchSyncDiagnostics(
            activationState: watchSyncService.activationState.displayName,
            isReachable: watchSyncService.isReachable,
            isCounterpartInstalled: watchSyncService.isCounterpartAppInstalled,
            lastEvent: watchSyncService.lastSyncEvent,
            lastError: watchSyncService.lastSyncError,
            lastReceivedAt: watchSyncService.lastReceivedAt,
            lastCheckInSentAt: watchSyncService.lastCheckInSentAt,
            lastCheckInReceivedAt: watchSyncService.lastCheckInReceivedAt,
            lastCheckInAcknowledgedAt: watchSyncService.lastCheckInAcknowledgedAt
        )
    }

    init(
        healthKitClient: HealthKitClient = HealthKitClient(),
        scorer: BodyCoachScorer = BodyCoachScorer(),
        watchSyncService: WatchSyncService = .shared
    ) {
        self.healthKitClient = healthKitClient
        self.scorer = scorer
        self.watchSyncService = watchSyncService
        self.summary = SampleBodyData.summary
        self.dashboardSnapshot = SampleBodyData.dashboardSnapshot
        self.dashboardTrends = SampleBodyData.dashboardTrends
        self.watchSyncService.onCheckInReceived = { [weak self] checkIn in
            self?.handleSubjectiveCheckIn(checkIn)
        }
    }

    func configurePersistence(_ persistenceStore: BodyCoachPersistenceStore) {
        self.persistenceStore = persistenceStore

        persistenceStore.loadCurrentGoal()
        if let persistedCheckIn = persistenceStore.latestSubjectiveCheckIn {
            latestSubjectiveCheckIn = persistedCheckIn
        }
        refreshSummary()
    }

    func activateWatchSync() {
        watchSyncService.activate()

        if let syncedCheckIn = watchSyncService.latestCheckIn {
            handleSubjectiveCheckIn(syncedCheckIn)
        } else if let persistedCheckIn = persistenceStore?.latestSubjectiveCheckIn {
            latestSubjectiveCheckIn = persistedCheckIn
            refreshSummary()
        }

        sendWatchSummary()
    }

    func connectAppleHealth() async {
        guard healthKitClient.isHealthDataAvailable else {
            permissionState = .unavailable
            dataSource = .sample
            summary = SampleBodyData.summary
            dashboardSnapshot = SampleBodyData.dashboardSnapshot
            dashboardTrends = SampleBodyData.dashboardTrends
            sendWatchSummary()
            return
        }

        permissionState = .requesting

        do {
            try await healthKitClient.requestAuthorization()

            async let snapshotTask = healthKitClient.todaySnapshot()
            async let trendsTask = healthKitClient.dashboardTrends()

            let snapshot = try await snapshotTask
            let trends = await trendsTask
            let dashboard = snapshot.dashboardSnapshot

            guard dashboard.hasAnyHealthSignal else {
                permissionState = .noData
                dataSource = .sample
                summary = SampleBodyData.summary
                dashboardSnapshot = SampleBodyData.dashboardSnapshot
                dashboardTrends = BodyDashboardTrends.empty(anchorDate: snapshot.date)
                lastUpdated = snapshot.date
                sendWatchSummary(updatedAt: snapshot.date)
                return
            }

            dashboardSnapshot = dashboard
            dashboardTrends = trends
            dataSource = .healthKit
            permissionState = state(for: dashboard)
            refreshSummary()
            lastUpdated = snapshot.date
            sendWatchSummary(updatedAt: snapshot.date)
        } catch {
            permissionState = .noData
            dataSource = .sample
            summary = SampleBodyData.summary
            dashboardSnapshot = SampleBodyData.dashboardSnapshot
            dashboardTrends = SampleBodyData.dashboardTrends
            sendWatchSummary()
        }
    }

    func clearLocalData() {
        persistenceStore?.deleteLocalData()
        latestSubjectiveCheckIn = nil
        refreshSummary()
        sendWatchSummary()
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
        persistenceStore?.saveFatLossGoal(
            startWeightKg: startWeightKg,
            targetWeightKg: targetWeightKg,
            targetDate: targetDate,
            weeklyWeightLossTargetKg: weeklyWeightLossTargetKg,
            preferredWorkoutMinutes: preferredWorkoutMinutes,
            dietaryNotes: dietaryNotes,
            workScheduleNotes: workScheduleNotes
        )
        refreshSummary()
        sendWatchSummary()
    }

    func saveSubjectiveCheckIn(stress: Int, fatigue: Int, hunger: Int, source: String = "iPhone") {
        handleSubjectiveCheckIn(
            WatchSubjectiveCheckInPayload(
                stress: stress,
                fatigue: fatigue,
                hunger: hunger,
                source: source
            )
        )
    }

    private func sendWatchSummary(updatedAt: Date = Date()) {
        watchSyncService.send(
            WatchSummaryPayload(
                summary: summary,
                snapshot: dashboardSnapshot,
                trends: dashboardTrends,
                updatedAt: updatedAt
            )
        )
    }

    private func handleSubjectiveCheckIn(_ checkIn: WatchSubjectiveCheckInPayload) {
        latestSubjectiveCheckIn = checkIn
        persistenceStore?.save(checkIn: checkIn)
        refreshSummary()
        sendWatchSummary()
    }

    private func refreshSummary() {
        summary = scorer.summarize(
            dashboardSnapshot.bodyMetrics(subjectiveCheckIn: latestSubjectiveCheckIn),
            goal: currentGoal?.bodyGoalContext(currentWeightKg: dashboardSnapshot.weightKg)
        )
        persistenceStore?.saveDailySummary(
            summary: summary,
            dataSource: dataSource,
            date: dashboardSnapshot.date
        )
    }

    private func state(for snapshot: BodyDashboardSnapshot) -> HealthPermissionState {
        let available = snapshot.availableFieldCount
        let expected = snapshot.expectedFieldCount

        if available >= 4 {
            return .authorized
        }

        return .partialData(available, expected)
    }
}

enum BodySummaryDataSource: Equatable, Sendable {
    case sample
    case healthKit

    var displayName: String {
        switch self {
        case .sample:
            return "模拟数据"
        case .healthKit:
            return "Apple 健康"
        }
    }
}

struct WatchSyncDiagnostics: Equatable {
    var activationState: String
    var isReachable: Bool
    var isCounterpartInstalled: Bool
    var lastEvent: String
    var lastError: String?
    var lastReceivedAt: Date?
    var lastCheckInSentAt: Date?
    var lastCheckInReceivedAt: Date?
    var lastCheckInAcknowledgedAt: Date?
}

private extension WCSessionActivationState {
    var displayName: String {
        switch self {
        case .notActivated:
            return "未激活"
        case .inactive:
            return "非活跃"
        case .activated:
            return "已激活"
        @unknown default:
            return "未知"
        }
    }
}

extension BodySummaryDataSource {
    var rawValue: String {
        switch self {
        case .sample:
            return "sample"
        case .healthKit:
            return "healthKit"
        }
    }
}

private extension UserGoal {
    func bodyGoalContext(currentWeightKg: Double?) -> BodyGoalContext {
        BodyGoalContext(
            kind: goalType.bodyGoalKind,
            currentWeightKg: currentWeightKg ?? startWeightKg,
            targetWeightKg: targetWeightKg,
            targetDate: targetDate,
            weeklyWeightLossTargetKg: weeklyWeightLossTargetKg,
            preferredWorkoutMinutes: preferredWorkoutMinutes.map(Double.init)
        )
    }
}

private extension UserGoalType {
    var bodyGoalKind: BodyGoalKind {
        switch self {
        case .fatLoss:
            return .fatLoss
        case .muscleGain:
            return .muscleGain
        case .stressReduction:
            return .stressReduction
        case .fitness:
            return .fitness
        case .skill:
            return .skill
        }
    }
}
