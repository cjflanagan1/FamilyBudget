import SwiftUI

struct CardholderListView: View {
    @StateObject private var viewModel = CardholderViewModel()

    var body: some View {
        NavigationStack {
            List(viewModel.users) { user in
                NavigationLink {
                    CardholderDetailView(user: user)
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(user.role == .parent ? Color.blue : Color.purple)
                            .frame(width: 36, height: 36)
                            .overlay(Text(String(user.name.prefix(1))).font(.caption).foregroundStyle(.white))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.name).font(.subheadline)
                            Text(user.role == .parent ? "Parent" : "Child")
                                .font(.caption).foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let spent = user.currentSpend {
                            Text(spent.formatted(.currency(code: "USD")))
                                .font(.subheadline)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Family")
            .refreshable { await viewModel.refresh() }
            .onAppear { viewModel.loadUsers() }
        }
    }
}

struct CardholderDetailView: View {
    let user: User
    @StateObject private var viewModel = CardholderDetailViewModel()

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Text("\(Int(user.percentUsed))%")
                        .font(.largeTitle).fontWeight(.bold)
                    ProgressView(value: min(user.percentUsed, 100), total: 100)
                        .tint(user.isOverLimit ? .red : user.isWarning ? .orange : .green)
                    HStack {
                        Text("Spent: \(user.currentSpend?.formatted(.currency(code: "USD")) ?? "$0")")
                        Spacer()
                        Text("Limit: \(user.monthlyLimit?.formatted(.currency(code: "USD")) ?? "None")")
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section("Recent Transactions") {
                ForEach(viewModel.transactions.prefix(10)) { txn in
                    HStack {
                        Text(txn.merchantDisplayName).font(.subheadline).lineLimit(1)
                        Spacer()
                        Text(txn.formattedAmount).font(.subheadline)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(user.name)
        .onAppear { viewModel.loadData(for: user.id) }
    }
}

class CardholderViewModel: ObservableObject {
    @Published var users: [User] = []
    func loadUsers() { Task { await refresh() } }
    @MainActor func refresh() async {
        do { users = try await APIClient.shared.getUsers() }
        catch { print("Error: \(error)") }
    }
}

class CardholderDetailViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    func loadData(for userId: Int) {
        Task {
            do {
                let txns = try await APIClient.shared.getTransactions(userId: userId, limit: 50)
                await MainActor.run { transactions = txns }
            } catch { print("Error: \(error)") }
        }
    }
}

#Preview { CardholderListView() }
