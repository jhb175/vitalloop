import Foundation
import Testing
@testable import BodyCoachCore

@Test func balancedDayProducesNormalStatus() {
    let scorer = BodyCoachScorer()
    let summary = scorer.summarize(BodyMetrics(
        sleepMinutes: 420,
        sleepBaselineMinutes: 450,
        activeEnergyKcal: 640,
        activeEnergyGoalKcal: 650,
        stepCount: 8_400,
        restingHeartRateBpm: 61,
        restingHeartRateBaselineBpm: 60,
        hrvMs: 43,
        hrvBaselineMs: 42,
        weightKg: 76.8,
        weightSevenDayDeltaKg: -0.4,
        subjectiveStress: 4,
        subjectiveFatigue: 4,
        hungerLevel: 5,
        workoutMinutes: 32
    ))

    #expect(summary.score.overall >= 70)
    #expect(summary.score.status == .normal || summary.score.status == .strong)
    #expect(summary.score.explanation.isEmpty == false)
    #expect(summary.recommendations.isEmpty == false)
}

@Test func weakSleepAndRecoveryPrioritizeRecovery() {
    let scorer = BodyCoachScorer()
    let summary = scorer.summarize(BodyMetrics(
        sleepMinutes: 310,
        sleepBaselineMinutes: 450,
        activeEnergyKcal: 520,
        activeEnergyGoalKcal: 650,
        stepCount: 6_500,
        restingHeartRateBpm: 68,
        restingHeartRateBaselineBpm: 60,
        hrvMs: 31,
        hrvBaselineMs: 43,
        weightSevenDayDeltaKg: -0.5,
        subjectiveStress: 7,
        subjectiveFatigue: 8,
        hungerLevel: 8
    ))

    #expect(summary.score.status == .recovery || summary.score.status == .caution)
    #expect(summary.recommendations.first?.type == .recovery)
    #expect(summary.recommendations.contains { $0.type == .sleep })
    #expect(summary.recommendations.contains { $0.type == .nutrition })
}

@Test func missingDataLowersCompletenessAndAddsLoggingAdvice() {
    let scorer = BodyCoachScorer()
    let summary = scorer.summarize(BodyMetrics(
        activeEnergyKcal: 300,
        activeEnergyGoalKcal: 650,
        stepCount: 3_200
    ))

    #expect(summary.score.dataCompleteness < 40)
    #expect(summary.recommendations.contains { $0.type == .logging })
    #expect(summary.score.explanation.contains { $0.contains("数据完整度不足") })
}

@Test func subjectiveLoadCanShiftRecommendationTowardRecovery() {
    let scorer = BodyCoachScorer()
    let calm = scorer.summarize(BodyMetrics(
        sleepMinutes: 430,
        sleepBaselineMinutes: 430,
        activeEnergyKcal: 620,
        activeEnergyGoalKcal: 650,
        stepCount: 8_200,
        restingHeartRateBpm: 60,
        restingHeartRateBaselineBpm: 60,
        hrvMs: 43,
        hrvBaselineMs: 43,
        weightSevenDayDeltaKg: -0.4,
        subjectiveStress: 2,
        subjectiveFatigue: 2,
        hungerLevel: 4,
        workoutMinutes: 30
    ))
    let overloaded = scorer.summarize(BodyMetrics(
        sleepMinutes: 430,
        sleepBaselineMinutes: 430,
        activeEnergyKcal: 620,
        activeEnergyGoalKcal: 650,
        stepCount: 8_200,
        restingHeartRateBpm: 60,
        restingHeartRateBaselineBpm: 60,
        hrvMs: 43,
        hrvBaselineMs: 43,
        weightSevenDayDeltaKg: -0.4,
        subjectiveStress: 10,
        subjectiveFatigue: 10,
        hungerLevel: 8,
        workoutMinutes: 30
    ))

    #expect(overloaded.score.recovery < calm.score.recovery)
    #expect(overloaded.score.overall < calm.score.overall)
    #expect(overloaded.recommendations.contains { $0.type == .nutrition })
}

