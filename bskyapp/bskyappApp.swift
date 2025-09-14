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
    
    @State private var isLoggedIn: Bool = false
    
    init() {
        // Check if user is already logged in
        _isLoggedIn = State(initialValue: SessionManager.shared.isLoggedIn())
    }
    
    @MainActor
    var body: some Scene {
        WindowGroup {
            if isLoggedIn {
                NavigationStack {
                    ContentView(viewModel: contentViewModel)
                        .onAppear {
                            // Refresh timeline when appearing
                            Task {
                                do {
                                    try await contentViewModel.fetchTimeline()
                                } catch {
                                    print("Error fetching timeline: \(error)")
                                }
                            }
                        }
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: {
                                    // Logout action
                                    SessionManager.shared.logout()
                                    isLoggedIn = false
                                }) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                }
                            }
                        }
                }
                .modelContainer(sharedModelContainer)
            } else {
                // Use LoginView directly
                LoginView(isLoggedIn: $isLoggedIn)
                    .modelContainer(sharedModelContainer)
            }
        }
    }
}
