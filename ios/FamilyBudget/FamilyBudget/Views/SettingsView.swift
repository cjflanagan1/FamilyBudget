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

    var body: some View {
        List {
            Section {
                NavigationLink("Link New Card") {
                    PlaidLinkView(userId: 1) { viewModel.loadCards(userId: 1) }
                }
            }
            Section("Cards") {
                ForEach(viewModel.cards) { card in
                    HStack {
                        Image(systemName: "creditcard.fill").foregroundStyle(.blue)
                        Text(card.name)
                        Spacer()
                        Text("•••• \(card.mask)").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Cards")
        .onAppear { viewModel.loadCards(userId: 1) }
    }
}

struct PlaidLinkView: View {
    let userId: Int
    let onSuccess: () -> Void
    @StateObject private var handler = PlaidLinkHandler.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Link Bank Account").font(.title2).fontWeight(.bold)
            Text("Connect your cards to track spending").foregroundStyle(.secondary)
            Spacer()
            Button {
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let vc = scene.windows.first?.rootViewController {
                    handler.startLink(for: userId, from: vc)
                }
            } label: {
                Text(handler.isLinking ? "Connecting..." : "Connect")
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.blue).foregroundStyle(.white).cornerRadius(10)
            }
            .disabled(handler.isLinking)
            .padding(.horizontal)
            Spacer()
        }
        .navigationTitle("Link Card")
        .alert("Success!", isPresented: Binding(get: { handler.linkedSuccessfully }, set: { _ in handler.linkedSuccessfully = false; onSuccess(); dismiss() })) { Button("OK") {} }
        .alert("Error", isPresented: Binding(get: { handler.linkError != nil }, set: { _ in handler.linkError = nil })) { Button("OK") {} } message: { Text(handler.linkError ?? "") }
    }
}

class LinkedCardsViewModel: ObservableObject {
    @Published var cards: [LinkedCard] = []
    func loadCards(userId: Int) {
        Task {
            do {
                let c = try await APIClient.shared.getLinkedCards(userId: userId)
                await MainActor.run { cards = c }
            } catch { print("Error: \(error)") }
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
