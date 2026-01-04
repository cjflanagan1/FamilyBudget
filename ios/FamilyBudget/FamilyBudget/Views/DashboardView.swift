import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @ObservedObject private var debugManager = DebugManager.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Total spending card
                    totalSpendingCard

                    // Family spending breakdown
                    familySpendingSection

                    // Top merchants
                    topMerchantsSection

                    // Recent transactions
                    recentTransactionsSection
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await viewModel.refresh()
            }
            .onAppear {
                viewModel.loadData()
            }
        }
    }

    private var totalSpendingCard: some View {
        VStack(spacing: 12) {
            Text("This Month")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(viewModel.totalSpent.formatted(.currency(code: "USD")))
                .font(.system(size: 42, weight: .bold))

            if let change = viewModel.monthOverMonthChange {
                HStack {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text("\(abs(change), specifier: "%.1f")% vs last month")
                }
                .font(.caption)
                .foregroundColor(change >= 0 ? .red : .green)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private var familySpendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Family Spending")
                .font(.headline)

            ForEach(viewModel.spendingStatus) { status in
                SpendingStatusRow(status: status, anonymize: debugManager.anonymizeNames)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private var topMerchantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Merchants")
                .font(.headline)

            if viewModel.topMerchants.isEmpty {
                Text("No transactions yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.topMerchants.prefix(5)) { merchant in
                    HStack {
                        Text(merchant.merchantName)
                            .lineLimit(1)
                        Spacer()
                        Text(merchant.total.formatted(.currency(code: "USD")))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                Spacer()
                NavigationLink("See All") {
                    TransactionListView()
                }
                .font(.subheadline)
            }

            if viewModel.recentTransactions.isEmpty {
                Text("No transactions yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.recentTransactions.prefix(5)) { transaction in
                    TransactionRow(transaction: transaction, anonymize: debugManager.anonymizeNames)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}

struct SpendingStatusRow: View {
    let status: SpendingStatus
    let anonymize: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(anonymize ? "Person \(status.id)" : status.name)
                    .font(.subheadline)

                if status.isOver {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                } else if status.isWarning {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                }

                Spacer()

                Text(status.currentSpend.formatted(.currency(code: "USD")))
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let limit = status.monthlyLimit {
                    Text("/ \(limit.formatted(.currency(code: "USD")))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if status.monthlyLimit != nil {
                ProgressView(value: min(status.percentUsed, 100), total: 100)
                    .tint(status.isOver ? .red : status.isWarning ? .orange : .green)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    let anonymize: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if transaction.isFoodDelivery {
                        Text("🔴")
                    }
                    Text(transaction.merchantDisplayName)
                        .lineLimit(1)
                }
                .font(.subheadline)

                Text(anonymize ? "Person" : (transaction.cardholderName ?? "Unknown"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(transaction.formattedAmount)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(transaction.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// View Model
class DashboardViewModel: ObservableObject {
    @Published var spendingStatus: [SpendingStatus] = []
    @Published var topMerchants: [TopMerchant] = []
    @Published var recentTransactions: [Transaction] = []
    @Published var totalSpent: Double = 0
    @Published var monthOverMonthChange: Double?
    @Published var isLoading = false

    private let apiClient = APIClient.shared

    func loadData() {
        Task {
            await refresh()
        }
    }

    @MainActor
    func refresh() async {
        isLoading = true

        do {
            async let statusTask = apiClient.getSpendingStatus()
            async let merchantsTask = apiClient.getTopMerchants()
            async let transactionsTask = apiClient.getTransactions(limit: 10)

            let (status, merchants, transactions) = try await (statusTask, merchantsTask, transactionsTask)

            self.spendingStatus = status
            self.topMerchants = merchants
            self.recentTransactions = transactions
            self.totalSpent = status.reduce(0) { $0 + $1.currentSpend }

        } catch {
            print("Error loading dashboard: \(error)")
        }

        isLoading = false
    }
}

#Preview {
    DashboardView()
}
