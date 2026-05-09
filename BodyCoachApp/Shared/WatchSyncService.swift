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
    private(set) var lastCheckInReceivedAt: Date?
    private(set) var lastCheckInAcknowledgedAt: Date?
    private(set) var activationState: WCSessionActivationState = .notActivated
    private(set) var isReachable: Bool = false
    private(set) var lastSyncEvent: String = "尚未启动"
    private(set) var lastSyncError: String?
    var onCheckInReceived: ((WatchSubjectiveCheckInPayload) -> Void)?

    #if os(iOS)
    private(set) var isCounterpartAppInstalled: Bool = false
    #else
    private(set) var isCounterpartAppInstalled: Bool = true
    #endif

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    override private init() {
        super.init()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func activate() {
        guard WCSession.isSupported() else {
            record("当前系统不支持 WatchConnectivity")
            return
        }

        let session = WCSession.default
        if session.delegate !== self {
            session.delegate = self
        }

        session.activate()
        refreshState(from: session)
        record("正在激活 Watch 同步")
    }

    func send(_ payload: WatchSummaryPayload) {
        latestPayload = payload

        guard WCSession.isSupported() else {
            record("无法发送摘要：系统不支持 WatchConnectivity")
            return
        }

        let session = WCSession.default
        guard session.activationState == .activated else {
            refreshState(from: session)
            record("摘要已暂存，等待 Watch 同步激活")
            return
        }

        let context = makeContext(from: payload)

        #if os(iOS)
        do {
            try session.updateApplicationContext(context)
            refreshState(from: session)
            record("已向 Apple Watch 更新今日摘要")
        } catch {
            lastSyncError = error.localizedDescription
            refreshState(from: session)
            record("发送今日摘要失败：\(error.localizedDescription)")
            return
        }

        if session.isWatchAppInstalled, session.isReachable {
            session.sendMessage(context, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.lastSyncError = error.localizedDescription
                    self?.record("即时发送今日摘要失败：\(error.localizedDescription)")
                }
            }
        }
        #endif
    }

    func send(_ checkIn: WatchSubjectiveCheckInPayload) {
        latestCheckIn = checkIn
        lastCheckInSentAt = Date()

        guard WCSession.isSupported() else {
            record("无法发送主观记录：系统不支持 WatchConnectivity")
            return
        }

        let session = WCSession.default
        guard session.activationState == .activated else {
            refreshState(from: session)
            record("主观记录已暂存，等待 Watch 同步激活")
            return
        }

        let message = makeMessage(from: checkIn)

        if session.isReachable {
            session.sendMessage(message) { [weak self] reply in
                let acknowledged = Self.isAcknowledged(reply)
                Task { @MainActor in
                    if acknowledged {
                        self?.lastSyncError = nil
                        self?.lastCheckInAcknowledgedAt = Date()
                        self?.record("iPhone 已接收主观记录")
                    } else {
                        self?.record("主观记录已发送，等待 iPhone 确认")
                    }
                }
            } errorHandler: { [weak self] error in
                let message = error.localizedDescription
                Task { @MainActor in
                    self?.lastSyncError = message
                    self?.record("即时发送主观记录失败：\(message)")
                }
            }
            refreshState(from: session)
            record("已即时发送主观记录")
        } else {
            session.transferUserInfo(message)
            refreshState(from: session)
            record("已排队发送主观记录")
        }
    }

    private func receiveSummary(data: Data?, receivedAt: Date) {
        guard let data, let payload = decodePayload(from: data) else {
            return
        }

        latestPayload = payload
        lastReceivedAt = receivedAt
        record("已收到 iPhone 今日摘要")
    }

    @discardableResult
    private func receiveCheckIn(data: Data?, receivedAt: Date = Date()) -> Bool {
        guard let data, let checkIn = decodeCheckIn(from: data) else {
            return false
        }

        receiveCheckIn(checkIn, receivedAt: receivedAt)
        return true
    }

    private func receiveCheckIn(_ checkIn: WatchSubjectiveCheckInPayload, receivedAt: Date = Date()) {
        latestCheckIn = checkIn
        lastCheckInReceivedAt = receivedAt
        onCheckInReceived?(checkIn)
        record(checkInReceivedEvent)
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
        #if os(watchOS)
        guard let latestCheckIn else {
            return
        }

        send(latestCheckIn)
        #endif
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

    private nonisolated static func decodedCheckIn(from data: Data?) -> WatchSubjectiveCheckInPayload? {
        guard let data else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WatchSubjectiveCheckInPayload.self, from: data)
    }

    private nonisolated static func isAcknowledged(_ reply: [String: Any]) -> Bool {
        reply[acknowledgedKey] as? Bool == true
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

    private func refreshState(from session: WCSession) {
        activationState = session.activationState
        isReachable = session.isReachable

        #if os(iOS)
        isCounterpartAppInstalled = session.isWatchAppInstalled
        #else
        isCounterpartAppInstalled = session.isCompanionAppInstalled
        #endif
    }

    private func refreshState(from snapshot: WatchSessionSnapshot) {
        activationState = snapshot.activationState
        isReachable = snapshot.isReachable
        isCounterpartAppInstalled = snapshot.isCounterpartAppInstalled
    }

    private nonisolated static func snapshot(from session: WCSession) -> WatchSessionSnapshot {
        #if os(iOS)
        let isCounterpartAppInstalled = session.isWatchAppInstalled
        #else
        let isCounterpartAppInstalled = session.isCompanionAppInstalled
        #endif

        return WatchSessionSnapshot(
            activationState: session.activationState,
            isReachable: session.isReachable,
            isCounterpartAppInstalled: isCounterpartAppInstalled
        )
    }

    private func record(_ event: String) {
        lastSyncEvent = event
        print("[VitalLoopSync] \(event)")
    }

    private var checkInReceivedEvent: String {
        #if os(iOS)
        return "已收到 Watch 主观记录"
        #else
        return "已收到 iPhone 主观记录"
        #endif
    }

    private nonisolated static let payloadKey = "watchSummaryPayload"
    private nonisolated static let checkInKey = "watchSubjectiveCheckIn"
    private nonisolated static let acknowledgedKey = "acknowledged"
}

