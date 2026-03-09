//
//  HomeView.swift
//  CapsuleAI
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var showCreateWorkspace = false
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.workspace == nil {
                    emptyWorkspaceState
                } else if viewModel.filteredNotes.isEmpty && viewModel.tags.isEmpty {
                    emptyNotesState
                } else {
                    contentScroll
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(viewModel.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                homeHeader
            }
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load()
            }
            .onReceive(NotificationCenter.default.publisher(for: .notesDidUpdate)) { _ in
                Task { await viewModel.load() }
            }
            .alert("Erreur", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                if let msg = viewModel.errorMessage {
                    Text(msg)
                }
            }
            .sheet(isPresented: $showCreateWorkspace) {
                CreateWorkspaceSheet(isPresented: $showCreateWorkspace) { companyName in
                    try await viewModel.createWorkspace(companyName: companyName)
                }
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

    /// Layout Home : nom app dans la nav bar (comme page Espaces), puis date + recherche
    private var homeHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(fullDateFrench)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            searchField
                .padding(.top, Spacing.sm)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var fullDateFrench: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE d MMMM yyyy"
        return formatter.string(from: Date())
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Rechercher dans toutes les notes...", text: $viewModel.searchQuery)
        }
        .padding(Spacing.sm)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
    }

    private var contentScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                notesGrid
                if !viewModel.tags.isEmpty {
                    TagSectionView(tags: viewModel.tags) { _ in
                        // TODO: filter by tag
                    }
                }
            }
            .padding(Spacing.md)
        }
    }

    private var notesGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: Spacing.md),
            GridItem(.flexible(), spacing: Spacing.md)
        ], spacing: Spacing.md) {
            ForEach(viewModel.filteredNotes) { note in
                NavigationLink {
                    NoteReaderView(noteId: note.id)
                } label: {
                    NoteCardView(
                        note: note,
                        spaceName: viewModel.spaceInfo(for: note.subSpaceId)?.name,
                        spaceColor: viewModel.spaceInfo(for: note.subSpaceId)?.color ?? "#3B82F6",
                        isImportant: note.unsplashImageUrl != nil,
                        modifierProfile: viewModel.modifierProfileByNoteId[note.id]
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyWorkspaceState: some View {
        ContentUnavailableView {
            Label("Créez votre espace", systemImage: "folder.badge.plus")
        } description: {
            Text("Donnez un nom à votre entreprise pour créer votre espace de travail et commencer à prendre des notes.")
        } actions: {
            Button("Créer mon espace") {
                showCreateWorkspace = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyNotesState: some View {
        ContentUnavailableView {
            Label("Aucune note", systemImage: "note.text.badge.plus")
        } description: {
            Text("Créez votre première note avec le bouton +Note.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}
