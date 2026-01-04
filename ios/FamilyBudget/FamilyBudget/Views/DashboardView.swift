import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @ObservedObject private var debugManager = DebugManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Total spending card
                totalSpendingCard

                // Family spending breakdown
                familySpendingSection

                // Top merchants
                topMerchantsSection

                // Recent transactions
                recentTransactionsSection
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .onAppear {
            viewModel.loadData()
        }
    }

    private var totalSpendingCard: some View {
        VStack(spacing: 6) {
            Text("This Month")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(viewModel.totalSpent.formatted(.currency(code: "USD")))
                .font(.system(size: 28, weight: .bold))

            if let change = viewModel.monthOverMonthChange {
                HStack(spacing: 3) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text("\(abs(change), specifier: "%.1f")% vs last month")
                        .font(.caption2)
                }
                .foregroundColor(change >= 0 ? .red : .green)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 0.5)
    }

    private var familySpendingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Family")
                .font(.caption)
                .fontWeight(.semibold)

            ForEach(viewModel.spendingStatus) { status in
                SpendingStatusRow(status: status, anonymize: debugManager.anonymizeNames)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 0.5)
    }

    private var topMerchantsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Top Merchants")
                .font(.caption)
                .fontWeight(.semibold)

            if viewModel.topMerchants.isEmpty {
                Text("No transactions")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.topMerchants.prefix(2)) { merchant in
                    HStack(spacing: 6) {
                        Text(merchant.merchantName)
                            .font(.caption2)
                            .lineLimit(1)
                        Spacer()
                        Text(merchant.total.formatted(.currency(code: "USD")))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 0.5)
    }

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recent")
                .font(.caption)
                .fontWeight(.semibold)

            if viewModel.recentTransactions.isEmpty {
                Text("No transactions")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.recentTransactions.prefix(2)) { transaction in
                    TransactionRow(transaction: transaction, anonymize: debugManager.anonymizeNames)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 0.5)
    }
}

struct SpendingStatusRow: View {
    let status: SpendingStatus
    let anonymize: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(anonymize ? "P\(status.id)" : status.name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .frame(width: 40, alignment: .leading)

                if status.isOver {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.red)
                } else if status.isWarning {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                }

                Spacer()

                HStack(spacing: 2) {
                    Text(status.currentSpend.formatted(.currency(code: "USD")))
                        .font(.caption2)
                        .fontWeight(.medium)

                    if let limit = status.monthlyLimit {
                        Text("/\(Int(limit))")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }

            if status.monthlyLimit != nil {
                ProgressView(value: min(status.percentUsed, 100), total: 100)
                    .scaleEffect(y: 0.6, anchor: .center)
                    .tint(status.isOver ? .red : status.isWarning ? .orange : .green)
            }
        }
        .padding(.vertical, 1)
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    let anonymize: Bool

    var body: some View {
        HStack(spacing: 6) {
            if transaction.isFoodDelivery {
                Text("🔴")
                    .font(.caption2)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(transaction.merchantDisplayName)
                    .font(.caption2)
                    .lineLimit(1)

                Text(transaction.formattedDate)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(transaction.formattedAmount)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.vertical, 1)
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
