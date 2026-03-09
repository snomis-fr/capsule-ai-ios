//
//  NoteEditorAIAssistBar.swift
//  CapsuleAI
//

import SwiftUI

struct NoteEditorAIAssistBar: View {
    let contentPlain: String
    let title: String
    let isEditing: Bool
    @Binding var triggerAction: AIAction?
    let onInsertSummary: (String) -> Void
    let onReplaceWithStructured: (String) -> Void
    let onInsertGenerated: (String) -> Void

    @State private var aiService = AIAssistService()
    @State private var showSummarySheet = false
    @State private var showStructureConfirm = false
    @State private var showGenerateSheet = false
    @State private var pendingResult = ""
    @State private var pendingAction: PendingAction?
    @State private var errorMessage: String?

    private var hasMinContent: Bool { contentPlain.trimmingCharacters(in: .whitespaces).count >= 10 }
    private var isDisabled: Bool { !hasMinContent || aiService.state == .loading }

    enum PendingAction { case structure }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                Text("Assistance IA")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: Spacing.sm) {
                aiButton("Résumer", icon: "doc.plaintext") {
                    Task { await runAction(.summarize) }
                }
                aiButton("Structurer", icon: "text.alignleft") {
                    Task { await runAction(.structure) }
                }
                aiButton("Générer", icon: "sparkles") {
                    Task { await runAction(.generate) }
                }
            }
        }
        .padding(Spacing.sm)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.7 : 1)
        .sheet(isPresented: $showSummarySheet) {
            aiResultSheet(result: pendingResult) {
                onInsertSummary(pendingResult)
                showSummarySheet = false
            }
        }
        .sheet(isPresented: $showGenerateSheet) {
            aiResultSheet(result: pendingResult) {
                onInsertGenerated(pendingResult)
                showGenerateSheet = false
            }
        }
        .confirmationDialog("Remplacer le contenu ?", isPresented: $showStructureConfirm) {
            Button("Remplacer") {
                if !pendingResult.isEmpty {
                    onReplaceWithStructured(pendingResult)
                }
                showStructureConfirm = false
            }
            Button("Annuler", role: .cancel) { showStructureConfirm = false }
        } message: {
            Text("Le contenu actuel sera remplacé par la version structurée.")
        }
        .alert("Erreur", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
        .onChange(of: triggerAction) { _, newValue in
            guard let action = newValue else { return }
            triggerAction = nil
            Task { await runAction(action) }
        }
    }

    @ViewBuilder
    private func aiButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if aiService.state == .loading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(label)
                    .font(.caption2)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 6)
            .background(Color.capsulePrimary.opacity(0.2))
            .foregroundStyle(Color.capsulePrimary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
        }
        .buttonStyle(.plain)
        .disabled(aiService.state == .loading)
    }

    private func runAction(_ action: AIAction) async {
        errorMessage = nil
        let ctx = isEditing && !title.isEmpty ? "Titre: \(title)" : nil
        do {
            let result = try await aiService.assist(action: action, content: contentPlain, context: ctx)
            pendingResult = result
            switch action {
            case .summarize: showSummarySheet = true
            case .structure: showStructureConfirm = true
            case .generate: showGenerateSheet = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func aiResultSheet(result: String, onInsert: @escaping () -> Void) -> some View {
        NavigationStack {
            HtmlContentView(html: result)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .navigationTitle("Résultat IA")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        showSummarySheet = false
                        showGenerateSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    HStack {
                        Button("Copier") {
                            UIPasteboard.general.string = result
                        }
                        Button("Insérer") { onInsert() }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }
}
