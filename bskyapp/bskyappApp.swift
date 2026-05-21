import SwiftData
import SwiftUI

@main
struct bskyappApp: App {
  var sharedModelContainer: ModelContainer = {
    let schema = Schema([
      Item.self,
      PostDraft.self,
      BookmarkedPost.self,
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
  @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.system
    .rawValue

  private var preferredColorScheme: ColorScheme? {
    (AppearanceMode(rawValue: appearanceModeRaw) ?? .system).colorScheme
  }

  init() {
    _isLoggedIn = State(initialValue: SessionManager.shared.isLoggedIn())
    URLCache.shared = URLCache(
      memoryCapacity: 50 * 1024 * 1024,
      diskCapacity: 200 * 1024 * 1024
    )
    // TODO: pod install 後にコメントを外す
    // FirebaseApp.configure()
  }

  @MainActor
  var body: some Scene {
    WindowGroup {
      if isLoggedIn {
        NavigationStack {
          ContentView(viewModel: contentViewModel, isLoggedIn: $isLoggedIn)
        }
        .preferredColorScheme(preferredColorScheme)
        .modelContainer(sharedModelContainer)
      } else {
        // Use LoginView directly
        LoginView(isLoggedIn: $isLoggedIn)
          .preferredColorScheme(preferredColorScheme)
          .modelContainer(sharedModelContainer)
      }
    }
  }
}
