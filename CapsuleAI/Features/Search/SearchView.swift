//
//  SearchView.swift
//  CapsuleAI
//

import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.results.isEmpty {
                    skeletonView
                } else if viewModel.errorMessage != nil {
                    errorView
                } else if viewModel.results.isEmpty && viewModel.hasSearched {
                    emptyView
                } else {
                    resultsView
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.large)
            .navigationTitle("Recherche")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appState.selectedTabIndex = 0
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
            .searchable(text: $viewModel.searchQuery, prompt: "Rechercher dans vos notes...")
            .task {
                await viewModel.loadFilters()
                if !viewModel.hasSearched { await viewModel.loadInitialOrSearch() }
            }
            .onChange(of: viewModel.searchQuery) { _, newVal in
                if newVal.trimmingCharacters(in: .whitespaces).count < 2 {
                    Task { await viewModel.loadInitialOrSearch() }
                }
            }
            .task(id: viewModel.searchQuery) {
                guard viewModel.searchQuery.trimmingCharacters(in: .whitespaces).count >= 2 else { return }
                try? await Task.sleep(nanoseconds: 300_000_000)
                await viewModel.loadInitialOrSearch()
            }
            .onChange(of: viewModel.filters.spaceId) { _, _ in Task { await viewModel.loadInitialOrSearch() } }
            .onChange(of: viewModel.filters.tagId) { _, _ in Task { await viewModel.loadInitialOrSearch() } }
            .onChange(of: viewModel.filters.noteType) { _, _ in Task { await viewModel.loadInitialOrSearch() } }
            .onChange(of: viewModel.filters.dateFilter) { _, _ in Task { await viewModel.loadInitialOrSearch() } }
            .onChange(of: viewModel.filters.isPrivate) { _, _ in Task { await viewModel.loadInitialOrSearch() } }
            .refreshable { await viewModel.loadInitialOrSearch() }
            .onReceive(NotificationCenter.default.publisher(for: .notesDidUpdate)) { _ in
                Task { await viewModel.loadInitialOrSearch() }
            }
            .navigationDestination(for: UUID.self) { noteId in
                NoteReaderView(noteId: noteId)
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

    private var skeletonView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                filterChips
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: CornerRadius.md).fill(Color(.tertiarySystemFill)).frame(height: 80)
                }
            }
            .padding(Spacing.lg)
        }
    }

    private var errorView: some View {
        ContentUnavailableView {
            Label("Erreur", systemImage: "exclamationmark.triangle")
        } description: {
            Text(viewModel.errorMessage ?? "Une erreur est survenue")
        } actions: {
            Button("Réessayer") { Task { await viewModel.retry() } }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        ContentUnavailableView("Aucune note trouvée", systemImage: "doc.text.magnifyingglass")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                filterChips
                HStack(alignment: .firstTextBaseline) {
                    Text(viewModel.hasSearched && viewModel.searchQuery.trimmingCharacters(in: .whitespaces).count >= 2 ? "Résultats" : "Notes récentes")
                        .font(.headline)
                    Text("(\(viewModel.results.count))")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, Spacing.md)
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(viewModel.results) { item in
                        NavigationLink(value: item.note.id) {
                            SearchResultRow(item: item, searchTerm: viewModel.searchQuery.trimmingCharacters(in: .whitespaces))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            .padding(.vertical, Spacing.md)
        }
    }

    private var filterChips: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Ligne 1 : Espaces (même tri que la vue Espaces, Non classées à la fin)
            filterRow {
                ForEach(viewModel.orderedSpaces, id: \.id) { s in
                    FilterChip(title: "\(s.emoji) \(s.name)", isSelected: viewModel.filters.spaceId == s.id) {
                        viewModel.filters.spaceId = viewModel.filters.spaceId == s.id ? nil : s.id
                    }
                }
            }
            // Ligne 2 : Types de notes
            filterRow {
                ForEach(viewModel.noteTypes, id: \.id) { nt in
                    FilterChip(title: "\(nt.emoji) \(nt.name)", isSelected: viewModel.filters.noteType == nt.name) {
                        viewModel.filters.noteType = viewModel.filters.noteType == nt.name ? nil : nt.name
                    }
                }
            }
            // Ligne 3 : Tags, date, visibilité
            filterRow {
                ForEach(viewModel.tags, id: \.id) { t in
                    FilterChip(title: "#\(t.name)", isSelected: viewModel.filters.tagId == t.id) {
                        viewModel.filters.tagId = viewModel.filters.tagId == t.id ? nil : t.id
                    }
                }
                ForEach(DateFilter.allCases, id: \.self) { df in
                    FilterChip(title: df.rawValue, isSelected: viewModel.filters.dateFilter == df) {
                        viewModel.filters.dateFilter = df
                    }
                }
                FilterChip(title: "Privée", isSelected: viewModel.filters.isPrivate == true) {
                    viewModel.filters.isPrivate = viewModel.filters.isPrivate == true ? nil : true
                }
                FilterChip(title: "Publique", isSelected: viewModel.filters.isPrivate == false) {
                    viewModel.filters.isPrivate = viewModel.filters.isPrivate == false ? nil : false
                }
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    @ViewBuilder
    private func filterRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                content()
            }
            .padding(.vertical, 2)
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.caption).padding(.horizontal, Spacing.sm).padding(.vertical, 6)
                .background(isSelected ? Color.capsulePrimary : Color(.tertiarySystemFill))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct SearchResultRow: View {
    let item: SearchResultItem
    let searchTerm: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("\(item.spaceEmoji) \(item.spaceName)")
                    .font(.caption2).padding(.horizontal, 6).padding(.vertical, 4)
                    .background(Color(hex: item.spaceColor)).foregroundStyle(.white)
                    .clipShape(Capsule())
                if item.note.isPrivate { Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary) }
                Spacer()
                if let u = item.note.updatedAt {
                    Text(u.relativeString()).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text(item.note.title).font(.headline).fontWeight(.bold)
            if !(item.note.contentPlain ?? item.note.aiSummary ?? "").isEmpty {
                excerptWithHighlight.lineLimit(2)
            }
            HStack(spacing: Spacing.xs) {
                ForEach(item.tags) { tag in
                    Text("#\(tag.name)").font(.caption2).foregroundStyle(Color(hex: tag.color))
                }
            }
            if let p = item.creatorProfile {
                avatarView(p.avatarUrl)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    private var excerptWithHighlight: Text {
        let raw = item.note.contentPlain ?? item.note.aiSummary ?? ""
        guard !searchTerm.isEmpty, let r = raw.lowercased().range(of: searchTerm.lowercased()) else {
            return Text(String(raw.prefix(150)) + (raw.count > 150 ? "..." : "")).font(.caption).foregroundStyle(.secondary)
        }
        let before = String(raw[..<r.lowerBound])
        let match = String(raw[r])
        let after = String(raw[r.upperBound...])
        var beforeAttr = AttributedString(before)
        beforeAttr.foregroundColor = .secondary
        var matchAttr = AttributedString(match)
        matchAttr.backgroundColor = .yellow
        matchAttr.foregroundColor = .primary
        var afterAttr = AttributedString(after)
        afterAttr.foregroundColor = .secondary
        return Text(beforeAttr + matchAttr + afterAttr).font(.caption)
    }

    private func avatarView(_ urlStr: String?) -> some View {
        Group {
            if let u = urlStr, let url = URL(string: u) {
                AsyncImage(url: url) { img in img.resizable() } placeholder: { Color.gray.opacity(0.3) }
            } else { Image(systemName: "person.circle.fill") }
        }
        .frame(width: 24, height: 24).clipShape(Circle())
    }
}

