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
                    Image(systemName: "chart.pie.fill")
                    Text("Home")
                }

            CardholderListView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Family")
                }

            TransactionListView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Txns")
                }

            SubscriptionsView()
                .tabItem {
                    Image(systemName: "repeat")
                    Text("Subs")
                }

            SettingsView()
                .tabItem {
                    Image(systemName: "gear.fill")
                    Text("More")
                }
        }
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            UITabBar.appearance().standardAppearance = appearance
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
