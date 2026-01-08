import Foundation

struct Subscription: Codable, Identifiable {
    let id: Int
    let userId: Int
    let merchantName: String
    let amount: Double
    let billingCycle: BillingCycle
    let nextRenewalDate: Date?
    let isActive: Bool
    let createdAt: Date?

    // Joined field
    var cardholderName: String?

    enum BillingCycle: String, Codable {
        case monthly
        case yearly
        case weekly
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case merchantName = "merchant_name"
        case amount
        case billingCycle = "billing_cycle"
        case nextRenewalDate = "next_renewal_date"
        case isActive = "is_active"
        case createdAt = "created_at"
        case cardholderName = "cardholder_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        userId = try container.decode(Int.self, forKey: .userId)
        merchantName = try container.decode(String.self, forKey: .merchantName)
        billingCycle = try container.decode(BillingCycle.self, forKey: .billingCycle)
        nextRenewalDate = try container.decodeIfPresent(Date.self, forKey: .nextRenewalDate)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        cardholderName = try container.decodeIfPresent(String.self, forKey: .cardholderName)

        // Handle amount as either String or Double
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

    var formattedRenewalDate: String {
        guard let date = nextRenewalDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var daysUntilRenewal: Int? {
        guard let date = nextRenewalDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: date)
        return components.day
    }

    var isRenewingSoon: Bool {
        guard let days = daysUntilRenewal else { return false }
        return days <= 7 && days >= 0
    }

    var monthlyEquivalent: Double {
        switch billingCycle {
        case .monthly:
            return amount
        case .yearly:
            return amount / 12
        case .weekly:
            return amount * 4.33
        }
    }
}

// Subscription totals
struct SubscriptionTotal: Codable {
    let monthlyTotal: Double?
    let subscriptionCount: Int

    enum CodingKeys: String, CodingKey {
        case monthlyTotal = "monthly_total"
        case subscriptionCount = "subscription_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle subscription_count as either String or Int
        if let val = try? container.decode(Int.self, forKey: .subscriptionCount) {
            subscriptionCount = val
        } else if let str = try? container.decode(String.self, forKey: .subscriptionCount) {
            subscriptionCount = Int(str) ?? 0
        } else {
            subscriptionCount = 0
        }

        // Handle monthly_total as either String or Double
        if let val = try? container.decodeIfPresent(Double.self, forKey: .monthlyTotal) {
            monthlyTotal = val
        } else if let str = try? container.decodeIfPresent(String.self, forKey: .monthlyTotal) {
            monthlyTotal = Double(str)
        } else {
            monthlyTotal = nil
        }
    }
}
