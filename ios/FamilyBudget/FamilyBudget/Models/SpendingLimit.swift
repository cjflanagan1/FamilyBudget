import Foundation

struct SpendingLimit: Codable, Identifiable {
    var id: Int { userId }
    let userId: Int
    let name: String?
    let monthlyLimit: Double
    let currentSpend: Double
    let resetDay: Int
    let updatedAt: Date?

    // Computed from API
    var percentUsed: Double?
    var remaining: Double?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case monthlyLimit = "monthly_limit"
        case currentSpend = "current_spend"
        case resetDay = "reset_day"
        case updatedAt = "updated_at"
        case percentUsed = "percent_used"
        case remaining
    }

    var calculatedPercentUsed: Double {
        percentUsed ?? (monthlyLimit > 0 ? (currentSpend / monthlyLimit) * 100 : 0)
    }

    var calculatedRemaining: Double {
        remaining ?? (monthlyLimit - currentSpend)
    }

    var isOverLimit: Bool {
        calculatedPercentUsed >= 100
    }

    var isWarning: Bool {
        calculatedPercentUsed >= 90 && calculatedPercentUsed < 100
    }

    var statusColor: String {
        if isOverLimit { return "red" }
        if isWarning { return "orange" }
        return "green"
    }
}

// Status for all users (dashboard)
struct SpendingStatus: Codable, Identifiable {
    let id: Int
    let name: String
    let role: String
    let monthlyLimit: Double?
    let currentSpend: Double
    let percentUsed: Double
    let remaining: Double
    let isWarning: Bool
    let isOver: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, role
        case monthlyLimit = "monthly_limit"
        case currentSpend = "current_spend"
        case percentUsed = "percent_used"
        case remaining
        case isWarning = "is_warning"
        case isOver = "is_over"
    }
}
