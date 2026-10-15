import SwiftData
import SwiftUI
import WidgetKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var subscriptions: [Subscription]
    @AppStorage("selectedTab") private var selectedTab = 0
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency
    @Environment(ProStore.self) private var store

    var body: some View {
        GeometryReader { proxy in
            tabs.environment(\.isCompactScreen,
                             proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom < 700)
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Subscriptions", systemImage: "creditcard.fill") }
                .tag(0)
            Group {
                if store.isPro { InsightsView() } else { LockedInsightsView() }
            }
                .tabItem { Label("Insights", systemImage: "chart.pie.fill") }
                .tag(1)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(2)
        }
        .onChange(of: scenePhase) { _, phase in
            // Renewals roll forward over time, so refresh the reminder queue whenever the app becomes active.
            if phase == .active { NotificationScheduler.shared.reschedule(subscriptions) }
            // Leaving the app is when Home Screen widgets become visible again, so hand them fresh data.
            if phase == .background { WidgetCenter.shared.reloadAllTimelines() }
        }
        .onAppear { SharedStore.defaults.set(currency, forKey: AppSettings.currencyKey) }
        .onChange(of: currency) { _, code in
            SharedStore.defaults.set(code, forKey: AppSettings.currencyKey)
        }
    }
}
