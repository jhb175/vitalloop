import Foundation
import Observation

@MainActor
@Observable
final class WatchSummaryStore {
    private let syncService: WatchSyncService

    init(syncService: WatchSyncService = .shared) {
        self.syncService = syncService
    }

    var payload: WatchSummaryPayload {
        syncService.latestPayload ?? .sample
    }

    var lastReceivedAt: Date? {
        syncService.lastReceivedAt
    }

    var usesLiveSync: Bool {
        syncService.latestPayload != nil
    }

    var syncStatusLabel: String {
        if let lastReceivedAt {
            return lastReceivedAt.formatted(date: .omitted, time: .shortened)
        }

        if syncService.isCounterpartAppInstalled {
            return syncService.lastSyncEvent
        }

        return "等待 iPhone"
    }

    var latestCheckIn: WatchSubjectiveCheckInPayload? {
        syncService.latestCheckIn
    }

    var lastCheckInSentAt: Date? {
        syncService.lastCheckInSentAt
    }

    var checkInDeliveryLabel: String {
        if let acknowledgedAt = syncService.lastCheckInAcknowledgedAt {
            return "iPhone 已确认 \(acknowledgedAt.formatted(date: .omitted, time: .shortened))"
        }

        if let sentAt = syncService.lastCheckInSentAt {
            return "已发送 \(sentAt.formatted(date: .omitted, time: .shortened))"
        }

        return "保存"
    }

    var checkInSyncDetail: String {
        if let latestCheckIn = syncService.latestPayload?.latestCheckIn {
            return "已计入评分 · \(latestCheckIn.compactSummary)"
        }

        if syncService.lastCheckInSentAt != nil {
            return "等待 iPhone 回传评分"
        }

        return "记录后会同步到 iPhone"
    }

    func activate() {
        syncService.activate()
    }

    func sendCheckIn(stress: Int, fatigue: Int, hunger: Int) {
        syncService.send(
            WatchSubjectiveCheckInPayload(
                stress: stress,
                fatigue: fatigue,
                hunger: hunger
            )
        )
    }
}
