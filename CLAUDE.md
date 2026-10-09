# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Bluepicca** is a native iOS Bluesky client built with SwiftUI. It implements the AT Protocol to interact with Bluesky's social networking features (timeline, posts, likes, reposts, profiles, replies, follows).

The Xcode project lives in `rapipopo/`. All source code is under `rapipopo/bskyapp/`.

## Build & Run

```bash
open rapipopo/bskyapp.xcodeproj

# CLI build
xcodebuild -project bskyapp.xcodeproj -scheme bskyapp -destination 'generic/platform=iOS Simulator' build
```

Build and run from Xcode (⌘B / ⌘R). Requires iOS 17+ (uses NavigationStack, SwiftData).

The `bskyapp/` folder is a **file-system synchronized group**: adding a file under it adds it to the target automatically. Do not edit `project.pbxproj` to register files. Files that must stay out of the app bundle (e.g. `*.md` notes) are listed in the group's `membershipExceptions`.

## Tests

Unit tests live in `bskyappTests/` (Swift Testing, file-system synchronized like `bskyapp/`). CI (`.github/workflows/ios.yml`) runs them on every PR.

```bash
# generic/platform=iOS Simulator does not work for test; pick a concrete simulator by UDID
xcrun simctl list devices available | grep iPhone
xcodebuild test -project bskyapp.xcodeproj -scheme bskyapp -destination 'platform=iOS Simulator,id=<UDID>' -testLanguage ja -testRegion JP
```

- After adding a test file, run `xcodebuild clean` first and confirm the new test names appear in the log. An incremental build can skip new files and still print `** TEST SUCCEEDED **`
- Keep `-testLanguage ja -testRegion JP` (tests assert Japanese strings; CI does the same)
- Singletons (`ContentLabelManager`, `MuteWordManager`, ...) persist to `UserDefaults.standard`. Tests that touch them save and restore the state and run in a `@Suite(.serialized)`
- The shared scheme `bskyapp.xcscheme` is committed and lists `bskyappTests`. Xcode Cloud also needs the scheme to be shared

## Dependencies

No third-party dependencies. HTTP goes through `Service/HTTPClient.swift`, a thin URLSession wrapper (`HTTPClient.decode` / `data` / `send`). Non-2xx responses throw `HTTPError`; check `statusCode` (e.g. 429 rate limit) instead of parsing messages.

- **SwiftUI** / **SwiftData** / **Combine** — UI, persistence, reactivity (all Apple built-in)

## Architecture

### MVVM Pattern

```
View/          →  ViewModel/          →  Service/          →  Model/
(SwiftUI)         (@Observable)          (HTTPClient)        (Codable structs)
```

- **Screen-level ViewModels** are `class` types conforming to `ObservableObject` (e.g., `ContentViewModel`, `PostDetailViewModel`)
- **List-item ViewModels** are `struct` types acting as pure presenters (e.g., `TimelineCardViewModel`)

### App Entry & Navigation

`bskyappApp.swift` is the `@main` entry point. It checks `SessionManager.shared.isLoggedIn()` and routes to either `LoginView` or `ContentView` inside a `NavigationStack`.

### Authentication

`Session/SessionManager.swift` is a singleton managing:
- AT Protocol session creation (handle + app password → `accessJwt` + `did`)
- Keychain storage (`com.bskyapp.credentials`) for secure credential persistence
- 12-hour token expiry with auto-refresh

### Key Services

| Service | Purpose |
|---------|---------|
| `InteractionService` | Like/repost API calls with optimistic UI |
| `PostCreationService` | Create posts/replies, upload images |
| `GetTimelineApi` | Fetch home timeline |
| `GetPostThreadApi` | Fetch post threads and replies |
| `CreateSessionApi` | Authentication against AT Protocol |

### State Management for Interactions

Likes and reposts use an optimistic update pattern:
1. `PostInteractionHelper` updates UI immediately with a temporary `pending_` URI
2. `InteractionService` sends the API request
3. On failure, the UI rolls back
4. `PostStateManager` persists interaction state to UserDefaults
5. `syncWithServerState()` reconciles local state on timeline refresh

### Model Structure

`Model/Feed/Post.swift` is the core data model — it's a `class` conforming to `ObservableObject` so views can observe changes to individual posts (likes, reposts) reactively.

`Model/API/` contains Codable request/response types mirroring the AT Protocol schema.
