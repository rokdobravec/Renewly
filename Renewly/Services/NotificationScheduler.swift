import Foundation
import UserNotifications

/// Schedules one local reminder per active subscription ahead of its next renewal.
@MainActor
final class NotificationScheduler {
    static let shared = NotificationScheduler()
    static let reminderHour = 9
    private let center = UNUserNotificationCenter.current()
    private let idPrefix = "renewal-"

    /// Asks for permission; returns whether reminders can be delivered.
    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Replaces every pending renewal reminder with a fresh set derived from `subscriptions`.
    func reschedule(_ subscriptions: [Subscription], currencyCode: String? = nil) {
        let code = currencyCode
            ?? UserDefaults.standard.string(forKey: AppSettings.currencyKey)
            ?? AppSettings.defaultCurrency
        let calendar = Calendar.current
        let now = Date.now
        let requests: [UNNotificationRequest] = subscriptions.compactMap { sub in
            guard !sub.isPaused, sub.reminderDaysBefore >= 0 else { return nil }
            // Use the first renewal whose reminder time is still in the future.
            var renewal = sub.nextRenewal(after: now)
            var fireDate = reminderDate(for: renewal, daysBefore: sub.reminderDaysBefore, calendar: calendar)
            if fireDate <= now {
                renewal = sub.nextRenewal(after: calendar.date(byAdding: .day, value: 1, to: renewal)!)
                fireDate = reminderDate(for: renewal, daysBefore: sub.reminderDaysBefore, calendar: calendar)
            }

            let content = UNMutableNotificationContent()
            content.title = sub.isTrial ? "\(sub.name) trial ends soon" : "\(sub.name) renews soon"
            let when: String = switch sub.reminderDaysBefore {
            case 0: "today"
            case 1: "tomorrow"
            default: "on \(renewal.formatted(.dateTime.weekday(.wide).day().month(.wide)))"
            }
            content.body = sub.isTrial
                ? "Your free trial converts to \(sub.price.currency(code)) \(when). Cancel now if you don't want it."
                : "\(sub.price.currency(code)) will be charged \(when)."
            content.sound = .default
            content.threadIdentifier = "renewals"

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            return UNNotificationRequest(identifier: idPrefix + sub.id.uuidString, content: content, trigger: trigger)
        }

        Task {
            let pending = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(
                withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) })
            // iOS keeps at most 64 pending notifications; keep the soonest.
            let sorted = requests.sorted {
                (($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture)
                    < (($1.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture)
            }
            for request in sorted.prefix(64) {
                try? await center.add(request)
            }
        }
    }

    private func reminderDate(for renewal: Date, daysBefore: Int, calendar: Calendar) -> Date {
        let day = calendar.date(byAdding: .day, value: -daysBefore, to: calendar.startOfDay(for: renewal))!
        return calendar.date(bySettingHour: Self.reminderHour, minute: 0, second: 0, of: day)!
    }
}
