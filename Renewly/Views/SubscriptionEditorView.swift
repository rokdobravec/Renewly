import SwiftData
import SwiftUI

struct SubscriptionEditorView: View {
    /// The subscription to edit, or nil to create a new one.
    let subscription: Subscription?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ProStore.self) private var store
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency

    @State private var name = ""
    @State private var price: Double?
    @State private var cycle: BillingCycle = .monthly
    @State private var category: SubscriptionCategory = .entertainment
    @State private var symbol = "creditcard.fill"
    @State private var colorHex = 0x5E5CE6
    @State private var firstBillingDate = Calendar.current.startOfDay(for: .now)
    @State private var reminderDaysBefore = 1
    @State private var isTrial = false
    @State private var notes = ""
    @State private var url = ""
    @State private var confirmingDelete = false
    @State private var saved = false
    @State private var showingPaywall = false
    @FocusState private var focusedField: Field?

    private enum Field { case name, price }

    private var isNew: Bool { subscription == nil }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (price ?? 0) > 0
    }

    static let reminderOptions: [(Int, String)] = [
        (-1, "None"), (0, "On the day"), (1, "1 day before"), (2, "2 days before"),
        (3, "3 days before"), (7, "1 week before"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                if isNew {
                    Section {
                        presetPicker
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    } header: {
                        Text("Popular")
                    }
                }

                Section {
                    HStack(spacing: 14) {
                        SubscriptionIcon(symbol: symbol, color: Color(hex: colorHex), size: 52)
                            .animation(.snappy, value: symbol)
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Name", text: $name)
                                .font(.title3.weight(.semibold))
                                .focused($focusedField, equals: .name)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .price }
                            TextField("Price", value: $price, format: .currency(code: currency))
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .price)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    NavigationLink {
                        AppearancePicker(symbol: $symbol, colorHex: $colorHex)
                    } label: {
                        Label("Icon & color", systemImage: "paintpalette")
                    }
                }

                Section("Billing") {
                    Picker("Repeats", selection: $cycle) {
                        ForEach(BillingCycle.allCases) { Text($0.title).tag($0) }
                    }
                    DatePicker("First payment", selection: $firstBillingDate, displayedComponents: .date)
                    Toggle("Free trial", isOn: $isTrial.animation())
                    if let price, price > 0 {
                        LabeledContent("Next payment") {
                            Text(previewNextRenewal, format: .dateTime.day().month(.wide).year())
                        }
                        LabeledContent("Costs you") {
                            Text("\((price * cycle.periodsPerYear / 12).currency(currency))/mo · \((price * cycle.periodsPerYear).currency(currency))/yr")
                                .monospacedDigit()
                        }
                    }
                }

                Section {
                    Picker("Category", selection: $category) {
                        ForEach(SubscriptionCategory.allCases) {
                            Label($0.title, systemImage: $0.symbol).tag($0)
                        }
                    }
                    Picker("Remind me", selection: $reminderDaysBefore) {
                        ForEach(Self.reminderOptions, id: \.0) { Text($0.1).tag($0.0) }
                    }
                } footer: {
                    if reminderDaysBefore >= 0 {
                        Text("You'll get a notification at \(NotificationScheduler.reminderHour):00 before each charge.")
                    }
                }

                Section("Notes") {
                    TextField("Website (optional)", text: $url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Plan, account, how to cancel…", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                if !isNew {
                    Section {
                        Button("Delete subscription", role: .destructive) { confirmingDelete = true }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(isNew ? "New subscription" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .confirmationDialog("Delete \(name)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive, action: delete)
            } message: {
                Text("Its reminders will be removed too.")
            }
            .sheet(isPresented: $showingPaywall) { PaywallView(reason: .limit) }
            .sensoryFeedback(.success, trigger: saved)
            .onAppear(perform: load)
        }
    }

    private var presetPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ServicePreset.all) { preset in
                    Button {
                        apply(preset)
                    } label: {
                        VStack(spacing: 6) {
                            SubscriptionIcon(symbol: preset.symbol, color: Color(hex: preset.colorHex), size: 46)
                            Text(preset.name)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        .frame(width: 72)
                        .padding(.vertical, 8)
                        .background {
                            if name == preset.name {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(hex: preset.colorHex).opacity(0.15))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .sensoryFeedback(.selection, trigger: name)
    }

    private var previewNextRenewal: Date {
        let probe = Subscription(name: name, price: price ?? 0, cycle: cycle, category: category,
                                 symbol: symbol, colorHex: colorHex, firstBillingDate: firstBillingDate)
        return probe.nextRenewal()
    }

    private func apply(_ preset: ServicePreset) {
        withAnimation(.snappy) {
            name = preset.name
            price = preset.price
            cycle = preset.cycle
            category = preset.category
            symbol = preset.symbol
            colorHex = preset.colorHex
        }
    }

    private func load() {
        guard let subscription else { return }
        name = subscription.name
        price = subscription.price
        cycle = subscription.cycle
        category = subscription.category
        symbol = subscription.symbol
        colorHex = subscription.colorHex
        firstBillingDate = subscription.firstBillingDate
        reminderDaysBefore = subscription.reminderDaysBefore
        isTrial = subscription.isTrial
        notes = subscription.notes
        url = subscription.url
    }

    private func save() {
        // Checked again here because subscriptions can be added elsewhere while the editor is open.
        if isNew, !store.canAdd(currentCount: (try? context.fetchCount(FetchDescriptor<Subscription>())) ?? 0) {
            showingPaywall = true
            return
        }
        let target = subscription ?? Subscription(name: "", price: 0, cycle: cycle, category: category,
                                                  symbol: symbol, colorHex: colorHex,
                                                  firstBillingDate: firstBillingDate)
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.price = price ?? 0
        target.cycle = cycle
        target.category = category
        target.symbol = symbol
        target.colorHex = colorHex
        target.firstBillingDate = Calendar.current.startOfDay(for: firstBillingDate)
        target.reminderDaysBefore = reminderDaysBefore
        target.isTrial = isTrial
        target.notes = notes
        target.url = url.trimmingCharacters(in: .whitespaces)
        if isNew { context.insert(target) }
        try? context.save()
        saved.toggle()

        let all = (try? context.fetch(FetchDescriptor<Subscription>())) ?? []
        let wantsReminder = reminderDaysBefore >= 0
        Task {
            if wantsReminder { await NotificationScheduler.shared.requestAuthorization() }
            NotificationScheduler.shared.reschedule(all)
        }
        dismiss()
    }

    private func delete() {
        guard let subscription else { return }
        context.delete(subscription)
        try? context.save()
        let all = (try? context.fetch(FetchDescriptor<Subscription>())) ?? []
        NotificationScheduler.shared.reschedule(all)
        dismiss()
    }
}

/// Lets the user pick a brand color and an SF Symbol for a subscription.
struct AppearancePicker: View {
    @Binding var symbol: String
    @Binding var colorHex: Int

    static let colors: [Int] = [
        0xFF453A, 0xFF9F0A, 0xFFD60A, 0x30D158, 0x10A37F, 0x64D2FF, 0x0A84FF, 0x5E5CE6,
        0xBF5AF2, 0xFF2D78, 0xD97757, 0xA2845E, 0x8E8E93, 0x1C1C1E,
    ]

    static let symbols: [String] = [
        "creditcard.fill", "play.rectangle.fill", "tv.fill", "music.note", "headphones", "film.fill",
        "gamecontroller.fill", "icloud.fill", "externaldrive.fill", "doc.text.fill", "paintpalette.fill",
        "camera.fill", "photo.fill", "newspaper.fill", "book.fill", "graduationcap.fill",
        "figure.run", "dumbbell.fill", "heart.fill", "leaf.fill", "cart.fill", "bag.fill",
        "shippingbox.fill", "car.fill", "bolt.fill", "wifi", "phone.fill", "house.fill",
        "lock.shield.fill", "key.fill", "sparkle", "star.fill", "globe", "cup.and.saucer.fill",
        "fork.knife", "pawprint.fill",
    ]

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    SubscriptionIcon(symbol: symbol, color: Color(hex: colorHex), size: 88)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .padding(.vertical, 8)
            }

            Section("Color") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 7), spacing: 12) {
                    ForEach(Self.colors, id: \.self) { hex in
                        Button {
                            withAnimation(.snappy) { colorHex = hex }
                        } label: {
                            Circle()
                                .fill(Color(hex: hex).gradient)
                                .frame(width: 34, height: 34)
                                .overlay {
                                    if hex == colorHex {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Color \(String(hex, radix: 16))")
                    }
                }
                .padding(.vertical, 6)
            }

            Section("Icon") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                    ForEach(Self.symbols, id: \.self) { name in
                        Button {
                            withAnimation(.snappy) { symbol = name }
                        } label: {
                            Image(systemName: name)
                                .font(.title3)
                                .frame(width: 44, height: 44)
                                .foregroundStyle(name == symbol ? .white : .primary)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(name == symbol ? Color(hex: colorHex) : Color(.tertiarySystemFill))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("Icon & color")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: symbol)
        .sensoryFeedback(.selection, trigger: colorHex)
    }
}
