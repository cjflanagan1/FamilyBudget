import SwiftUI

struct TransactionListView: View {
    @StateObject private var viewModel = TransactionListViewModel()
    @State private var searchText = ""

    var filteredTransactions: [Transaction] {
        searchText.isEmpty ? viewModel.transactions :
            viewModel.transactions.filter { $0.merchantDisplayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.transactions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "creditcard")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No transactions yet")
                            .font(.headline)
                        Text("Link a card to start tracking spending")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredTransactions) { txn in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(txn.isFoodDelivery ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "creditcard")
                                            .font(.caption)
                                            .foregroundStyle(txn.isFoodDelivery ? .red : .blue)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
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
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Transactions")
            .searchable(text: $searchText, prompt: "Search")
            .refreshable { await viewModel.refresh() }
            .onAppear { viewModel.loadTransactions() }
        }
    }
}

class TransactionListViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []

    func loadTransactions() { Task { await refresh() } }

    @MainActor
    func refresh() async {
        do { transactions = try await APIClient.shared.getTransactions(limit: 200) }
        catch { print("Error: \(error)") }
    }
}

#Preview { TransactionListView() }
