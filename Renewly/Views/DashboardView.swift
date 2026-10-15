import SwiftData
import SwiftUI

enum SortOrder: String, CaseIterable, Identifiable {
    case renewal = "Next renewal"
    case price = "Monthly cost"
    case name = "Name"
    var id: String { rawValue }
}

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Environment(ProStore.self) private var store
    @Query private var subscriptions: [Subscription]
    @AppStorage("sortOrder") private var sortOrder: SortOrder = .renewal
    @State private var searchText = ""
    @State private var showingEditor = false
    @State private var editing: Subscription?
    @State private var showingPaywall = false

    private var filtered: [Subscription] {
        guard !searchText.isEmpty else { return subscriptions }
        return subscriptions.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var active: [Subscription] {
        let items = filtered.filter { !$0.isPaused }
        switch sortOrder {
        case .renewal: return items.sorted { $0.nextRenewal() < $1.nextRenewal() }
        case .price: return items.sorted { $0.monthlyCost > $1.monthlyCost }
        case .name: return items.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        }
    }

    private var paused: [Subscription] {
        filtered.filter(\.isPaused).sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            Group {
                if subscriptions.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Renewly")
            .toolbar {
                if !subscriptions.isEmpty {
                    ToolbarItem(placement: .topBarLeading) { sortMenu }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addSubscription()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("Add subscription")
                }
            }
            .navigationDestination(for: Subscription.self) { SubscriptionDetailView(subscription: $0) }
            .sheet(isPresented: $showingEditor) { SubscriptionEditorView(subscription: nil) }
            .sheet(item: $editing) { SubscriptionEditorView(subscription: $0) }
            .sheet(isPresented: $showingPaywall) { PaywallView(reason: .limit) }
        }
    }

    private var list: some View {
        List {
            if searchText.isEmpty {
                Section {
                    SummaryCard(active: subscriptions.filter { !$0.isPaused })
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                }
            }

            if !active.isEmpty {
                Section {
                    ForEach(active) { row($0) }
                } header: {
                    sectionHeader(sortOrder == .renewal ? "Upcoming" : "Active")
                }
            }

            if !paused.isEmpty {
                Section {
                    ForEach(paused) { row($0) }
                } header: {
                    sectionHeader("Paused")
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Search subscriptions")
        .overlay {
            if !searchText.isEmpty && filtered.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .animation(.snappy, value: subscriptions.map(\.isPaused))
        .animation(.snappy, value: sortOrder)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3.bold())
            .foregroundStyle(.primary)
            .textCase(nil)
            .padding(.leading, -4)
    }

    private func row(_ subscription: Subscription) -> some View {
        NavigationLink(value: subscription) {
            SubscriptionRow(subscription: subscription)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                delete(subscription)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                editing = subscription
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.indigo)
        }
        .swipeActions(edge: .leading) {
            Button {
                togglePause(subscription)
            } label: {
                Label(subscription.isPaused ? "Resume" : "Pause",
                      systemImage: subscription.isPaused ? "play.fill" : "pause.fill")
            }
            .tint(subscription.isPaused ? .green : .orange)
        }
        .contextMenu {
            Button { editing = subscription } label: { Label("Edit", systemImage: "pencil") }
            Button { togglePause(subscription) } label: {
                Label(subscription.isPaused ? "Resume" : "Pause",
                      systemImage: subscription.isPaused ? "play" : "pause")
            }
            Divider()
            Button(role: .destructive) { delete(subscription) } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $sortOrder) {
                ForEach(SortOrder.allCases) { Text($0.rawValue).tag($0) }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
                .font(.title3)
        }
        .accessibilityLabel("Sort")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text("No subscriptions yet")
            } icon: {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
            }
        } description: {
            Text("Add the services you pay for and Renewly will show what's due and remind you before every charge.")
        } actions: {
            Button {
                addSubscription()
            } label: {
                Label("Add subscription", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)

            Button("Try with sample data") {
                withAnimation {
                    SampleData.insert(into: context, limit: store.isPro ? .max : ProStore.freeLimit)
                }
            }
            .font(.subheadline)
        }
    }

    /// Opens the editor, or the paywall once the free plan is full.
    private func addSubscription() {
        if store.canAdd(currentCount: subscriptions.count) {
            showingEditor = true
        } else {
            showingPaywall = true
        }
    }

    private func togglePause(_ subscription: Subscription) {
        withAnimation { subscription.isPaused.toggle() }
        NotificationScheduler.shared.reschedule(subscriptions)
    }

    private func delete(_ subscription: Subscription) {
        withAnimation { context.delete(subscription) }
        try? context.save()
        NotificationScheduler.shared.reschedule(subscriptions.filter { $0.id != subscription.id })
    }
}
