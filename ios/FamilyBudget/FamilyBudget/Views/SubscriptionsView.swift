import SwiftUI

struct SubscriptionsView: View {
    @StateObject private var viewModel = SubscriptionsViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Monthly").font(.caption).foregroundStyle(.secondary)
                            Text(viewModel.monthlyTotal.formatted(.currency(code: "USD")))
                                .font(.title3).fontWeight(.bold)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Count").font(.caption).foregroundStyle(.secondary)
                            Text("\(viewModel.subscriptions.count)")
                                .font(.title3).fontWeight(.bold)
                        }
                    }
                }

                Section("Subscriptions") {
                    ForEach(viewModel.subscriptions) { sub in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sub.merchantName).font(.subheadline)
                                Text(sub.billingCycle.rawValue.capitalized)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(sub.formattedAmount).font(.subheadline)
                        }
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            viewModel.deleteSubscription(viewModel.subscriptions[i])
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Subscriptions")
            .refreshable { await viewModel.refresh() }
            .onAppear { viewModel.loadData() }
        }
    }
}

class SubscriptionsViewModel: ObservableObject {
    @Published var subscriptions: [Subscription] = []
    @Published var monthlyTotal: Double = 0

    func loadData() { Task { await refresh() } }

    @MainActor func refresh() async {
        do {
            subscriptions = try await APIClient.shared.getSubscriptions()
            monthlyTotal = try await APIClient.shared.getSubscriptionTotal().monthlyTotal ?? 0
        } catch { print("Error: \(error)") }
    }

    func deleteSubscription(_ sub: Subscription) {
        Task {
            try? await APIClient.shared.deleteSubscription(id: sub.id)
            await refresh()
        }
    }
}

#Preview { SubscriptionsView() }
