import BodyCoachCore
import Foundation

struct HealthMetricSnapshot: Equatable, Sendable {
    var date: Date
    var sleepMinutes: Double?
    var activeEnergyKcal: Double?
    var stepCount: Double?
    var restingHeartRateBpm: Double?
    var hrvMs: Double?
    var hrvBaselineMs: Double?
    var weightKg: Double?
    var workoutMinutes: Double?
    var weightSevenDayDeltaKg: Double?
    var sleepBaselineMinutes: Double?
    var restingHeartRateBaselineBpm: Double?

    init(
        date: Date,
        sleepMinutes: Double? = nil,
        activeEnergyKcal: Double? = nil,
        stepCount: Double? = nil,
        restingHeartRateBpm: Double? = nil,
        hrvMs: Double? = nil,
        hrvBaselineMs: Double? = nil,
        weightKg: Double? = nil,
        workoutMinutes: Double? = nil,
        weightSevenDayDeltaKg: Double? = nil,
        sleepBaselineMinutes: Double? = nil,
        restingHeartRateBaselineBpm: Double? = nil
    ) {
        self.date = date
        self.sleepMinutes = sleepMinutes
        self.activeEnergyKcal = activeEnergyKcal
        self.stepCount = stepCount
        self.restingHeartRateBpm = restingHeartRateBpm
        self.hrvMs = hrvMs
        self.hrvBaselineMs = hrvBaselineMs
        self.weightKg = weightKg
        self.workoutMinutes = workoutMinutes
        self.weightSevenDayDeltaKg = weightSevenDayDeltaKg
        self.sleepBaselineMinutes = sleepBaselineMinutes
        self.restingHeartRateBaselineBpm = restingHeartRateBaselineBpm
    }

    var dashboardSnapshot: BodyDashboardSnapshot {
        BodyDashboardSnapshot(
            date: date,
            sleepMinutes: sleepMinutes,
            activeEnergyKcal: activeEnergyKcal,
            activeEnergyGoalKcal: 800,
            stepCount: stepCount,
            restingHeartRateBpm: restingHeartRateBpm,
            hrvMs: hrvMs,
            hrvBaselineMs: hrvBaselineMs,
            weightKg: weightKg,
            weightSevenDayDeltaKg: weightSevenDayDeltaKg,
            workoutMinutes: workoutMinutes,
            sleepBaselineMinutes: sleepBaselineMinutes,
            restingHeartRateBaselineBpm: restingHeartRateBaselineBpm
        )
    }
}
