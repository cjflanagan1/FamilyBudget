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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(Int.self, forKey: .userId)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        resetDay = try container.decodeIfPresent(Int.self, forKey: .resetDay) ?? 1
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)

        if let val = try? container.decode(Double.self, forKey: .monthlyLimit) {
            monthlyLimit = val
        } else if let str = try? container.decode(String.self, forKey: .monthlyLimit) {
            monthlyLimit = Double(str) ?? 0
        } else {
            monthlyLimit = 0
        }

        if let val = try? container.decode(Double.self, forKey: .currentSpend) {
            currentSpend = val
        } else if let str = try? container.decode(String.self, forKey: .currentSpend) {
            currentSpend = Double(str) ?? 0
        } else {
            currentSpend = 0
        }

        if let val = try? container.decodeIfPresent(Double.self, forKey: .percentUsed) {
            percentUsed = val
        } else if let str = try container.decodeIfPresent(String.self, forKey: .percentUsed) {
            percentUsed = Double(str)
        } else {
            percentUsed = nil
        }

        if let val = try? container.decodeIfPresent(Double.self, forKey: .remaining) {
            remaining = val
        } else if let str = try container.decodeIfPresent(String.self, forKey: .remaining) {
            remaining = Double(str)
        } else {
            remaining = nil
        }
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        role = try container.decode(String.self, forKey: .role)
        isWarning = try container.decodeIfPresent(Bool.self, forKey: .isWarning) ?? false
        isOver = try container.decodeIfPresent(Bool.self, forKey: .isOver) ?? false

        if let val = try? container.decodeIfPresent(Double.self, forKey: .monthlyLimit) {
            monthlyLimit = val
        } else if let str = try container.decodeIfPresent(String.self, forKey: .monthlyLimit) {
            monthlyLimit = Double(str)
        } else {
            monthlyLimit = nil
        }

        if let val = try? container.decode(Double.self, forKey: .currentSpend) {
            currentSpend = val
        } else if let str = try? container.decode(String.self, forKey: .currentSpend) {
            currentSpend = Double(str) ?? 0
        } else {
            currentSpend = 0
        }

        if let val = try? container.decode(Double.self, forKey: .percentUsed) {
            percentUsed = val
        } else if let str = try? container.decode(String.self, forKey: .percentUsed) {
            percentUsed = Double(str) ?? 0
        } else {
            percentUsed = 0
        }

        if let val = try? container.decode(Double.self, forKey: .remaining) {
            remaining = val
        } else if let str = try? container.decode(String.self, forKey: .remaining) {
            remaining = Double(str) ?? 0
        } else {
            remaining = 0
        }
    }
}
