import SwiftUI

/// Rounded tile showing a subscription's symbol on its brand color.
struct SubscriptionIcon: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 44

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
            }
            .shadow(color: color.opacity(0.35), radius: size * 0.12, y: size * 0.06)
    }
}

/// "Today" / "Tomorrow" / "in 5 days" capsule, colored by urgency.
struct RenewalBadge: View {
    let days: Int

    private var label: String {
        switch days {
        case 0: "Today"
        case 1: "Tomorrow"
        default: "in \(days) days"
        }
    }

    private var tint: Color {
        switch days {
        case 0...1: .red
        case 2...3: .orange
        case 4...7: .blue
        default: .secondary
        }
    }

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(days <= 7 ? tint : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(days <= 7 ? 0.15 : 0.1), in: Capsule())
    }
}

struct TrialBadge: View {
    var body: some View {
        Text("TRIAL")
            .font(.system(size: 9, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.orange.gradient, in: Capsule())
    }
}

extension EnvironmentValues {
    /// True on short screens such as the 4.7" iPhone SE, where the dashboard uses tighter layouts.
    @Entry var isCompactScreen = false
}
