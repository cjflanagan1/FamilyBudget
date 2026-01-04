import Foundation
import SwiftUI

// Note: You'll need to add the Plaid Link SDK via Swift Package Manager:
// https://github.com/plaid/plaid-link-ios

/*
 To add Plaid Link SDK:
 1. In Xcode, go to File > Add Packages...
 2. Enter: https://github.com/plaid/plaid-link-ios
 3. Select version 4.x or later
 4. Add to your target

 Then uncomment the imports and code below.
*/

// import LinkKit

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

    // Start the Plaid Link flow
    func startLink(for userId: Int, from viewController: UIViewController? = nil) {
        Task {
            await MainActor.run {
                isLinking = true
                linkError = nil
            }

            do {
                let linkToken = try await createLinkToken(for: userId)

                // In production, you would use the Plaid Link SDK here:
                /*
                await MainActor.run {
                    var linkConfiguration = LinkTokenConfiguration(
                        token: linkToken,
                        onSuccess: { linkSuccess in
                            self.handleSuccess(linkSuccess, userId: userId)
                        }
                    )
                    linkConfiguration.onExit = { linkExit in
                        self.handleExit(linkExit)
                    }

                    let result = Plaid.create(linkConfiguration)
                    switch result {
                    case .success(let handler):
                        if let vc = viewController {
                            handler.open(presentUsing: .viewController(vc))
                        }
                    case .failure(let error):
                        self.linkError = error.localizedDescription
                    }
                }
                */

                // For now, log the link token (remove in production)
                print("Link token created: \(linkToken)")

                await MainActor.run {
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
