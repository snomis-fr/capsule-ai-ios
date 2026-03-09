//
//  CreateWorkspaceSheet.swift
//  CapsuleAI
//

import SwiftUI

struct CreateWorkspaceSheet: View {
    @Binding var isPresented: Bool
    let onCreate: (String) async throws -> Void

    @State private var companyName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom de l'entreprise", text: $companyName)
                        .textContentType(.organizationName)
                        .autocapitalization(.words)
                } header: {
                    Text("Votre espace de travail")
                } footer: {
                    Text("Ex. Ippon Technologies → l'app affichera « Capsule Ippon »")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(Color.capsuleError)
                    }
                }
            }
            .navigationTitle("Créer mon espace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        Task { await createWorkspace() }
                    }
                    .disabled(companyName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                    .fontWeight(.semibold)
                }
            }
            .interactiveDismissDisabled(isLoading)
        }
    }

    private func createWorkspace() async {
        let name = companyName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await onCreate(name)
            isPresented = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
