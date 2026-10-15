import SwiftUI

struct SubscriptionRow: View {
    let subscription: Subscription
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency

    @Environment(\.isCompactScreen) private var compact

    var body: some View {
        HStack(spacing: compact ? 10 : 14) {
            SubscriptionIcon(symbol: subscription.symbol, color: subscription.color, size: compact ? 38 : 44)
                .saturation(subscription.isPaused ? 0 : 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(subscription.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    if subscription.isTrial { TrialBadge() }
                }
                Text(subscription.isPaused
                     ? "Paused"
                     : subscription.nextRenewal().formatted(.dateTime.day().month(.abbreviated).weekday(.abbreviated)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            // The name gets space before the price, which can shrink slightly instead.
            .layoutPriority(1)

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(subscription.price.currency(currency))
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(subscription.cycle.suffix)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !subscription.isPaused {
                    RenewalBadge(days: subscription.daysUntilRenewal())
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(subscription.isPaused ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }
}
