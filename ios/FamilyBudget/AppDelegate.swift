import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Request notification permissions
        requestNotificationPermission()

        return true
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                print("[Push] Notification permission granted")
            } else if let error = error {
                print("[Push] Notification permission error: \(error)")
            }
        }
    }

    // Called when APNs has assigned a device token
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[Push] Device token: \(token)")

        // Save token and send to backend
        Task {
            await registerDeviceToken(token)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Push] Failed to register: \(error)")
    }

    // Register device token with backend
    private func registerDeviceToken(_ token: String) async {
        // Store locally
        UserDefaults.standard.set(token, forKey: "pushDeviceToken")

        // Send to backend for all users (primary parent)
        do {
            try await APIClient.shared.registerDeviceToken(token: token, userId: 1)
            print("[Push] Token registered with backend")
        } catch {
            print("[Push] Failed to register token with backend: \(error)")
        }
    }

    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("[Push] Notification tapped: \(userInfo)")

        // Handle navigation based on notification type
        if let type = userInfo["type"] as? String {
            NotificationCenter.default.post(name: .pushNotificationReceived, object: nil, userInfo: ["type": type])
        }

        completionHandler()
    }
}

// Notification name for handling push notification taps
extension Notification.Name {
    static let pushNotificationReceived = Notification.Name("pushNotificationReceived")
}
