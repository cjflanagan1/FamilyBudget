import Foundation

class APIClient {
    static let shared = APIClient()

    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        // Use debug manager for base URL
        self.baseURL = DebugManager.shared.apiBaseURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try multiple date formats
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                "yyyy-MM-dd'T'HH:mm:ssZ",
                "yyyy-MM-dd"
            ]

            for format in formats {
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "en_US_POSIX")
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
    }

    // MARK: - Users

    func getUsers() async throws -> [User] {
        return try await request(endpoint: "/api/users")
    }

    func getUser(id: Int) async throws -> User {
        return try await request(endpoint: "/api/users/\(id)")
    }

    func updateUserPhone(id: Int, phone: String) async throws -> User {
        return try await request(endpoint: "/api/users/\(id)/phone", method: "PATCH", body: ["phone_number": phone])
    }

    func updateNotificationSettings(id: Int, alertMode: String?, threshold: Double?) async throws {
        var body: [String: Any] = [:]
        if let mode = alertMode { body["alert_mode"] = mode }
        if let thresh = threshold { body["threshold_amount"] = thresh }

        let _: User = try await request(endpoint: "/api/users/\(id)/notifications", method: "PATCH", body: body)
    }

    // MARK: - Transactions

    func getTransactions(userId: Int? = nil, limit: Int = 100) async throws -> [Transaction] {
        var endpoint = "/api/transactions?limit=\(limit)"
        if let userId = userId {
            endpoint += "&userId=\(userId)"
        }
        return try await request(endpoint: endpoint)
    }

    func getSpendingSummary() async throws -> [SpendingSummary] {
        return try await request(endpoint: "/api/transactions/summary")
    }

    func getCategoryBreakdown(userId: Int? = nil) async throws -> [CategorySpend] {
        var endpoint = "/api/transactions/by-category"
        if let userId = userId {
            endpoint += "?userId=\(userId)"
        }
        return try await request(endpoint: endpoint)
    }

    func getTopMerchants(userId: Int? = nil, limit: Int = 10) async throws -> [TopMerchant] {
        var endpoint = "/api/transactions/top-merchants?limit=\(limit)"
        if let userId = userId {
            endpoint += "&userId=\(userId)"
        }
        return try await request(endpoint: endpoint)
    }

    // MARK: - Spending Limits

    func getSpendingLimits() async throws -> [SpendingLimit] {
        return try await request(endpoint: "/api/limits")
    }

    func getSpendingLimit(userId: Int) async throws -> SpendingLimit {
        return try await request(endpoint: "/api/limits/\(userId)")
    }

    func updateSpendingLimit(userId: Int, monthlyLimit: Double) async throws -> SpendingLimit {
        return try await request(endpoint: "/api/limits/\(userId)", method: "PUT", body: ["monthly_limit": monthlyLimit])
    }

    func getSpendingStatus() async throws -> [SpendingStatus] {
        return try await request(endpoint: "/api/limits/status/all")
    }

    func getCardBalances() async throws -> [CardBalance] {
        return try await request(endpoint: "/api/plaid/balances")
    }

    // MARK: - Subscriptions

    func getSubscriptions(userId: Int? = nil, activeOnly: Bool = true) async throws -> [Subscription] {
        var endpoint = "/api/subscriptions?active_only=\(activeOnly)"
        if let userId = userId {
            endpoint += "&userId=\(userId)"
        }
        return try await request(endpoint: endpoint)
    }

    func getUpcomingRenewals(days: Int = 7) async throws -> [Subscription] {
        return try await request(endpoint: "/api/subscriptions/upcoming?days=\(days)")
    }

    func addSubscription(_ subscription: [String: Any]) async throws -> Subscription {
        return try await request(endpoint: "/api/subscriptions", method: "POST", body: subscription)
    }

    func updateSubscription(id: Int, updates: [String: Any]) async throws -> Subscription {
        return try await request(endpoint: "/api/subscriptions/\(id)", method: "PUT", body: updates)
    }

    func deleteSubscription(id: Int) async throws {
        let _: [String: Bool] = try await request(endpoint: "/api/subscriptions/\(id)", method: "DELETE")
    }

    func getSubscriptionTotal(userId: Int? = nil) async throws -> SubscriptionTotal {
        var endpoint = "/api/subscriptions/total"
        if let userId = userId {
            endpoint += "?userId=\(userId)"
        }
        return try await request(endpoint: endpoint)
    }

    // MARK: - Plaid

    func createLinkToken(userId: Int) async throws -> LinkTokenResponse {
        return try await request(endpoint: "/api/plaid/create-link-token", method: "POST", body: ["userId": userId])
    }

    func exchangePublicToken(publicToken: String, userId: Int) async throws -> ExchangeTokenResponse {
        return try await request(endpoint: "/api/plaid/exchange-token", method: "POST", body: ["publicToken": publicToken, "userId": userId])
    }

    func getLinkedCards(userId: Int) async throws -> [LinkedCard] {
        return try await request(endpoint: "/api/plaid/cards/\(userId)")
    }

    func getAllLinkedCards() async throws -> [LinkedCard] {
        return try await request(endpoint: "/api/plaid/cards")
    }

    // MARK: - Push Notifications

    func registerDeviceToken(token: String, userId: Int) async throws {
        let _: [String: Bool] = try await request(
            endpoint: "/api/notifications/register-device",
            method: "POST",
            body: ["device_token": token, "user_id": userId, "platform": "ios"]
        )
    }

    // MARK: - Private

    private func request<T: Decodable>(endpoint: String, method: String = "GET", body: [String: Any]? = nil) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        // Log request in debug mode
        if DebugManager.shared.isDebugMode {
            print("API Request: \(method) \(endpoint)")
            if let body = body {
                print("Body: \(body)")
            }
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Log response in debug mode
        if DebugManager.shared.isDebugMode {
            print("API Response: \(httpResponse.statusCode)")
            if let json = String(data: data, encoding: .utf8) {
                print("Data: \(json.prefix(500))")
            }
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }

        return try decoder.decode(T.self, from: data)
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Response Types

struct LinkTokenResponse: Codable {
    let link_token: String?
    let expiration: String?
}

struct ExchangeTokenResponse: Codable {
    let access_token: String?
    let item_id: String?
}

struct LinkedCard: Codable, Identifiable {
    let id: Int
    let mask: String
    let name: String
    let userId: Int?
    let userName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case mask = "last_four"
        case name = "nickname"
        case userId = "user_id"
        case userName = "user_name"
    }
}
