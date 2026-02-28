# Stratégie de test — 2 iPhones

## Devices
| Device | Rôle | Compte Google | Usage |
|--------|------|---------------|-------|
| iPhone 1 (Stéphane) | **Manager** | snomis@ippon.fr | Crée le workspace, gère tout |
| iPhone 2 (Test) | **Collaborateur** | compte test Google | Teste les droits restreints |

## Scénarios de test par feature

### 1. AUTHENTIFICATION
| # | Test | Device | Résultat attendu |
|---|------|--------|-----------------|
| 1.1 | Login Google | Les 2 | Connexion OK, profil créé |
| 1.2 | Relancer l'app | Les 2 | Session persistée, pas de re-login |
| 1.3 | Déconnexion | Les 2 | Retour écran login, session effacée |

### 2. WORKSPACE & PROFIL
| # | Test | Device | Résultat attendu |
|---|------|--------|-----------------|
| 2.1 | Créer workspace | Manager | "Capsule Ippon" créé |
| 2.2 | Modifier profil (nom, titre, ville) | Manager | Sauvegardé en BDD |
| 2.3 | Changer photo profil | Les 2 | Upload OK, affichée partout |
| 2.4 | Voir nom société | Collab | Voit "Capsule Ippon", ne peut pas modifier |
| 2.5 | Modifier son titre | Collab | OK |
| 2.6 | Modifier son statut | Collab | OK (Dispo/Congés/Malade) |
| 2.7 | Modifier autre champ | Collab | Interdit (grisé ou non affiché) |

### 3. ESPACES & SOUS-ESPACES
| # | Test | Device | Résultat attendu |
|---|------|--------|-----------------|
| 3.1 | Créer un espace | Manager (profil) | Espace créé avec emoji et couleur |
| 3.2 | Réordonner espaces (drag & drop) | Manager (profil) | Nouvel ordre sauvegardé |
| 3.3 | Supprimer espace vide | Manager | Supprimé |
| 3.4 | Supprimer espace avec sous-espaces | Manager | **Bloqué** avec message erreur |
| 3.5 | Créer un sous-espace | Manager | Sous-espace ajouté dans l'espace |
| 3.6 | Supprimer sous-espace avec notes | Manager | Notes migrent vers "Non classées" |
| 3.7 | Supprimer "Non classées" | Manager | **Impossible** |
| 3.8 | Voir espaces partagés | Collab | Voit uniquement ceux autorisés |
| 3.9 | Créer espace privé | Collab | Créé, visible que par lui |
| 3.10 | Vérifier espace privé collab | Manager | **Ne voit PAS** l'espace privé du collab |
| 3.11 | Drag & drop espaces du manager | Collab | **Interdit** |

### 4. COLLABORATEURS
| # | Test | Device | Résultat attendu |
|---|------|--------|-----------------|
| 4.1 | Ajouter un collaborateur | Manager | Collab ajouté (max 7) |
| 4.2 | Ajouter un 8ème | Manager | **Bloqué** avec message |
| 4.3 | Définir droits d'accès | Manager | Checkboxes sous-espaces |
| 4.4 | Retirer accès à un sous-espace | Manager | Collab ne voit plus les notes |
| 4.5 | Supprimer un collaborateur | Manager | Supprimé, ses notes privées supprimées |

### 5. NOTES — CRÉATION
| # | Test | Device | Résultat attendu |
|---|------|--------|-----------------|
| 5.1 | Créer note sans espace | Les 2 | **Bouton Enregistrer grisé** |
| 5.2 | Créer note sans titre | Les 2 | **Bouton Enregistrer grisé** |
| 5.3 | Créer note complète | Les 2 | Note créée, résumé IA généré |
| 5.4 | Ajouter 3 tags | Les 2 | OK |
| 5.5 | Ajouter un 4ème tag | Les 2 | **Bloqué** avec message |
| 5.6 | Marquer note privée | Les 2 | Cadenas affiché |
| 5.7 | Ajouter pièce jointe photo > 4 Mo | Les 2 | **Refusée** avec message |
| 5.8 | Ajouter pièce jointe PDF < 20 Mo | Les 2 | OK |
| 5.9 | Sélectionner type "Projet" | Les 2 | Checkboxes plan d'action affichées |
| 5.10 | Géolocalisation activée | Les 2 | Ville + pays capturés |
| 5.11 | Géolocalisation désactivée | Les 2 | Champ lieu vide |

### 6. NOTES — LECTURE & ÉDITION
| # | Test | Device | Résultat attendu |
|---|------|--------|-----------------|
| 6.1 | Ouvrir note en lecture | Les 2 | Contenu rendu, résumé IA affiché |
| 6.2 | Cocher une action en lecture | Les 2 | Checkbox mise à jour, fond vert |
| 6.3 | Passer en édition | Les 2 | Éditeur Tiptap chargé |
| 6.4 | Voir note privée d'un autre | Collab | **Invisible** (pas dans la liste) |
| 6.5 | Supprimer une note | Créateur | Supprimée |
| 6.6 | Bandeau "Modifié par" | Les 2 | Affiche avatar + prénom dernier modif |

### 7. NOTES — TEMPS RÉEL
| # | Test | Device | Résultat attendu |
|---|------|--------|-----------------|
| 7.1 | Manager crée une note | Collab | Note apparaît sur Home du collab (si accès) |
| 7.2 | Collab coche une action | Manager | Checkbox mise à jour sur l'écran du manager |
| 7.3 | Manager modifie une note | Collab | Bandeau "Modifié par" mis à jour |

### 8. RECHERCHE
| # | Test | Device | Résultat attendu |
|---|------|--------|-----------------|
| 8.1 | Recherche full-text | Les 2 | Résultats pertinents |
| 8.2 | Filtre par pays | Les 2 | Notes du pays sélectionné |
| 8.3 | Filtre par espace | Les 2 | Notes de l'espace sélectionné |
| 8.4 | Combinaison pays + espace | Les 2 | Intersection correcte |
| 8.5 | Compteur résultats | Les 2 | "[X] RÉSULTATS" correct |

### 9. COACH IA
| # | Test | Device | Résultat attendu |
|---|------|--------|-----------------|
| 9.1 | Ouvrir Coach IA | Les 2 | Message d'accueil avec prénom |
| 9.2 | Tap suggestion | Les 2 | Réponse contextuelle basée sur les notes |
| 9.3 | Question libre | Les 2 | Réponse pertinente, scope = notes only |
| 9.4 | Question hors-scope | Les 2 | Coach refuse poliment, redirige vers notes |

### 10. ASSISTANCE IA
| # | Test | Device | Résultat attendu |
|---|------|--------|-----------------|
| 10.1 | "Structurer la note" | Les 2 | Note restructurée avec titres |
| 10.2 | "Résumer en 3 points" | Les 2 | 3 points clés générés |
| 10.3 | "Traduire en anglais" | Les 2 | Traduction complète |
| 10.4 | "Ajouter plan d'action" | Les 2 | Actions concrètes générées |
| 10.5 | Note #Important → image | Les 2 | Image Unsplash affichée sur la carte |

## Process de test
1. **Après chaque feature** → tester sur iPhone Manager
2. **Si la feature touche aux droits/collaboration** → tester AUSSI sur iPhone Collaborateur
3. **Avant chaque push sur `develop`** → passer les tests critiques (auth, création note, droits)
4. **Avant chaque release TestFlight** → passer TOUS les scénarios
