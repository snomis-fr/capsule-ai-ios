//
//  AppState.swift
//  CapsuleAI
//

import Foundation
import Observation

@Observable
final class AppState {
    var isAuthenticated = false
    var currentUserId: UUID?
    var currentWorkspaceId: UUID?
    var currentProfile: Profile?
    /// Index de l'onglet sélectionné (0=Notes, 1=Espaces, 2=+Note, 3=Recherche, 4=Profil)
    var selectedTabIndex = 0
}
