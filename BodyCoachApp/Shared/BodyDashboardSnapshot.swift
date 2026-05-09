import BodyCoachCore
import Foundation

struct BodyDashboardSnapshot: Equatable, Sendable {
    var date: Date
    var sleepMinutes: Double?
    var activeEnergyKcal: Double?
    var activeEnergyGoalKcal: Double?
    var stepCount: Double?
    var restingHeartRateBpm: Double?
    var hrvMs: Double?
    var hrvBaselineMs: Double?
    var weightKg: Double?
    var weightSevenDayDeltaKg: Double?
    var workoutMinutes: Double?
    var sleepBaselineMinutes: Double?
    var restingHeartRateBaselineBpm: Double?

    init(
        date: Date,
        sleepMinutes: Double? = nil,
        activeEnergyKcal: Double? = nil,
        activeEnergyGoalKcal: Double? = nil,
        stepCount: Double? = nil,
        restingHeartRateBpm: Double? = nil,
        hrvMs: Double? = nil,
        hrvBaselineMs: Double? = nil,
        weightKg: Double? = nil,
        weightSevenDayDeltaKg: Double? = nil,
        workoutMinutes: Double? = nil,
        sleepBaselineMinutes: Double? = nil,
        restingHeartRateBaselineBpm: Double? = nil
    ) {
        self.date = date
        self.sleepMinutes = sleepMinutes
        self.activeEnergyKcal = activeEnergyKcal
        self.activeEnergyGoalKcal = activeEnergyGoalKcal
        self.stepCount = stepCount
        self.restingHeartRateBpm = restingHeartRateBpm
        self.hrvMs = hrvMs
        self.hrvBaselineMs = hrvBaselineMs
        self.weightKg = weightKg
        self.weightSevenDayDeltaKg = weightSevenDayDeltaKg
        self.workoutMinutes = workoutMinutes
        self.sleepBaselineMinutes = sleepBaselineMinutes
        self.restingHeartRateBaselineBpm = restingHeartRateBaselineBpm
    }

    var availableFieldCount: Int {
        [
            sleepMinutes,
            activeEnergyKcal,
            stepCount,
            restingHeartRateBpm,
            hrvMs,
            weightKg,
            workoutMinutes
        ].compactMap { $0 }.count
    }

    var expectedFieldCount: Int {
        7
    }

    var hasAnyHealthSignal: Bool {
        availableFieldCount > 0
    }

    func bodyMetrics(subjectiveCheckIn: WatchSubjectiveCheckInPayload? = nil) -> BodyMetrics {
        BodyMetrics(
            sleepMinutes: sleepMinutes,
            sleepBaselineMinutes: sleepBaselineMinutes,
            activeEnergyKcal: activeEnergyKcal,
            activeEnergyGoalKcal: activeEnergyGoalKcal ?? 800,
            stepCount: stepCount,
            restingHeartRateBpm: restingHeartRateBpm,
            restingHeartRateBaselineBpm: restingHeartRateBaselineBpm,
            hrvMs: hrvMs,
            hrvBaselineMs: hrvBaselineMs,
            weightKg: weightKg,
            weightSevenDayDeltaKg: weightSevenDayDeltaKg,
            subjectiveStress: subjectiveCheckIn.map { Double($0.stress) },
            subjectiveFatigue: subjectiveCheckIn.map { Double($0.fatigue) },
            hungerLevel: subjectiveCheckIn.map { Double($0.hunger) },
            workoutMinutes: workoutMinutes
        )
    }

    static func sample(date: Date = Date()) -> BodyDashboardSnapshot {
        BodyDashboardSnapshot(
            date: date,
            sleepMinutes: SampleBodyData.metrics.sleepMinutes,
            activeEnergyKcal: SampleBodyData.metrics.activeEnergyKcal,
            activeEnergyGoalKcal: SampleBodyData.metrics.activeEnergyGoalKcal,
            stepCount: SampleBodyData.metrics.stepCount,
            restingHeartRateBpm: SampleBodyData.metrics.restingHeartRateBpm,
            hrvMs: SampleBodyData.metrics.hrvMs,
            hrvBaselineMs: SampleBodyData.metrics.hrvBaselineMs,
            weightKg: SampleBodyData.metrics.weightKg,
            weightSevenDayDeltaKg: SampleBodyData.metrics.weightSevenDayDeltaKg,
            workoutMinutes: SampleBodyData.metrics.workoutMinutes,
            sleepBaselineMinutes: SampleBodyData.metrics.sleepBaselineMinutes,
            restingHeartRateBaselineBpm: SampleBodyData.metrics.restingHeartRateBaselineBpm
        )
    }
}

struct MetricDisplay: Equatable, Sendable {
    var value: String
    var unit: String
    var status: String
    var note: String
    var noteTone: MetricDisplayTone

    init(
        value: String,
        unit: String,
        status: String,
        note: String,
        noteTone: MetricDisplayTone = .normal
    ) {
        self.value = value
        self.unit = unit
        self.status = status
        self.note = note
        self.noteTone = noteTone
    }
}

