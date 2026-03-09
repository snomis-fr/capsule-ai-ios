//
//  CapsuleAIApp.swift
//  CapsuleAI
//

import SwiftUI

@main
struct CapsuleAIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onOpenURL { url in
                    Task {
                        _ = SupabaseManager.shared.client.auth.handle(url)
                    }
                }
        }
    }
}
