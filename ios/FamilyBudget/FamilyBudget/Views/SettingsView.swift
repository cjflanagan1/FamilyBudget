import SwiftUI

struct SettingsView: View {
    @State private var versionTapCount = 0
    @State private var showDevMode = false

    var body: some View {
        NavigationStack {
            List {
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
            .alert("Developer Mode", isPresented: $showDevMode) { Button("OK") {} }
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
                            Text(card.name)
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
            AddCardView {
                viewModel.loadData()
            }
        }
    }
}

struct AddCardView: View {
    let onSuccess: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var lastFour = ""
    @State private var nickname = ""
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
                    .disabled(lastFour.count != 4 || isLoading)
                }
            }
        }
    }

    private func saveCard() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await APIClient.shared.addCardManually(
                    userId: 2, // CJ is the primary account holder
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
    let onSuccess: () -> Void
    @ObservedObject private var handler = PlaidLinkHandler.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "creditcard.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Link Card")
                .font(.title2)
                .fontWeight(.bold)

            Text("Connect to American Express to track spending")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button {
                handler.startLink(for: 2) // CJ is primary
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

    func loadData() {
        Task {
            do {
                let c = try await APIClient.shared.getAllLinkedCards()
                await MainActor.run {
                    cards = c
                }
            } catch { print("Error loading cards: \(error)") }
        }
    }
}

#Preview { SettingsView() }
