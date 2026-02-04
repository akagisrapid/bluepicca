# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Rapipopo** is a native iOS Bluesky client built with SwiftUI. It implements the AT Protocol to interact with Bluesky's social networking features (timeline, posts, likes, reposts, profiles, replies, follows).

The Xcode project lives in `rapipopo/`. All source code is under `rapipopo/bskyapp/`.

## Build & Run

```bash
# Install dependencies (CocoaPods)
cd rapipopo && pod install

# Open workspace (must use .xcworkspace, not .xcodeproj, due to CocoaPods)
open rapipopo/bskyapp.xcworkspace
```

Build and run from Xcode (⌘B / ⌘R). Requires iOS 16+ (uses NavigationStack, SwiftData).

There are no automated tests or linting configured in this project.

## Dependencies

- **Alamofire** — HTTP networking for all AT Protocol API calls
- **SwiftUI** / **SwiftData** / **Combine** — UI, persistence, reactivity (all Apple built-in)

## Architecture

### MVVM Pattern

```
View/          →  ViewModel/          →  Service/          →  Model/
(SwiftUI)         (@Observable)          (Alamofire API)      (Codable structs)
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
