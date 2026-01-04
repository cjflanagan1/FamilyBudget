import SwiftUI

struct LimitsSettingsView: View {
    @StateObject private var viewModel = LimitsSettingsViewModel()
    @ObservedObject private var debugManager = DebugManager.shared
    @State private var editingUser: User?

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                List {
                    Section {
                        Text("Set monthly spending limits for each family member. You'll receive alerts when spending reaches 90% of the limit.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Section("Spending Limits") {
                        ForEach(viewModel.users) { user in
                            LimitRow(
                                user: user,
                                anonymize: debugManager.anonymizeNames
                            ) {
                                editingUser = user
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color(.systemBackground))
            }
            .navigationTitle("Spending Limits")
            .refreshable {
                await viewModel.refresh()
            }
            .onAppear {
                viewModel.loadUsers()
            }
            .sheet(item: $editingUser) { user in
                EditLimitSheet(user: user) { newLimit in
                    viewModel.updateLimit(for: user.id, limit: newLimit)
                }
            }
        }
    }
}

struct LimitRow: View {
    let user: User
    let anonymize: Bool
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(anonymize ? "Person \(user.id)" : user.name)
                            .font(.headline)
                            .foregroundColor(.primary)

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

                    if let limit = user.monthlyLimit {
                        Text("Limit: \(limit.formatted(.currency(code: "USD")))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No limit set")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if let spent = user.currentSpend {
                        Text(spent.formatted(.currency(code: "USD")))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text("\(Int(user.percentUsed))% used")
                            .font(.caption)
                            .foregroundColor(user.isOverLimit ? .red : user.isWarning ? .orange : .green)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct EditLimitSheet: View {
    let user: User
    let onSave: (Double) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var limitAmount: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Current Status") {
                    HStack {
                        Text("Current Spending")
                        Spacer()
                        Text(user.currentSpend?.formatted(.currency(code: "USD")) ?? "$0")
                            .foregroundColor(.secondary)
                    }

                    if let limit = user.monthlyLimit {
                        HStack {
                            Text("Current Limit")
                            Spacer()
                            Text(limit.formatted(.currency(code: "USD")))
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Remaining")
                            Spacer()
                            Text(user.remaining.formatted(.currency(code: "USD")))
                                .foregroundColor(user.remaining < 0 ? .red : .green)
                        }
                    }
                }

                Section("New Monthly Limit") {
                    HStack {
                        Text("$")
                        TextField("Enter amount", text: $limitAmount)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    Text("You'll receive SMS alerts when \(user.name) reaches 90% of their monthly limit, and again when they exceed it.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Limit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let limit = Double(limitAmount) {
                            onSave(limit)
                        }
                        dismiss()
                    }
                    .disabled(limitAmount.isEmpty)
                }
            }
            .onAppear {
                limitAmount = user.monthlyLimit?.formatted() ?? ""
            }
        }
    }
}

class LimitsSettingsViewModel: ObservableObject {
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

    func updateLimit(for userId: Int, limit: Double) {
        Task {
            do {
                let _ = try await apiClient.updateSpendingLimit(userId: userId, monthlyLimit: limit)
                await refresh()
            } catch {
                print("Error updating limit: \(error)")
            }
        }
    }
}

#Preview {
    LimitsSettingsView()
}
