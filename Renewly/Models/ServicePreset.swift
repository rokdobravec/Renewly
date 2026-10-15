import Foundation

/// A popular service the user can pick to prefill the editor.
struct ServicePreset: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let price: Double
    let cycle: BillingCycle
    let category: SubscriptionCategory
    let symbol: String
    let colorHex: Int

    static let all: [ServicePreset] = [
        .init(name: "Netflix", price: 15.49, cycle: .monthly, category: .entertainment, symbol: "play.rectangle.fill", colorHex: 0xE50914),
        .init(name: "Spotify", price: 11.99, cycle: .monthly, category: .music, symbol: "music.note", colorHex: 0x1DB954),
        .init(name: "Apple Music", price: 10.99, cycle: .monthly, category: .music, symbol: "music.quarternote.3", colorHex: 0xFA2D48),
        .init(name: "iCloud+", price: 2.99, cycle: .monthly, category: .cloud, symbol: "icloud.fill", colorHex: 0x0A84FF),
        .init(name: "YouTube Premium", price: 13.99, cycle: .monthly, category: .entertainment, symbol: "play.fill", colorHex: 0xFF0000),
        .init(name: "Disney+", price: 13.99, cycle: .monthly, category: .entertainment, symbol: "sparkles.tv.fill", colorHex: 0x113CCF),
        .init(name: "Max", price: 16.99, cycle: .monthly, category: .entertainment, symbol: "tv.fill", colorHex: 0x002BE7),
        .init(name: "Apple TV+", price: 9.99, cycle: .monthly, category: .entertainment, symbol: "appletv.fill", colorHex: 0x1C1C1E),
        .init(name: "ChatGPT Plus", price: 20.00, cycle: .monthly, category: .productivity, symbol: "bubble.left.and.text.bubble.right.fill", colorHex: 0x10A37F),
        .init(name: "Claude Pro", price: 20.00, cycle: .monthly, category: .productivity, symbol: "sparkle", colorHex: 0xD97757),
        .init(name: "Notion", price: 10.00, cycle: .monthly, category: .productivity, symbol: "doc.text.fill", colorHex: 0x37352F),
        .init(name: "Figma", price: 15.00, cycle: .monthly, category: .productivity, symbol: "paintpalette.fill", colorHex: 0xA259FF),
        .init(name: "Microsoft 365", price: 99.99, cycle: .yearly, category: .productivity, symbol: "square.grid.2x2.fill", colorHex: 0xD83B01),
        .init(name: "Adobe Creative Cloud", price: 59.99, cycle: .monthly, category: .productivity, symbol: "camera.aperture", colorHex: 0xFF0000),
        .init(name: "Dropbox", price: 11.99, cycle: .monthly, category: .cloud, symbol: "shippingbox.fill", colorHex: 0x0061FF),
        .init(name: "Google One", price: 1.99, cycle: .monthly, category: .cloud, symbol: "externaldrive.fill.badge.icloud", colorHex: 0x4285F4),
        .init(name: "Amazon Prime", price: 139.00, cycle: .yearly, category: .utilities, symbol: "shippingbox.circle.fill", colorHex: 0xFF9900),
        .init(name: "Xbox Game Pass", price: 19.99, cycle: .monthly, category: .gaming, symbol: "gamecontroller.fill", colorHex: 0x107C10),
        .init(name: "PlayStation Plus", price: 79.99, cycle: .yearly, category: .gaming, symbol: "playstation.logo", colorHex: 0x003791),
        .init(name: "Duolingo Super", price: 59.99, cycle: .yearly, category: .education, symbol: "character.bubble.fill", colorHex: 0x58CC02),
        .init(name: "Strava", price: 79.99, cycle: .yearly, category: .fitness, symbol: "figure.run", colorHex: 0xFC4C02),
        .init(name: "Gym Membership", price: 39.00, cycle: .monthly, category: .fitness, symbol: "dumbbell.fill", colorHex: 0x30D158),
        .init(name: "The New York Times", price: 4.00, cycle: .weekly, category: .news, symbol: "newspaper.fill", colorHex: 0x1C1C1E),
        .init(name: "Medium", price: 50.00, cycle: .yearly, category: .news, symbol: "text.book.closed.fill", colorHex: 0x292929),
    ]
}
