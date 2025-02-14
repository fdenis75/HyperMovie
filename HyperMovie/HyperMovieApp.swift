//
//  HyperMovieApp.swift
//  HyperMovie
//
//  Created by Francois on 14/02/2025.
//

import SwiftUI

@main
struct HyperMovieApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
