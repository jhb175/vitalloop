import BodyCoachCore

extension BodyStatus {
    var displayName: String {
        switch self {
        case .strong:
            return "状态很好"
        case .normal:
            return "状态正常"
        case .caution:
            return "需要注意"
        case .recovery:
            return "优先恢复"
        }
    }

    var headline: String {
        switch self {
        case .strong:
            return "今天可以推进训练。"
        case .normal:
            return "今天适合轻训练，别加压。"
        case .caution:
            return "今天控制强度，先稳住节奏。"
        case .recovery:
            return "今天先恢复，避免硬练。"
        }
    }
}

extension RecommendationType {
    var displayName: String {
        switch self {
        case .movement:
            return "运动"
        case .nutrition:
            return "饮食"
        case .sleep:
            return "睡眠"
        case .recovery:
            return "恢复"
        case .logging:
            return "记录"
        }
    }

    var symbolName: String {
        switch self {
        case .movement:
            return "figure.walk"
        case .nutrition:
            return "fork.knife"
        case .sleep:
            return "moon.fill"
        case .recovery:
            return "heart.fill"
        case .logging:
            return "square.and.pencil"
        }
    }
}

extension ScoreBreakdown {
    var conciseExplanation: String {
        explanation.prefix(2).joined(separator: "，")
    }
}
