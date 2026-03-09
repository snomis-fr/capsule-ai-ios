//
//  TagEditSheet.swift
//  CapsuleAI
//

import SwiftUI

struct TagEditSheet: View {
    let tag: Tag
    @State private var name: String
    @State private var color: String
    let onSave: (String, String) -> Void
    let onDismiss: () -> Void

    init(tag: Tag, onSave: @escaping (String, String) -> Void, onDismiss: @escaping () -> Void) {
        self.tag = tag
        _name = State(initialValue: tag.name)
        _color = State(initialValue: tag.color)
        self.onSave = onSave
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nom", text: $name)
                Section("Couleur") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: Spacing.sm) {
                        ForEach(TagColors.all, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 36, height: 36)
                                .overlay(Circle().stroke(color == hex ? Color.primary : Color.clear, lineWidth: 3))
                                .onTapGesture { color = hex }
                        }
                    }
                }
            }
            .navigationTitle("Modifier le tag")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        onSave(name, color)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
