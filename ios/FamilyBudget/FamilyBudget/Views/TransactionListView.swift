import SwiftUI

struct TransactionListView: View {
    @StateObject private var viewModel = TransactionListViewModel()
    @ObservedObject private var debugManager = DebugManager.shared
    @State private var searchText = ""
    @State private var selectedFilter: TransactionFilter = .all

    enum TransactionFilter: String, CaseIterable {
        case all = "All"
        case foodDelivery = "Food Delivery"
        case recurring = "Recurring"
    }

    var filteredTransactions: [Transaction] {
        var result = viewModel.transactions

        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .foodDelivery:
            result = result.filter { $0.isFoodDelivery }
        case .recurring:
            result = result.filter { $0.isRecurring }
        }

        // Apply search
        if !searchText.isEmpty {
            result = result.filter {
                $0.merchantDisplayName.localizedCaseInsensitiveContains(searchText) ||
                ($0.cardholderName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(TransactionFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Transaction list
                List {
                    ForEach(groupedTransactions.keys.sorted().reversed(), id: \.self) { date in
                        Section(header: Text(formatSectionDate(date))) {
                            ForEach(groupedTransactions[date] ?? []) { transaction in
                                TransactionDetailRow(
                                    transaction: transaction,
                                    anonymize: debugManager.anonymizeNames
                                )
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Transactions")
            .searchable(text: $searchText, prompt: "Search transactions")
            .refreshable {
                await viewModel.refresh()
            }
            .onAppear {
                viewModel.loadTransactions()
            }
        }
    }

    private var groupedTransactions: [Date: [Transaction]] {
        let calendar = Calendar.current
        return Dictionary(grouping: filteredTransactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
    }

    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

struct TransactionDetailRow: View {
    let transaction: Transaction
    let anonymize: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(transaction.isFoodDelivery ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: iconForCategory(transaction.category))
                    .foregroundColor(transaction.isFoodDelivery ? .red : .blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if transaction.isFoodDelivery {
                        Text("🔴")
                            .font(.caption)
                    }
                    Text(transaction.merchantDisplayName)
                        .font(.subheadline)
                        .lineLimit(1)
                }

                HStack {
                    Text(anonymize ? "Person" : (transaction.cardholderName ?? "Unknown"))
                    if let lastFour = transaction.lastFour {
                        Text("•••• \(lastFour)")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(transaction.formattedAmount)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if let category = transaction.category {
                    Text(category)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func iconForCategory(_ category: String?) -> String {
        guard let category = category?.lowercased() else { return "creditcard" }

        if category.contains("food") || category.contains("restaurant") || category.contains("dining") {
            return "fork.knife"
        } else if category.contains("shop") || category.contains("retail") {
            return "bag"
        } else if category.contains("gas") || category.contains("fuel") {
            return "fuelpump"
        } else if category.contains("grocery") {
            return "cart"
        } else if category.contains("entertainment") {
            return "tv"
        } else if category.contains("travel") || category.contains("transport") {
            return "car"
        } else if category.contains("subscription") {
            return "repeat"
        }

        return "creditcard"
    }
}

class TransactionListViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false

    private let apiClient = APIClient.shared

    func loadTransactions() {
        Task {
            await refresh()
        }
    }

    @MainActor
    func refresh() async {
        isLoading = true
        do {
            transactions = try await apiClient.getTransactions(limit: 200)
        } catch {
            print("Error loading transactions: \(error)")
        }
        isLoading = false
    }
}

#Preview {
    TransactionListView()
}
