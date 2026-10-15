import SwiftUI

enum SubscriptionCategory: String, Codable, CaseIterable, Identifiable {
    case entertainment, music, productivity, cloud, fitness, news, gaming, education, utilities, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .entertainment: "Entertainment"
        case .music: "Music"
        case .productivity: "Productivity"
        case .cloud: "Cloud & Storage"
        case .fitness: "Health & Fitness"
        case .news: "News & Reading"
        case .gaming: "Gaming"
        case .education: "Education"
        case .utilities: "Utilities"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .entertainment: "play.tv.fill"
        case .music: "music.note"
        case .productivity: "briefcase.fill"
        case .cloud: "icloud.fill"
        case .fitness: "figure.run"
        case .news: "newspaper.fill"
        case .gaming: "gamecontroller.fill"
        case .education: "graduationcap.fill"
        case .utilities: "bolt.fill"
        case .other: "square.grid.2x2.fill"
        }
    }

    var color: Color {
        switch self {
        case .entertainment: Color(hex: 0xFF453A)
        case .music: Color(hex: 0xFF2D78)
        case .productivity: Color(hex: 0x5E5CE6)
        case .cloud: Color(hex: 0x0A84FF)
        case .fitness: Color(hex: 0x30D158)
        case .news: Color(hex: 0xFF9F0A)
        case .gaming: Color(hex: 0xBF5AF2)
        case .education: Color(hex: 0x64D2FF)
        case .utilities: Color(hex: 0xFFD60A)
        case .other: Color(hex: 0x8E8E93)
        }
    }
}
