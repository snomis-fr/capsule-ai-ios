//
//  AIAssistButtonsView.swift
//  CapsuleAI
//

import SwiftUI

struct AIAssistButtonsView: View {
    let onStructurer: () -> Void
    let onResumer: () -> Void
    let onPlanAction: () -> Void
    let onTraduire: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                Text("Assistance IA — Laissez l'IA vous aider à structurer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: Spacing.sm) {
                assistButton("Structurer", action: onStructurer)
                assistButton("Résumer en 3 points", action: onResumer)
                assistButton("Plan d'action", action: onPlanAction)
                assistButton("Traduire en anglais", action: onTraduire)
            }
        }
    }

    private func assistButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption2)
                .lineLimit(1)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(Color.capsulePrimary.opacity(0.15))
                .foregroundStyle(Color.capsulePrimary)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
        }
    }
}
