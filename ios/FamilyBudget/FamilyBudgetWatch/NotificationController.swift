import WatchKit
import SwiftUI
import UserNotifications

class NotificationController: WKUserNotificationHostingController<NotificationView> {
    var amount: Double = 0
    var merchantName: String = ""
    var cardholderName: String = ""
    var isRefund: Bool = false

    override var body: NotificationView {
        NotificationView(
            amount: amount,
            merchantName: merchantName,
            cardholderName: cardholderName,
            isRefund: isRefund
        )
    }

    override func willActivate() {
        super.willActivate()
    }

    override func didDeactivate() {
        super.didDeactivate()
    }

    override func didReceive(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo

        // Parse transaction data from notification payload
        if let txnData = userInfo["transaction"] as? [String: Any] {
            if let amt = txnData["amount"] as? Double {
                amount = amt
            } else if let amtStr = txnData["amount"] as? String {
                amount = Double(amtStr) ?? 0
            }

            merchantName = txnData["merchant_name"] as? String ?? "Unknown Merchant"
            cardholderName = txnData["cardholder_name"] as? String ?? "Unknown"
            isRefund = txnData["is_refund"] as? Bool ?? false
        } else {
            // Fallback to notification content
            let content = notification.request.content
            merchantName = content.title
            cardholderName = content.subtitle
        }
    }
}

struct NotificationView: View {
    let amount: Double
    let merchantName: String
    let cardholderName: String
    let isRefund: Bool

    var body: some View {
        ZStack {
            // Blue background
            Color.blue
                .ignoresSafeArea()

            VStack(spacing: 10) {
                // Header
                Text(isRefund ? "Refund" : "New Charge")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                // Amount
                Text(formattedAmount)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(isRefund ? .green : .white)

                // Merchant
                Text(merchantName)
                    .font(.body)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Spacer()

                // Cardholder
                Text(cardholderName)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
            }
            .padding()
        }
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let amtStr = formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
        return isRefund ? "+\(amtStr)" : amtStr
    }
}

#Preview {
    NotificationView(
        amount: 45.99,
        merchantName: "Amazon",
        cardholderName: "Paige",
        isRefund: false
    )
}
