import Foundation

struct BodyMetricBaseline: Equatable, Sendable {
    var sleepMinutes: Double?
    var restingHeartRateBpm: Double?
    var hrvMs: Double?

    var availableFieldCount: Int {
        [
            sleepMinutes,
            restingHeartRateBpm,
            hrvMs
        ].compactMap { $0 }.count
    }
}

struct BaselineSample: Equatable, Sendable {
    var date: Date
    var sleepMinutes: Double?
    var restingHeartRateBpm: Double?
    var hrvMs: Double?
}

struct BaselineCalculator: Sendable {
    var minimumSampleCount = 5

    func calculate(from samples: [BaselineSample]) -> BodyMetricBaseline {
        BodyMetricBaseline(
            sleepMinutes: medianAfterTrimming(samples.compactMap(\.sleepMinutes)),
            restingHeartRateBpm: medianAfterTrimming(samples.compactMap(\.restingHeartRateBpm)),
            hrvMs: medianAfterTrimming(samples.compactMap(\.hrvMs))
        )
    }

    private func medianAfterTrimming(_ values: [Double]) -> Double? {
        let cleaned = values
            .filter { $0.isFinite && $0 > 0 }
            .sorted()

        guard cleaned.count >= minimumSampleCount else {
            return nil
        }

        let trimmed = trimOutliers(cleaned)
        guard trimmed.isEmpty == false else {
            return nil
        }

        let middle = trimmed.count / 2
        if trimmed.count.isMultiple(of: 2) {
            return (trimmed[middle - 1] + trimmed[middle]) / 2
        }

        return trimmed[middle]
    }

    private func trimOutliers(_ sortedValues: [Double]) -> [Double] {
        guard sortedValues.count >= 8 else {
            return sortedValues
        }

        let trimCount = max(1, Int(Double(sortedValues.count) * 0.1))
        guard sortedValues.count > trimCount * 2 else {
            return sortedValues
        }

        return Array(sortedValues.dropFirst(trimCount).dropLast(trimCount))
    }
}