private struct WatchSessionSnapshot: Sendable {
    var activationState: WCSessionActivationState
    var isReachable: Bool
    var isCounterpartAppInstalled: Bool
}

extension WatchSyncService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let snapshot = Self.snapshot(from: session)
        let payloadData = Self.payloadData(from: session.receivedApplicationContext)
        let checkInData = Self.checkInData(from: session.receivedApplicationContext)
        let receivedAt = Date()
        let errorDescription = error?.localizedDescription

        Task { @MainActor in
            self.refreshState(from: snapshot)
            self.activationState = activationState

            if let errorDescription {
                self.lastSyncError = errorDescription
                self.record("Watch 同步激活失败：\(errorDescription)")
            } else {
                self.lastSyncError = nil
                self.record("Watch 同步已激活")
            }

            if activationState == .activated {
                self.receiveSummary(data: payloadData, receivedAt: receivedAt)
                self.receiveCheckIn(data: checkInData)
                self.sendLatestPayloadIfNeeded()
                self.sendLatestCheckInIfNeeded()
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let snapshot = Self.snapshot(from: session)

        Task { @MainActor in
            self.refreshState(from: snapshot)
            self.record(snapshot.isReachable ? "Watch 同步已可达" : "Watch 同步暂不可达")

            if snapshot.isReachable {
                self.sendLatestPayloadIfNeeded()
                self.sendLatestCheckInIfNeeded()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let payloadData = Self.payloadData(from: applicationContext)
        let checkInData = Self.checkInData(from: applicationContext)
        let receivedAt = Date()
        let snapshot = Self.snapshot(from: session)

        Task { @MainActor in
            self.refreshState(from: snapshot)
            self.receiveSummary(data: payloadData, receivedAt: receivedAt)
            self.receiveCheckIn(data: checkInData, receivedAt: receivedAt)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let payloadData = Self.payloadData(from: message)
        let checkInData = Self.checkInData(from: message)
        let receivedAt = Date()
        let snapshot = Self.snapshot(from: session)

        Task { @MainActor in
            self.refreshState(from: snapshot)
            self.receiveSummary(data: payloadData, receivedAt: receivedAt)
            self.receiveCheckIn(data: checkInData, receivedAt: receivedAt)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let payloadData = Self.payloadData(from: message)
        let checkInData = Self.checkInData(from: message)
        let checkIn = Self.decodedCheckIn(from: checkInData)
        let receivedAt = Date()
        let snapshot = Self.snapshot(from: session)

        replyHandler([Self.acknowledgedKey: checkIn != nil])

        Task { @MainActor in
            self.refreshState(from: snapshot)
            self.receiveSummary(data: payloadData, receivedAt: receivedAt)
            if let checkIn {
                self.receiveCheckIn(checkIn, receivedAt: receivedAt)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let checkInData = Self.checkInData(from: userInfo)
        let receivedAt = Date()
        let snapshot = Self.snapshot(from: session)

        Task { @MainActor in
            self.refreshState(from: snapshot)
            self.receiveCheckIn(data: checkInData, receivedAt: receivedAt)
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        let snapshot = Self.snapshot(from: session)

        Task { @MainActor in
            self.refreshState(from: snapshot)
            self.record("Watch 同步进入非活跃状态")
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
