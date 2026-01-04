import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 4) {
                        Text("This Month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(viewModel.totalSpent.formatted(.currency(code: "USD")))
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("Family") {
                    ForEach(viewModel.spendingStatus) { status in
                        HStack {
                            Text(status.name)
                                .font(.subheadline)
                            Spacer()
                            Text(status.currentSpend.formatted(.currency(code: "USD")))
                                .font(.subheadline)
                            if let limit = status.monthlyLimit {
                                Text("/ \(Int(limit))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Top Merchants") {
                    ForEach(viewModel.topMerchants.prefix(5)) { merchant in
                        HStack {
                            Text(merchant.merchantName)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Text(merchant.total.formatted(.currency(code: "USD")))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Recent") {
                    ForEach(viewModel.recentTransactions.prefix(5)) { txn in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(txn.merchantDisplayName)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Text(txn.formattedDate)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(txn.formattedAmount)
                                .font(.subheadline)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Dashboard")
            .refreshable { await viewModel.refresh() }
            .onAppear { viewModel.loadData() }
        }
    }
}

class DashboardViewModel: ObservableObject {
    @Published var spendingStatus: [SpendingStatus] = []
    @Published var topMerchants: [TopMerchant] = []
    @Published var recentTransactions: [Transaction] = []
    @Published var totalSpent: Double = 0

    func loadData() { Task { await refresh() } }

    @MainActor
    func refresh() async {
        do {
            async let s = APIClient.shared.getSpendingStatus()
            async let m = APIClient.shared.getTopMerchants()
            async let t = APIClient.shared.getTransactions(limit: 10)
            let (status, merchants, txns) = try await (s, m, t)
            spendingStatus = status
            topMerchants = merchants
            recentTransactions = txns
            totalSpent = status.reduce(0) { $0 + $1.currentSpend }
        } catch { print("Error: \(error)") }
    }
}

#Preview { DashboardView() }
