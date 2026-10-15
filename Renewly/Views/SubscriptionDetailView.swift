import SwiftData
import SwiftUI

struct SubscriptionDetailView: View {
    @Bindable var subscription: Subscription

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency
    @State private var editing = false
    @State private var confirmingDelete = false

    private var upcoming: [Date] {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .year, value: 2, to: start)!
        return Array(subscription.renewals(in: DateInterval(start: start, end: end)).prefix(6))
    }

    /// Estimated total paid so far, counting every renewal up to and including today.
    private var paidSoFar: Double {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now))!
        guard subscription.firstBillingDate < tomorrow else { return 0 }
        let count = subscription.renewals(in: DateInterval(start: subscription.firstBillingDate, end: tomorrow)).count
        return Double(count) * subscription.price
    }

    private var reminderText: String {
        SubscriptionEditorView.reminderOptions.first { $0.0 == subscription.reminderDaysBefore }?.1 ?? "None"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                nextPaymentCard
                statsRow
                upcomingCard
                detailsCard
                if !subscription.notes.isEmpty { notesCard }
                actions
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") { editing = true }
        }
        .sheet(isPresented: $editing) { SubscriptionEditorView(subscription: subscription) }
        .confirmationDialog("Delete \(subscription.name)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                context.delete(subscription)
                try? context.save()
                NotificationScheduler.shared.reschedule((try? context.fetch(FetchDescriptor<Subscription>())) ?? [])
                dismiss()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            SubscriptionIcon(symbol: subscription.symbol, color: subscription.color, size: 84)
                .saturation(subscription.isPaused ? 0 : 1)
            HStack(spacing: 8) {
                Text(subscription.name)
                    .font(.title.bold())
                if subscription.isTrial { TrialBadge() }
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(subscription.price.currency(currency))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text(subscription.cycle.suffix)
                    .foregroundStyle(.secondary)
            }
            Label(subscription.category.title, systemImage: subscription.category.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(subscription.category.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(subscription.category.color.opacity(0.12), in: Capsule())
        }
        .padding(.top, 8)
    }

    private var nextPaymentCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.isPaused ? "Paused" : (subscription.isTrial ? "Trial ends" : "Next payment"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                Text(subscription.isPaused
                     ? "No upcoming charges"
                     : subscription.nextRenewal().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            Spacer()
            if !subscription.isPaused {
                let days = subscription.daysUntilRenewal()
                VStack(spacing: 0) {
                    Text("\(days)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text(days == 1 ? "day" : "days")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
            }
        }
        .padding(20)
        .background(subscription.color.gradient.opacity(subscription.isPaused ? 0.4 : 1),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .saturation(subscription.isPaused ? 0 : 1)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            stat("Per month", subscription.monthlyCost.currency(currency))
            stat("Per year", subscription.yearlyCost.currency(currency))
            stat("Paid so far", paidSoFar.currency(currency))
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var upcomingCard: some View {
        if !subscription.isPaused {
            card(title: "Upcoming payments") {
                ForEach(Array(upcoming.enumerated()), id: \.offset) { index, date in
                    HStack {
                        Circle()
                            .fill(index == 0 ? subscription.color : Color(.tertiaryLabel))
                            .frame(width: 8, height: 8)
                        Text(date, format: .dateTime.day().month(.wide).year())
                        Spacer()
                        Text(subscription.price.currency(currency))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .padding(.vertical, 10)
                    if index < upcoming.count - 1 { Divider() }
                }
            }
        }
    }

    private var detailsCard: some View {
        card(title: "Details") {
            detailRow("Repeats", subscription.cycle.title)
            Divider()
            detailRow("Reminder", reminderText)
            Divider()
            detailRow("Started", subscription.firstBillingDate.formatted(date: .abbreviated, time: .omitted))
            if let link = URL(string: subscription.url), !subscription.url.isEmpty {
                Divider()
                HStack {
                    Text("Website").foregroundStyle(.secondary)
                    Spacer()
                    Link(link.host() ?? subscription.url, destination: link.scheme == nil
                         ? URL(string: "https://\(subscription.url)") ?? link : link)
                        .lineLimit(1)
                }
                .font(.subheadline)
                .padding(.vertical, 10)
            }
        }
    }

    private var notesCard: some View {
        card(title: "Notes") {
            Text(subscription.notes)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.snappy) { subscription.isPaused.toggle() }
                try? context.save()
                NotificationScheduler.shared.reschedule((try? context.fetch(FetchDescriptor<Subscription>())) ?? [])
            } label: {
                Label(subscription.isPaused ? "Resume subscription" : "Pause subscription",
                      systemImage: subscription.isPaused ? "play.fill" : "pause.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .tint(subscription.isPaused ? .green : .orange)

            Button(role: .destructive) {
                confirmingDelete = true
            } label: {
                Label("Delete", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
        }
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .sensoryFeedback(.impact, trigger: subscription.isPaused)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
        .padding(.vertical, 10)
    }

    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 4)
            content()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
