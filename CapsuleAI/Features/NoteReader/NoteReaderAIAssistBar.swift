//
//  NoteReaderAIAssistBar.swift
//  CapsuleAI
//

import SwiftUI

struct NoteReaderAIAssistBar: View {
    let contentPlain: String
    let title: String
    let noteId: UUID
    let onOpenEditorWithContent: (String) -> Void
    var onSaveSummary: ((String) -> Void)?

    @State private var aiService = AIAssistService()
    @State private var showSummarySheet = false
    @State private var showStructureSheet = false
    @State private var showGenerateSheet = false
    @State private var pendingResult = ""
    @State private var errorMessage: String?

    private var hasMinContent: Bool { contentPlain.trimmingCharacters(in: .whitespaces).count >= 10 }
    private var isDisabled: Bool { !hasMinContent || aiService.state == .loading }

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
            readerResultSheet(result: pendingResult, showCopyOnly: true, onSaveToNote: onSaveSummary.map { save in
                {
                    save(pendingResult)
                    showSummarySheet = false
                }
            })
        }
        .sheet(isPresented: $showStructureSheet) {
            readerResultSheet(result: pendingResult, showCopyOnly: false) {
                onOpenEditorWithContent(pendingResult)
                showStructureSheet = false
            }
        }
        .sheet(isPresented: $showGenerateSheet) {
            readerResultSheet(result: pendingResult, showCopyOnly: true)
        }
        .alert("Erreur", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let msg = errorMessage { Text(msg) }
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
        let ctx = !title.isEmpty ? "Titre: \(title)" : nil
        do {
            let result = try await aiService.assist(action: action, content: contentPlain, context: ctx)
            pendingResult = result
            switch action {
            case .summarize: showSummarySheet = true
            case .structure: showStructureSheet = true
            case .generate: showGenerateSheet = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func readerResultSheet(result: String, showCopyOnly: Bool, onOpenInEditor: (() -> Void)? = nil, onSaveToNote: (() -> Void)? = nil) -> some View {
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
                            showStructureSheet = false
                            showGenerateSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        HStack(spacing: Spacing.sm) {
                            Button("Copier") {
                                UIPasteboard.general.string = result
                            }
                            if let onSave = onSaveToNote {
                                Button("Enregistrer sur la note") {
                                    onSave()
                                }
                                .fontWeight(.semibold)
                            }
                            if !showCopyOnly, let onOpen = onOpenInEditor {
                                Button("Ouvrir dans l'éditeur") { onOpen() }
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
        }
    }
}
