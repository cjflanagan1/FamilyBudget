import SwiftUI
import Charts

struct TrendsView: View {
    @StateObject private var viewModel = TrendsViewModel()
    @ObservedObject private var debugManager = DebugManager.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Month over month comparison
                    monthComparisonCard

                    // Spending trend chart
                    spendingTrendChart

                    // Category trends
                    categoryTrendsSection
                }
                .padding()
            }
            .navigationTitle("Trends")
            .onAppear {
                viewModel.loadData()
            }
        }
    }

    private var monthComparisonCard: some View {
        VStack(spacing: 12) {
            Text("Month over Month")
                .font(.headline)

            HStack(spacing: 30) {
                VStack {
                    Text("Last Month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.lastMonthTotal.formatted(.currency(code: "USD")))
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Image(systemName: viewModel.changePercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.title)
                    .foregroundColor(viewModel.changePercent >= 0 ? .red : .green)

                VStack {
                    Text("This Month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.thisMonthTotal.formatted(.currency(code: "USD")))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }

            Text("\(viewModel.changePercent >= 0 ? "+" : "")\(viewModel.changePercent, specifier: "%.1f")% change")
                .font(.subheadline)
                .foregroundColor(viewModel.changePercent >= 0 ? .red : .green)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private var spendingTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("6-Month Trend")
                .font(.headline)

            if #available(iOS 16.0, *) {
                Chart(viewModel.monthlyTrends) { trend in
                    BarMark(
                        x: .value("Month", trend.monthLabel),
                        y: .value("Amount", trend.total)
                    )
                    .foregroundStyle(Color.blue.gradient)
                }
                .frame(height: 200)
            } else {
                // Fallback for older iOS
                SimpleTrendChart(data: viewModel.monthlyTrends)
                    .frame(height: 200)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private var categoryTrendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Categories This Month")
                .font(.headline)

            ForEach(viewModel.categoryBreakdown) { category in
                HStack {
                    Text(category.category)
                    Spacer()

                    let percentage = viewModel.totalSpent > 0
                        ? (category.total / viewModel.totalSpent) * 100
                        : 0

                    Text("\(percentage, specifier: "%.0f")%")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(category.total.formatted(.currency(code: "USD")))
                        .fontWeight(.medium)
                }

                ProgressView(value: min(viewModel.totalSpent > 0 ? category.total / viewModel.totalSpent : 0, 1))
                    .tint(.blue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}

// Simple fallback chart for older iOS
struct SimpleTrendChart: View {
    let data: [MonthlyTrend]

    var maxValue: Double {
        data.map { $0.total }.max() ?? 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(data) { trend in
                VStack {
                    Spacer()

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(height: CGFloat(trend.total / maxValue) * 150)

                    Text(trend.monthLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// Data models for trends
struct MonthlyTrend: Identifiable {
    let id = UUID()
    let month: Date
    let total: Double
    let transactionCount: Int

    var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: month)
    }
}

class TrendsViewModel: ObservableObject {
    @Published var monthlyTrends: [MonthlyTrend] = []
    @Published var categoryBreakdown: [CategorySpend] = []
    @Published var thisMonthTotal: Double = 0
    @Published var lastMonthTotal: Double = 0
    @Published var changePercent: Double = 0
    @Published var totalSpent: Double = 0

    private let apiClient = APIClient.shared

    func loadData() {
        Task {
            do {
                // Load spending summary
                let summary = try await apiClient.getSpendingSummary()
                let categories = try await apiClient.getCategoryBreakdown()

                await MainActor.run {
                    self.thisMonthTotal = summary.reduce(0) { $0 + $1.totalSpent }
                    self.totalSpent = self.thisMonthTotal
                    self.categoryBreakdown = categories

                    // Generate mock trend data (in production, this would come from API)
                    self.generateMockTrends()
                }
            } catch {
                print("Error loading trends: \(error)")
            }
        }
    }

    private func generateMockTrends() {
        let calendar = Calendar.current
        var trends: [MonthlyTrend] = []

        for i in (0..<6).reversed() {
            if let date = calendar.date(byAdding: .month, value: -i, to: Date()) {
                let mockTotal = Double.random(in: 1500...4000)
                trends.append(MonthlyTrend(
                    month: date,
                    total: i == 0 ? thisMonthTotal : mockTotal,
                    transactionCount: Int.random(in: 30...80)
                ))
            }
        }

        monthlyTrends = trends

        if trends.count >= 2 {
            lastMonthTotal = trends[trends.count - 2].total
            if lastMonthTotal > 0 {
                changePercent = ((thisMonthTotal - lastMonthTotal) / lastMonthTotal) * 100
            }
        }
    }
}

#Preview {
    TrendsView()
}
