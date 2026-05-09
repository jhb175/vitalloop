import Foundation

public struct BodyMetrics: Equatable, Sendable {
    public var sleepMinutes: Double?
    public var sleepBaselineMinutes: Double?
    public var activeEnergyKcal: Double?
    public var activeEnergyGoalKcal: Double?
    public var stepCount: Double?
    public var restingHeartRateBpm: Double?
    public var restingHeartRateBaselineBpm: Double?
    public var hrvMs: Double?
    public var hrvBaselineMs: Double?
    public var weightKg: Double?
    public var weightSevenDayDeltaKg: Double?
    public var subjectiveStress: Double?
    public var subjectiveFatigue: Double?
    public var hungerLevel: Double?
    public var workoutMinutes: Double?

    public init(
        sleepMinutes: Double? = nil,
        sleepBaselineMinutes: Double? = nil,
        activeEnergyKcal: Double? = nil,
        activeEnergyGoalKcal: Double? = nil,
        stepCount: Double? = nil,
        restingHeartRateBpm: Double? = nil,
        restingHeartRateBaselineBpm: Double? = nil,
        hrvMs: Double? = nil,
        hrvBaselineMs: Double? = nil,
        weightKg: Double? = nil,
        weightSevenDayDeltaKg: Double? = nil,
        subjectiveStress: Double? = nil,
        subjectiveFatigue: Double? = nil,
        hungerLevel: Double? = nil,
        workoutMinutes: Double? = nil
    ) {
        self.sleepMinutes = sleepMinutes
        self.sleepBaselineMinutes = sleepBaselineMinutes
        self.activeEnergyKcal = activeEnergyKcal
        self.activeEnergyGoalKcal = activeEnergyGoalKcal
        self.stepCount = stepCount
        self.restingHeartRateBpm = restingHeartRateBpm
        self.restingHeartRateBaselineBpm = restingHeartRateBaselineBpm
        self.hrvMs = hrvMs
        self.hrvBaselineMs = hrvBaselineMs
        self.weightKg = weightKg
        self.weightSevenDayDeltaKg = weightSevenDayDeltaKg
        self.subjectiveStress = subjectiveStress
        self.subjectiveFatigue = subjectiveFatigue
        self.hungerLevel = hungerLevel
        self.workoutMinutes = workoutMinutes
    }
}

public enum BodyGoalKind: String, Equatable, Sendable {
    case fatLoss
    case muscleGain
    case stressReduction
    case fitness
    case skill
}

public struct BodyGoalContext: Equatable, Sendable {
    public var kind: BodyGoalKind
    public var currentWeightKg: Double?
    public var targetWeightKg: Double?
    public var targetDate: Date?
    public var weeklyWeightLossTargetKg: Double?
    public var preferredWorkoutMinutes: Double?

    public init(
        kind: BodyGoalKind,
        currentWeightKg: Double? = nil,
        targetWeightKg: Double? = nil,
        targetDate: Date? = nil,
        weeklyWeightLossTargetKg: Double? = nil,
        preferredWorkoutMinutes: Double? = nil
    ) {
        self.kind = kind
        self.currentWeightKg = currentWeightKg
        self.targetWeightKg = targetWeightKg
        self.targetDate = targetDate
        self.weeklyWeightLossTargetKg = weeklyWeightLossTargetKg
        self.preferredWorkoutMinutes = preferredWorkoutMinutes
    }
}

public struct BodyWeightSample: Equatable, Sendable {
    public var date: Date
    public var kg: Double

    public init(date: Date, kg: Double) {
        self.date = date
        self.kg = kg
    }
}

public struct WeightTrendFilter: Sendable {
    private let plausibleRange: ClosedRange<Double> = 30 ... 250
    private let medianToleranceKg = 8.0
    private let medianToleranceRatio = 0.1
    private let maxAcceptedJumpKg = 4.0
    private let minimumDeltaSpacing: TimeInterval = 3 * 24 * 60 * 60

    public init() {}

