//
//  bskyappApp.swift
//  bskyapp
//
//  Created by 名鉄開発用 on 2024/02/22.
//

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
    var vm: PostScreenModel = PostScreenModel(text: "aaa")

    var body: some Scene {
        WindowGroup {
            ContentView(postScreenVm: vm)
        }
        .modelContainer(sharedModelContainer)
    }
}
