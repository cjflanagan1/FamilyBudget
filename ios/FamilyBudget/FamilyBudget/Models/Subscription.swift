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
}
