//
//  FrostSentinelApp.swift
//  PlantSentinel (formerly FrostSentinel)
//
//  Two questions, answered quietly: does anything in my garden need covering
//  tonight — and does anything need water before tomorrow's heat?
//
//  (The type keeps its original name; the app the user sees is Plant
//  Sentinel, set via INFOPLIST_KEY_CFBundleDisplayName.)
//

import SwiftUI

@main
struct FrostSentinelApp: App {
    private let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            GardenView(
                viewModel: GardenViewModel(
                    store: GardenStore(context: persistence.viewContext)
                ),
                store: GardenStore(context: persistence.viewContext)
            )
        }
    }
}
