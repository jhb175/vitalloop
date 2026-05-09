import BodyCoachCore
import Foundation
import HealthKit

actor HealthKitClient {
    private let store = HKHealthStore()
    private let baselineCalculator = BaselineCalculator()
    private let weightTrendFilter = WeightTrendFilter()

    nonisolated var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitClientError.unavailable
        }

        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func todaySnapshot(now: Date = Date(), calendar: Calendar = .current) async throws -> HealthMetricSnapshot {
        guard isHealthDataAvailable else {
            throw HealthKitClientError.unavailable
        }

        let dayInterval = calendar.dateInterval(of: .day, for: now) ?? DateInterval(start: now.addingTimeInterval(-86_400), end: now)
        let sleepInterval = sleepWindow(for: now, calendar: calendar)
        let recentInterval = DateInterval(start: calendar.date(byAdding: .day, value: -7, to: now) ?? now.addingTimeInterval(-604_800), end: now)
        let weightInterval = DateInterval(start: calendar.date(byAdding: .day, value: -14, to: now) ?? now.addingTimeInterval(-1_209_600), end: now)
        let baselineInterval = DateInterval(start: calendar.date(byAdding: .day, value: -28, to: now) ?? now.addingTimeInterval(-2_419_200), end: now)

        async let sleep = optional { try await self.sleepMinutes(in: sleepInterval) }
        async let activeEnergy = optional { try await self.quantitySum(.activeEnergyBurned, unit: .kilocalorie(), in: dayInterval) }
        async let steps = optional { try await self.quantitySum(.stepCount, unit: .count(), in: dayInterval) }
        async let restingHeartRate = optional { try await self.latestQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), in: recentInterval) }
        async let hrv = optional { try await self.latestQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), in: recentInterval) }
        async let bodyMass = optional { try await self.latestFilteredWeight(in: weightInterval) }
        async let weightDelta = optional { try await self.weightSevenDayDelta(in: weightInterval) }
        async let workouts = optional { try await self.workoutMinutes(in: dayInterval) }
        async let baseline = baseline(in: baselineInterval, calendar: calendar)

        return await HealthMetricSnapshot(
            date: now,
            sleepMinutes: sleep,
            activeEnergyKcal: activeEnergy,
            stepCount: steps,
            restingHeartRateBpm: restingHeartRate,
            hrvMs: hrv,
            hrvBaselineMs: baseline.hrvMs,
            weightKg: bodyMass,
            workoutMinutes: workouts,
            weightSevenDayDeltaKg: weightDelta,
            sleepBaselineMinutes: baseline.sleepMinutes,
            restingHeartRateBaselineBpm: baseline.restingHeartRateBpm
        )
    }

    func dashboardTrends(now: Date = Date(), calendar: Calendar = .current) async -> BodyDashboardTrends {
        guard isHealthDataAvailable else {
            return BodyDashboardTrends.empty(anchorDate: now, calendar: calendar)
        }

        let today = calendar.startOfDay(for: now)
        let trendStart = calendar.date(byAdding: .day, value: -6, to: today) ?? now.addingTimeInterval(-6 * 86_400)
        let trendInterval = DateInterval(start: trendStart, end: now)
        let sleepStart = calendar.date(byAdding: .hour, value: -12, to: trendStart) ?? trendStart.addingTimeInterval(-12 * 60 * 60)
        let sleepInterval = DateInterval(start: sleepStart, end: now)
        let days = trendDays(endingAt: now, count: 7, calendar: calendar)

        async let activeEnergy: [Date: Double] = optionalSamples {
            try await self.dailyQuantitySums(.activeEnergyBurned, unit: .kilocalorie(), in: trendInterval, calendar: calendar)
        }
        async let sleep: [Date: Double] = optionalSamples {
            try await self.dailySleepSamples(in: sleepInterval, calendar: calendar)
        }
        async let hrv: [(date: Date, value: Double)] = optionalSamples {
            try await self.quantitySamples(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), in: trendInterval)
        }
        async let weight: [(date: Date, value: Double)] = optionalSamples {
            try await self.quantitySamples(.bodyMass, unit: .gramUnit(with: .kilo), in: trendInterval)
        }

        let activeEnergyByDay = await activeEnergy
        let sleepByDay = await sleep
        let hrvByDay = groupedDailyMedian(await hrv, calendar: calendar)
        let weightByDay = groupedDailyLatest(filteredWeightSamples(await weight), calendar: calendar)

        return BodyDashboardTrends(
            activeEnergy: dashboardTrendSeries(days: days, values: activeEnergyByDay),
            sleep: dashboardTrendSeries(days: days, values: sleepByDay),
            recovery: dashboardTrendSeries(days: days, values: hrvByDay),
            weight: dashboardTrendSeries(days: days, values: weightByDay)
        )
    }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKObjectType.workoutType()
        ]

        [
            HKQuantityTypeIdentifier.activeEnergyBurned,
            .stepCount,
            .restingHeartRate,
            .heartRateVariabilitySDNN,
            .bodyMass
        ].compactMap(HKObjectType.quantityType(forIdentifier:)).forEach {
            types.insert($0)
        }

        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }

        return types
    }

    private func quantitySum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, in interval: DateInterval) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: [.strictStartDate])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
            }

            store.execute(query)
        }
    }

    private func dailyQuantitySums(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        in interval: DateInterval,
        calendar: Calendar
    ) async throws -> [Date: Double] {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            return [:]
        }

        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: [.strictStartDate])
        var intervalComponents = DateComponents()
        intervalComponents.day = 1

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: calendar.startOfDay(for: interval.start),
                intervalComponents: intervalComponents
            )

            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                var values = [Date: Double]()
                collection?.enumerateStatistics(from: interval.start, to: interval.end) { statistics, _ in
                    guard let value = statistics.sumQuantity()?.doubleValue(for: unit), value > 0 else {
                        return
                    }

                    values[calendar.startOfDay(for: statistics.startDate)] = value
                }

                continuation.resume(returning: values)
            }

            store.execute(query)
        }
    }

    private func latestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, in interval: DateInterval) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }

            store.execute(query)
        }
    }

    private func sleepMinutes(in interval: DateInterval) async throws -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: [])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let asleepSeconds = (samples as? [HKCategorySample])?.reduce(0.0) { total, sample in
                    guard sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                        || sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                        || sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                        || sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    else {
                        return total
                    }

                    let clippedStart = max(sample.startDate, interval.start)
                    let clippedEnd = min(sample.endDate, interval.end)
                    return total + max(0, clippedEnd.timeIntervalSince(clippedStart))
                }

                guard let asleepSeconds else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: asleepSeconds / 60)
            }

            store.execute(query)
        }
    }

    private func workoutMinutes(in interval: DateInterval) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: [.strictStartDate])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let minutes = (samples as? [HKWorkout])?.reduce(0.0) { total, workout in
                    total + workout.duration / 60
                }

                continuation.resume(returning: minutes)
            }

            store.execute(query)
        }
    }

    private func weightSevenDayDelta(in interval: DateInterval) async throws -> Double? {
        let samples = try await quantitySamples(.bodyMass, unit: .gramUnit(with: .kilo), in: interval)
        return weightTrendFilter.sevenDayDelta(from: bodyWeightSamples(samples))
    }

    private func baseline(in interval: DateInterval, calendar: Calendar) async -> BodyMetricBaseline {
        async let sleepSamples = optionalSamples { try await self.dailySleepSamples(in: interval, calendar: calendar) }
        async let restingSamples = optionalSamples { try await self.quantitySamples(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), in: interval) }
        async let hrvSamples = optionalSamples { try await self.quantitySamples(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), in: interval) }

        let sleeps = await sleepSamples
        let resting = await restingSamples
        let hrv = await hrvSamples

        let groupedResting = groupedDailyMedian(resting, calendar: calendar)
        let groupedHRV = groupedDailyMedian(hrv, calendar: calendar)
        let days = Set(sleeps.keys).union(groupedResting.keys).union(groupedHRV.keys)

        let samples = days.map { day in
            BaselineSample(
                date: day,
                sleepMinutes: sleeps[day],
                restingHeartRateBpm: groupedResting[day],
                hrvMs: groupedHRV[day]
            )
        }

        return baselineCalculator.calculate(from: samples)
    }

    private func dailySleepSamples(in interval: DateInterval, calendar: Calendar) async throws -> [Date: Double] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return [:]
        }

        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: [])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let sleepSamples = (samples as? [HKCategorySample]) ?? []
                let grouped = sleepSamples.reduce(into: [Date: Double]()) { result, sample in
                    guard sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                        || sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                        || sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                        || sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    else {
                        return
                    }

                    let day = calendar.startOfDay(for: sample.endDate)
                    result[day, default: 0] += sample.endDate.timeIntervalSince(sample.startDate) / 60
                }

                continuation.resume(returning: grouped)
            }

            store.execute(query)
        }
    }

    private func quantitySamples(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, in interval: DateInterval) async throws -> [(date: Date, value: Double)] {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let values = ((samples as? [HKQuantitySample]) ?? []).map { sample in
                    (date: sample.endDate, value: sample.quantity.doubleValue(for: unit))
                }

                continuation.resume(returning: values)
            }

            store.execute(query)
        }
    }

    private func groupedDailyMedian(_ samples: [(date: Date, value: Double)], calendar: Calendar) -> [Date: Double] {
        let grouped = Dictionary(grouping: samples) { sample in
            calendar.startOfDay(for: sample.date)
        }

        return grouped.compactMapValues { samples in
            median(samples.map(\.value))
        }
    }

    private func groupedDailyLatest(_ samples: [(date: Date, value: Double)], calendar: Calendar) -> [Date: Double] {
        samples.reduce(into: [Date: Double]()) { result, sample in
            guard sample.value.isFinite, sample.value > 0 else {
                return
            }

            result[calendar.startOfDay(for: sample.date)] = sample.value
        }
    }

    private func latestFilteredWeight(in interval: DateInterval) async throws -> Double? {
        let samples = try await quantitySamples(.bodyMass, unit: .gramUnit(with: .kilo), in: interval)
        return weightTrendFilter.filteredSamples(bodyWeightSamples(samples)).last?.kg
    }

    private func filteredWeightSamples(_ samples: [(date: Date, value: Double)]) -> [(date: Date, value: Double)] {
        weightTrendFilter.filteredSamples(bodyWeightSamples(samples)).map { sample in
            (date: sample.date, value: sample.kg)
        }
    }

    private func bodyWeightSamples(_ samples: [(date: Date, value: Double)]) -> [BodyWeightSample] {
        samples.map { sample in
            BodyWeightSample(date: sample.date, kg: sample.value)
        }
    }

    private func dashboardTrendSeries(days: [Date], values: [Date: Double]) -> DashboardTrendSeries {
        DashboardTrendSeries(
            points: days.map { day in
                DashboardTrendPoint(date: day, value: values[day])
            }
        )
    }

    private func median(_ values: [Double]) -> Double? {
        let sorted = values.filter { $0.isFinite && $0 > 0 }.sorted()
        guard sorted.isEmpty == false else {
            return nil
        }

        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }

        return sorted[middle]
    }

    private func sleepWindow(for date: Date, calendar: Calendar) -> DateInterval {
        let today = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .hour, value: -6, to: today) ?? date.addingTimeInterval(-30 * 60 * 60)
        let end = calendar.date(byAdding: .hour, value: 12, to: today) ?? date
        return DateInterval(start: start, end: max(end, date))
    }

    private func trendDays(endingAt date: Date, count: Int, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: date)
        return (0..<count).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - count + 1, to: today)
        }
    }

    private func optional(_ operation: @escaping @Sendable () async throws -> Double?) async -> Double? {
        do {
            return try await operation()
        } catch {
            return nil
        }
    }

    private func optionalSamples<Value: Sendable>(_ operation: @escaping @Sendable () async throws -> Value) async -> Value where Value: ExpressibleByDictionaryLiteral {
        do {
            return try await operation()
        } catch {
            return [:]
        }
    }

    private func optionalSamples<Value: Sendable>(_ operation: @escaping @Sendable () async throws -> Value) async -> Value where Value: ExpressibleByArrayLiteral {
        do {
            return try await operation()
        } catch {
            return []
        }
    }
}

enum HealthKitClientError: Error, Equatable {
    case unavailable
}
