import Foundation

enum BillingCycle: String, Codable, CaseIterable, Identifiable {
    case weekly, monthly, quarterly, semiannual, yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .quarterly: "Every 3 months"
        case .semiannual: "Every 6 months"
        case .yearly: "Yearly"
        }
    }

    /// Short suffix used next to prices, e.g. "$9.99/mo".
    var suffix: String {
        switch self {
        case .weekly: "/wk"
        case .monthly: "/mo"
        case .quarterly: "/3mo"
        case .semiannual: "/6mo"
        case .yearly: "/yr"
        }
    }

    var component: Calendar.Component {
        self == .weekly ? .weekOfYear : .month
    }

    var step: Int {
        switch self {
        case .weekly, .monthly: 1
        case .quarterly: 3
        case .semiannual: 6
        case .yearly: 12
        }
    }

    /// How many times this cycle bills per year.
    var periodsPerYear: Double {
        switch self {
        case .weekly: 52
        case .monthly: 12
        case .quarterly: 4
        case .semiannual: 2
        case .yearly: 1
        }
    }
}
