import Foundation
import SwiftUI

// Import will be available after adding the Plaid SDK package
#if canImport(LinkKit)
import LinkKit
#endif

class PlaidLinkHandler: ObservableObject {
    static let shared = PlaidLinkHandler()

    @Published var isLinking = false
    @Published var linkError: String?
    @Published var linkedSuccessfully = false

    private let apiClient = APIClient.shared

    // Create a link token from the backend
    func createLinkToken(for userId: Int) async throws -> String {
        let response = try await apiClient.createLinkToken(userId: userId)
        guard let linkToken = response.link_token else {
            throw PlaidError.invalidResponse
        }
        return linkToken
    }

    @Published var plaidLinkHandler: Any? // Holds the LinkHandler instance

    // Start the Plaid Link flow
    func startLink(for userId: Int, from viewController: UIViewController? = nil) {
        Task {
            await MainActor.run {
                isLinking = true
                linkError = nil
            }

            do {
                print("[PlaidLinkHandler] Starting link for userId: \(userId)")
                let linkToken = try await createLinkToken(for: userId)
                print("[PlaidLinkHandler] Link token created successfully: \(linkToken.prefix(20))...")

#if canImport(LinkKit)
                await MainActor.run {
                    print("[PlaidLinkHandler] Configuring Plaid Link with token")
                    var linkConfiguration = LinkTokenConfiguration(
                        token: linkToken,
                        onSuccess: { linkSuccess in
                            print("[PlaidLinkHandler] Plaid Link succeeded with public token: \(linkSuccess.publicToken.prefix(20))...")
                            self.handleSuccess(publicToken: linkSuccess.publicToken, userId: userId)
                        }
                    )
                    linkConfiguration.onExit = { linkExit in
                        print("[PlaidLinkHandler] Plaid Link exited")
                        if let error = linkExit.error {
                            print("[PlaidLinkHandler] Exit error: \(error.localizedDescription)")
                        }
                        self.handleExit(error: linkExit.error)
                    }

                    print("[PlaidLinkHandler] Creating Plaid handler")
                    let result = Plaid.create(linkConfiguration)
                    switch result {
                    case .success(let handler):
                        print("[PlaidLinkHandler] Plaid handler created, presenting modal")
                        self.plaidLinkHandler = handler // Keep reference

                        // Use the provided view controller or find the key window's root
                        var presentingVC = viewController
                        if presentingVC == nil {
                            // Try to get the most recently presented view controller
                            if let window = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               var topVC = window.windows.first?.rootViewController {
                                // Walk up the navigation/modal hierarchy
                                while let presented = topVC.presentedViewController {
                                    topVC = presented
                                }
                                presentingVC = topVC
                            }
                        }

                        if let presentingVC = presentingVC {
                            print("[PlaidLinkHandler] Presenting from view controller")
                            handler.open(presentUsing: .viewController(presentingVC))
                        } else {
                            print("[PlaidLinkHandler] ERROR: Could not find view controller to present from")
                            self.linkError = "Could not find view controller to present Plaid Link"
                            self.isLinking = false
                        }
                    case .failure(let error):
                        print("[PlaidLinkHandler] Plaid creation failed: \(error.localizedDescription)")
                        self.linkError = error.localizedDescription
                        self.isLinking = false
                    }
                }
#else
                // Plaid SDK not available - show error
                await MainActor.run {
                    print("[PlaidLinkHandler] ERROR: Plaid SDK not available")
                    self.linkError = "Plaid SDK not installed. Please add the plaid-link-ios package."
                    self.isLinking = false
                }
#endif

            } catch {
                await MainActor.run {
                    print("[PlaidLinkHandler] ERROR: \(error.localizedDescription)")
                    linkError = error.localizedDescription
                    isLinking = false
                }
            }
        }
    }

    // Handle successful link
    private func handleSuccess(publicToken: String, userId: Int) {
        Task {
            do {
                // Exchange public token for access token
                let _ = try await apiClient.exchangePublicToken(
                    publicToken: publicToken,
                    userId: userId
                )

                await MainActor.run {
                    linkedSuccessfully = true
                    isLinking = false
                }
            } catch {
                await MainActor.run {
                    linkError = error.localizedDescription
                    isLinking = false
                }
            }
        }
    }

    // Handle link exit (user cancelled or error)
    private func handleExit(error: Error?) {
        Task {
            await MainActor.run {
                if let error = error {
                    linkError = error.localizedDescription
                }
                isLinking = false
            }
        }
    }
}

enum PlaidError: Error, LocalizedError {
    case invalidResponse
    case linkFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .linkFailed(let message):
            return "Link failed: \(message)"
        }
    }
}

// SwiftUI view for linking cards
struct PlaidLinkButton: View {
    let userId: Int
    @StateObject private var linkHandler = PlaidLinkHandler.shared

    var body: some View {
        Button {
            linkHandler.startLink(for: userId)
        } label: {
            HStack {
                if linkHandler.isLinking {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                }
                Text(linkHandler.isLinking ? "Connecting..." : "Link Amex Card")
            }
        }
        .disabled(linkHandler.isLinking)
        .alert("Link Error", isPresented: .constant(linkHandler.linkError != nil)) {
            Button("OK") {
                linkHandler.linkError = nil
            }
        } message: {
            Text(linkHandler.linkError ?? "")
        }
        .alert("Card Linked!", isPresented: $linkHandler.linkedSuccessfully) {
            Button("OK") { }
        } message: {
            Text("Your Amex card has been successfully linked.")
        }
    }
}

#Preview {
    PlaidLinkButton(userId: 1)
}
