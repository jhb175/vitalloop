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
