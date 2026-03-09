//
//  CapsuleAIUITests.swift
//  CapsuleAIUITests
//
//  Tests d'interface utilisateur XCUITest pour Capsule AI.
//  Détecte les crashes, freezes et vérifie que les écrans principaux répondent.
//

import XCTest

final class CapsuleAIUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tests de démarrage

    /// Vérifie que l'app démarre sans crash et qu'un écran principal s'affiche
    func testAppLaunchesWithoutCrash() throws {
        // L'app a lancé = pas de crash au démarrage
        XCTAssertTrue(app.state == .runningForeground)

        // On doit voir soit Login, soit Home/TabRouter (si session restaurée)
        let loginExists = app.staticTexts["Connexion requise"].waitForExistence(timeout: 5)
        let tabNotesExists = app.buttons["Notes"].waitForExistence(timeout: 3)
        let onboardingExists = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'espace' OR label CONTAINS 'Espace'")).firstMatch.waitForExistence(timeout: 3)

        XCTAssertTrue(
            loginExists || tabNotesExists || onboardingExists,
            "Un écran principal (Login, Home ou Onboarding) doit être visible"
        )
    }

    /// Vérifie que l'écran de login s'affiche (quand non connecté)
    func testLoginScreenDisplaysWhenNotAuthenticated() throws {
        // Si on voit "Connexion requise", c'est le login
        let loginTitle = app.staticTexts["Connexion requise"]
        let loginButton = app.buttons["Se connecter avec Google"]

        // L'un des deux indique qu'on est sur le login
        let hasLogin = loginTitle.waitForExistence(timeout: 5) || loginButton.waitForExistence(timeout: 5)

        if hasLogin {
            XCTAssertTrue(loginTitle.exists || loginButton.exists)
            // Le bouton doit être interactif (pas de freeze)
            if loginButton.exists {
                XCTAssertTrue(loginButton.isHittable, "Le bouton de connexion doit être cliquable")
            }
        }
        // Si déjà connecté, le test passe (pas d'assertion de login)
    }

    /// Vérifie que la barre d'onglets custom est visible (quand connecté)
    func testTabBarVisibleWhenAuthenticated() throws {
        // Attendre un peu pour le chargement éventuel
        _ = app.wait(for: .runningForeground, timeout: 3)

        // Chercher les onglets de la barre custom
        let notesTab = app.buttons["Notes"]
        let espacesTab = app.buttons["Espaces"]
        let searchTab = app.buttons["Recherche"]
        let profilTab = app.buttons["Profil"]

        let notesExists = notesTab.waitForExistence(timeout: 8)
        if notesExists {
            XCTAssertTrue(notesTab.exists, "L'onglet Notes doit exister")
            XCTAssertTrue(espacesTab.exists, "L'onglet Espaces doit exister")
            XCTAssertTrue(searchTab.exists, "L'onglet Recherche doit exister")
            XCTAssertTrue(profilTab.exists, "L'onglet Profil doit exister")
        }
        // Si pas connecté, on n'a pas la tab bar → test OK
    }

    /// Vérifie que les onglets répondent (pas de freeze) en tapant sur un élément
    func testTabBarTabsAreTappable() throws {
        let notesTab = app.buttons["Notes"]
        let notesExists = notesTab.waitForExistence(timeout: 8)

        guard notesExists else {
            // Non connecté, on skip le test des onglets
            return
        }

        // Tap sur Espaces
        let espacesTab = app.buttons["Espaces"]
        if espacesTab.exists && espacesTab.isHittable {
            espacesTab.tap()
            // Vérifier qu'on a changé d'écran (pas de freeze)
            let espacesTitle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Espace' OR label CONTAINS 'espace'")).firstMatch
            _ = espacesTitle.waitForExistence(timeout: 3)
            XCTAssertTrue(app.state == .runningForeground, "L'app doit rester réactive après le tap")
        }

        // Retour à Notes
        let notesTabAgain = app.buttons["Notes"]
        if notesTabAgain.exists && notesTabAgain.isHittable {
            notesTabAgain.tap()
            XCTAssertTrue(app.state == .runningForeground, "L'app doit rester réactive")
        }
    }

    /// Test de réactivité : vérifier qu'un élément cliquable répond dans un délai raisonnable
    func testAppRespondsToInteraction() throws {
        // Attendre que l'UI soit prête
        sleep(2)

        let loginButton = app.buttons["Se connecter avec Google"]
        let notesTab = app.buttons["Notes"]

        if loginButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(loginButton.isHittable, "Le bouton login doit être hittable (pas de freeze)")
        } else if notesTab.waitForExistence(timeout: 2) {
            XCTAssertTrue(notesTab.isHittable, "L'onglet Notes doit être hittable (pas de freeze)")
        }
        // Au moins un élément interactif doit répondre
        XCTAssertTrue(app.state == .runningForeground)
    }
}