    public func filteredSamples(_ samples: [BodyWeightSample]) -> [BodyWeightSample] {
        let plausible = samples
            .filter { sample in
                sample.kg.isFinite && plausibleRange.contains(sample.kg)
            }
            .sorted { $0.date < $1.date }

        guard plausible.count >= 3 else {
            return filterSparseSamples(plausible)
        }

        let center = median(plausible.map(\.kg))
        let tolerance = max(medianToleranceKg, center * medianToleranceRatio)
        let medianFiltered = plausible.filter { sample in
            abs(sample.kg - center) <= tolerance
        }

        return medianFiltered.reduce(into: [BodyWeightSample]()) { result, sample in
            guard let previous = result.last else {
                result.append(sample)
                return
            }

            if abs(sample.kg - previous.kg) <= maxAcceptedJumpKg {
                result.append(sample)
            }
        }
    }

    public func sevenDayDelta(from samples: [BodyWeightSample]) -> Double? {
        let filtered = filteredSamples(samples)
        guard let latest = filtered.last, filtered.count >= 2 else {
            return nil
        }

        let comparisonDate = latest.date.addingTimeInterval(-7 * 24 * 60 * 60)
        let earlierBaseline = filtered.last { $0.date <= comparisonDate }
        let laterBaseline = filtered.first { $0.date >= comparisonDate }
        guard let baseline = earlierBaseline ?? laterBaseline ?? filtered.first else {
            return nil
        }

        guard latest.date.timeIntervalSince(baseline.date) >= minimumDeltaSpacing else {
            return nil
        }

        let delta = latest.kg - baseline.kg
        guard abs(delta) <= maxAcceptedJumpKg else {
            return nil
        }

        return delta
    }

    private func filterSparseSamples(_ samples: [BodyWeightSample]) -> [BodyWeightSample] {
        guard samples.count == 2,
              let first = samples.first,
              let last = samples.last,
              abs(last.kg - first.kg) > maxAcceptedJumpKg
        else {
            return samples
        }

        return [last]
    }

    private func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }

        return sorted[middle]
    }
}

public enum BodyStatus: String, Equatable, Sendable {
    case strong
    case normal
    case caution
    case recovery
}

public enum RecommendationType: String, Equatable, Sendable {
    case movement
    case nutrition
    case sleep
    case recovery
    case logging
}

public struct ScoreBreakdown: Equatable, Sendable {
    public var overall: Int
    public var sleep: Int
    public var recovery: Int
    public var activity: Int
    public var weightTrend: Int
    public var dataCompleteness: Int
    public var status: BodyStatus
    public var explanation: [String]

    public init(
        overall: Int,
        sleep: Int,
        recovery: Int,
        activity: Int,
        weightTrend: Int,
        dataCompleteness: Int,
        status: BodyStatus,
        explanation: [String]
    ) {
        self.overall = overall
        self.sleep = sleep
        self.recovery = recovery
        self.activity = activity
        self.weightTrend = weightTrend
        self.dataCompleteness = dataCompleteness
        self.status = status
        self.explanation = explanation
    }
}

public struct DailyRecommendation: Equatable, Sendable {
    public var type: RecommendationType
    public var title: String
    public var rationale: String
    public var priority: Int

    public init(type: RecommendationType, title: String, rationale: String, priority: Int) {
        self.type = type
        self.title = title
        self.rationale = rationale
        self.priority = priority
    }
}

public struct DailyBodySummary: Equatable, Sendable {
    public var score: ScoreBreakdown
    public var recommendations: [DailyRecommendation]

    public init(score: ScoreBreakdown, recommendations: [DailyRecommendation]) {
        self.score = score
        self.recommendations = recommendations
    }
}

public struct BodyCoachScorer: Sendable {
    public init() {}

