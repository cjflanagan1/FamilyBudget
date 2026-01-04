import Foundation

class DashboardViewModel: ObservableObject {
    @Published var spendingStatus: [SpendingStatus] = []
    @Published var totalSpent: Double = 0
    @Published var topMerchants: [MerchantSpending] = []
    @Published var recentTransactions: [Transaction] = []
    @Published var monthOverMonthChange: Double? = nil
    @Published var isLoading = false
    @Published var error: String?

    private let apiClient = APIClient.shared

    func loadData() {
        Task {
            await MainActor.run {
                isLoading = true
                error = nil
            }

            do {
                // Fetch spending status for all family members
                let statusData = try await fetchSpendingStatus()

                // Fetch all transactions
                let transactions = try await apiClient.getTransactions()

                // Calculate metrics
                let totalSpent = statusData.reduce(0) { $0 + $1.current_spend }
                let merchants = calculateTopMerchants(from: transactions)

                await MainActor.run {
                    self.spendingStatus = statusData
                    self.totalSpent = totalSpent
                    self.topMerchants = merchants
                    self.recentTransactions = Array(transactions.sorted { $0.date > $1.date }.prefix(5))
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func fetchSpendingStatus() async throws -> [SpendingStatus] {
        let url = URL(string: "http://localhost:3000/api/limits/status/all")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        return try decoder.decode([SpendingStatus].self, from: data)
    }

    func refresh() async {
        loadData()
    }

    private func calculateTopMerchants(from transactions: [Transaction]) -> [MerchantSpending] {
        var merchantMap: [String: Double] = [:]

        for transaction in transactions {
            merchantMap[transaction.merchant_name, default: 0] += transaction.amount
        }

        return merchantMap
            .map { MerchantSpending(merchantName: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
    }
}

struct SpendingStatus: Identifiable, Codable {
    let id: Int
    let name: String
    let role: String
    let monthly_limit: Double
    let current_spend: Double
    let percent_used: Double
    let remaining: Double
    let is_warning: Bool
    let is_over: Bool

    var isWarning: Bool { is_warning }
    var isOver: Bool { is_over }
}

struct MerchantSpending: Identifiable {
    let id = UUID()
    let merchantName: String
    let total: Double
}
