//
//  iDoc_WatchApp.swift
//  iDoc
//
//  Created by Keith  Salyer on 2/24/25.
//

import SwiftUI

@main
struct iDoc_WatchApp: App {
    @StateObject private var healthManager = WatchHealthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthManager)
        }
    }
}
