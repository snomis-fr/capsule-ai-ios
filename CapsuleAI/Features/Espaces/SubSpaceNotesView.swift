//
//  SubSpaceNotesView.swift
//  CapsuleAI
//

import SwiftUI

struct SubSpaceNotesView: View {
    let space: Space
    let subSpace: SubSpace
    let spaceColor: String

    @State private var viewModel = SubSpaceNotesViewModel()
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.items.isEmpty {
                ContentUnavailableView {
                    Label(subSpace.isTrash ? "Corbeille vide" : "Aucune note", systemImage: subSpace.isTrash ? "trash" : "note.text.badge.plus")
                } description: {
                    Text(subSpace.isTrash ? "Les notes supprimées apparaîtront ici pendant 30 jours." : "Créez une note avec le bouton +Note.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                notesList
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(subSpace.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    appState.selectedTabIndex = 0
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                if !subSpace.isTrash {
                    NavigationLink {
                        NoteEditorView(mode: .create(subSpaceId: subSpace.id, spaceId: space.id))
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
        }
        .task {
            await viewModel.load(subSpaceId: subSpace.id, spaceName: space.name, spaceColor: spaceColor, spaceEmoji: space.emoji)
        }
        .refreshable {
            await viewModel.load(subSpaceId: subSpace.id, spaceName: space.name, spaceColor: spaceColor, spaceEmoji: space.emoji)
        }
        .onReceive(NotificationCenter.default.publisher(for: .notesDidUpdate)) { _ in
            Task {
                await viewModel.load(subSpaceId: subSpace.id, spaceName: space.name, spaceColor: spaceColor, spaceEmoji: space.emoji)
            }
        }
        .navigationDestination(for: UUID.self) { noteId in
            NoteReaderView(noteId: noteId)
        }
        .alert("Erreur", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage { Text(msg) }
        }
    }

    private var notesList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if !viewModel.pinnedItems.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("📌 Épinglées")
                            .font(.headline)
                            .padding(.horizontal, Spacing.md)
                        LazyVStack(spacing: Spacing.sm) {
                            ForEach(viewModel.pinnedItems) { item in
                                NavigationLink(value: item.note.id) {
                                    SubSpaceNoteCard(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                    }
                }
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(viewModel.pinnedItems.isEmpty ? "Notes" : "Autres")
                            .font(.headline)
                        Text("(\(viewModel.unpinnedItems.count))")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(viewModel.unpinnedItems) { item in
                            NavigationLink(value: item.note.id) {
                                SubSpaceNoteCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            .padding(.vertical, Spacing.md)
        }
    }
}

private struct SubSpaceNoteCard: View {
    let item: SubSpaceNoteItem

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("\(item.spaceEmoji) \(item.spaceName)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color(hex: item.spaceColor))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                if item.note.isPrivate {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let u = item.note.updatedAt {
                    Text(u.relativeString())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(item.note.title)
                .font(.headline)
                .fontWeight(.bold)
            if !excerpt.isEmpty {
                Text(excerpt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if !item.tags.isEmpty {
                HStack(spacing: Spacing.xs) {
                    ForEach(item.tags) { tag in
                        Text("#\(tag.name)")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: tag.color))
                    }
                }
            }
            if let p = item.creatorProfile {
                HStack(spacing: 4) {
                    avatarView(p.avatarUrl)
                    Text("\(p.firstName ?? "") \(p.lastName ?? "")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    private var excerpt: String {
        let raw = item.note.contentPlain ?? item.note.aiSummary ?? ""
        return String(raw.prefix(150)) + (raw.count > 150 ? "..." : "")
    }

    private func avatarView(_ urlStr: String?) -> some View {
        Group {
            if let u = urlStr, let url = URL(string: u) {
                AsyncImage(url: url) { img in img.resizable() } placeholder: { Color.gray.opacity(0.3) }
            } else {
                Image(systemName: "person.circle.fill")
            }
        }
        .frame(width: 24, height: 24)
        .clipShape(Circle())
    }
}
