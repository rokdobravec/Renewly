import Foundation
import SwiftData
import SwiftUI

@Model
final class Subscription {
    var id: UUID = UUID()
    var name: String = ""
    var price: Double = 0
    var cycleRaw: String = BillingCycle.monthly.rawValue
    var categoryRaw: String = SubscriptionCategory.other.rawValue
    /// SF Symbol shown in the subscription's icon tile.
    var symbol: String = "creditcard.fill"
    var colorHex: Int = 0x5E5CE6
    /// The first billing date; future renewals are derived from it.
    var firstBillingDate: Date = Date.now
    /// Days before renewal to send a reminder, or -1 for no reminder.
    var reminderDaysBefore: Int = 1
    var isPaused: Bool = false
    var isTrial: Bool = false
    var notes: String = ""
    var url: String = ""
    var createdAt: Date = Date.now

    init(name: String, price: Double, cycle: BillingCycle, category: SubscriptionCategory,
         symbol: String, colorHex: Int, firstBillingDate: Date,
         reminderDaysBefore: Int = 1, isTrial: Bool = false, notes: String = "", url: String = "") {
        self.name = name
        self.price = price
        self.cycleRaw = cycle.rawValue
        self.categoryRaw = category.rawValue
        self.symbol = symbol
        self.colorHex = colorHex
        self.firstBillingDate = firstBillingDate
        self.reminderDaysBefore = reminderDaysBefore
        self.isTrial = isTrial
        self.notes = notes
        self.url = url
    }

    var cycle: BillingCycle {
        get { BillingCycle(rawValue: cycleRaw) ?? .monthly }
        set { cycleRaw = newValue.rawValue }
    }

    var category: SubscriptionCategory {
        get { SubscriptionCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var color: Color { Color(hex: colorHex) }

    var monthlyCost: Double { price * cycle.periodsPerYear / 12 }
    var yearlyCost: Double { price * cycle.periodsPerYear }

    /// The renewal date `offset` cycles after the first billing date.
    func renewal(at offset: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: cycle.component, value: offset * cycle.step, to: firstBillingDate) ?? firstBillingDate
    }

    /// Index of the first renewal falling on or after the start of `date`'s day.
    private func nextRenewalOffset(after date: Date, calendar: Calendar) -> Int {
        let today = calendar.startOfDay(for: date)
        guard firstBillingDate < today else { return 0 }
        let elapsed = calendar.dateComponents([cycle.component], from: firstBillingDate, to: today)
        let units = cycle == .weekly ? (elapsed.weekOfYear ?? 0) : (elapsed.month ?? 0)
        var offset = max(0, units / cycle.step)
        while renewal(at: offset, calendar: calendar) < today { offset += 1 }
        return offset
    }

    /// The first renewal falling on or after the start of `date`'s day.
    /// Always adds from the first billing date so month-end dates don't drift (Jan 31 → Feb 28 → Mar 31).
    func nextRenewal(after date: Date = .now, calendar: Calendar = .current) -> Date {
        renewal(at: nextRenewalOffset(after: date, calendar: calendar), calendar: calendar)
    }

    /// Whole days from today until the next renewal.
    func daysUntilRenewal(from date: Date = .now, calendar: Calendar = .current) -> Int {
        let next = nextRenewal(after: date, calendar: calendar)
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: date),
                                       to: calendar.startOfDay(for: next)).day ?? 0
    }

    /// All renewal dates inside `interval`, used for calendar and month totals.
    func renewals(in interval: DateInterval, calendar: Calendar = .current) -> [Date] {
        var dates: [Date] = []
        var offset = nextRenewalOffset(after: interval.start, calendar: calendar)
        var date = renewal(at: offset, calendar: calendar)
        while date < interval.end {
            dates.append(date)
            offset += 1
            date = renewal(at: offset, calendar: calendar)
        }
        return dates
    }
}

extension Color {
    init(hex: Int) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