    public func summarize(_ metrics: BodyMetrics, goal: BodyGoalContext? = nil) -> DailyBodySummary {
        let sleepScore = scoreSleep(metrics)
        let recoveryScore = scoreRecovery(metrics)
        let activityScore = scoreActivity(metrics)
        let weightScore = scoreWeightTrend(metrics)
        let completenessScore = scoreDataCompleteness(metrics)

        let weighted = (Double(sleepScore) * 0.24)
            + (Double(recoveryScore) * 0.28)
            + (Double(activityScore) * 0.22)
            + (Double(weightScore) * 0.14)
            + (Double(completenessScore) * 0.12)

        let overall = clampInt(weighted.rounded())
        let status = statusFor(overall: overall, recovery: recoveryScore, sleep: sleepScore)
        let explanation = explanations(
            metrics: metrics,
            sleepScore: sleepScore,
            recoveryScore: recoveryScore,
            activityScore: activityScore,
            weightScore: weightScore,
            completenessScore: completenessScore,
            goal: goal
        )

        let score = ScoreBreakdown(
            overall: overall,
            sleep: sleepScore,
            recovery: recoveryScore,
            activity: activityScore,
            weightTrend: weightScore,
            dataCompleteness: completenessScore,
            status: status,
            explanation: explanation
        )

        return DailyBodySummary(
            score: score,
            recommendations: recommendations(for: metrics, score: score, goal: goal)
        )
    }

    private func scoreSleep(_ metrics: BodyMetrics) -> Int {
        guard let minutes = metrics.sleepMinutes else { return 50 }
        let baseline = metrics.sleepBaselineMinutes ?? 450
        let ratio = minutes / max(baseline, 360)
        let durationScore = 100 * min(max(ratio, 0), 1.08)
        let penalty = minutes < 360 ? 18 : 0
        return clampInt(durationScore - Double(penalty))
    }

    private func scoreRecovery(_ metrics: BodyMetrics) -> Int {
        var score = 76.0

        if let hrv = metrics.hrvMs, let baseline = metrics.hrvBaselineMs, baseline > 0 {
            let delta = (hrv - baseline) / baseline
            score += delta * 90
        }

        if let resting = metrics.restingHeartRateBpm,
           let baseline = metrics.restingHeartRateBaselineBpm,
           baseline > 0 {
            let delta = (resting - baseline) / baseline
            score -= delta * 120
        }

        if let stress = metrics.subjectiveStress {
            score -= normalizedTenPoint(stress) * 14
        }

        if let fatigue = metrics.subjectiveFatigue {
            score -= normalizedTenPoint(fatigue) * 14
        }

        return clampInt(score)
    }

    private func scoreActivity(_ metrics: BodyMetrics) -> Int {
        guard metrics.activeEnergyKcal != nil || metrics.stepCount != nil || metrics.workoutMinutes != nil else {
            return 50
        }

        var components: [Double] = []

        if let activeEnergy = metrics.activeEnergyKcal {
            let goal = max(metrics.activeEnergyGoalKcal ?? 600, 250)
            components.append(min(activeEnergy / goal, 1.18) * 100)
        }

        if let steps = metrics.stepCount {
            components.append(min(steps / 8_000, 1.12) * 100)
        }

        if let workout = metrics.workoutMinutes {
            components.append(min(workout / 35, 1.12) * 100)
        }

        return clampInt(components.reduce(0, +) / Double(components.count))
    }

    private func scoreWeightTrend(_ metrics: BodyMetrics) -> Int {
        guard let delta = metrics.weightSevenDayDeltaKg else { return 62 }

        switch delta {
        case -0.8 ... -0.15:
            return 86
        case -1.3 ..< -0.8:
            return 72
        case -0.15 ... 0.25:
            return 70
        case ..<(-1.3):
            return 52
        default:
            return 56
        }
    }

    private func scoreDataCompleteness(_ metrics: BodyMetrics) -> Int {
        let fields: [Any?] = [
            metrics.sleepMinutes,
            metrics.activeEnergyKcal,
            metrics.stepCount,
            metrics.restingHeartRateBpm,
            metrics.hrvMs,
            metrics.weightKg,
            metrics.subjectiveStress,
            metrics.subjectiveFatigue,
            metrics.hungerLevel,
        ]
        let present = fields.filter { $0 != nil }.count
        return clampInt((Double(present) / Double(fields.count)) * 100)
    }

    private func statusFor(overall: Int, recovery: Int, sleep: Int) -> BodyStatus {
        if recovery < 45 || sleep < 45 { return .recovery }
        if overall >= 82 && recovery >= 68 { return .strong }
        if overall >= 67 { return .normal }
        return .caution
    }

