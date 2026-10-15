import Foundation
import SwiftData

enum SampleData {
    /// Inserts a realistic set of subscriptions with renewals spread over the coming weeks.
    /// `limit` caps how many are added, so the free plan's sample stays within its subscription limit.
    @MainActor
    static func insert(into context: ModelContext, limit: Int = .max, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: .now)
        func monthsAgo(_ months: Int, plusDays days: Int) -> Date {
            let base = calendar.date(byAdding: .month, value: -months, to: today)!
            return calendar.date(byAdding: .day, value: days, to: base)!
        }
        let picks: [(String, Date, Bool)] = [
            ("Netflix", monthsAgo(14, plusDays: 2), false),
            ("Spotify", monthsAgo(30, plusDays: 5), false),
            ("iCloud+", monthsAgo(40, plusDays: 9), false),
            ("Figma", monthsAgo(6, plusDays: 14), false),
            ("ChatGPT Plus", monthsAgo(4, plusDays: 0), false),
            ("Amazon Prime", monthsAgo(10, plusDays: 21), false),
            ("Duolingo Super", calendar.date(byAdding: .day, value: 6, to: today)!, true),
            ("Gym Membership", monthsAgo(18, plusDays: 18), false),
            ("Disney+", monthsAgo(8, plusDays: 26), false),
        ]
        for (name, date, trial) in picks.prefix(limit) {
            guard let preset = ServicePreset.all.first(where: { $0.name == name }) else { continue }
            context.insert(Subscription(name: preset.name, price: preset.price, cycle: preset.cycle,
                                        category: preset.category, symbol: preset.symbol,
                                        colorHex: preset.colorHex, firstBillingDate: date,
                                        reminderDaysBefore: trial ? 2 : 1, isTrial: trial))
        }
        try? context.save()
    }
}
