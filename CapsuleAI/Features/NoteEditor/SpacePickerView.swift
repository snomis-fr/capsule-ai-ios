//
//  SpacePickerView.swift
//  CapsuleAI
//

import SwiftUI

struct SpacePickerView: View {
    let spaces: [Space]
    let subSpaces: [SubSpace]
    @Binding var selectedSpaceId: UUID?
    @Binding var selectedSubSpaceId: UUID?

    private var filteredSubSpaces: [SubSpace] {
        guard let sid = selectedSpaceId else { return [] }
        return subSpaces.filter { $0.spaceId == sid }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("→ choisir un espace de travail ↓")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            spaceBadges
            if selectedSpaceId != nil {
                subSpaceBadges
            }
            if selectedSpaceId != nil, selectedSubSpaceId != nil, let space = spaces.first(where: { $0.id == selectedSpaceId }), let sub = filteredSubSpaces.first(where: { $0.id == selectedSubSpaceId }) {
                HStack {
                    Text("\(space.emoji) \(space.name) > \(sub.emoji) \(sub.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "pin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var spaceBadges: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(spaces) { space in
                    Button {
                        selectedSpaceId = space.id
                        selectedSubSpaceId = nil
                    } label: {
                        HStack(spacing: 4) {
                            Text(space.emoji)
                            Text(space.name)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(selectedSpaceId == space.id ? Color(hex: space.color) : Color(.tertiarySystemFill))
                        .foregroundStyle(selectedSpaceId == space.id ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var subSpaceBadges: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(filteredSubSpaces) { sub in
                    Button {
                        selectedSubSpaceId = sub.id
                    } label: {
                        HStack(spacing: 4) {
                            Text(sub.emoji)
                            Text(sub.name)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(selectedSubSpaceId == sub.id ? Color.capsulePrimary : Color(.tertiarySystemFill))
                        .foregroundStyle(selectedSubSpaceId == sub.id ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}
