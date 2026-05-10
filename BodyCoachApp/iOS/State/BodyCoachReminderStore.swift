import Foundation
import Observation
import UserNotifications

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

    private let defaults: UserDefaults
    private let center: UNUserNotificationCenter
    private let calendar = Calendar.current

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
            identifier: Reminder.weight.identifier,
            title: Reminder.weight.title,
            body: Reminder.weight.body,
            time: weightReminderTime
        )
    }

    func setSleepReminderEnabled(_ isEnabled: Bool) {
        isSleepReminderEnabled = isEnabled
        defaults.set(isEnabled, forKey: Keys.sleepEnabled)
        applyReminder(
            isEnabled: isEnabled,
            identifier: Reminder.sleep.identifier,
            title: Reminder.sleep.title,
            body: Reminder.sleep.body,
            time: sleepReminderTime
        )
    }

    func setMealReminderEnabled(_ isEnabled: Bool) {
        isMealReminderEnabled = isEnabled
        defaults.set(isEnabled, forKey: Keys.mealEnabled)
        applyReminder(
            isEnabled: isEnabled,
            identifier: Reminder.meal.identifier,
            title: Reminder.meal.title,
            body: Reminder.meal.body,
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
        identifier: String,
        title: String,
        body: String,
        time: Date
    ) {
        if isEnabled {
            schedule(Reminder(identifier: identifier, title: title, body: body), at: time)
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
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

                let trigger = UNCalendarNotificationTrigger(dateMatching: timeComponents(from: time), repeats: true)
                let request = UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger)
                center.removePendingNotificationRequests(withIdentifiers: [reminder.identifier])
                try await center.add(request)
                lastReminderError = nil
            } catch {
                lastReminderError = error.localizedDescription
                disable(reminder)
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

    static let weight = Reminder(
        identifier: "vitalloop.reminder.weight",
        title: "记录今日体重",
        body: "用同一时间称重，趋势会比单日数字更有参考价值。"
    )

    static let sleep = Reminder(
        identifier: "vitalloop.reminder.sleep",
        title: "准备睡眠恢复",
        body: "今晚优先保证睡眠，明天的恢复分会更可靠。"
    )

    static let meal = Reminder(
        identifier: "vitalloop.reminder.meal",
        title: "补一条饮食简记",
        body: "标记今天是否偏多、偏少或高油高糖，周复盘会更清楚。"
    )
}

private enum Keys {
    static let weightEnabled = "reminder.weight.enabled"
    static let sleepEnabled = "reminder.sleep.enabled"
    static let mealEnabled = "reminder.meal.enabled"
    static let weightTime = "reminder.weight.time"
    static let sleepTime = "reminder.sleep.time"
    static let mealTime = "reminder.meal.time"
}

