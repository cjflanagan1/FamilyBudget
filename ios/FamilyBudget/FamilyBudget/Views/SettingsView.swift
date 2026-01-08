import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var versionTapCount = 0
    @State private var showDevMode = false

    var body: some View {
        NavigationStack {
            List {
                Section("Family") {
                    ForEach(viewModel.users) { user in
                        NavigationLink(user.name) {
                            UserSettingsView(user: user)
                        }
                    }
                }

                Section("Cards") {
                    NavigationLink("Linked Cards") { LinkedCardsView() }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0").foregroundStyle(.secondary)
                            .onTapGesture {
                                versionTapCount += 1
                                if versionTapCount >= 7 {
                                    DebugManager.shared.isDebugMode = true
                                    showDevMode = true
                                    versionTapCount = 0
                                }
                            }
                    }
                    if DebugManager.shared.isDebugMode {
                        NavigationLink("Developer") { DeveloperModeView() }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .onAppear { viewModel.loadUsers() }
            .alert("Developer Mode", isPresented: $showDevMode) { Button("OK") {} }
        }
    }
}

struct UserSettingsView: View {
    let user: User
    @State private var limit = ""
    @State private var phone = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
            Section("Spending Limit") {
                TextField("Monthly Limit", text: $limit)
                    .keyboardType(.decimalPad)
            }
            Section("Contact") {
                TextField("Phone", text: $phone)
                    .keyboardType(.phonePad)
            }
            Section {
                Button("Save") {
                    Task {
                        // Strip non-numeric characters except decimal point
                        let cleanLimit = limit.filter { $0.isNumber || $0 == "." }
                        if let l = Double(cleanLimit), l > 0 {
                            _ = try? await APIClient.shared.updateSpendingLimit(userId: user.id, monthlyLimit: l)
                        }
                        if !phone.isEmpty {
                            _ = try? await APIClient.shared.updateUserPhone(id: user.id, phone: phone)
                        }
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(user.name)
        .onAppear {
            if let ml = user.monthlyLimit {
                limit = String(format: "%.0f", ml)
            }
            phone = user.phoneNumber ?? ""
        }
    }
}

struct LinkedCardsView: View {
    @StateObject private var viewModel = LinkedCardsViewModel()
    @State private var showingAddCard = false

    var body: some View {
        List {
            Section {
                Button {
                    showingAddCard = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill").foregroundStyle(.green)
                        Text("Add Card")
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            }
            Section("Linked Cards") {
                if viewModel.cards.isEmpty {
                    Text("No cards added yet").foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.cards) { card in
                        HStack {
                            Image(systemName: "creditcard.fill").foregroundStyle(.blue)
                            VStack(alignment: .leading) {
                                Text(card.name)
                                if let ownerName = card.userName {
                                    Text(ownerName).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text("•••• \(card.mask)").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Cards")
        .onAppear { viewModel.loadData() }
        .sheet(isPresented: $showingAddCard) {
            AddCardView(users: viewModel.users) {
                viewModel.loadData()
            }
        }
    }
}

struct AddCardView: View {
    let users: [User]
    let onSuccess: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var lastFour = ""
    @State private var nickname = ""
    @State private var selectedUserId: Int?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Card Details") {
                    TextField("Last 4 digits", text: $lastFour)
                        .keyboardType(.numberPad)
                    TextField("Card nickname (optional)", text: $nickname)
                }

                Section("Card Owner") {
                    ForEach(users) { user in
                        Button {
                            selectedUserId = user.id
                        } label: {
                            HStack {
                                Text(user.name)
                                Spacer()
                                if selectedUserId == user.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCard()
                    }
                    .disabled(lastFour.count != 4 || selectedUserId == nil || isLoading)
                }
            }
        }
    }

    private func saveCard() {
        guard let userId = selectedUserId else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await APIClient.shared.addCardManually(
                    userId: userId,
                    lastFour: lastFour,
                    nickname: nickname.isEmpty ? "Card ending in \(lastFour)" : nickname
                )
                await MainActor.run {
                    onSuccess()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct PlaidLinkView: View {
    let userId: Int
    let userName: String
    let onSuccess: () -> Void
    @ObservedObject private var handler = PlaidLinkHandler.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "creditcard.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Link Card for \(userName)")
                .font(.title2)
                .fontWeight(.bold)

            Text("Connect to American Express to track spending")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button {
                handler.startLink(for: userId)
            } label: {
                HStack {
                    if handler.isLinking {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(handler.isLinking ? "Connecting..." : "Connect with Plaid")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(handler.isLinking)
            .padding(.horizontal, 32)

            Button("Cancel") {
                dismiss()
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, 32)
        }
        .onChange(of: handler.linkedSuccessfully) { success in
            if success {
                handler.linkedSuccessfully = false
                onSuccess()
                dismiss()
            }
        }
        .alert("Error", isPresented: Binding(get: { handler.linkError != nil }, set: { _ in handler.linkError = nil })) {
            Button("OK") {}
        } message: {
            Text(handler.linkError ?? "")
        }
    }
}

class LinkedCardsViewModel: ObservableObject {
    @Published var cards: [LinkedCard] = []
    @Published var users: [User] = []

    func loadData() {
        Task {
            do {
                async let cardsTask = APIClient.shared.getAllLinkedCards()
                async let usersTask = APIClient.shared.getUsers()
                let (c, u) = try await (cardsTask, usersTask)
                await MainActor.run {
                    cards = c
                    users = u
                }
            } catch { print("Error loading cards: \(error)") }
        }
    }
}

class SettingsViewModel: ObservableObject {
    @Published var users: [User] = []
    func loadUsers() {
        Task {
            do {
                let u = try await APIClient.shared.getUsers()
                await MainActor.run { users = u }
            } catch { print("Error: \(error)") }
        }
    }
}

#Preview { SettingsView() }
