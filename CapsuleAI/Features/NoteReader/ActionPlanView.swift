//
//  ActionPlanView.swift
//  CapsuleAI
//

import SwiftUI

struct ActionPlanView: View {
    let actions: [NoteAction]
    let onToggle: (UUID, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("PLAN D'ACTION")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(actions) { action in
                    Button {
                        onToggle(action.id, !action.isChecked)
                    } label: {
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            Image(systemName: action.isChecked ? "checkmark.square.fill" : "square")
                                .foregroundStyle(action.isChecked ? Color.capsuleSuccess : .secondary)
                            Text(action.label)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .strikethrough(action.isChecked)
                            Spacer()
                        }
                        .padding(Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(action.isChecked ? Color.capsuleSuccess.opacity(0.15) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
