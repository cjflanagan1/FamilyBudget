import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        if let balance = viewModel.cardBalances.first {
                            HStack {
                                VStack {
                                    Text("Balance")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(balance.currentBalance.formatted(.currency(code: "USD")))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                }
                                Spacer()
                                VStack {
                                    Text("Payment Due")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text((balance.paymentDue ?? 0).formatted(.currency(code: "USD")))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(balance.paymentDue != nil ? .red : .secondary)
                                }
                            }
                            Text("\(balance.nickname) •••\(balance.lastFour)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        Text("Spent This Month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(viewModel.totalSpent.formatted(.currency(code: "USD")))
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("Family") {
                    ForEach(viewModel.spendingStatus) { status in
                        HStack {
                            Text(status.name)
                            Spacer()
                            Text(status.currentSpend.formatted(.currency(code: "USD")))
                            if let limit = status.monthlyLimit {
                                Text("/ \(Int(limit))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Top Merchants") {
                    ForEach(viewModel.topMerchants.prefix(5)) { merchant in
                        HStack {
                            Text(merchant.merchantName)
                            Spacer()
                            Text(merchant.total.formatted(.currency(code: "USD")))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Recent") {
                    ForEach(viewModel.recentTransactions.prefix(5)) { txn in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(txn.merchantDisplayName)
                                Text(txn.formattedDate)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(txn.formattedAmount)
                        }
                    }
                }
            }
            .navigationTitle("Dashboard")
            .refreshable { await viewModel.refresh() }
            .task { await viewModel.refresh() }
        }
    }
}

class DashboardViewModel: ObservableObject {
    @Published var spendingStatus: [SpendingStatus] = []
    @Published var topMerchants: [TopMerchant] = []
    @Published var recentTransactions: [Transaction] = []
    @Published var cardBalances: [CardBalance] = []
    @Published var totalSpent: Double = 0

    @MainActor
    func refresh() async {
        do {
            let balances = try await APIClient.shared.getCardBalances()
            cardBalances = balances

            let status = try await APIClient.shared.getSpendingStatus()
            spendingStatus = status
            totalSpent = status.reduce(0) { $0 + $1.currentSpend }

            let merchants = try await APIClient.shared.getTopMerchants()
            topMerchants = merchants

            let txns = try await APIClient.shared.getTransactions(limit: 10)
            recentTransactions = txns
        } catch {
            print("Dashboard Error: \(error)")
        }
    }
}

#Preview { DashboardView() }
