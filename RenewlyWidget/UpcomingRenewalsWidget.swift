import SwiftData
import SwiftUI
import WidgetKit

/// What the widget shows on a given day: this month's charges and the next few renewals.
struct RenewalsEntry: TimelineEntry {
    struct Item: Identifiable {
        let id: UUID
        let name: String
        let symbol: String
        let colorHex: Int
        let price: Double
        let renewal: Date
        let days: Int
    }

    let date: Date
    let monthTotal: Double
    let activeCount: Int
    let upcoming: [Item]
    let currency: String

    static let placeholder = RenewalsEntry(
        date: .now, monthTotal: 128.44, activeCount: 7,
        upcoming: [
            Item(id: UUID(), name: "Netflix", symbol: "play.rectangle.fill", colorHex: 0xE50914,
                 price: 15.49, renewal: .now, days: 0),
            Item(id: UUID(), name: "Spotify", symbol: "music.note", colorHex: 0x1DB954,
                 price: 11.99, renewal: .now.addingTimeInterval(86_400 * 2), days: 2),
            Item(id: UUID(), name: "iCloud+", symbol: "icloud.fill", colorHex: 0x0A84FF,
                 price: 2.99, renewal: .now.addingTimeInterval(86_400 * 6), days: 6),
        ],
        currency: AppSettings.defaultCurrency)
}

struct RenewalsProvider: TimelineProvider {
    func placeholder(in context: Context) -> RenewalsEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (RenewalsEntry) -> Void) {
        let subscriptions = Self.loadActive()
        completion(subscriptions.isEmpty && context.isPreview ? .placeholder : Self.entry(for: .now, from: subscriptions))
    }

    /// One entry per day for the next week, so "Tomorrow" and month totals roll over at midnight.
    func getTimeline(in context: Context, completion: @escaping (Timeline<RenewalsEntry>) -> Void) {
        let subscriptions = Self.loadActive()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        let entries = days.enumerated().map { index, day in
            Self.entry(for: index == 0 ? .now : day, from: subscriptions)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private static func loadActive() -> [Subscription] {
        do {
            let container = try ModelContainer(for: Subscription.self,
                                               configurations: ModelConfiguration(url: SharedStore.storeURL, allowsSave: false))
            let context = ModelContext(container)
            return try context.fetch(FetchDescriptor<Subscription>(predicate: #Predicate { !$0.isPaused }))
        } catch {
            return []
        }
    }

    private static func entry(for date: Date, from subscriptions: [Subscription]) -> RenewalsEntry {
        let calendar = Calendar.current
        let month = calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
        let total = subscriptions.reduce(0) { $0 + Double($1.renewals(in: month, calendar: calendar).count) * $1.price }
        let upcoming = subscriptions
            .map { sub in
                RenewalsEntry.Item(id: sub.id, name: sub.name, symbol: sub.symbol, colorHex: sub.colorHex,
                                   price: sub.price, renewal: sub.nextRenewal(after: date, calendar: calendar),
                                   days: sub.daysUntilRenewal(from: date, calendar: calendar))
            }
            .sorted { $0.renewal < $1.renewal }
        return RenewalsEntry(date: date, monthTotal: total, activeCount: subscriptions.count,
                             upcoming: Array(upcoming.prefix(4)), currency: AppSettings.sharedCurrency)
    }
}

struct UpcomingRenewalsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UpcomingRenewals", provider: RenewalsProvider()) { entry in
            RenewalsWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack {
                        LinearGradient(colors: [Color(hex: 0x4540F2), Color(hex: 0x9E4DFA)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                        GeometryReader { geo in
                            Circle().fill(.white.opacity(0.12))
                                .frame(width: geo.size.height * 1.1)
                                .position(x: geo.size.width - 10, y: 0)
                        }
                    }
                }
        }
        .configurationDisplayName("Upcoming renewals")
        .description("This month's total and what renews next.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct RenewalsWidgetView: View {
    let entry: RenewalsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium: medium
        default: small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            monthHeader
            Spacer(minLength: 4)
            totalBlock
            Spacer(minLength: 6)
            if let next = entry.upcoming.first {
                HStack(spacing: 6) {
                    WidgetIcon(symbol: next.symbol, colorHex: next.colorHex, size: 22)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(next.name)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(dayLabel(next.days))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            } else {
                Text("No upcoming renewals")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                monthHeader
                Spacer(minLength: 4)
                totalBlock
                Spacer(minLength: 4)
                Text("\(entry.activeCount) active")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.18), in: Capsule())
            }
            // Narrower widgets (4.7" iPhone SE) shrink this column so service names in "Next up" stay readable.
            .frame(minWidth: 96, idealWidth: 118, maxWidth: 118, alignment: .leading)

            VStack(alignment: .leading, spacing: 7) {
                Text("Next up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                if entry.upcoming.isEmpty {
                    Spacer()
                    Text("Add a subscription in Renewly to see it here.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                } else {
                    ForEach(entry.upcoming.prefix(3)) { item in
                        HStack(spacing: 8) {
                            WidgetIcon(symbol: item.symbol, colorHex: item.colorHex, size: 24)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(item.name)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                Text(dayLabel(item.days))
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .layoutPriority(1)
                            Spacer(minLength: 4)
                            Text(item.price.currency(entry.currency))
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
        .foregroundStyle(.white)
    }

    private var monthHeader: some View {
        Label(entry.date.formatted(.dateTime.month(.wide)), systemImage: "calendar")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(1)
    }

    private var totalBlock: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(entry.monthTotal.currency(entry.currency))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text("this month")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func dayLabel(_ days: Int) -> String {
        switch days {
        case 0: "Today"
        case 1: "Tomorrow"
        default: "in \(days) days"
        }
    }
}

/// Compact version of the app's subscription icon tile.
private struct WidgetIcon: View {
    let symbol: String
    let colorHex: Int
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(Color(hex: colorHex).gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
            }
    }
}

#Preview(as: .systemSmall) {
    UpcomingRenewalsWidget()
} timeline: {
    RenewalsEntry.placeholder
}

#Preview(as: .systemMedium) {
    UpcomingRenewalsWidget()
} timeline: {
    RenewalsEntry.placeholder
}
