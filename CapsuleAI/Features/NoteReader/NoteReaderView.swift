//
//  NoteReaderView.swift
//  CapsuleAI
//

import SwiftUI

struct NoteReaderView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let noteId: UUID
    @State private var viewModel = NoteReaderViewModel()
    @State private var showDeleteConfirm = false
    @State private var showRestoreSheet = false
    @State private var showPermanentDeleteConfirm = false
    @State private var restoreDestinations: [(Space, SubSpace)] = []
    @State private var showEditorWithContent = false
    @State private var editorHtmlContent = ""

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let note = viewModel.note {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        breadcrumb
                        metadataSection(note: note)
                        if let summary = note.aiSummary, !summary.isEmpty {
                            aiSummarySection(summary)
                        }
                        contentSection(note: note)
                        attachmentsSection
                        actionPlanSection
                        if !viewModel.tags.isEmpty {
                            tagsSection
                        }
                        if let note = viewModel.note, let plain = note.contentPlain ?? note.content.flatMap({ String(data: $0, encoding: .utf8) }), !plain.isEmpty {
                            NoteReaderAIAssistBar(
                                contentPlain: plain,
                                title: note.title,
                                noteId: noteId,
                                onOpenEditorWithContent: { html in
                                    editorHtmlContent = html
                                    showEditorWithContent = true
                                },
                                onSaveSummary: { html in
                                    let summary = html.strippingHTML()
                                    guard !summary.isEmpty else { return }
                                    Task {
                                        try? await viewModel.updateAiSummary(noteId: noteId, summary: summary)
                                        await viewModel.load(noteId: noteId)
                                    }
                                }
                            )
                        }
                    }
                    .padding(Spacing.md)
                }
            } else {
                ContentUnavailableView("Note introuvable", systemImage: "doc.text.magnifyingglass")
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: Spacing.sm) {
                    NavigationLink {
                        NoteEditorView(mode: .create(subSpaceId: viewModel.subSpace?.id, spaceId: viewModel.space?.id))
                    } label: {
                        Image(systemName: "plus")
                    }
                    if viewModel.note != nil {
                        NavigationLink {
                            NoteEditorView(mode: .edit(noteId: noteId))
                        } label: {
                            Image(systemName: "pencil")
                        }
                        if viewModel.subSpace?.isTrash == true {
                            Button {
                                Task { await openRestoreSheet() }
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                            }
                            Button(role: .destructive) {
                                showPermanentDeleteConfirm = true
                            } label: {
                                Image(systemName: "trash")
                            }
                        } else {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
            }
        }
        .confirmationDialog("Déplacer vers la corbeille", isPresented: $showDeleteConfirm) {
            Button("Déplacer vers Poubelle", role: .destructive) {
                Task { await deleteNote() }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("La note sera dans la corbeille (Poubelle) pendant 30 jours. Vous pourrez la restaurer avant suppression définitive.")
        }
        .confirmationDialog("Supprimer définitivement", isPresented: $showPermanentDeleteConfirm) {
            Button("Supprimer", role: .destructive) {
                Task { await deleteNotePermanently() }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Cette note sera supprimée définitivement et ne pourra pas être récupérée.")
        }
        .sheet(isPresented: $showRestoreSheet) {
            restoreNoteSheet
        }
        .task {
            await viewModel.load(noteId: noteId)
        }
        .refreshable {
            await viewModel.load(noteId: noteId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .notesDidUpdate)) { _ in
            Task { await viewModel.load(noteId: noteId) }
        }
        .alert("Erreur", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage { Text(msg) }
        }
        .fullScreenCover(isPresented: $showEditorWithContent) {
            NavigationStack {
                NoteEditorView(mode: .editWithContent(noteId: noteId, htmlContent: editorHtmlContent), onSaveSuccess: { showEditorWithContent = false }, onBack: { showEditorWithContent = false })
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fermer") { showEditorWithContent = false }
                    }
                }
            }
        }
    }

    // MARK: - Breadcrumb cliquable : < (home) | Tag nom de l'espace
    @ViewBuilder
    private var breadcrumb: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.medium))
            }
            .accessibilityLabel("Retour à l'accueil")
            if let space = viewModel.space, let sub = viewModel.subSpace {
                NavigationLink(value: SubSpaceRoute(space: space, subSpace: sub)) {
                    HStack(spacing: 4) {
                        Text(space.emoji)
                        Text(space.name)
                        Text("·")
                        Text(sub.emoji)
                        Text(sub.name)
                    }
                    .font(.caption)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 6)
                    .background(Color(hex: space.color).opacity(0.2))
                    .foregroundStyle(Color(hex: space.color))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, Spacing.xs)
    }

    // MARK: - Métadonnées : badge espace, titre, bandeau modification (avatar + prénom + timestamp)
    private func metadataSection(note: Note) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(note.title)
                .font(.title2)
                .fontWeight(.bold)
            if let mod = viewModel.modifierProfile {
                HStack(spacing: Spacing.sm) {
                    avatarView(mod.avatarUrl)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mod.firstName ?? mod.email)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if let up = note.updatedAt {
                            Text(up.relativeString())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            } else if let updated = note.updatedAt {
                Text(updated.relativeString())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func avatarView(_ urlStr: String?) -> some View {
        Group {
            if let u = urlStr, let url = URL(string: u) {
                AsyncImage(url: url) { img in
                    img.resizable()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
    }

    private func aiSummarySection(_ summary: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "cpu")
                .foregroundStyle(.secondary)
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    @ViewBuilder
    private var actionPlanSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Plan d'action")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            if viewModel.actions.isEmpty {
                Text("Aucun élément")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(Spacing.sm)
            } else {
                ActionPlanView(actions: viewModel.actions) { id, checked in
                    Task {
                        guard let uid = appState.currentUserId else { return }
                        await viewModel.toggleAction(id: id, isChecked: checked, userId: uid)
                    }
                }
            }
        }
    }

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Pièces jointes")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            if viewModel.attachments.isEmpty {
                Text("Aucune pièce jointe")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(Spacing.sm)
            } else {
                ForEach(viewModel.attachments) { att in
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: att.fileType == "photo" ? "photo.fill" : "doc.fill")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(att.fileName)
                                .font(.subheadline)
                                .lineLimit(1)
                            Text(formatFileSize(att.fileSize))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .padding(Spacing.sm)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                }
            }
        }
    }

    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func contentSection(note: Note) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Contenu")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Group {
                if let data = note.content, data.count > 10 {
                    TiptapReadOnlyView(contentJson: data)
                        .frame(height: 400)
                        .id(note.id)
                } else if let plain = note.contentPlain, !plain.isEmpty {
                    Text(plain)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Aucun contenu")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var tagsSection: some View {
        FlowLayout(spacing: Spacing.sm) {
            ForEach(viewModel.tags) { tag in
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: tag.color))
                        .frame(width: 8, height: 8)
                    Text("#\(tag.name)")
                        .font(.caption)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 4)
                .background(Color(hex: tag.color).opacity(0.2))
                .clipShape(Capsule())
            }
        }
    }

    private func deleteNote() async {
        guard let workspaceId = viewModel.note?.workspaceId else { return }
        do {
            try await viewModel.deleteNote(noteId: noteId, workspaceId: workspaceId)
            dismiss()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func deleteNotePermanently() async {
        do {
            try await viewModel.deleteNotePermanently(noteId: noteId)
            dismiss()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func openRestoreSheet() async {
        guard let workspaceId = viewModel.note?.workspaceId else { return }
        do {
            restoreDestinations = try await viewModel.loadRestoreDestinations(workspaceId: workspaceId)
            showRestoreSheet = true
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private var restoreNoteSheet: some View {
        NavigationStack {
            List {
                ForEach(restoreDestinations, id: \.1.id) { space, subSpace in
                    Button {
                        Task { await restoreNote(to: subSpace.id) }
                    } label: {
                        HStack {
                            Text(space.emoji)
                            Text("\(space.name) · \(subSpace.name)")
                        }
                    }
                }
            }
            .navigationTitle("Restaurer vers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { showRestoreSheet = false }
                }
            }
        }
    }

    private func restoreNote(to subSpaceId: UUID) async {
        do {
            try await viewModel.restoreNote(noteId: noteId, targetSubSpaceId: subSpaceId)
            showRestoreSheet = false
            await viewModel.load(noteId: noteId)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

}
