import Foundation
import Observation
@preconcurrency import UserNotifications

@MainActor
@Observable
final class BodyCoachReminderStore {
    var isWeightReminderEnabled: Bool
    var isSleepReminderEnabled: Bool
    var isMealReminderEnabled: Bool
    var weightReminderTime: Date
    var sleepReminderTime: Date
    var mealReminderTime: Date
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var lastReminderError: String?
    private(set) var pendingRouteRequest: BodyCoachReminderRouteRequest?
    private(set) var lastOpenedReminder: BodyCoachReminderRoute?
    private(set) var lastOpenedReminderAt: Date?
    private(set) var pendingNotificationCount = 0

    private let defaults: UserDefaults
    private let center: UNUserNotificationCenter
    private let calendar = Calendar.current
    private let notificationDelegate = BodyCoachNotificationDelegate()

    init(
        defaults: UserDefaults = .standard,
        center: UNUserNotificationCenter = .current()
    ) {
        self.defaults = defaults
        self.center = center
        self.isWeightReminderEnabled = defaults.bool(forKey: Keys.weightEnabled)
        self.isSleepReminderEnabled = defaults.bool(forKey: Keys.sleepEnabled)
        self.isMealReminderEnabled = defaults.bool(forKey: Keys.mealEnabled)
        self.weightReminderTime = Self.time(for: Keys.weightTime, defaults: defaults, defaultHour: 8, defaultMinute: 30)
        self.sleepReminderTime = Self.time(for: Keys.sleepTime, defaults: defaults, defaultHour: 22, defaultMinute: 30)
        self.mealReminderTime = Self.time(for: Keys.mealTime, defaults: defaults, defaultHour: 19, defaultMinute: 30)

        notificationDelegate.didOpenReminder = { [weak self] identifier, openedAt in
            Task { @MainActor in
                self?.handleNotificationOpen(identifier: identifier, openedAt: openedAt)
            }
        }
        center.delegate = notificationDelegate
    }

    var enabledReminderCount: Int {
        [isWeightReminderEnabled, isSleepReminderEnabled, isMealReminderEnabled].filter(\.self).count
    }

    var enabledReminderSummary: String {
        let enabled = [
            isWeightReminderEnabled ? BodyCoachReminderRoute.weight.displayName : nil,
            isSleepReminderEnabled ? BodyCoachReminderRoute.sleep.displayName : nil,
            isMealReminderEnabled ? BodyCoachReminderRoute.meal.displayName : nil
        ].compactMap(\.self)

        guard !enabled.isEmpty else {
            return "未开启任何提醒"
        }

        return "已开启：" + enabled.joined(separator: "、")
    }

    func activateNotificationRouting() {
        center.delegate = notificationDelegate
        refreshAuthorizationStatus()
        refreshPendingReminderCount()
    }

    func refreshAuthorizationStatus() {
        Task {
            let settings = await center.notificationSettings()
            authorizationStatus = settings.authorizationStatus
        }
    }

    func setWeightReminderEnabled(_ isEnabled: Bool) {
        isWeightReminderEnabled = isEnabled
        defaults.set(isEnabled, forKey: Keys.weightEnabled)
        applyReminder(
            isEnabled: isEnabled,
            reminder: .weight,
            time: weightReminderTime
        )
    }

    func setSleepReminderEnabled(_ isEnabled: Bool) {
        isSleepReminderEnabled = isEnabled
        defaults.set(isEnabled, forKey: Keys.sleepEnabled)
        applyReminder(
            isEnabled: isEnabled,
            reminder: .sleep,
            time: sleepReminderTime
        )
    }

    func setMealReminderEnabled(_ isEnabled: Bool) {
        isMealReminderEnabled = isEnabled
        defaults.set(isEnabled, forKey: Keys.mealEnabled)
        applyReminder(
            isEnabled: isEnabled,
            reminder: .meal,
            time: mealReminderTime
        )
    }

    func updateWeightReminderTime(_ time: Date) {
        weightReminderTime = time
        save(time, key: Keys.weightTime)
        if isWeightReminderEnabled {
            schedule(Reminder.weight, at: time)
        }
    }

    func updateSleepReminderTime(_ time: Date) {
        sleepReminderTime = time
        save(time, key: Keys.sleepTime)
        if isSleepReminderEnabled {
            schedule(Reminder.sleep, at: time)
        }
    }

    func updateMealReminderTime(_ time: Date) {
        mealReminderTime = time
        save(time, key: Keys.mealTime)
        if isMealReminderEnabled {
            schedule(Reminder.meal, at: time)
        }
    }

