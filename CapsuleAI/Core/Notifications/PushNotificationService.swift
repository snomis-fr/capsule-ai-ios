//
//  PushNotificationService.swift
//  CapsuleAI
//

import Foundation
import UIKit
import UserNotifications
import Supabase

/// Gère les notifications push : permission, enregistrement du device token, envoi à Supabase.
final class PushNotificationService {
    static let shared = PushNotificationService()

    private let supabase = SupabaseManager.shared.client

    private init() {}

    /// Demande la permission et enregistre le device token si accordé.
    /// À appeler après connexion quand l'utilisateur a activé les notifications.
    func registerIfAuthorized() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional:
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        case .denied:
            break
        @unknown default:
            break
        }
    }

    /// Appelé par AppDelegate quand le device token est reçu.
    /// Enregistre le token dans Supabase pour l'utilisateur connecté.
    func didRegisterForRemoteNotifications(deviceToken: Data) async {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        guard let userId = (try? await supabase.auth.session)?.user.id else { return }

        struct Insert: Encodable {
            let user_id: UUID
            let token: String
            let platform: String
        }

        do {
            try await supabase
                .from(Tables.deviceTokens)
                .upsert(Insert(user_id: userId, token: tokenString, platform: "ios"), onConflict: "user_id,token")
                .execute()
        } catch {
            print("[PushNotification] Erreur enregistrement token: \(error)")
        }
    }

    /// Appelé quand l'enregistrement pour les notifications push échoue (simulateur).
    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("[PushNotification] Échec enregistrement: \(error.localizedDescription)")
    }
}
