//
//  SpaceDetailView.swift
//  CapsuleAI
//

import SwiftUI

struct SpaceDetailView: View {
    let space: Space
    @Bindable var viewModel: SpacesViewModel
    let onAddSubSpace: () -> Void
    let onEditSpace: () -> Void
    let onEditSubSpace: (SubSpace) -> Void
    let onDeleteSubSpace: (SubSpace) -> Void

    @Environment(AppState.self) private var appState

    private var subSpaces: [SubSpace] { viewModel.subSpacesBySpace[space.id] ?? [] }

    var body: some View {
        Group {
            if subSpaces.isEmpty {
                ContentUnavailableView {
                    Label("Aucun sous-espace", systemImage: "folder.badge.plus")
                } description: {
                    Text("Créez une sous-catégorie avec le bouton +")
                } actions: {
                    Button("Créer") { onAddSubSpace() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                subSpacesList
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(space.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    appState.selectedTabIndex = 0
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: Spacing.sm) {
                    Menu {
                        Button("Modifier l'espace") {
                            onEditSpace()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    Button {
                        onAddSubSpace()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
        }
    }

    private var spaceHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.md) {
                LinearGradient(
                    colors: [Color(hex: space.color), Color(hex: space.color).opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                HStack(spacing: Spacing.sm) {
                    Text(space.emoji)
                        .font(.title2)
                    Text(space.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                Spacer()
            }
            .padding(Spacing.md)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: space.color), Color(hex: space.color).opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 4)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    private var subSpacesList: some View {
        List {
            Section {
                ForEach(subSpaces) { sub in
                NavigationLink(value: SubSpaceRoute(space: space, subSpace: sub)) {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: "line.3.horizontal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(sub.emoji)
                        Text(sub.name)
                        if !viewModel.sharedSubSpaceIds.contains(sub.id) {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Modifier") {
                            onEditSubSpace(sub)
                        }
                        .buttonStyle(.borderless)
                        Text("\(viewModel.noteCountBySubSpace[sub.id] ?? 0) notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if viewModel.canDeleteSubSpace(sub, space: space) {
                        Button(role: .destructive) {
                            onDeleteSubSpace(sub)
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            spaceHeader
        }
        }
    }
}