    private func applyReminder(
        isEnabled: Bool,
        reminder: Reminder,
        time: Date
    ) {
        if isEnabled {
            schedule(reminder, at: time)
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [reminder.identifier])
            lastReminderError = nil
            refreshPendingReminderCount()
        }
    }

    private func schedule(_ reminder: Reminder, at time: Date) {
        Task {
            do {
                try await ensureAuthorization()
                let content = UNMutableNotificationContent()
                content.title = reminder.title
                content.body = reminder.body
                content.sound = .default
                content.userInfo = [
                    Reminder.routeUserInfoKey: reminder.route.rawValue
                ]

                let trigger = UNCalendarNotificationTrigger(dateMatching: timeComponents(from: time), repeats: true)
                let request = UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger)
                center.removePendingNotificationRequests(withIdentifiers: [reminder.identifier])
                try await center.add(request)
                lastReminderError = nil
                refreshPendingReminderCount()
            } catch {
                lastReminderError = error.localizedDescription
                disable(reminder)
                refreshPendingReminderCount()
            }

            refreshAuthorizationStatus()
        }
    }

    private func ensureAuthorization() async throws {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return
        case .notDetermined:
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            authorizationStatus = granted ? .authorized : .denied
            if !granted {
                throw ReminderError.authorizationDenied
            }
        case .denied:
            throw ReminderError.authorizationDenied
        @unknown default:
            throw ReminderError.authorizationDenied
        }
    }

    private func disable(_ reminder: Reminder) {
        switch reminder.identifier {
        case Reminder.weight.identifier:
            isWeightReminderEnabled = false
            defaults.set(false, forKey: Keys.weightEnabled)
        case Reminder.sleep.identifier:
            isSleepReminderEnabled = false
            defaults.set(false, forKey: Keys.sleepEnabled)
        case Reminder.meal.identifier:
            isMealReminderEnabled = false
            defaults.set(false, forKey: Keys.mealEnabled)
        default:
            break
        }
    }

    private func refreshPendingReminderCount() {
        Task {
            let requests = await center.pendingNotificationRequests()
            pendingNotificationCount = requests.filter { request in
                Reminder.allIdentifiers.contains(request.identifier)
            }.count
        }
    }

    private func handleNotificationOpen(identifier: String, openedAt: Date) {
        guard let route = BodyCoachReminderRoute(identifier: identifier) else {
            return
        }

        lastOpenedReminder = route
        lastOpenedReminderAt = openedAt
        pendingRouteRequest = BodyCoachReminderRouteRequest(route: route, openedAt: openedAt)
        lastReminderError = nil
    }

    func consumePendingRouteRequest(id: UUID) {
        guard pendingRouteRequest?.id == id else {
            return
        }

        pendingRouteRequest = nil
    }

    private func save(_ time: Date, key: String) {
        let components = timeComponents(from: time)
        defaults.set(components.hour ?? 0, forKey: "\(key).hour")
        defaults.set(components.minute ?? 0, forKey: "\(key).minute")
    }

    private func timeComponents(from time: Date) -> DateComponents {
        calendar.dateComponents([.hour, .minute], from: time)
    }

    private static func time(for key: String, defaults: UserDefaults, defaultHour: Int, defaultMinute: Int) -> Date {
        let hourKey = "\(key).hour"
        let minuteKey = "\(key).minute"
        let hour = defaults.object(forKey: hourKey) as? Int ?? defaultHour
        let minute = defaults.object(forKey: minuteKey) as? Int ?? defaultMinute
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}

struct BodyCoachReminderRouteRequest: Equatable, Sendable {
    let id = UUID()
    let route: BodyCoachReminderRoute
    let openedAt: Date
}

enum BodyCoachReminderRoute: String, Equatable, Sendable {
    case weight
    case sleep
    case meal

    init?(identifier: String) {
        switch identifier {
        case Reminder.weight.identifier:
            self = .weight
        case Reminder.sleep.identifier:
            self = .sleep
        case Reminder.meal.identifier:
            self = .meal
        default:
            return nil
        }
    }

    var displayName: String {
        switch self {
        case .weight:
            return "体重记录"
        case .sleep:
            return "睡眠准备"
        case .meal:
            return "饮食简记"
        }
    }
}

private final class BodyCoachNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    var didOpenReminder: @Sendable (_ identifier: String, _ openedAt: Date) -> Void = { _, _ in }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        didOpenReminder(response.notification.request.identifier, Date())
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

private enum ReminderError: LocalizedError {
    case authorizationDenied

    var errorDescription: String? {
        "通知权限未开启，请在系统设置中允许 VitalLoop 发送通知。"
    }
}

private struct Reminder {
    let identifier: String
    let title: String
    let body: String
    let route: BodyCoachReminderRoute

    static let routeUserInfoKey = "vitalloop.reminder.route"

    static let weight = Reminder(
        identifier: "vitalloop.reminder.weight",
        title: "记录今日体重",
        body: "用同一时间称重，趋势会比单日数字更有参考价值。",
        route: .weight
    )

    static let sleep = Reminder(
        identifier: "vitalloop.reminder.sleep",
        title: "准备睡眠恢复",
        body: "今晚优先保证睡眠，明天的恢复分会更可靠。",
        route: .sleep
    )

    static let meal = Reminder(
        identifier: "vitalloop.reminder.meal",
        title: "补一条饮食简记",
        body: "标记今天是否偏多、偏少或高油高糖，周复盘会更清楚。",
        route: .meal
    )

    static let allIdentifiers = [
        Reminder.weight.identifier,
        Reminder.sleep.identifier,
        Reminder.meal.identifier
    ]
}

private enum Keys {
    static let weightEnabled = "reminder.weight.enabled"
    static let sleepEnabled = "reminder.sleep.enabled"
    static let mealEnabled = "reminder.meal.enabled"
    static let weightTime = "reminder.weight.time"
    static let sleepTime = "reminder.sleep.time"
    static let mealTime = "reminder.meal.time"
}