@Test func aggressiveFatLossGoalAddsPacingRecommendation() {
    let scorer = BodyCoachScorer()
    let summary = scorer.summarize(
        BodyMetrics(
            sleepMinutes: 430,
            sleepBaselineMinutes: 430,
            activeEnergyKcal: 680,
            activeEnergyGoalKcal: 650,
            stepCount: 8_800,
            restingHeartRateBpm: 60,
            restingHeartRateBaselineBpm: 60,
            hrvMs: 43,
            hrvBaselineMs: 43,
            weightKg: 78,
            weightSevenDayDeltaKg: -0.4,
            subjectiveStress: 3,
            subjectiveFatigue: 3,
            hungerLevel: 5,
            workoutMinutes: 35
        ),
        goal: BodyGoalContext(
            kind: .fatLoss,
            currentWeightKg: 78,
            targetWeightKg: 72,
            targetDate: Date().addingTimeInterval(4 * 7 * 24 * 60 * 60),
            weeklyWeightLossTargetKg: 1.0,
            preferredWorkoutMinutes: 45
        )
    )

    #expect(summary.score.explanation.contains { $0.contains("目标偏快") })
    #expect(summary.recommendations.contains { $0.title == "放缓减脂目标节奏" })
}

@Test func preferredWorkoutMinutesAdjustsMovementRecommendation() {
    let scorer = BodyCoachScorer()
    let summary = scorer.summarize(
        BodyMetrics(
            sleepMinutes: 460,
            sleepBaselineMinutes: 430,
            activeEnergyKcal: 680,
            activeEnergyGoalKcal: 650,
            stepCount: 8_800,
            restingHeartRateBpm: 59,
            restingHeartRateBaselineBpm: 60,
            hrvMs: 45,
            hrvBaselineMs: 43,
            weightKg: 78,
            weightSevenDayDeltaKg: -0.4,
            subjectiveStress: 2,
            subjectiveFatigue: 2,
            hungerLevel: 4,
            workoutMinutes: 35
        ),
        goal: BodyGoalContext(
            kind: .fatLoss,
            currentWeightKg: 78,
            targetWeightKg: 75,
            targetDate: Date().addingTimeInterval(12 * 7 * 24 * 60 * 60),
            weeklyWeightLossTargetKg: 0.4,
            preferredWorkoutMinutes: 45
        )
    )

    #expect(summary.recommendations.contains { $0.title.contains("45 分钟") })
}

@Test func weightTrendFilterRemovesImplausibleOutliers() {
    let filter = WeightTrendFilter()
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let samples = [
        BodyWeightSample(date: start, kg: 76.2),
        BodyWeightSample(date: start.addingTimeInterval(24 * 60 * 60), kg: 75.9),
        BodyWeightSample(date: start.addingTimeInterval(2 * 24 * 60 * 60), kg: 112.0),
        BodyWeightSample(date: start.addingTimeInterval(7 * 24 * 60 * 60), kg: 75.4)
    ]

    let filtered = filter.filteredSamples(samples)
    #expect(filtered.map(\.kg) == [76.2, 75.9, 75.4])
    let delta = filter.sevenDayDelta(from: samples)
    #expect(delta != nil)
    #expect(abs((delta ?? 0) + 0.8) < 0.001)
}

@Test func weightTrendFilterRejectsSparseLargeJump() {
    let filter = WeightTrendFilter()
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let samples = [
        BodyWeightSample(date: start, kg: 74.0),
        BodyWeightSample(date: start.addingTimeInterval(7 * 24 * 60 * 60), kg: 93.0)
    ]

    #expect(filter.filteredSamples(samples).map(\.kg) == [93.0])
    #expect(filter.sevenDayDelta(from: samples) == nil)
}
