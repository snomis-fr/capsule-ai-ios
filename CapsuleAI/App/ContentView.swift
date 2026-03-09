//
//  ContentView.swift
//  CapsuleAI
//

import SwiftUI
import Supabase

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var authManager = AuthManager()
    @State private var isLoadingProfile = false

    var body: some View {
        Group {
            if !appState.isAuthenticated {
                LoginView()
            } else if isLoadingProfile {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.currentProfile?.workspaceId == nil {
                OnboardingView()
            } else {
                TabRouter()
            }
        }
        .task {
            await checkSession()
            guard appState.isAuthenticated else { return }
            await loadProfile()
        }
        .onChange(of: appState.isAuthenticated) { _, isAuth in
            guard isAuth else { return }
            Task { await loadProfile() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await checkSession() }
            }
        }
    }

    private func checkSession() async {
        appState.isAuthenticated = await authManager.checkSession()
        if appState.isAuthenticated {
            appState.currentUserId = authManager.currentUserId
        } else {
            appState.currentProfile = nil
            appState.currentWorkspaceId = nil
        }
    }

    private func loadProfile() async {
        guard appState.isAuthenticated else { return }
        guard let userId = appState.currentUserId ?? authManager.currentUserId else { return }
        isLoadingProfile = true
        defer { isLoadingProfile = false }

        // Restaurer depuis le cache local si disponible (en arrière-plan pour ne pas bloquer l’UI)
        do {
            let profile: Profile = try await SupabaseManager.shared.client
                .from(Tables.profiles)
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            appState.currentProfile = profile
            appState.currentWorkspaceId = profile.workspaceId
            if profile.notificationsEnabledOrDefault {
                await PushNotificationService.shared.registerIfAuthorized()
            }
        } catch {
            // En cas d'erreur réseau, le cache (si présent) conserve les données affichées
            if appState.currentProfile == nil {
                appState.currentProfile = nil
                appState.currentWorkspaceId = nil
            }
        }
    }
}
