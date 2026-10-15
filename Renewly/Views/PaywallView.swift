import StoreKit
import SwiftUI

/// Sheet offering the one-time "Renewly Pro" unlock.
struct PaywallView: View {
    /// What the user was trying to do when the paywall appeared.
    enum Reason: String, Identifiable {
        case limit, insights, export, upgrade

        var id: String { rawValue }

        var message: String {
            switch self {
            case .limit: "The free plan tracks up to \(ProStore.freeLimit) subscriptions. Go Pro to add as many as you like."
            case .insights: "See where your money goes with charts by category and a 12-month forecast."
            case .export: "Take your data anywhere with a spreadsheet-ready CSV export."
            case .upgrade: "Everything Renewly can do, unlocked forever with a single purchase."
            }
        }
    }

    var reason: Reason = .upgrade

    @Environment(ProStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var unlocked = false

    private static let features: [(symbol: String, color: Color, title: String, detail: String)] = [
        ("infinity", Color(hex: 0x5E5CE6), "Unlimited subscriptions", "Track every service, not just \(ProStore.freeLimit)."),
        ("chart.pie.fill", Color(hex: 0xBF5AF2), "Insights", "Spending by category and a 12-month forecast."),
        ("tablecells.fill", Color(hex: 0x30D158), "CSV export", "Open your data in Numbers, Excel or Sheets."),
        ("heart.fill", Color(hex: 0xFF2D78), "Pay once, keep forever", "No subscription to track. Ironic, we know."),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Self.features, id: \.title) { feature in
                        featureRow(feature)
                    }
                }
                .padding(.horizontal, 28)
            }
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .ignoresSafeArea(edges: .top)
        .safeAreaInset(edge: .bottom) { footer }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.2), in: Circle())
            }
            .padding(16)
            .accessibilityLabel("Close")
        }
        .sensoryFeedback(.success, trigger: unlocked)
        .task {
            // The App Store can return nothing on a slow or flaky connection; keep trying while the paywall is open.
            for attempt in 0..<6 where store.product == nil {
                if attempt > 0 { try? await Task.sleep(for: .seconds(2)) }
                await store.loadProduct()
            }
        }
        .onDisappear { store.clearError() }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(.white.opacity(0.16)).frame(width: 96, height: 96)
                Image(systemName: unlocked ? "checkmark.seal.fill" : "crown.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.top, 8)

            Text(unlocked ? "You're Pro!" : "Renewly Pro")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.opacity)

            Text(unlocked ? "Thanks for supporting Renewly. Everything is unlocked." : reason.message)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 64)
        .padding(.bottom, 32)
        .background {
            ZStack {
                LinearGradient(colors: [Color(hex: 0x4540F2), Color(hex: 0x9E4DFA)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(.white.opacity(0.12)).frame(width: 260).offset(x: 150, y: -110)
                Circle().fill(.white.opacity(0.07)).frame(width: 190).offset(x: -160, y: 110)
            }
        }
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 32, bottomTrailingRadius: 32, style: .continuous))
        .shadow(color: Color(hex: 0x4540F2).opacity(0.25), radius: 12, y: 6)
    }

    private func featureRow(_ feature: (symbol: String, color: Color, title: String, detail: String)) -> some View {
        HStack(spacing: 14) {
            SubscriptionIcon(symbol: feature.symbol, color: feature.color, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title).font(.headline)
                Text(feature.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if case .failed(let message) = store.purchaseState {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            } else if store.purchaseState == .pending {
                Text("Your purchase is waiting for approval. Pro unlocks as soon as it's approved.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                if unlocked || store.isPro {
                    dismiss()
                } else {
                    Task { await buy() }
                }
            } label: {
                ZStack {
                    if store.purchaseState == .purchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(buttonTitle)
                            .font(.headline)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    LinearGradient(colors: [Color(hex: 0x4540F2), Color(hex: 0x9E4DFA)],
                                   startPoint: .leading, endPoint: .trailing),
                    in: Capsule()
                )
                .shadow(color: Color(hex: 0x6A46F6).opacity(0.35), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
            .disabled(store.purchaseState == .purchasing || store.isRestoring)
            .accessibilityIdentifier("paywall.purchase")

            HStack(spacing: 6) {
                if !store.isPro {
                    Button {
                        Task {
                            if await store.restore() { withAnimation(.snappy) { unlocked = true } }
                        }
                    } label: {
                        if store.isRestoring {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Restore Purchases")
                        }
                    }
                    .disabled(store.purchaseState == .purchasing || store.isRestoring)
                    Text("·").foregroundStyle(.tertiary)
                }
                Text("One-time purchase")
                    .foregroundStyle(.secondary)
            }
            .font(.footnote.weight(.medium))
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private var buttonTitle: String {
        if unlocked || store.isPro { return "Done" }
        if let product = store.product { return "Unlock for \(product.displayPrice)" }
        return "Unlock Renewly Pro"
    }

    private func buy() async {
        if await store.purchase() {
            withAnimation(.snappy) { unlocked = true }
        }
    }
}

/// Small gradient "PRO" capsule marking features that need the unlock.
struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                LinearGradient(colors: [Color(hex: 0x4540F2), Color(hex: 0x9E4DFA)],
                               startPoint: .leading, endPoint: .trailing),
                in: Capsule()
            )
    }
}
