//
//  OnboardingView.swift
//  CapsuleAI
//

import SwiftUI

struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Header
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 80)

            Text("Bienvenue sur Capsule")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Pour commencer, donnez un nom à votre entreprise. Votre espace de travail sera créé automatiquement.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)

            Spacer()

            // Form
            VStack(spacing: Spacing.md) {
                TextField("Nom de l'entreprise", text: $viewModel.companyName)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.organizationName)
                    .autocapitalization(.words)
                    .padding(.horizontal, Spacing.lg)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.capsuleError)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.lg)
                }

                Button {
                    Task { await createWorkspace() }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Créer mon espace")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.capsulePrimary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
                .disabled(viewModel.companyName.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading)
                .padding(.horizontal, Spacing.lg)
            }
            .padding(.bottom, Spacing.xl)
        }
        .padding(Spacing.lg)
        .background(Color(.systemGroupedBackground))
        .alert("Erreur", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage {
                Text(msg)
            }
        }
    }

    private func createWorkspace() async {
        viewModel.isLoading = true
        viewModel.errorMessage = nil
        defer { viewModel.isLoading = false }

        do {
            let profile = try await viewModel.createWorkspaceAndCompleteOnboarding()
            appState.currentProfile = profile
            appState.currentWorkspaceId = profile.workspaceId
        } catch let error as DecodingError {
            viewModel.errorMessage = decodeErrorMessage(error)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func decodeErrorMessage(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _):
            return "Champ manquant: \(key.stringValue)"
        case .typeMismatch(let type, let context):
            return "Type incorrect (\(type)): \(context.debugDescription)"
        case .valueNotFound(_, let context):
            return "Valeur absente: \(context.debugDescription)"
        case .dataCorrupted(let context):
            return "Données corrompues: \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }
}
