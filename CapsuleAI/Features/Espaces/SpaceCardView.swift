//
//  SpaceCardView.swift
//  CapsuleAI
//

import SwiftUI

struct SpaceCardView: View {
    let space: Space
    let subSpaces: [SubSpace]
    let noteCount: Int
    let subSpaceNoteCounts: [UUID: Int]
    let sharedSubSpaceIds: Set<UUID>
    let onAddSubSpace: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                if !subSpaces.isEmpty {
                    subSpacesSection
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        }
    }

    private var headerSection: some View {
        HStack(spacing: Spacing.md) {
            LinearGradient(
                colors: [Color(hex: space.color), Color(hex: space.color).opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: 4)
            .clipShape(RoundedRectangle(cornerRadius: 2))

            Text(space.emoji)
                .font(.title2)
            Text(space.name)
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Text("\(subSpaces.count) sous-espaces · \(noteCount) notes")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
            Button(action: onAddSubSpace) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
        .padding(Spacing.md)
        .background(
            LinearGradient(
                colors: [Color(hex: space.color), Color(hex: space.color).opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    private var subSpacesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(subSpaces) { sub in
                NavigationLink(value: SubSpaceRoute(space: space, subSpace: sub)) {
                    HStack(spacing: Spacing.sm) {
                        Text(sub.emoji)
                        Text(sub.name)
                            .font(.subheadline)
                        if !sharedSubSpaceIds.contains(sub.id) {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(subSpaceNoteCounts[sub.id] ?? 0) notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, Spacing.xs)
                    .padding(.horizontal, Spacing.md)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
