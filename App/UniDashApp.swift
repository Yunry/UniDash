//
//  UniDashApp.swift
//  UniDash
//
//  Application entry point configuring purely local SwiftData storage and scene setup.
//

import SwiftUI
import SwiftData

@main
struct UniDashApp: App {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([
                Course.self,
                ScheduleItem.self
            ])
            // Free personal Apple ID signing constraint: Purely local storage, explicitly disable CloudKit
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            self.container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not configure SwiftData ModelContainer: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AdaptiveRootView()
        }
        .modelContainer(container)
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1000, height: 700)
        .commands {
            SidebarCommands()
        }
        #endif
    }
}
