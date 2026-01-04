import Foundation

struct Transaction: Codable, Identifiable {
    let id: Int
    let cardId: Int
    let plaidTransactionId: String?
    let amount: Double
    let merchantName: String?
    let category: String?
    let date: Date
    let isRecurring: Bool
    let isFoodDelivery: Bool
    let createdAt: Date?

    // Joined fields
    var cardholderName: String?
    var lastFour: String?

    enum CodingKeys: String, CodingKey {
        case id
        case cardId = "card_id"
        case plaidTransactionId = "plaid_transaction_id"
        case amount
        case merchantName = "merchant_name"
        case category
        case date
        case isRecurring = "is_recurring"
        case isFoodDelivery = "is_food_delivery"
        case createdAt = "created_at"
        case cardholderName = "cardholder_name"
        case lastFour = "last_four"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        cardId = try container.decode(Int.self, forKey: .cardId)
        plaidTransactionId = try container.decodeIfPresent(String.self, forKey: .plaidTransactionId)
        merchantName = try container.decodeIfPresent(String.self, forKey: .merchantName)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        date = try container.decode(Date.self, forKey: .date)
        isRecurring = try container.decodeIfPresent(Bool.self, forKey: .isRecurring) ?? false
        isFoodDelivery = try container.decodeIfPresent(Bool.self, forKey: .isFoodDelivery) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        cardholderName = try container.decodeIfPresent(String.self, forKey: .cardholderName)
        lastFour = try container.decodeIfPresent(String.self, forKey: .lastFour)

        if let val = try? container.decode(Double.self, forKey: .amount) {
            amount = val
        } else if let str = try? container.decode(String.self, forKey: .amount) {
            amount = Double(str) ?? 0
        } else {
            amount = 0
        }
    }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var merchantDisplayName: String {
        merchantName ?? "Unknown Merchant"
    }
}

// Spending summary for dashboard
struct SpendingSummary: Codable, Identifiable {
    var id: Int { userId }
    let userId: Int
    let name: String
    let role: String
    let totalSpent: Double
    let monthlyLimit: Double?
    let transactionCount: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case role
        case totalSpent = "total_spent"
        case monthlyLimit = "monthly_limit"
        case transactionCount = "transaction_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(Int.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        role = try container.decode(String.self, forKey: .role)
        transactionCount = try container.decode(Int.self, forKey: .transactionCount)

        if let val = try? container.decode(Double.self, forKey: .totalSpent) {
            totalSpent = val
        } else if let str = try? container.decode(String.self, forKey: .totalSpent) {
            totalSpent = Double(str) ?? 0
        } else {
            totalSpent = 0
        }

        if let val = try? container.decodeIfPresent(Double.self, forKey: .monthlyLimit) {
            monthlyLimit = val
        } else if let str = try container.decodeIfPresent(String.self, forKey: .monthlyLimit) {
            monthlyLimit = Double(str)
        } else {
            monthlyLimit = nil
        }
    }

    var percentUsed: Double {
        guard let limit = monthlyLimit, limit > 0 else { return 0 }
        return (totalSpent / limit) * 100
    }

    var remaining: Double {
        guard let limit = monthlyLimit else { return 0 }
        return limit - totalSpent
    }
}

// Category breakdown
struct CategorySpend: Codable, Identifiable {
    var id: String { category }
    let category: String
    let total: Double
    let count: Int

    enum CodingKeys: String, CodingKey {
        case category, total, count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        category = try container.decode(String.self, forKey: .category)
        count = try container.decode(Int.self, forKey: .count)
        if let val = try? container.decode(Double.self, forKey: .total) {
            total = val
        } else if let str = try? container.decode(String.self, forKey: .total) {
            total = Double(str) ?? 0
        } else {
            total = 0
        }
    }
}

// Top merchant
struct TopMerchant: Codable, Identifiable {
    var id: String { merchantName }
    let merchantName: String
    let total: Double
    let count: Int

    enum CodingKeys: String, CodingKey {
        case merchantName = "merchant_name"
        case total
        case count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        merchantName = try container.decode(String.self, forKey: .merchantName)
        count = try container.decode(Int.self, forKey: .count)
        if let val = try? container.decode(Double.self, forKey: .total) {
            total = val
        } else if let str = try? container.decode(String.self, forKey: .total) {
            total = Double(str) ?? 0
        } else {
            total = 0
        }
    }
}
