//
//  LoginView.swift
//  CapsuleAI
//

import SwiftUI
import UIKit

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @State private var authManager = AuthManager()
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 80)

            Text("Connexion requise")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.capsuleError)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                Task { await signInWithGoogle() }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "globe")
                        Text("Se connecter avec Google")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.capsulePrimary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }
            .disabled(isLoading)
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xl)
        }
        .padding()
    }

    private func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authManager.signInWithGoogle()
            appState.isAuthenticated = true
            appState.currentUserId = authManager.currentUserId
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
