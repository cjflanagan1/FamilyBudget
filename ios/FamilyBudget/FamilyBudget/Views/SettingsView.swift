import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var debugManager = DebugManager.shared

    @State private var versionTapCount = 0
    @State private var showDeveloperMode = false

    var body: some View {
        NavigationView {
            List {
                // Family members section
                Section("Family Members") {
                    ForEach(viewModel.users) { user in
                        NavigationLink {
                            UserSettingsView(user: user)
                        } label: {
                            HStack {
                                Text(debugManager.anonymizeNames ? "Person \(user.id)" : user.name)
                                Spacer()
                                if user.role == .parent {
                                    Text("Parent")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                // Notification settings (parents only)
                Section("Notifications") {
                    NavigationLink("Notification Preferences") {
                        NotificationSettingsView()
                    }
                }

                // Linked cards
                Section("Linked Cards") {
                    NavigationLink("Manage Cards") {
                        LinkedCardsView()
                    }
                }

                // About section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                            .onTapGesture {
                                versionTapCount += 1
                                if versionTapCount >= 7 {
                                    debugManager.isDebugMode = true
                                    showDeveloperMode = true
                                    versionTapCount = 0
                                }
                            }
                    }

                    if debugManager.isDebugMode {
                        NavigationLink {
                            DeveloperModeView()
                        } label: {
                            HStack {
                                Image(systemName: "hammer.fill")
                                    .foregroundColor(.orange)
                                Text("Developer Mode")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                viewModel.loadUsers()
            }
            .alert("Developer Mode Enabled", isPresented: $showDeveloperMode) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You now have access to developer options.")
            }
        }
    }
}

struct UserSettingsView: View {
    let user: User
    @State private var monthlyLimit: String = ""
    @State private var phoneNumber: String = ""
    @State private var isSaving = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
            Section("Spending Limit") {
                TextField("Monthly Limit", text: $monthlyLimit)
                    .keyboardType(.decimalPad)

                if let current = user.currentSpend {
                    HStack {
                        Text("Current Spending")
                        Spacer()
                        Text(current.formatted(.currency(code: "USD")))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Contact") {
                TextField("Phone Number", text: $phoneNumber)
                    .keyboardType(.phonePad)
            }

            Section {
                Button("Save Changes") {
                    saveChanges()
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle(user.name)
        .onAppear {
            monthlyLimit = user.monthlyLimit?.formatted() ?? ""
            phoneNumber = user.phoneNumber ?? ""
        }
    }

    private func saveChanges() {
        isSaving = true
        Task {
            do {
                if let limit = Double(monthlyLimit) {
                    let _ = try await APIClient.shared.updateSpendingLimit(userId: user.id, monthlyLimit: limit)
                }
                if !phoneNumber.isEmpty {
                    let _ = try await APIClient.shared.updateUserPhone(id: user.id, phone: phoneNumber)
                }
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error saving: \(error)")
            }
            await MainActor.run {
                isSaving = false
            }
        }
    }
}

struct NotificationSettingsView: View {
    @State private var alertMode = "all"
    @State private var thresholdAmount = "25"
    @State private var parentUsers: [User] = []

    var body: some View {
        Form {
            Section("Alert Mode") {
                Picker("When to send alerts", selection: $alertMode) {
                    Text("Every Purchase").tag("all")
                    Text("Weekly Summary").tag("weekly")
                    Text("Above Threshold").tag("threshold")
                }
                .pickerStyle(.inline)
            }

            if alertMode == "threshold" {
                Section("Threshold Amount") {
                    HStack {
                        Text("$")
                        TextField("Amount", text: $thresholdAmount)
                            .keyboardType(.decimalPad)
                    }
                    Text("You'll only be notified for purchases above this amount")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button("Save") {
                    saveSettings()
                }
            }
        }
        .navigationTitle("Notifications")
        .onAppear {
            loadParentUsers()
        }
    }

    private func loadParentUsers() {
        Task {
            do {
                let users = try await APIClient.shared.getUsers()
                await MainActor.run {
                    parentUsers = users.filter { $0.role == .parent }
                    if let first = parentUsers.first {
                        alertMode = first.alertMode?.rawValue ?? "all"
                        thresholdAmount = first.thresholdAmount?.formatted() ?? "25"
                    }
                }
            } catch {
                print("Error loading users: \(error)")
            }
        }
    }

    private func saveSettings() {
        Task {
            for parent in parentUsers {
                try? await APIClient.shared.updateNotificationSettings(
                    id: parent.id,
                    alertMode: alertMode,
                    threshold: Double(thresholdAmount)
                )
            }
        }
    }
}

struct LinkedCardsView: View {
    @State private var cards: [[String: Any]] = []

    var body: some View {
        List {
            Section {
                Button {
                    // Would trigger Plaid Link
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                        Text("Link New Card")
                    }
                }
            }

            Section("Linked Cards") {
                if cards.isEmpty {
                    Text("No cards linked yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(0..<cards.count, id: \.self) { index in
                        let card = cards[index]
                        HStack {
                            Image(systemName: "creditcard.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(card["nickname"] as? String ?? "Card")
                                Text("•••• \(card["last_four"] as? String ?? "****")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Linked Cards")
    }
}

class SettingsViewModel: ObservableObject {
    @Published var users: [User] = []

    func loadUsers() {
        Task {
            do {
                let fetchedUsers = try await APIClient.shared.getUsers()
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
    SettingsView()
}
