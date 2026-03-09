//
//  Date+Relative.swift
//  CapsuleAI
//

import Foundation

extension Date {
    /// Chaîne relative au présent (ex. "2 min", "1 h") sans "ago" / "il y a".
    func relativeString(style: RelativeDateTimeFormatter.UnitsStyle = .abbreviated) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale.current
        f.unitsStyle = style
        var s = f.localizedString(for: self, relativeTo: Date())
        // Retirer "ago" / "il y a" — on sait que c'est dans le passé
        s = s.replacingOccurrences(of: " ago.", with: "")
        s = s.replacingOccurrences(of: " ago", with: "")
        s = s.replacingOccurrences(of: "il y a ", with: "")
        return s.trimmingCharacters(in: .whitespaces)
    }
}
