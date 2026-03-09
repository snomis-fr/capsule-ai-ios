//
//  AppConstants.swift
//  CapsuleAI
//

import CoreGraphics

enum AppLimits {
    /// Limite Notes Home : toutes les notes affichées (Home + Espaces/sous-espaces)
    static let maxNotesHome = 200
    /// Notes récentes affichées par défaut dans l'onglet Recherche (sans filtre de recherche)
    static let maxNotesSearchRecent = 50
    static let maxTagsPerNote = 3
    static let maxCollaborators = 7
    static let maxPhotoSizeMB = 4
    static let maxFileSizeMB = 20
}

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum CornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let pill: CGFloat = 100
}

/// 24 couleurs pour les tags (spec Profil §9.6)
enum TagColors {
    static let all: [String] = [
        "#3B82F6", "#EF4444", "#22C55E", "#F59E0B", "#8B5CF6", "#EC4899",
        "#06B6D4", "#84CC16", "#F97316", "#6366F1", "#14B8A6", "#A855F7",
        "#EAB308", "#64748B", "#78716C", "#6B7280", "#DC2626", "#2563EB",
        "#059669", "#D97706", "#7C3AED", "#DB2777", "#0D9488", "#65A30D"
    ]
}
