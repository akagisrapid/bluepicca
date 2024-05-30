import SwiftUI
import SwiftData

@main
struct bskyappApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    var contentViewModel = ContentViewModel()
    
    @MainActor
    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: contentViewModel)
        }
        .modelContainer(sharedModelContainer)
    }
}