enum MetricDisplayTone: Equatable, Sendable {
    case normal
    case warning
}

extension BodyDashboardSnapshot {
    var activeEnergyDisplay: MetricDisplay {
        guard let activeEnergyKcal else {
            return MetricDisplay(
                value: "--",
                unit: "kcal",
                status: "缺数据",
                note: "缺少活动能量，活动判断只能参考步数或锻炼记录。",
                noteTone: .warning
            )
        }

        let goal = activeEnergyGoalKcal ?? 800
        let percent = Int((activeEnergyKcal / max(goal, 1) * 100).rounded())
        let note: String
        let tone: MetricDisplayTone
        if stepCount == nil && workoutMinutes == nil {
            note = "缺少步数和锻炼记录，活动完成度可信度偏弱。"
            tone = .warning
        } else if stepCount == nil {
            note = "缺少步数，活动判断主要依赖能量消耗。"
            tone = .warning
        } else if workoutMinutes == nil {
            note = "缺少锻炼记录，但活动能量和步数可用。"
            tone = .normal
        } else {
            note = "活动能量、步数和锻炼记录已接入。"
            tone = .normal
        }

        return MetricDisplay(value: activeEnergyKcal.roundedString, unit: "kcal", status: "\(percent)%", note: note, noteTone: tone)
    }

    var sleepDisplay: MetricDisplay {
        guard let sleepMinutes else {
            return MetricDisplay(
                value: "--",
                unit: "睡眠",
                status: "缺数据",
                note: "缺少睡眠样本，建议佩戴 Apple Watch 入睡。",
                noteTone: .warning
            )
        }

        let hours = Int(sleepMinutes / 60)
        let minutes = Int(sleepMinutes.truncatingRemainder(dividingBy: 60))
        let status = sleepMinutes >= 420 ? "达标" : "一般"
        let note: String
        let tone: MetricDisplayTone
        if let sleepBaselineMinutes {
            let delta = sleepMinutes - sleepBaselineMinutes
            note = "较个人基线 \(delta.signedMinutesString)。"
            tone = abs(delta) > 45 ? .warning : .normal
        } else {
            note = "缺少 28 天睡眠基线，暂按通用目标判断。"
            tone = .warning
        }

        return MetricDisplay(value: "\(hours)h\(String(format: "%02d", minutes))", unit: "总时长", status: status, note: note, noteTone: tone)
    }

    var recoveryDisplay: MetricDisplay {
        guard let hrvMs else {
            let note = restingHeartRateBpm == nil ? "缺少 HRV 和静息心率，恢复判断可信度较低。" : "缺少 HRV，恢复判断只参考静息心率。"
            return MetricDisplay(value: "--", unit: "HRV", status: "缺数据", note: note, noteTone: .warning)
        }

        if let hrvBaselineMs {
            let delta = hrvMs - hrvBaselineMs
            let note = restingHeartRateBpm == nil ? "缺少静息心率，恢复判断只用 HRV。" : "基于 HRV、静息心率和个人基线。"
            let tone: MetricDisplayTone = restingHeartRateBpm == nil || delta < 0 ? .warning : .normal
            return MetricDisplay(value: hrvMs.roundedString, unit: "ms", status: delta >= 0 ? "高于基线" : "低于基线", note: note, noteTone: tone)
        }

        return MetricDisplay(
            value: hrvMs.roundedString,
            unit: "ms",
            status: "待基线",
            note: "缺少 28 天 HRV 基线，暂不做强判断。",
            noteTone: .warning
        )
    }

    var weightTrendDisplay: MetricDisplay {
        if let weightSevenDayDeltaKg {
            return MetricDisplay(
                value: weightSevenDayDeltaKg.signedOneDecimalString,
                unit: "kg",
                status: "7 日",
                note: "已过滤不合理体重跳变，趋势只看长期变化。"
            )
        }

        guard let weightKg else {
            return MetricDisplay(
                value: "--",
                unit: "kg",
                status: "缺数据",
                note: "缺少体重记录，无法判断减脂进度。",
                noteTone: .warning
            )
        }

        return MetricDisplay(
            value: weightKg.oneDecimalString,
            unit: "kg",
            status: "最近",
            note: "缺少 7 日对比记录，暂不判断趋势。",
            noteTone: .warning
        )
    }
}

extension Double {
    var roundedString: String {
        String(Int(rounded()))
    }

    var oneDecimalString: String {
        String(format: "%.1f", self)
    }

    var signedOneDecimalString: String {
        let formatted = String(format: "%.1f", self)
        return self > 0 ? "+\(formatted)" : formatted
    }

    var signedMinutesString: String {
        let minutes = Int(rounded())
        if minutes == 0 {
            return "持平"
        }

        let prefix = minutes > 0 ? "+" : "-"
        return "\(prefix)\(abs(minutes))分钟"
    }
}
