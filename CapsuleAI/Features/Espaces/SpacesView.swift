//
//  SpacesView.swift
//  CapsuleAI
//

import SwiftUI

struct SpacesView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SpacesViewModel()
    @State private var selectedSpace: Space?
    @State private var showCreateSubSpace: Space?
    @State private var showDeleteSubSpaceConfirm: (SubSpace, Space)?
    @State private var showEditSubSpace: EditSubSpaceItem?
    @State private var spaceToEdit: Space?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.spaces.isEmpty {
                    ContentUnavailableView {
                        Label("Aucun espace", systemImage: "folder.badge.questionmark")
                    } description: {
                        Text("Créez des espaces depuis votre profil (section Gestion des espaces).")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    spacesList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Mes espaces")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appState.selectedTabIndex = 0
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
            .task(id: appState.currentWorkspaceId) {
                guard let uid = appState.currentUserId else { return }
                await viewModel.load(workspaceId: appState.currentWorkspaceId, userId: uid)
            }
            .refreshable {
                guard let uid = appState.currentUserId else { return }
                await viewModel.load(workspaceId: appState.currentWorkspaceId, userId: uid)
            }
            .alert("Erreur", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                if let msg = viewModel.errorMessage { Text(msg) }
            }
            .sheet(item: $showCreateSubSpace) { space in
                CreateSubSpaceSheet(spaceName: space.name, onCreate: { name, emoji in
                    guard let uid = appState.currentUserId else {
                        throw NSError(domain: "SpacesView", code: 401, userInfo: [NSLocalizedDescriptionKey: "Session expirée. Reconnectez-vous."])
                    }
                    try await viewModel.createSubSpace(spaceId: space.id, name: name, emoji: emoji, createdBy: uid)
                    let wsId = appState.currentWorkspaceId ?? space.workspaceId
                    await viewModel.load(workspaceId: wsId, userId: uid)
                }, onDismiss: { showCreateSubSpace = nil })
                    .presentationDetents([.medium])
            }
            .sheet(item: $showEditSubSpace) { item in
                EditSubSpaceSheet(
                    subSpace: item.subSpace,
                    onSave: { name, emoji in
                        try await viewModel.updateSubSpace(id: item.subSpace.id, name: name, emoji: emoji)
                        guard let uid = appState.currentUserId else { return }
                        await viewModel.load(workspaceId: appState.currentWorkspaceId, userId: uid)
                    },
                    onDismiss: { showEditSubSpace = nil }
                )
            }
            .alert("Supprimer la sous-catégorie ?", isPresented: .constant(showDeleteSubSpaceConfirm != nil)) {
                Button("Annuler", role: .cancel) { showDeleteSubSpaceConfirm = nil }
                Button("Supprimer", role: .destructive) {
                    guard let (sub, _) = showDeleteSubSpaceConfirm else { return }
                    Task {
                        try? await viewModel.deleteSubSpace(id: sub.id)
                        guard let uid = appState.currentUserId else { return }
                        await viewModel.load(workspaceId: appState.currentWorkspaceId, userId: uid)
                    }
                    showDeleteSubSpaceConfirm = nil
                }
            } message: {
                Text("Les notes seront déplacées vers « Non classées ».")
            }
            .sheet(item: $spaceToEdit) { space in
                EditSpaceSheet(space: space, onSave: { newName, newColor in
                    Task {
                        try? await viewModel.updateSpaceName(space, name: newName)
                        try? await viewModel.updateSpaceColor(space, color: newColor)
                        guard let uid = appState.currentUserId else { return }
                        await viewModel.load(workspaceId: appState.currentWorkspaceId, userId: uid)
                    }
                    spaceToEdit = nil
                }, onDismiss: { spaceToEdit = nil })
            }
            .navigationDestination(for: Space.self) { space in
                SpaceDetailView(
                    space: space,
                    viewModel: viewModel,
                    onAddSubSpace: { showCreateSubSpace = space },
                    onEditSpace: { spaceToEdit = space },
                    onEditSubSpace: { sub in showEditSubSpace = EditSubSpaceItem(subSpace: sub, space: space) },
                    onDeleteSubSpace: { sub in showDeleteSubSpaceConfirm = (sub, space) }
                )
            }
            .navigationDestination(for: SubSpaceRoute.self) { route in
                SubSpaceNotesView(
                    space: route.space,
                    subSpace: route.subSpace,
                    spaceColor: route.space.color
                )
            }
        }
    }

    private var spacesList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(viewModel.orderedSpaces) { space in
                    NavigationLink(value: space) {
                        SpaceCardView(
                            space: space,
                            subSpaces: viewModel.subSpacesBySpace[space.id] ?? [],
                            noteCount: viewModel.noteCountBySpace[space.id] ?? 0,
                            subSpaceNoteCounts: viewModel.noteCountBySubSpace,
                            sharedSubSpaceIds: viewModel.sharedSubSpaceIds,
                            onAddSubSpace: { showCreateSubSpace = space }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.md)
        }
    }
}

struct SubSpaceRoute: Hashable {
    let space: Space
    let subSpace: SubSpace
}

private struct EditSubSpaceItem: Identifiable {
    let subSpace: SubSpace
    let space: Space
    var id: UUID { subSpace.id }
}

private struct EditSubSpaceSheet: View {
    let subSpace: SubSpace
    let onSave: (String, String) async throws -> Void
    let onDismiss: () -> Void

    @State private var name: String
    @State private var emoji: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(subSpace: SubSpace, onSave: @escaping (String, String) async throws -> Void, onDismiss: @escaping () -> Void) {
        self.subSpace = subSpace
        self.onSave = onSave
        self.onDismiss = onDismiss
        _name = State(initialValue: subSpace.name)
        _emoji = State(initialValue: subSpace.emoji)
    }

    private let emojis = ["📄", "📋", "📁", "📂", "🗂", "📌", "🔖", "📎", "✏️", "📝", "📃", "📑"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom", text: $name)
                    HStack {
                        Text("Emoji")
                        Spacer()
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: Spacing.sm) {
                            ForEach(emojis, id: \.self) { e in
                                Button { emoji = e } label: {
                                    Text(e).font(.title2)
                                        .frame(width: 36, height: 36)
                                        .background(emoji == e ? Color.capsulePrimary.opacity(0.2) : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                if let err = errorMessage {
                    Section { Text(err).foregroundStyle(Color.capsuleError) }
                }
            }
            .navigationTitle("Modifier le sous-espace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        Task { await save() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await onSave(trimmed, emoji)
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
