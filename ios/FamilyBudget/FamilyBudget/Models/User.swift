import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let name: String
    let role: UserRole
    var phoneNumber: String?
    var alertMode: AlertMode?
    var thresholdAmount: Double?
    var monthlyLimit: Double?
    var currentSpend: Double?
    let createdAt: Date?

    enum UserRole: String, Codable {
        case parent
        case child
    }

    enum AlertMode: String, Codable {
        case all
        case weekly
        case threshold
    }

    enum CodingKeys: String, CodingKey {
        case id, name, role
        case phoneNumber = "phone_number"
        case alertMode = "alert_mode"
        case thresholdAmount = "threshold_amount"
        case monthlyLimit = "monthly_limit"
        case currentSpend = "current_spend"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        role = try container.decode(UserRole.self, forKey: .role)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        alertMode = try container.decodeIfPresent(AlertMode.self, forKey: .alertMode)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)

        // Handle decimal fields as either String or Double (PostgreSQL returns decimals as strings)
        if let val = try? container.decodeIfPresent(Double.self, forKey: .thresholdAmount) {
            thresholdAmount = val
        } else if let str = try? container.decodeIfPresent(String.self, forKey: .thresholdAmount) {
            thresholdAmount = Double(str)
        } else {
            thresholdAmount = nil
        }

        if let val = try? container.decodeIfPresent(Double.self, forKey: .monthlyLimit) {
            monthlyLimit = val
        } else if let str = try? container.decodeIfPresent(String.self, forKey: .monthlyLimit) {
            monthlyLimit = Double(str)
        } else {
            monthlyLimit = nil
        }

        if let val = try? container.decodeIfPresent(Double.self, forKey: .currentSpend) {
            currentSpend = val
        } else if let str = try? container.decodeIfPresent(String.self, forKey: .currentSpend) {
            currentSpend = Double(str)
        } else {
            currentSpend = nil
        }
    }

    var percentUsed: Double {
        guard let limit = monthlyLimit, let spent = currentSpend, limit > 0 else { return 0 }
        return (spent / limit) * 100
    }

    var remaining: Double {
        guard let limit = monthlyLimit, let spent = currentSpend else { return 0 }
        return limit - spent
    }

    var isOverLimit: Bool {
        percentUsed >= 100
    }

    var isWarning: Bool {
        percentUsed >= 90 && percentUsed < 100
    }
}

// For display purposes with debug mode
extension User {
    func displayName(anonymized: Bool) -> String {
        if anonymized {
            return "Person \(id)"
        }
        return name
    }
}
