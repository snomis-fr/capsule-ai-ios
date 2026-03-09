//
//  NoteCardView.swift
//  CapsuleAI
//

import SwiftUI

struct NoteCardView: View {
    let note: Note
    let spaceName: String?
    let spaceColor: String
    let isImportant: Bool
    let modifierProfile: Profile?

    init(note: Note, spaceName: String? = nil, spaceColor: String = "#3B82F6", isImportant: Bool = false, modifierProfile: Profile? = nil) {
        self.note = note
        self.spaceName = spaceName
        self.spaceColor = spaceColor
        self.isImportant = isImportant
        self.modifierProfile = modifierProfile
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if isImportant, let urlString = note.unsplashImageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 80)
                .clipped()
                .overlay(alignment: .topTrailing) {
                    Text("IMPORTANT")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(Spacing.xs)
                }
            }

            Text(note.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .foregroundStyle(.primary)

            if let name = spaceName {
                Text(name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 4)
                    .background(Color(hex: spaceColor))
                    .clipShape(Capsule())
            }

            if let summary = note.aiSummary, !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack {
                if let p = modifierProfile {
                    noteCardAvatar(p.avatarUrl)
                }
                Spacer()
                if note.isPrivate {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let updated = note.updatedAt {
                    Text(updated.relativeString())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    private func noteCardAvatar(_ urlStr: String?) -> some View {
        Group {
            if let u = urlStr, let url = URL(string: u) {
                AsyncImage(url: url) { img in img.resizable() } placeholder: { Color.gray.opacity(0.3) }
            } else {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 24, height: 24)
        .clipShape(Circle())
    }
}
