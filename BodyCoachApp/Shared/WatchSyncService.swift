import Foundation
import Observation
import WatchConnectivity

@MainActor
@Observable
final class WatchSyncService: NSObject {
    static let shared = WatchSyncService()

    private(set) var latestPayload: WatchSummaryPayload?
    private(set) var latestCheckIn: WatchSubjectiveCheckInPayload?
    private(set) var lastReceivedAt: Date?
    private(set) var lastCheckInSentAt: Date?
    private(set) var activationState: WCSessionActivationState = .notActivated
    private(set) var isReachable: Bool = false
    var onCheckInReceived: ((WatchSubjectiveCheckInPayload) -> Void)?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    override private init() {
        super.init()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func activate() {
        guard WCSession.isSupported() else {
            return
        }

        let session = WCSession.default
        if session.delegate !== self {
            session.delegate = self
        }

        session.activate()
        activationState = session.activationState
        isReachable = session.isReachable
    }

    func send(_ payload: WatchSummaryPayload) {
        latestPayload = payload

        guard WCSession.isSupported() else {
            return
        }

        let session = WCSession.default
        guard session.activationState == .activated else {
            return
        }

        let context = makeContext(from: payload)

        #if os(iOS)
        do {
            try session.updateApplicationContext(context)
        } catch {
            return
        }

        if session.isWatchAppInstalled, session.isReachable {
            session.sendMessage(context, replyHandler: nil)
        }
        #endif
    }

    func send(_ checkIn: WatchSubjectiveCheckInPayload) {
        latestCheckIn = checkIn
        lastCheckInSentAt = Date()

        guard WCSession.isSupported() else {
            return
        }

        let session = WCSession.default
        guard session.activationState == .activated else {
            return
        }

        let message = makeMessage(from: checkIn)

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
        } else {
            session.transferUserInfo(message)
        }
    }

    private func receiveSummary(data: Data?, receivedAt: Date) {
        guard let data, let payload = decodePayload(from: data) else {
            return
        }

        latestPayload = payload
        lastReceivedAt = receivedAt
    }

    private func receiveCheckIn(data: Data?) {
        guard let data, let checkIn = decodeCheckIn(from: data) else {
            return
        }

        latestCheckIn = checkIn
        onCheckInReceived?(checkIn)
    }

    private func sendLatestPayloadIfNeeded() {
        #if os(iOS)
        guard let latestPayload else {
            return
        }

        send(latestPayload)
        #endif
    }

    private func sendLatestCheckInIfNeeded() {
        guard let latestCheckIn else {
            return
        }

        send(latestCheckIn)
    }

    private func decodePayload(from data: Data) -> WatchSummaryPayload? {
        try? decoder.decode(WatchSummaryPayload.self, from: data)
    }

    private nonisolated static func payloadData(from context: [String: Any]) -> Data? {
        context[payloadKey] as? Data
    }

    private func decodeCheckIn(from data: Data) -> WatchSubjectiveCheckInPayload? {
        try? decoder.decode(WatchSubjectiveCheckInPayload.self, from: data)
    }

    private nonisolated static func checkInData(from context: [String: Any]) -> Data? {
        context[checkInKey] as? Data
    }

    private func makeContext(from payload: WatchSummaryPayload) -> [String: Any] {
        guard let data = try? encoder.encode(payload) else {
            return [:]
        }

        return [Self.payloadKey: data]
    }

    private func makeMessage(from checkIn: WatchSubjectiveCheckInPayload) -> [String: Any] {
        guard let data = try? encoder.encode(checkIn) else {
            return [:]
        }

        return [Self.checkInKey: data]
    }

    private nonisolated static let payloadKey = "watchSummaryPayload"
    private nonisolated static let checkInKey = "watchSubjectiveCheckIn"
}

extension WatchSyncService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let reachable = session.isReachable
        let payloadData = Self.payloadData(from: session.receivedApplicationContext)
        let checkInData = Self.checkInData(from: session.receivedApplicationContext)
        let receivedAt = Date()

        Task { @MainActor in
            self.activationState = activationState
            self.isReachable = reachable

            if activationState == .activated {
                self.receiveSummary(data: payloadData, receivedAt: receivedAt)
                self.receiveCheckIn(data: checkInData)
                self.sendLatestPayloadIfNeeded()
                self.sendLatestCheckInIfNeeded()
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable

        Task { @MainActor in
            self.isReachable = reachable

            if reachable {
                self.sendLatestPayloadIfNeeded()
                self.sendLatestCheckInIfNeeded()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let payloadData = Self.payloadData(from: applicationContext)
        let checkInData = Self.checkInData(from: applicationContext)
        let receivedAt = Date()

        Task { @MainActor in
            self.receiveSummary(data: payloadData, receivedAt: receivedAt)
            self.receiveCheckIn(data: checkInData)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let payloadData = Self.payloadData(from: message)
        let checkInData = Self.checkInData(from: message)
        let receivedAt = Date()

        Task { @MainActor in
            self.receiveSummary(data: payloadData, receivedAt: receivedAt)
            self.receiveCheckIn(data: checkInData)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let checkInData = Self.checkInData(from: userInfo)

        Task { @MainActor in
            self.receiveCheckIn(data: checkInData)
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        let activationState = session.activationState

        Task { @MainActor in
            self.activationState = activationState
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
