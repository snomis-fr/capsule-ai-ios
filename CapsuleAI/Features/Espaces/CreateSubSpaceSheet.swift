//
//  CreateSubSpaceSheet.swift
//  CapsuleAI
//

import SwiftUI

struct CreateSubSpaceSheet: View {
    let spaceName: String
    let onCreate: (String, String) async throws -> Void
    let onDismiss: () -> Void

    @State private var name = ""
    @State private var emoji = "📄"
    @State private var isCreating = false
    @State private var errorMessage: String?

    private let emojis = ["📄", "📋", "📁", "📂", "🗂", "📌", "🔖", "📎", "✏️", "📝", "📃", "📑"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ex. Projets 2025", text: $name)
                        .textInputAutocapitalization(.sentences)
                    HStack {
                        Text("Emoji")
                        Spacer()
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: Spacing.sm) {
                            ForEach(emojis, id: \.self) { e in
                                Button {
                                    emoji = e
                                } label: {
                                    Text(e)
                                        .font(.title2)
                                        .frame(width: 36, height: 36)
                                        .background(emoji == e ? Color.capsulePrimary.opacity(0.2) : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } header: {
                    Text("Dans l'espace « \(spaceName) »")
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundStyle(Color.capsuleError)
                    }
                }
            }
            .navigationTitle("Créer une sous-catégorie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        Task { await handleCreate() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
            }
            .interactiveDismissDisabled(isCreating)
        }
    }

    private func handleCreate() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }
        do {
            try await onCreate(trimmed, emoji)
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
