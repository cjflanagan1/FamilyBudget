import SwiftUI

@main
struct FamilyBudgetApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

// Main app state
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var familyMembers: [User] = []
    @Published var isLoading = false

    private let apiClient = APIClient.shared

    init() {
        loadFamilyMembers()
    }

    func loadFamilyMembers() {
        Task {
            do {
                let members = try await apiClient.getUsers()
                await MainActor.run {
                    self.familyMembers = members
                }
            } catch {
                print("Error loading family members: \(error)")
            }
        }
    }
}

// Main content view with tab navigation
struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.pie")
                }

            CardholderListView()
                .tabItem {
                    Label("Family", systemImage: "person.3")
                }

            TransactionListView()
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet.rectangle")
                }

            SubscriptionsView()
                .tabItem {
                    Label("Subscriptions", systemImage: "repeat")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
