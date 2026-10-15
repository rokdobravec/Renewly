import Charts
import SwiftData
import SwiftUI

struct InsightsView: View {
    @Query(filter: #Predicate<Subscription> { !$0.isPaused }) private var active: [Subscription]
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency
    @State private var period: Period = .monthly
    @State private var selectedAngle: Double?

    enum Period: String, CaseIterable, Identifiable {
        case monthly = "Monthly", yearly = "Yearly"
        var id: String { rawValue }
        var multiplier: Double { self == .monthly ? 1 : 12 }
    }

    struct CategoryTotal: Identifiable {
        let category: SubscriptionCategory
        let amount: Double
        let count: Int
        var id: SubscriptionCategory { category }
    }

    struct MonthTotal: Identifiable {
        let month: Date
        let amount: Double
        var id: Date { month }
    }

    private var total: Double { active.reduce(0) { $0 + $1.monthlyCost } * period.multiplier }

    private var byCategory: [CategoryTotal] {
        Dictionary(grouping: active, by: \.category)
            .map { CategoryTotal(category: $0.key,
                                 amount: $0.value.reduce(0) { $0 + $1.monthlyCost } * period.multiplier,
                                 count: $0.value.count) }
            .sorted { $0.amount > $1.amount }
    }

    /// Actual charges due in each of the next 12 calendar months.
    private var projection: [MonthTotal] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .month, for: .now)!.start
        return (0..<12).map { offset in
            let month = calendar.date(byAdding: .month, value: offset, to: start)!
            let interval = calendar.dateInterval(of: .month, for: month)!
            let amount = active.reduce(0) { $0 + Double($1.renewals(in: interval).count) * $1.price }
            return MonthTotal(month: month, amount: amount)
        }
    }

    private var selectedCategory: CategoryTotal? {
        guard let selectedAngle else { return nil }
        var running = 0.0
        for item in byCategory {
            running += item.amount
            if selectedAngle <= running { return item }
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if active.isEmpty {
                    ContentUnavailableView("No insights yet",
                                           systemImage: "chart.pie",
                                           description: Text("Add a subscription to see where your money goes."))
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            Picker("Period", selection: $period.animation(.snappy)) {
                                ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.segmented)

                            categoryCard
                            projectionCard
                            topCard
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Insights")
        }
    }

    private var categoryCard: some View {
        card(title: "By category") {
            Chart(byCategory) { item in
                SectorMark(angle: .value("Amount", item.amount),
                           innerRadius: .ratio(0.64),
                           angularInset: 2)
                    .cornerRadius(5)
                    .foregroundStyle(item.category.color.gradient)
                    .opacity(selectedCategory == nil || selectedCategory?.category == item.category ? 1 : 0.35)
            }
            .chartAngleSelection(value: $selectedAngle)
            .chartBackground { proxy in
                GeometryReader { geo in
                    if let frame = proxy.plotFrame {
                        let rect = geo[frame]
                        VStack(spacing: 2) {
                            Text(selectedCategory?.category.title ?? "Total")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text((selectedCategory?.amount ?? total).currency(currency))
                                .font(.title2.bold())
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text(period == .monthly ? "per month" : "per year")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .position(x: rect.midX, y: rect.midY)
                    }
                }
            }
            .frame(height: 240)
            .padding(.vertical, 8)
            .sensoryFeedback(.selection, trigger: selectedCategory?.category)

            VStack(spacing: 0) {
                ForEach(byCategory) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.category.symbol)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(item.category.color.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.category.title).font(.subheadline.weight(.medium))
                            Text("\(item.count) \(item.count == 1 ? "subscription" : "subscriptions")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(item.amount.currency(currency))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                            Text((total > 0 ? item.amount / total : 0).formatted(.percent.precision(.fractionLength(0))))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var projectionCard: some View {
        let data = projection
        let yearTotal = data.reduce(0) { $0 + $1.amount }
        let currentMonth = Calendar.current.dateInterval(of: .month, for: .now)!.start
        return card(title: "Next 12 months") {
            Text("\(yearTotal.currency(currency)) in scheduled charges")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Chart(data) { item in
                BarMark(x: .value("Month", item.month, unit: .month),
                        y: .value("Amount", item.amount))
                    .cornerRadius(5)
                    .foregroundStyle(item.month == currentMonth
                                     ? AnyShapeStyle(Color.accentColor.gradient)
                                     : AnyShapeStyle(Color.accentColor.opacity(0.35).gradient))
                RuleMark(y: .value("Average", yearTotal / 12))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisValueLabel(format: .dateTime.month(.narrow), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount, format: .currency(code: currency).precision(.fractionLength(0)))
                        }
                    }
                }
            }
            .frame(height: 200)
            .padding(.top, 8)
        }
    }

    private var topCard: some View {
        let top = active.sorted { $0.monthlyCost > $1.monthlyCost }.prefix(3)
        return card(title: "Biggest costs") {
            ForEach(Array(top.enumerated()), id: \.element.id) { index, sub in
                HStack(spacing: 12) {
                    SubscriptionIcon(symbol: sub.symbol, color: sub.color, size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(sub.name).font(.subheadline.weight(.medium))
                        Text("\((sub.monthlyCost * period.multiplier).currency(currency)) \(period == .monthly ? "per month" : "per year")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("#\(index + 1)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
            }
            if let biggest = top.first {
                Label {
                    Text("Cancelling **\(biggest.name)** would save you **\(biggest.yearlyCost.currency(currency))** a year.")
                } icon: {
                    Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                }
                .font(.footnote)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 6)
            }
        }
    }

    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Insights teaser for the free plan: the real charts, blurred, under an unlock card.
struct LockedInsightsView: View {
    @State private var showingPaywall = false

    var body: some View {
        InsightsView()
            .blur(radius: 10)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .overlay {
                VStack(spacing: 14) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(
                            LinearGradient(colors: [Color(hex: 0x4540F2), Color(hex: 0x9E4DFA)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Text("Insights").font(.title2.bold())
                            ProBadge()
                        }
                        Text("See spending by category, a 12-month forecast and your biggest costs.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Button {
                        showingPaywall = true
                    } label: {
                        Text("Unlock Insights")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28)
                            .frame(minHeight: 48)
                            .background(
                                LinearGradient(colors: [Color(hex: 0x4540F2), Color(hex: 0x9E4DFA)],
                                               startPoint: .leading, endPoint: .trailing),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
                .padding(.horizontal, 32)
            }
            .sheet(isPresented: $showingPaywall) { PaywallView(reason: .insights) }
    }
}
