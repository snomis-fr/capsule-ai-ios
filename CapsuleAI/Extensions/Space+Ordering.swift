//
//  Space+Ordering.swift
//  CapsuleAI
//
//  RÈGLE DANS LE MARBRE : « Non classé » (isDefault) doit TOUJOURS être en dernier
//  dans tout affichage des espaces. Ne jamais inverser.
//

import Foundation

extension Array where Element == Space {
    /// « Non classé » toujours en dernier. Règle immuable.
    func sortedWithDefaultLast() -> [Space] {
        sorted { s1, s2 in
            if s1.isDefault { return false }
            if s2.isDefault { return true }
            return s1.sortOrder < s2.sortOrder
        }
    }
}
