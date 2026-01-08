import SwiftUI
import WatchKit

struct ContentView: View {
    @State private var cardBalance: Double = 0
    @State private var paymentDue: Double = 0
    @State private var spentThisMonth: Double = 0
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.blue.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if let error = errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
            } else {
                VStack(spacing: 8) {
                    VStack(spacing: 0) {
                        Text("Flanagan")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("Family Budget")
                            .font(.caption2)
                    }
                    .foregroundColor(.white.opacity(0.9))

                    // Balance
                    HStack {
                        Text("Balance")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(formatCurrency(cardBalance))
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }

                    // Payment Due
                    HStack {
                        Text("Due")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(formatCurrency(paymentDue))
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(paymentDue > 0 ? .orange : .green)
                    }

                    // Spent This Month
                    HStack {
                        Text("Spent")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(formatCurrency(spentThisMonth))
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .onAppear {
            loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTransaction)) { _ in
            loadData()
        }
    }

    private func loadData() {
        isLoading = true
        errorMessage = nil
        Task {
            await fetchCardBalance()
            await fetchSpentThisMonth()
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func fetchCardBalance() async {
        guard let url = URL(string: "http://192.168.1.184:3000/api/plaid/balances") else {
            await MainActor.run { errorMessage = "Invalid URL" }
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let card = json.first {
                await MainActor.run {
                    if let balance = card["current_balance"] as? Double {
                        cardBalance = balance
                    } else if let balanceStr = card["current_balance"] as? String {
                        cardBalance = Double(balanceStr) ?? 0
                    }

                    if let due = card["payment_due"] as? Double {
                        paymentDue = due
                    } else if let dueStr = card["payment_due"] as? String {
                        paymentDue = Double(dueStr) ?? 0
                    } else {
                        paymentDue = 0
                    }
                    errorMessage = nil
                }
            }
        } catch {
            print("[Watch] Failed to fetch card balance: \(error)")
            await MainActor.run {
                errorMessage = "Network error"
            }
        }
    }

    private func fetchSpentThisMonth() async {
        guard let url = URL(string: "http://192.168.1.184:3000/api/limits/status/all") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                var total: Double = 0
                for user in json {
                    if let spent = user["current_spend"] as? Double {
                        total += spent
                    } else if let spentStr = user["current_spend"] as? String {
                        total += Double(spentStr) ?? 0
                    }
                }
                await MainActor.run {
                    spentThisMonth = total
                }
            }
        } catch {
            print("[Watch] Failed to fetch spending: \(error)")
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

struct TransactionInfo {
    let amount: Double
    let merchantName: String
    let cardholderName: String
    let isRefund: Bool

    init(from dict: [String: Any]) {
        if let amt = dict["amount"] as? Double {
            self.amount = amt
        } else if let amtStr = dict["amount"] as? String {
            self.amount = Double(amtStr) ?? 0
        } else {
            self.amount = 0
        }

        self.merchantName = dict["merchant_name"] as? String ?? "Unknown"
        self.cardholderName = dict["cardholder_name"] as? String ?? "Unknown"
        self.isRefund = dict["is_refund"] as? Bool ?? false
    }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let amtStr = formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
        return isRefund ? "+\(amtStr)" : "-\(amtStr)"
    }
}

#Preview {
    ContentView()
}
