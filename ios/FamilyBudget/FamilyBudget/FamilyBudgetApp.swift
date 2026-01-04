import SwiftUI

@main
struct FamilyBudgetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            CardholderListView()
                .tabItem { Label("Family", systemImage: "person.2.fill") }

            TransactionListView()
                .tabItem { Label("Transactions", systemImage: "list.bullet") }

            SubscriptionsView()
                .tabItem { Label("Subs", systemImage: "repeat") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}
