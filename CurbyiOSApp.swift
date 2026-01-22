//
//  CurbyiOSApp.swift
//  CurbyiOS
//
//  Created by Isaiah Hinds on 1/5/26.
//

import SwiftUI
import SwiftData
import Combine

@main
struct CurbyiOSApp: App {
    @StateObject private var auth = AuthManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Hazard.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
        }
        .modelContainer(sharedModelContainer)
    }
}
