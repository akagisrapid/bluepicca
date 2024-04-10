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
    
    @MainActor
    var vm: PostScreenModel = PostScreenModel(text: "どやこんが")
    
    var timelineVm = TimelineViewModel()
    var timelineSm = TimelineScreenModel(feeds: [])
    var body: some Scene {
        WindowGroup {
            ContentView(postScreenVm: vm, timelineScreenVm:timelineSm)
        }
        .modelContainer(sharedModelContainer)
    }
}
