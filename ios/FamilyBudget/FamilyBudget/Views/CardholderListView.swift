import SwiftUI

struct CardholderListView: View {
    @StateObject private var viewModel = CardholderViewModel()
    @ObservedObject private var debugManager = DebugManager.shared

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.users) { user in
                    NavigationLink {
                        CardholderDetailView(user: user)
                    } label: {
                        CardholderRow(user: user, anonymize: debugManager.anonymizeNames)
                    }
                }
            }
            .navigationTitle("Family")
            .refreshable {
                await viewModel.refresh()
            }
            .onAppear {
                viewModel.loadUsers()
            }
        }
    }
}

struct CardholderRow: View {
    let user: User
    let anonymize: Bool

    var body: some View {
        HStack {
            // Avatar
            ZStack {
                Circle()
                    .fill(user.role == .parent ? Color.blue : Color.purple)
                    .frame(width: 44, height: 44)

                Text(String((anonymize ? "P\(user.id)" : user.name).prefix(1)))
                    .font(.headline)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(anonymize ? "Person \(user.id)" : user.name)
                        .font(.headline)

                    if user.isOverLimit {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    } else if user.isWarning {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }

                Text(user.role == .parent ? "Parent" : "Child")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let spent = user.currentSpend {
                    Text(spent.formatted(.currency(code: "USD")))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                if let limit = user.monthlyLimit {
                    Text("of \(limit.formatted(.currency(code: "USD")))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CardholderDetailView: View {
    let user: User
    @StateObject private var viewModel = CardholderDetailViewModel()
    @ObservedObject private var debugManager = DebugManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Spending status card
                spendingStatusCard

                // Recent transactions
                recentTransactionsSection

                // Category breakdown
                categoryBreakdownSection
            }
            .padding()
        }
        .navigationTitle(debugManager.anonymizeNames ? "Person \(user.id)" : user.name)
        .onAppear {
            viewModel.loadData(for: user.id)
        }
    }

    private var spendingStatusCard: some View {
        VStack(spacing: 12) {
            // Circular progress
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: min(user.percentUsed / 100, 1))
                    .stroke(
                        user.isOverLimit ? Color.red :
                        user.isWarning ? Color.orange : Color.green,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack {
                    Text("\(Int(user.percentUsed))%")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Stats
            HStack(spacing: 30) {
                VStack {
                    Text(user.currentSpend?.formatted(.currency(code: "USD")) ?? "$0")
                        .font(.headline)
                    Text("Spent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text(user.remaining.formatted(.currency(code: "USD")))
                        .font(.headline)
                        .foregroundColor(user.remaining < 0 ? .red : .primary)
                    Text("Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text(user.monthlyLimit?.formatted(.currency(code: "USD")) ?? "No limit")
                        .font(.headline)
                    Text("Limit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Transactions")
                .font(.headline)

            if viewModel.transactions.isEmpty {
                Text("No transactions yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.transactions.prefix(10)) { transaction in
                    HStack {
                        VStack(alignment: .leading) {
                            HStack {
                                if transaction.isFoodDelivery {
                                    Text("🔴")
                                }
                                Text(transaction.merchantDisplayName)
                                    .lineLimit(1)
                            }
                            Text(transaction.formattedDate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(transaction.formattedAmount)
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Category")
                .font(.headline)

            if viewModel.categories.isEmpty {
                Text("No data yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.categories) { category in
                    HStack {
                        Text(category.category)
                        Spacer()
                        Text(category.total.formatted(.currency(code: "USD")))
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
}

// View Models
class CardholderViewModel: ObservableObject {
    @Published var users: [User] = []

    private let apiClient = APIClient.shared

    func loadUsers() {
        Task {
            await refresh()
        }
    }

    @MainActor
    func refresh() async {
        do {
            users = try await apiClient.getUsers()
        } catch {
            print("Error loading users: \(error)")
        }
    }
}

class CardholderDetailViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var categories: [CategorySpend] = []

    private let apiClient = APIClient.shared

    func loadData(for userId: Int) {
        Task {
            do {
                async let transactionsTask = apiClient.getTransactions(userId: userId, limit: 50)
                async let categoriesTask = apiClient.getCategoryBreakdown(userId: userId)

                let (txns, cats) = try await (transactionsTask, categoriesTask)

                await MainActor.run {
                    self.transactions = txns
                    self.categories = cats
                }
            } catch {
                print("Error loading user data: \(error)")
            }
        }
    }
}

#Preview {
    CardholderListView()
}
