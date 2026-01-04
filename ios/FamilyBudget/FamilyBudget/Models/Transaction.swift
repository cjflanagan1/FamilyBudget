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
}
