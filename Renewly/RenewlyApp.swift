import SwiftData
import SwiftUI

@main
struct RenewlyApp: App {
    let container: ModelContainer
    @State private var store = ProStore()

    init() {
        let inMemory = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        if !inMemory { SharedStore.migrateLegacyStoreIfNeeded() }
        // Lives in the App Group container so the widget reads the same data.
        let config = inMemory
            ? ModelConfiguration(isStoredInMemoryOnly: true)
            : ModelConfiguration(url: SharedStore.storeURL)
        do {
            container = try ModelContainer(for: Subscription.self, configurations: config)
        } catch {
            fatalError("Could not create the data store: \(error)")
        }
        if ProcessInfo.processInfo.arguments.contains("-seedSampleData") {
            let context = container.mainContext
            if (try? context.fetchCount(FetchDescriptor<Subscription>())) == 0 {
                SampleData.insert(into: context)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
        .modelContainer(container)
    }
}
