import Foundation
import SwiftUI

class DebugManager: ObservableObject {
    static let shared = DebugManager()

    // Debug mode state
    @Published var isDebugMode: Bool {
        didSet {
            UserDefaults.standard.set(isDebugMode, forKey: "debug_mode_enabled")
        }
    }

    // Debug settings
    @Published var anonymizeNames: Bool {
        didSet {
            UserDefaults.standard.set(anonymizeNames, forKey: "debug_anonymize_names")
        }
    }

    @Published var showRawResponses: Bool {
        didSet {
            UserDefaults.standard.set(showRawResponses, forKey: "debug_show_raw")
        }
    }

    @Published var plaidEnvironment: PlaidEnvironment {
        didSet {
            UserDefaults.standard.set(plaidEnvironment.rawValue, forKey: "debug_plaid_env")
        }
    }

    @Published var apiLogs: [APILog] = []

    // API configuration
    var apiBaseURL: String {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "debug_api_url") ?? "https://familybudget-production-98f3.up.railway.app"
        #else
        return "https://familybudget-production-98f3.up.railway.app"
        #endif
    }

    enum PlaidEnvironment: String, CaseIterable {
        case sandbox = "sandbox"
        case development = "development"
        case production = "production"
    }

    private init() {
        self.isDebugMode = UserDefaults.standard.bool(forKey: "debug_mode_enabled")
        self.anonymizeNames = UserDefaults.standard.bool(forKey: "debug_anonymize_names")
        self.showRawResponses = UserDefaults.standard.bool(forKey: "debug_show_raw")

        let envString = UserDefaults.standard.string(forKey: "debug_plaid_env") ?? "sandbox"
        self.plaidEnvironment = PlaidEnvironment(rawValue: envString) ?? .sandbox
    }

    // Log API calls
    func logAPICall(endpoint: String, method: String, status: Int, response: String?) {
        let log = APILog(
            timestamp: Date(),
            endpoint: endpoint,
            method: method,
            statusCode: status,
            response: response
        )

        DispatchQueue.main.async {
            self.apiLogs.insert(log, at: 0)
            // Keep only last 50 logs
            if self.apiLogs.count > 50 {
                self.apiLogs = Array(self.apiLogs.prefix(50))
            }
        }
    }

    // Clear all logs
    func clearLogs() {
        apiLogs.removeAll()
    }

    // Clear local cache
    func clearCache() {
        // Clear URLCache
        URLCache.shared.removeAllCachedResponses()

        // Clear UserDefaults (except debug settings)
        let defaults = UserDefaults.standard
        let debugKeys = ["debug_mode_enabled", "debug_anonymize_names", "debug_show_raw", "debug_plaid_env", "debug_api_url"]
        let dictionary = defaults.dictionaryRepresentation()
        for key in dictionary.keys {
            if !debugKeys.contains(key) {
                defaults.removeObject(forKey: key)
            }
        }

        print("Cache cleared")
    }

    // Force trigger test notification (for debugging)
    func triggerTestNotification() {
        // This would call the backend to send a test SMS
        print("Test notification triggered")
    }

    // Export logs
    func exportLogs() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(apiLogs),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "Failed to export logs"
    }

    // Set custom API URL
    func setAPIURL(_ url: String) {
        UserDefaults.standard.set(url, forKey: "debug_api_url")
    }

    // Get display name (respects anonymization)
    func displayName(for name: String, id: Int) -> String {
        if anonymizeNames {
            return "Person \(id)"
        }
        return name
    }
}

struct APILog: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let endpoint: String
    let method: String
    let statusCode: Int
    let response: String?

    init(id: UUID = UUID(), timestamp: Date, endpoint: String, method: String, statusCode: Int, response: String?) {
        self.id = id
        self.timestamp = timestamp
        self.endpoint = endpoint
        self.method = method
        self.statusCode = statusCode
        self.response = response
    }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }

    var isSuccess: Bool {
        (200...299).contains(statusCode)
    }

    enum CodingKeys: String, CodingKey {
        case timestamp, endpoint, method, statusCode, response
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(endpoint, forKey: .endpoint)
        try container.encode(method, forKey: .method)
        try container.encode(statusCode, forKey: .statusCode)
        try container.encode(response, forKey: .response)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.endpoint = try container.decode(String.self, forKey: .endpoint)
        self.method = try container.decode(String.self, forKey: .method)
        self.statusCode = try container.decode(Int.self, forKey: .statusCode)
        self.response = try container.decode(String?.self, forKey: .response)
    }
}
