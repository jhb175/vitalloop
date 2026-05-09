import BodyCoachCore
import Foundation

struct WatchMetricPayload: Codable, Equatable, Sendable {
    var title: String
    var value: String
    var unit: String
    var kind: WatchMetricKind
    var bars: [Double]
}

enum WatchMetricKind: String, Codable, Equatable, Sendable {
    case heartRate
    case activeEnergy
    case sleep
    case hrv
    case steps
    case weight
}

struct WatchRecommendationPayload: Codable, Equatable, Sendable {
    var type: RecommendationType
    var title: String
    var rationale: String
    var priority: Int

    init(type: RecommendationType, title: String, rationale: String, priority: Int) {
        self.type = type
        self.title = title
        self.rationale = rationale
        self.priority = priority
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawType = try container.decode(String.self, forKey: .type)
        self.type = RecommendationType(rawValue: rawType) ?? .logging
        self.title = try container.decode(String.self, forKey: .title)
        self.rationale = try container.decode(String.self, forKey: .rationale)
        self.priority = try container.decode(Int.self, forKey: .priority)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encode(rationale, forKey: .rationale)
        try container.encode(priority, forKey: .priority)
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case title
        case rationale
        case priority
    }
}

struct WatchSubjectiveCheckInPayload: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var capturedAt: Date
    var stress: Int
    var fatigue: Int
    var hunger: Int
    var source: String

    init(
        id: UUID = UUID(),
        capturedAt: Date = Date(),
        stress: Int,
        fatigue: Int,
        hunger: Int,
        source: String = "Apple Watch"
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.stress = Self.clamped(stress)
        self.fatigue = Self.clamped(fatigue)
        self.hunger = Self.clamped(hunger)
        self.source = source
    }

    var averageLoad: Double {
        Double(stress + fatigue + hunger) / 3
    }

    var statusLabel: String {
        switch averageLoad {
        case 0 ..< 4:
            return "负荷较低"
        case 4 ..< 7:
            return "负荷正常"
        default:
            return "需要关注"
        }
    }

    var compactSummary: String {
        "压力 \(stress) · 疲劳 \(fatigue) · 饥饿 \(hunger)"
    }

    private static func clamped(_ value: Int) -> Int {
        min(max(value, 1), 10)
    }
}

struct WatchSummaryPayload: Codable, Equatable, Sendable {
    var updatedAt: Date
    var score: Int
    var status: BodyStatus
    var headline: String
    var detail: String
    var metrics: [WatchMetricPayload]
    var recommendations: [WatchRecommendationPayload]

    init(
        updatedAt: Date,
        score: Int,
        status: BodyStatus,
        headline: String,
        detail: String,
        metrics: [WatchMetricPayload],
        recommendations: [WatchRecommendationPayload]
    ) {
        self.updatedAt = updatedAt
        self.score = score
        self.status = status
        self.headline = headline
        self.detail = detail
        self.metrics = metrics
        self.recommendations = recommendations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        self.score = try container.decode(Int.self, forKey: .score)

        let rawStatus = try container.decode(String.self, forKey: .status)
        self.status = BodyStatus(rawValue: rawStatus) ?? .caution

        self.headline = try container.decode(String.self, forKey: .headline)
        self.detail = try container.decode(String.self, forKey: .detail)
        self.metrics = try container.decode([WatchMetricPayload].self, forKey: .metrics)
        self.recommendations = try container.decode([WatchRecommendationPayload].self, forKey: .recommendations)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(score, forKey: .score)
        try container.encode(status.rawValue, forKey: .status)
        try container.encode(headline, forKey: .headline)
        try container.encode(detail, forKey: .detail)
        try container.encode(metrics, forKey: .metrics)
        try container.encode(recommendations, forKey: .recommendations)
    }

    private enum CodingKeys: String, CodingKey {
        case updatedAt
        case score
        case status
        case headline
        case detail
        case metrics
        case recommendations
    }
}

extension WatchSummaryPayload {
    init(summary: DailyBodySummary, snapshot: BodyDashboardSnapshot, trends: BodyDashboardTrends, updatedAt: Date) {
        self.init(
            updatedAt: updatedAt,
            score: summary.score.overall,
            status: summary.score.status,
            headline: summary.score.status.headline,
            detail: summary.score.conciseExplanation,
            metrics: [
                WatchMetricPayload(
                    title: "心率",
                    value: snapshot.restingHeartRateBpm?.roundedString ?? "--",
                    unit: "bpm",
                    kind: .heartRate,
                    bars: Self.trendBars(from: trends.recovery)
                ),
                WatchMetricPayload(
                    title: "活动",
                    value: snapshot.activeEnergyKcal?.roundedString ?? "--",
                    unit: "kcal",
                    kind: .activeEnergy,
                    bars: Self.trendBars(from: trends.activeEnergy)
                ),
                WatchMetricPayload(
                    title: "睡眠",
                    value: snapshot.sleepDurationCompact,
                    unit: snapshot.sleepDeltaCompact,
                    kind: .sleep,
                    bars: Self.trendBars(from: trends.sleep)
                ),
                WatchMetricPayload(
                    title: "HRV",
                    value: snapshot.hrvMs?.roundedString ?? "--",
                    unit: "ms",
                    kind: .hrv,
                    bars: Self.trendBars(from: trends.recovery)
                ),
                WatchMetricPayload(
                    title: "步数",
                    value: snapshot.stepCount?.compactCountString ?? "--",
                    unit: "步",
                    kind: .steps,
                    bars: Self.fallbackBars
                ),
                WatchMetricPayload(
                    title: "体重",
                    value: snapshot.weightSevenDayDeltaKg?.signedOneDecimalString ?? snapshot.weightKg?.oneDecimalString ?? "--",
                    unit: "kg",
                    kind: .weight,
                    bars: Self.trendBars(from: trends.weight)
                )
            ],
            recommendations: summary.recommendations.prefix(3).map { recommendation in
                WatchRecommendationPayload(
                    type: recommendation.type,
                    title: recommendation.title,
                    rationale: recommendation.rationale,
                    priority: recommendation.priority
                )
            }
        )
    }

    static var sample: WatchSummaryPayload {
        WatchSummaryPayload(
            summary: SampleBodyData.summary,
            snapshot: SampleBodyData.dashboardSnapshot,
            trends: SampleBodyData.dashboardTrends,
            updatedAt: Date()
        )
    }

    private static var fallbackBars: [Double] {
        [0.34, 0.42, 0.51, 0.58, 0.66]
    }

    private static func trendBars(from trend: DashboardTrendSeries) -> [Double] {
        let values = trend.normalizedValues
        guard values.count >= 2 else {
            return fallbackBars
        }

        return Array(values.suffix(5))
    }
}

extension BodyDashboardSnapshot {
    var sleepDurationCompact: String {
        guard let sleepMinutes else {
            return "--"
        }

        let hours = Int(sleepMinutes / 60)
        let minutes = Int(sleepMinutes.truncatingRemainder(dividingBy: 60))
        return "\(hours)h\(String(format: "%02d", minutes))"
    }

    var sleepDeltaCompact: String {
        guard let sleepMinutes, let sleepBaselineMinutes else {
            return "睡眠"
        }

        return (sleepMinutes - sleepBaselineMinutes).signedMinutesString
    }
}

extension Double {
    var compactCountString: String {
        if self >= 1_000 {
            return String(format: "%.1fk", self / 1_000)
        }

        return roundedString
    }
}
