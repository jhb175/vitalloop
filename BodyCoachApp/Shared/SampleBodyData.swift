import BodyCoachCore

enum SampleBodyData {
    static let metrics = BodyMetrics(
        sleepMinutes: 394,
        sleepBaselineMinutes: 450,
        activeEnergyKcal: 684,
        activeEnergyGoalKcal: 800,
        stepCount: 7_820,
        restingHeartRateBpm: 62,
        restingHeartRateBaselineBpm: 60,
        hrvMs: 38,
        hrvBaselineMs: 43,
        weightKg: 76.8,
        weightSevenDayDeltaKg: -0.4,
        subjectiveStress: 5,
        subjectiveFatigue: 4,
        hungerLevel: 6,
        workoutMinutes: 28
    )

    static var summary: DailyBodySummary {
        BodyCoachScorer().summarize(metrics)
    }

    static var dashboardSnapshot: BodyDashboardSnapshot {
        BodyDashboardSnapshot.sample()
    }

    static var dashboardTrends: BodyDashboardTrends {
        BodyDashboardTrends.sample()
    }
}
