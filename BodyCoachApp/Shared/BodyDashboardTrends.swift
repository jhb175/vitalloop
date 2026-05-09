import Foundation

struct BodyDashboardTrends: Equatable, Sendable {
    var activeEnergy: DashboardTrendSeries
    var sleep: DashboardTrendSeries
    var recovery: DashboardTrendSeries
    var weight: DashboardTrendSeries

    static func empty(anchorDate: Date = Date(), calendar: Calendar = .current) -> BodyDashboardTrends {
        let points = trendDays(endingAt: anchorDate, count: 7, calendar: calendar).map {
            DashboardTrendPoint(date: $0, value: nil)
        }

        return BodyDashboardTrends(
            activeEnergy: DashboardTrendSeries(points: points),
            sleep: DashboardTrendSeries(points: points),
            recovery: DashboardTrendSeries(points: points),
            weight: DashboardTrendSeries(points: points)
        )
    }

    static func sample(anchorDate: Date = Date(), calendar: Calendar = .current) -> BodyDashboardTrends {
        BodyDashboardTrends(
            activeEnergy: series(endingAt: anchorDate, calendar: calendar, values: [520, 610, 580, 670, 730, 690, 760]),
            sleep: series(endingAt: anchorDate, calendar: calendar, values: [438, 402, 416, 382, 398, 376, 394]),
            recovery: series(endingAt: anchorDate, calendar: calendar, values: [52, 49, 47, 44, 46, 43, 45]),
            weight: series(endingAt: anchorDate, calendar: calendar, values: [75.8, 75.6, 75.5, 75.4, 75.2, 75.1, 75.0])
        )
    }

    static func series(endingAt date: Date, calendar: Calendar, values: [Double?]) -> DashboardTrendSeries {
        let days = trendDays(endingAt: date, count: values.count, calendar: calendar)
        let points = zip(days, values).map { day, value in
            DashboardTrendPoint(date: day, value: value)
        }

        return DashboardTrendSeries(points: points)
    }

    private static func trendDays(endingAt date: Date, count: Int, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: date)
        return (0..<count).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - count + 1, to: today)
        }
    }
}

struct DashboardTrendSeries: Equatable, Sendable {
    var points: [DashboardTrendPoint]

    var availableValues: [Double] {
        points.compactMap { point in
            guard let value = point.value, value.isFinite else {
                return nil
            }

            return value
        }
    }

    var availablePointCount: Int {
        availableValues.count
    }

    var coverageLabel: String {
        "\(availablePointCount)/\(points.count)天"
    }

    var hasEnoughData: Bool {
        availablePointCount >= 2
    }

    var normalizedValues: [Double] {
        let values = availableValues
        guard values.count >= 2, let minValue = values.min(), let maxValue = values.max() else {
            return []
        }

        let range = maxValue - minValue
        guard range > 0.0001 else {
            return values.map { _ in 0.5 }
        }

        return values.map { value in
            0.12 + ((value - minValue) / range) * 0.76
        }
    }
}

struct DashboardTrendPoint: Equatable, Sendable {
    var date: Date
    var value: Double?
}
