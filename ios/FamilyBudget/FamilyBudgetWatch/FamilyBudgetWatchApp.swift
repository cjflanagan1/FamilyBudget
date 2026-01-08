import SwiftUI
import WatchKit
import UserNotifications

@main
struct FamilyBudgetWatchApp: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        WKNotificationScene(controller: NotificationController.self, category: "transaction")
    }
}

class AppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {

    func applicationDidFinishLaunching() {
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    WKApplication.shared().registerForRemoteNotifications()
                }
                print("[Watch] Notification permission granted")
            }
        }
    }

    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[Watch] Device token: \(token)")

        // Store and send to backend
        UserDefaults.standard.set(token, forKey: "watchPushToken")
        Task {
            await registerWatchToken(token)
        }
    }

    func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
        print("[Watch] Failed to register: \(error)")
    }

    private func registerWatchToken(_ token: String) async {
        // Send to backend - same endpoint, different platform
        guard let url = URL(string: "http://172.20.10.11:3000/api/notifications/register-device") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "device_token": token,
            "user_id": 1,
            "platform": "watchos"
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            print("[Watch] Token registered with backend")
        } catch {
            print("[Watch] Failed to register token: \(error)")
        }
    }

    // Handle notification when watch app is active
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Update the UI with the transaction data
        if let userInfo = notification.request.content.userInfo as? [String: Any] {
            NotificationCenter.default.post(name: .newTransaction, object: nil, userInfo: userInfo)
        }
        completionHandler([.banner, .sound])
    }
}

extension Notification.Name {
    static let newTransaction = Notification.Name("newTransaction")
}
