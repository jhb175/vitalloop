import Foundation
import SwiftData

enum UserGoalType: String, Codable, CaseIterable {
    case fatLoss
    case muscleGain
    case stressReduction
    case fitness
    case skill

    var displayName: String {
        switch self {
        case .fatLoss:
            return "减脂"
        case .muscleGain:
            return "增肌"
        case .stressReduction:
            return "减压"
        case .fitness:
            return "运动能力"
        case .skill:
            return "技能提升"
        }
    }
}

@Model
final class UserGoal {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var goalTypeRawValue: String
    var targetWeightKg: Double?
    var startWeightKg: Double?
    var targetDate: Date?
    var weeklyWeightLossTargetKg: Double?
    var preferredWorkoutMinutes: Int?
    var dietaryNotes: String
    var workScheduleNotes: String

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        goalType: UserGoalType = .fatLoss,
        targetWeightKg: Double? = nil,
        startWeightKg: Double? = nil,
        targetDate: Date? = nil,
        weeklyWeightLossTargetKg: Double? = nil,
        preferredWorkoutMinutes: Int? = nil,
        dietaryNotes: String = "",
        workScheduleNotes: String = ""
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.goalTypeRawValue = goalType.rawValue
        self.targetWeightKg = targetWeightKg
        self.startWeightKg = startWeightKg
        self.targetDate = targetDate
        self.weeklyWeightLossTargetKg = weeklyWeightLossTargetKg
        self.preferredWorkoutMinutes = preferredWorkoutMinutes
        self.dietaryNotes = dietaryNotes
        self.workScheduleNotes = workScheduleNotes
    }

    var goalType: UserGoalType {
        get {
            UserGoalType(rawValue: goalTypeRawValue) ?? .fatLoss
        }
        set {
            goalTypeRawValue = newValue.rawValue
            updatedAt = Date()
        }
    }

    var remainingWeightLossKg: Double? {
        guard goalType == .fatLoss,
              let startWeightKg,
              let targetWeightKg,
              startWeightKg > targetWeightKg
        else {
            return nil
        }

        return startWeightKg - targetWeightKg
    }

    var isMeaningfulFatLossGoal: Bool {
        goalType == .fatLoss && targetWeightKg != nil
    }
}

@Model
final class DailySummaryRecord {
    @Attribute(.unique) var id: UUID
    var date: Date
    var createdAt: Date
    var updatedAt: Date
    var overallScore: Int
    var statusRawValue: String
    var dataSourceRawValue: String
    var summaryText: String
    var sleepScore: Int
    var recoveryScore: Int
    var activityScore: Int
    var weightTrendScore: Int
    var dataCompleteness: Int

    init(
        id: UUID = UUID(),
        date: Date,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        overallScore: Int,
        statusRawValue: String,
        dataSourceRawValue: String,
        summaryText: String,
        sleepScore: Int,
        recoveryScore: Int,
        activityScore: Int,
        weightTrendScore: Int,
        dataCompleteness: Int
    ) {
        self.id = id
        self.date = date
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.overallScore = overallScore
        self.statusRawValue = statusRawValue
        self.dataSourceRawValue = dataSourceRawValue
        self.summaryText = summaryText
        self.sleepScore = sleepScore
        self.recoveryScore = recoveryScore
        self.activityScore = activityScore
        self.weightTrendScore = weightTrendScore
        self.dataCompleteness = dataCompleteness
    }
}

@Model
final class SubjectiveCheckIn {
    @Attribute(.unique) var id: UUID
    var capturedAt: Date
    var createdAt: Date
    var stress: Int
    var fatigue: Int
    var hunger: Int
    var source: String

    init(
        id: UUID = UUID(),
        capturedAt: Date = Date(),
        createdAt: Date = Date(),
        stress: Int,
        fatigue: Int,
        hunger: Int,
        source: String = "Apple Watch"
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.createdAt = createdAt
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

    static func clamped(_ value: Int) -> Int {
        min(max(value, 1), 10)
    }
}

@Model
final class WeightEntry {
    @Attribute(.unique) var id: UUID
    var capturedAt: Date
    var createdAt: Date
    var weightKg: Double
    var source: String
    var note: String

    init(
        id: UUID = UUID(),
        capturedAt: Date = Date(),
        createdAt: Date = Date(),
        weightKg: Double,
        source: String = "Manual",
        note: String = ""
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.createdAt = createdAt
        self.weightKg = weightKg
        self.source = source
        self.note = note
    }
}
