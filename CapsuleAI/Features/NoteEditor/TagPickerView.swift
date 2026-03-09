//
//  TagPickerView.swift
//  CapsuleAI
//

import SwiftUI

struct TagPickerView: View {
    let tags: [Tag]
    @Binding var selectedTagIds: Set<UUID>
    let maxSelection: Int

    init(tags: [Tag], selectedTagIds: Binding<Set<UUID>>, maxSelection: Int = AppLimits.maxTagsPerNote) {
        self.tags = tags
        _selectedTagIds = selectedTagIds
        self.maxSelection = maxSelection
    }

    var body: some View {
        FlowLayout(spacing: Spacing.sm) {
                ForEach(tags) { tag in
                    let isSelected = selectedTagIds.contains(tag.id)
                    Button {
                        if isSelected {
                            selectedTagIds.remove(tag.id)
                        } else if selectedTagIds.count < maxSelection {
                            selectedTagIds.insert(tag.id)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: tag.color))
                                .frame(width: 8, height: 8)
                            Text("#\(tag.name)")
                                .font(.subheadline)
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(isSelected ? Color(hex: tag.color).opacity(0.3) : Color(.tertiarySystemFill))
                        .overlay(RoundedRectangle(cornerRadius: CornerRadius.sm).strokeBorder(isSelected ? Color(hex: tag.color) : Color.clear, lineWidth: 2))
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    }
                }
        }
    }
}
