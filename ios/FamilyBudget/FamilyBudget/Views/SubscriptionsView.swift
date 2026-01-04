import SwiftUI

struct SubscriptionsView: View {
    @StateObject private var viewModel = SubscriptionsViewModel()
    @ObservedObject private var debugManager = DebugManager.shared
    @State private var showingAddSheet = false

    var body: some View {
        NavigationView {
            List {
                // Summary section
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Monthly Total")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(viewModel.monthlyTotal.formatted(.currency(code: "USD")))
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Subscriptions")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(viewModel.subscriptions.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Upcoming renewals
                if !viewModel.upcomingRenewals.isEmpty {
                    Section("Renewing Soon") {
                        ForEach(viewModel.upcomingRenewals) { subscription in
                            SubscriptionRow(
                                subscription: subscription,
                                anonymize: debugManager.anonymizeNames,
                                showRenewalBadge: true
                            )
                        }
                    }
                }

                // All subscriptions
                Section("All Subscriptions") {
                    ForEach(viewModel.subscriptions) { subscription in
                        SubscriptionRow(
                            subscription: subscription,
                            anonymize: debugManager.anonymizeNames,
                            showRenewalBadge: false
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.deleteSubscription(subscription)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Subscriptions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddSubscriptionView { subscription in
                    viewModel.addSubscription(subscription)
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .onAppear {
                viewModel.loadData()
            }
        }
    }
}

struct SubscriptionRow: View {
    let subscription: Subscription
    let anonymize: Bool
    let showRenewalBadge: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.merchantName)
                    .font(.headline)

                HStack {
                    Text(anonymize ? "Person" : (subscription.cardholderName ?? "Unknown"))
                    Text("•")
                    Text(subscription.billingCycle.rawValue.capitalized)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(subscription.formattedAmount)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if showRenewalBadge, let days = subscription.daysUntilRenewal {
                    Text(days == 0 ? "Today" : "in \(days) days")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                } else {
                    Text(subscription.formattedRenewalDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddSubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    let onAdd: ([String: Any]) -> Void

    @State private var merchantName = ""
    @State private var amount = ""
    @State private var billingCycle = "monthly"
    @State private var nextRenewalDate = Date()
    @State private var selectedUserId = 1

    @StateObject private var viewModel = AddSubscriptionViewModel()

    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Service Name", text: $merchantName)

                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)

                    Picker("Billing Cycle", selection: $billingCycle) {
                        Text("Monthly").tag("monthly")
                        Text("Yearly").tag("yearly")
                        Text("Weekly").tag("weekly")
                    }

                    DatePicker("Next Renewal", selection: $nextRenewalDate, displayedComponents: .date)
                }

                Section("Card Holder") {
                    Picker("Who pays for this?", selection: $selectedUserId) {
                        ForEach(viewModel.users) { user in
                            Text(user.name).tag(user.id)
                        }
                    }
                }
            }
            .navigationTitle("Add Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"

                        let subscription: [String: Any] = [
                            "user_id": selectedUserId,
                            "merchant_name": merchantName,
                            "amount": Double(amount) ?? 0,
                            "billing_cycle": billingCycle,
                            "next_renewal_date": formatter.string(from: nextRenewalDate)
                        ]
                        onAdd(subscription)
                        dismiss()
                    }
                    .disabled(merchantName.isEmpty || amount.isEmpty)
                }
            }
            .onAppear {
                viewModel.loadUsers()
            }
        }
    }
}

// View Models
class SubscriptionsViewModel: ObservableObject {
    @Published var subscriptions: [Subscription] = []
    @Published var upcomingRenewals: [Subscription] = []
    @Published var monthlyTotal: Double = 0

    private let apiClient = APIClient.shared

    func loadData() {
        Task {
            await refresh()
        }
    }

    @MainActor
    func refresh() async {
        do {
            async let subsTask = apiClient.getSubscriptions()
            async let upcomingTask = apiClient.getUpcomingRenewals(days: 7)
            async let totalTask = apiClient.getSubscriptionTotal()

            let (subs, upcoming, total) = try await (subsTask, upcomingTask, totalTask)

            subscriptions = subs
            upcomingRenewals = upcoming
            monthlyTotal = total.monthlyTotal ?? 0
        } catch {
            print("Error loading subscriptions: \(error)")
        }
    }

    func addSubscription(_ data: [String: Any]) {
        Task {
            do {
                let _ = try await apiClient.addSubscription(data)
                await refresh()
            } catch {
                print("Error adding subscription: \(error)")
            }
        }
    }

    func deleteSubscription(_ subscription: Subscription) {
        Task {
            do {
                try await apiClient.deleteSubscription(id: subscription.id)
                await refresh()
            } catch {
                print("Error deleting subscription: \(error)")
            }
        }
    }
}

class AddSubscriptionViewModel: ObservableObject {
    @Published var users: [User] = []

    private let apiClient = APIClient.shared

    func loadUsers() {
        Task {
            do {
                let fetchedUsers = try await apiClient.getUsers()
                await MainActor.run {
                    self.users = fetchedUsers
                }
            } catch {
                print("Error loading users: \(error)")
            }
        }
    }
}

#Preview {
    SubscriptionsView()
}