    private func explanations(
        metrics: BodyMetrics,
        sleepScore: Int,
        recoveryScore: Int,
        activityScore: Int,
        weightScore: Int,
        completenessScore: Int,
        goal: BodyGoalContext?
    ) -> [String] {
        var result: [String] = []

        if sleepScore < 65 {
            result.append("睡眠低于个人基线，今日恢复分被拉低。")
        } else {
            result.append("睡眠接近基线，可支持低到中等强度活动。")
        }

        if recoveryScore < 62 {
            result.append("HRV、静息心率或主观疲劳提示恢复偏弱。")
        } else {
            result.append("恢复信号稳定，没有明显过载迹象。")
        }

        if activityScore < 70 {
            result.append("活动量还未达到今日目标，可以用低强度步行补足。")
        } else {
            result.append("活动量完成度较好，今日不需要额外加压。")
        }

        if weightScore >= 80 {
            result.append("7 天体重趋势处于较合理的减脂区间。")
        } else if metrics.weightSevenDayDeltaKg == nil {
            result.append("缺少连续体重记录，体重趋势判断可信度有限。")
        }

        if completenessScore < 70 {
            result.append("数据完整度不足，建议补充体重或主观状态记录。")
        }

        if let analysis = fatLossAnalysis(metrics: metrics, goal: goal) {
            if analysis.remainingLossKg > 0 {
                result.append("距离目标体重还有 \(analysis.remainingLossKg.oneDecimalString)kg，后续应按周趋势调整计划。")
            }

            if analysis.isAggressive {
                result.append("当前减脂节奏目标偏快，需要优先保证睡眠、恢复和执行稳定性。")
            }
        }

        return result
    }

    private func recommendations(
        for metrics: BodyMetrics,
        score: ScoreBreakdown,
        goal: BodyGoalContext?
    ) -> [DailyRecommendation] {
        var items: [DailyRecommendation] = []
        let workoutMinutes = preferredWorkoutMinutes(from: goal)

        if score.recovery < 62 || score.sleep < 65 {
            items.append(DailyRecommendation(
                type: .recovery,
                title: "今天保持轻训练，避免冲强度",
                rationale: "恢复或睡眠分偏低，继续加压会降低计划稳定性。",
                priority: 1
            ))
            items.append(DailyRecommendation(
                type: .sleep,
                title: "今晚提前 30 分钟上床",
                rationale: "优先修复连续低恢复信号，比额外运动更重要。",
                priority: 2
            ))
        } else {
            items.append(DailyRecommendation(
                type: .movement,
                title: "安排一次 \(workoutMinutes) 分钟中低强度训练",
                rationale: "恢复状态允许训练，控制强度能兼顾减脂和可持续性。",
                priority: 1
            ))
        }

        if score.activity < 70 {
            items.append(DailyRecommendation(
                type: .movement,
                title: "饭后快走 25 到 35 分钟",
                rationale: "用低恢复成本补足活动消耗。",
                priority: 3
            ))
        }

        if let hunger = metrics.hungerLevel, hunger >= 7 {
            items.append(DailyRecommendation(
                type: .nutrition,
                title: "晚餐不要继续削减热量",
                rationale: "饥饿感偏高时继续节食，容易影响睡眠和第二天执行。",
                priority: 4
            ))
        } else {
            items.append(DailyRecommendation(
                type: .nutrition,
                title: "优先保证蛋白质和蔬菜",
                rationale: "体重趋势由长期缺口决定，先保证饮食结构稳定。",
                priority: 4
            ))
        }

        if score.dataCompleteness < 70 {
            items.append(DailyRecommendation(
                type: .logging,
                title: "补记体重和主观疲劳",
                rationale: "缺少关键输入时，今日评分只能作为弱参考。",
                priority: 5
            ))
        }

        if let goalRecommendation = fatLossGoalRecommendation(metrics: metrics, score: score, goal: goal) {
            items.append(goalRecommendation)
        }

        return items.sorted { $0.priority < $1.priority }
    }

