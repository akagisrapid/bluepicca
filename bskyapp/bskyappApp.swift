import FirebaseCore
import SwiftData
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    FirebaseApp.configure()

    return true
  }
}

@main
struct bskyappApp: App {
  // register app delegate for Firebase setup
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

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
