import SwiftUI

/// Hero card at the top of the dashboard: what's due this month, plus monthly and yearly run-rate.
struct SummaryCard: View {
    let active: [Subscription]
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency
    @Environment(\.isCompactScreen) private var compact

    private var monthInterval: DateInterval {
        Calendar.current.dateInterval(of: .month, for: .now) ?? DateInterval(start: .now, duration: 0)
    }

    private var dueThisMonth: Double {
        let interval = monthInterval
        return active.reduce(0) { $0 + Double($1.renewals(in: interval).count) * $1.price }
    }

    private var remainingThisMonth: Double {
        let interval = DateInterval(start: Calendar.current.startOfDay(for: .now), end: monthInterval.end)
        return active.reduce(0) { $0 + Double($1.renewals(in: interval).count) * $1.price }
    }

    private var monthlyAverage: Double { active.reduce(0) { $0 + $1.monthlyCost } }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 18) {
            HStack {
                Label(Date.now.formatted(.dateTime.month(.wide)), systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text("\(active.count) active")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.18), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(dueThisMonth.currency(currency))
                    .font(.system(size: compact ? 34 : 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("\(remainingThisMonth.currency(currency)) still to pay this month")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }

            HStack(spacing: 0) {
                stat(title: "Avg / month", value: monthlyAverage.currency(currency))
                Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    .padding(.horizontal, 16)
                stat(title: "Per year", value: (monthlyAverage * 12).currency(currency))
                Spacer()
            }
        }
        .padding(compact ? 16 : 22)
        .background {
            ZStack {
                LinearGradient(colors: [Color(hex: 0x4540F2), Color(hex: 0x9E4DFA)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(.white.opacity(0.12)).frame(width: 220).offset(x: 140, y: -90)
                Circle().fill(.white.opacity(0.07)).frame(width: 160).offset(x: -150, y: 90)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color(hex: 0x4540F2).opacity(0.25), radius: 10, y: 5)
        .animation(.snappy, value: dueThisMonth)
    }

    private func stat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
            Text(value)
                .font(.headline)
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }
}