    private struct FatLossAnalysis {
        var remainingLossKg: Double
        var requiredWeeklyLossKg: Double?
        var selectedWeeklyTargetKg: Double?
        var actualSevenDayDeltaKg: Double?

        var isAggressive: Bool {
            if let selectedWeeklyTargetKg, selectedWeeklyTargetKg > 0.8 {
                return true
            }

            if let requiredWeeklyLossKg, requiredWeeklyLossKg > 0.8 {
                return true
            }

            return false
        }
    }

    private func fatLossAnalysis(metrics: BodyMetrics, goal: BodyGoalContext?) -> FatLossAnalysis? {
        guard let goal, goal.kind == .fatLoss else {
            return nil
        }

        let currentWeight = goal.currentWeightKg ?? metrics.weightKg
        guard let currentWeight,
              let targetWeight = goal.targetWeightKg,
              currentWeight > targetWeight
        else {
            return nil
        }

        let remainingLossKg = currentWeight - targetWeight
        let requiredWeeklyLossKg: Double?
        if let targetDate = goal.targetDate {
            let weeks = targetDate.timeIntervalSince(Date()) / (7 * 24 * 60 * 60)
            if weeks > 0.5 {
                requiredWeeklyLossKg = remainingLossKg / weeks
            } else {
                requiredWeeklyLossKg = nil
            }
        } else {
            requiredWeeklyLossKg = nil
        }

        return FatLossAnalysis(
            remainingLossKg: remainingLossKg,
            requiredWeeklyLossKg: requiredWeeklyLossKg,
            selectedWeeklyTargetKg: goal.weeklyWeightLossTargetKg,
            actualSevenDayDeltaKg: metrics.weightSevenDayDeltaKg
        )
    }

    private func fatLossGoalRecommendation(
        metrics: BodyMetrics,
        score: ScoreBreakdown,
        goal: BodyGoalContext?
    ) -> DailyRecommendation? {
        guard let analysis = fatLossAnalysis(metrics: metrics, goal: goal) else {
            if goal?.kind == .fatLoss {
                return DailyRecommendation(
                    type: .logging,
                    title: "确认当前体重和目标体重",
                    rationale: "减脂计划需要当前体重、目标体重和周期，缺失时不应自动加大训练量。",
                    priority: 5
                )
            }

            return nil
        }

        if analysis.isAggressive {
            return DailyRecommendation(
                type: .nutrition,
                title: "放缓减脂目标节奏",
                rationale: "目标速度偏快时，先把周下降控制在可持续范围，避免牺牲睡眠和恢复。",
                priority: 2
            )
        }

        if let actualSevenDayDeltaKg = analysis.actualSevenDayDeltaKg, actualSevenDayDeltaKg < -1.0 {
            return DailyRecommendation(
                type: .nutrition,
                title: "不要继续扩大热量缺口",
                rationale: "7 天体重下降已经偏快，今天优先保证蛋白质、晚餐和睡眠质量。",
                priority: 3
            )
        }

        if score.activity < 70 {
            return DailyRecommendation(
                type: .movement,
                title: "用低强度活动补足减脂缺口",
                rationale: "当前恢复不适合盲目加压，用步行和日常活动比冲强度更稳定。",
                priority: 3
            )
        }

        return DailyRecommendation(
            type: .nutrition,
            title: "维持当前减脂节奏",
            rationale: "体重目标和今日身体信号没有冲突，继续保持饮食结构和训练稳定性。",
            priority: 4
        )
    }

    private func preferredWorkoutMinutes(from goal: BodyGoalContext?) -> Int {
        guard let preferred = goal?.preferredWorkoutMinutes, preferred.isFinite else {
            return 35
        }

        return Int(min(max(preferred.rounded(), 15), 75))
    }

    private func normalizedTenPoint(_ value: Double) -> Double {
        min(max(value, 0), 10) / 10
    }

    private func clampInt(_ value: Double) -> Int {
        Int(min(max(value, 0), 100))
    }
}

private extension Double {
    var oneDecimalString: String {
        String(format: "%.1f", self)
    }
}
