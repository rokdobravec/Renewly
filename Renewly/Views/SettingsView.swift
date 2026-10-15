import SwiftData
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ProStore.self) private var store
    @Query(sort: \Subscription.name) private var subscriptions: [Subscription]
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var confirmingDeleteAll = false
    @State private var paywallReason: PaywallView.Reason?

    private static let currencies = ["USD", "EUR", "GBP", "CHF", "CAD", "AUD", "JPY", "CNY", "INR", "BRL",
                                     "MXN", "SEK", "NOK", "DKK", "PLN", "CZK", "HUF", "TRY", "KRW", "SGD", "NZD", "ZAR"]

    private var currencyOptions: [String] {
        Self.currencies.contains(currency) ? Self.currencies : [currency] + Self.currencies
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    proRow
                }

                Section {
                    Picker(selection: $currency) {
                        ForEach(currencyOptions, id: \.self) { code in
                            Text("\(code) · \(Locale.current.localizedString(forCurrencyCode: code) ?? code)").tag(code)
                        }
                    } label: {
                        Label("Currency", systemImage: "dollarsign.circle.fill")
                    }
                } footer: {
                    Text("Prices are shown in this currency. Existing amounts aren't converted.")
                }

                Section("Reminders") {
                    HStack {
                        Label("Notifications", systemImage: "bell.badge.fill")
                        Spacer()
                        switch notificationStatus {
                        case .authorized, .provisional, .ephemeral:
                            Text("On").foregroundStyle(.secondary)
                        case .denied:
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            }
                        default:
                            Button("Turn on") {
                                Task {
                                    await NotificationScheduler.shared.requestAuthorization()
                                    NotificationScheduler.shared.reschedule(subscriptions)
                                    await refreshStatus()
                                }
                            }
                        }
                    }
                    if notificationStatus == .denied {
                        Text("Reminders are off. Turn on notifications for Renewly in Settings so you're never surprised by a charge.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Your data") {
                    if store.isPro {
                        ShareLink(item: CSVExport(subscriptions: subscriptions, currency: currency),
                                  preview: SharePreview("Renewly subscriptions.csv")) {
                            Label("Export as CSV", systemImage: "square.and.arrow.up")
                        }
                        .disabled(subscriptions.isEmpty)
                    } else {
                        Button {
                            paywallReason = .export
                        } label: {
                            HStack {
                                Label("Export as CSV", systemImage: "square.and.arrow.up")
                                Spacer()
                                ProBadge()
                            }
                        }
                    }

                    if subscriptions.isEmpty {
                        Button {
                            SampleData.insert(into: context, limit: store.isPro ? .max : ProStore.freeLimit)
                        } label: {
                            Label("Load sample data", systemImage: "sparkles")
                        }
                    } else {
                        Button(role: .destructive) {
                            confirmingDeleteAll = true
                        } label: {
                            Label("Delete all subscriptions", systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }

                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Private by design")
                            Text("Everything stays on your iPhone. No accounts, no tracking, no bank access.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "lock.shield.fill").foregroundStyle(.green)
                    }
                    LabeledContent("Version", value: Bundle.main.appVersion)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Delete all \(subscriptions.count) subscriptions?",
                                isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
                Button("Delete all", role: .destructive) {
                    for sub in subscriptions { context.delete(sub) }
                    try? context.save()
                    NotificationScheduler.shared.reschedule([])
                }
            } message: {
                Text("This can't be undone.")
            }
            .sheet(item: $paywallReason) { PaywallView(reason: $0) }
            .task { await refreshStatus() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshStatus() } }
            }
            .onChange(of: currency) {
                NotificationScheduler.shared.reschedule(subscriptions, currencyCode: currency)
            }
        }
    }

    @ViewBuilder
    private var proRow: some View {
        if store.isPro {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Renewly Pro")
                    Text("Unlocked. Thanks for your support!")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "crown.fill").foregroundStyle(Color(hex: 0x7A46F6))
            }
        } else {
            Button {
                paywallReason = .upgrade
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "crown.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Upgrade to Renewly Pro")
                            .font(.headline)
                        Text("Unlimited subscriptions, Insights & CSV export")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.bold())
                        .foregroundStyle(.white.opacity(0.7))
                }
                .foregroundStyle(.white)
                .padding(.vertical, 6)
            }
            .listRowBackground(
                LinearGradient(colors: [Color(hex: 0x4540F2), Color(hex: 0x9E4DFA)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .accessibilityIdentifier("settings.upgrade")
        }
    }

    private func refreshStatus() async {
        notificationStatus = await NotificationScheduler.shared.authorizationStatus()
    }
}

/// CSV file of all subscriptions, shared through the system share sheet.
struct CSVExport: Transferable {
    /// Rendered up front so the export holds plain text, not model objects, when the share sheet reads it.
    let csv: String

    init(subscriptions: [Subscription], currency: String) {
        func escape(_ value: String) -> String {
            value.contains(where: { ",\"\n".contains($0) })
                ? "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\"" : value
        }
        let header = "Name,Price,Currency,Cycle,Category,Next renewal,Monthly cost,Yearly cost,Status,Notes"
        let iso = Date.ISO8601FormatStyle().year().month().day()
        let rows = subscriptions.map { sub in
            [escape(sub.name),
             String(format: "%.2f", sub.price),
             currency,
             sub.cycle.title,
             sub.category.title,
             sub.nextRenewal().formatted(iso),
             String(format: "%.2f", sub.monthlyCost),
             String(format: "%.2f", sub.yearlyCost),
             sub.isPaused ? "Paused" : (sub.isTrial ? "Trial" : "Active"),
             escape(sub.notes)].joined(separator: ",")
        }
        csv = ([header] + rows).joined(separator: "\n")
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { export in
            Data(export.csv.utf8)
        }
        .suggestedFileName("Renewly subscriptions.csv")
    }
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
