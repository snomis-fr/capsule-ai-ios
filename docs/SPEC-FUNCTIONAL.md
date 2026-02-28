# CAPSULE AI — Cahier des charges fonctionnel
## Application native iOS (SwiftUI)
### Version 1.0 — Février 2026

---

## 1. PRÉSENTATION GÉNÉRALE

### 1.1 Concept
Capsule AI est une application collaborative de prise de notes augmentée par l'IA, destinée aux dirigeants et à leurs équipes rapprochées (max 7 collaborateurs). L'application permet de créer, organiser, partager et analyser des notes professionnelles et personnelles dans des espaces thématiques.

### 1.2 Nom de l'application
Le nom affiché est dynamique : **"Capsule [Premier mot du nom de la société]"**
Exemple : si l'entreprise est "Ippon Technologies" → l'app affiche "Capsule Ippon"

### 1.3 Authentification
Connexion obligatoire via **compte Google** (Google Sign-In). L'email Google devient l'identifiant unique de l'utilisateur et ne peut pas être modifié dans l'app.

### 1.4 Rôles utilisateurs
- **Manager** (créateur du workspace) : accès total, gestion des espaces, des collaborateurs, des droits
- **Collaborateur** (invité par le manager, max 7) : accès restreint selon les droits attribués

---

## 2. ARCHITECTURE DE NAVIGATION

### 2.1 Barre de navigation (Tab Bar — bas de l'écran)
5 onglets permanents :

| Position | Icône | Label | Destination |
|----------|-------|-------|-------------|
| 1 | ☰ | Notes | Écran d'accueil (Home) |
| 2 | ⊞ | Espaces | Gestion des espaces |
| 3 | + | +Note | Création de note (bouton bleu, central, proéminent) |
| 4 | 🔍 | Recherche | Recherche et filtres |
| 5 | 🧠 | Coach IA | Assistant IA contextuel |

---

## 3. ÉCRAN D'ACCUEIL (HOME)

### 3.1 Header
- **Date du jour** : localisée selon la langue du téléphone (ex : "Mercredi 18 Fév")
- **Titre** : "Capsule [Premier mot société]" (gras, grande taille)
- **Photo de profil** : coin supérieur droit, circulaire. Tap → navigation vers le profil utilisateur

### 3.2 Barre de recherche
- Placeholder : "Rechercher dans toutes les notes..."
- Recherche full-text sur l'ensemble des notes accessibles par l'utilisateur

### 3.3 Section "Notes" (30 max)
- **Disposition** : grille 2 colonnes
- **Contenu** : les 30 notes les plus récemment modifiées (par l'utilisateur OU par un membre de son équipe)
- **Tri** : par date de dernière modification, la plus récente en premier

#### 3.3.1 Carte note standard
- **Titre** de la note (gras)
- **Résumé auto-généré par IA** (2-3 lignes max, troncature avec "...")
- **Bas gauche** : badge avec le nom de l'espace (couleur de l'espace)
- **Bas droite** : avatar du dernier modificateur + timestamp relatif ("il y a 30 min", "17 févr.")
- **Icône cadenas** si la note est privée/confidentielle
- **Tap** → ouverture de la note en mode lecture

#### 3.3.2 Carte note #Important
- Même structure que la carte standard, PLUS :
- **Image en haut de la carte** : générée automatiquement via API Unsplash/Pexels, en rapport avec le titre/sujet de la note
- **Étoile dorée** + label "IMPORTANT" superposé sur l'image

### 3.4 Section "Tags"
- Affichée après les 30 notes, en scroll vertical
- Liste de **tous les tags** existants dans le workspace
- Chaque tag = point de couleur + #NomDuTag
- **Tap sur un tag** → affiche la liste filtrée de toutes les notes contenant ce tag

---

## 4. ÉCRAN ESPACES

### 4.1 Header
- Bouton "Accueil" (retour à la Home)
- Titre : **"Mes espaces"**
- Sous-titre : "[X] espaces · [X] notes" (compteurs globaux)
- Avatar utilisateur (coin supérieur droit)

### 4.2 Hiérarchie
L'organisation est sur 2 niveaux : **Espace** (niveau 1) → **Sous-espace** (niveau 2) → Notes

### 4.3 Carte Espace (niveau 1)
- Header avec **dégradé de couleur** (couleur définie dans le profil, unique par espace)
- Icône/emoji + **Nom de l'espace** (gras, blanc)
- Sous-titre : "[X] sous-espaces · [X] notes"
- Bouton **"+"** → ouvre la modale de création de sous-espace
- **Badge** avec le nombre total de notes

### 4.4 Règles sur les espaces (niveau 1)
- Les espaces se **créent, suppriment, réordonnent et changent de couleur UNIQUEMENT dans le profil utilisateur** (pas dans l'écran Espaces)
- Un espace ne peut être supprimé que s'il **ne contient plus aucun sous-espace**
- L'ordre des espaces est géré par **drag & drop dans le profil**

### 4.5 Ligne Sous-espace (niveau 2)
- **Icône drag & drop** (6 points à gauche) → réordonner par glisser-déposer
- Icône/emoji du sous-espace
- **Nom** du sous-espace
- Bouton **"Modifier"** (à gauche du compteur) → renommer le sous-espace
- **Nombre de notes** dans le sous-espace
- **Chevron ">"** → navigation vers la liste des notes

### 4.6 Création de sous-espace (modale)
- Titre : "Créer une sous-catégorie"
- Sous-titre : "Dans l'espace « [Nom espace] »"
- Champ texte : Nom (placeholder : "Ex. Projets 2025")
- Boutons : Annuler | Créer

### 4.7 Vue sous-espace ouverte (liste des notes)
- **Breadcrumb** : Accueil > Espaces > [Nom espace]
- Header avec drapeau/icône + nom de l'espace parent + nom du sous-espace
- Dropdown chevron pour naviguer entre sous-espaces du même espace
- Bouton **"Supprimer la sous-catégorie"**
- Section **"📌 Épinglées"** : notes épinglées affichées en premier
- Puis toutes les notes, triées du plus récent au plus ancien
- Chaque carte note affiche : titre, résumé IA, avatar + timestamp, tags

### 4.8 Espace "Non classées"
- **Obligatoire, non supprimable**, toujours en dernière position
- Contient toutes les notes sans espace assigné
- Quand un sous-espace est supprimé → ses notes migrent automatiquement vers "Non classées"
- **Les notes ne sont JAMAIS supprimées** par la suppression d'un sous-espace

---

## 5. CRÉATION / ÉDITION DE NOTE

### 5.1 Header
- Bouton "< Retour"
- Titre : "Nouvelle note" (création) ou "Modifier la note" (édition)
- Bouton **"Enregistrer"** : grisé/inactif tant que les champs obligatoires ne sont pas remplis

### 5.2 Champs obligatoires (bloquent l'enregistrement)
1. **Espace** (niveau 1) — sélection obligatoire
2. **Sous-espace** (niveau 2) — sélection obligatoire
3. **Titre de la note**

Sans ces 3 éléments → bouton Enregistrer reste inactif, impossible de sauvegarder.

### 5.3 Sélection de l'espace de travail
- Label : "→ choisir un espace de travail ↓"
- Affiche tous les espaces sous forme de **badges cliquables** (emoji + nom)
- Sélection d'un espace → affiche ses sous-espaces pour sélection
- **Breadcrumb** affiché après sélection : [Icône Espace] > [Icône Sous-espace]
- Icône épingle à droite du breadcrumb

### 5.4 Éditeur de texte riche (Tiptap ou équivalent)
- **Champ titre** : placeholder "Titre de la note..."
- **Barre de formatage** :
  - Titres : T1, T2, T3
  - Style : Gras, Italique, Souligné
  - Listes : à puces, numérotée
  - Indentation : augmenter / diminuer
  - Alignement texte
  - Insertion de tableau
- **Barre d'outils secondaire** :
  - **Fond** : couleur de fond du bloc de texte
  - **Séparateur** : ligne horizontale
  - **"+ Insérer"** → menu popup avec 3 options :
    - Image depuis mon fichier...
    - Image depuis une URL...
    - Vidéo YouTube...
  - **"✨ IA"** → menu popup avec 3 options :
    - ✨ Résumer
    - ✨ Restructurer
    - ✨ Suggestions
  - **"👥 Collaboration"** (fonctionnalité future)
- **Footer éditeur** : compteur de mots (gauche) + date de création (droite)

### 5.5 Pièces jointes
- Titre : "PIÈCES JOINTES" + badge compteur (X)
- Bouton **"+ Ajouter depuis l'ordinateur"** (ou "depuis le téléphone" sur iOS)
- 3 types acceptés : **Photo** | **PDF** | **Fichier**
- **Limites** :
  - Photos : 4 Mo max
  - PDF / Documents : 20 Mo max
- Affichage des PJ ajoutées : icône type + nom du fichier + taille + bouton ✕ pour supprimer

### 5.6 Tags (0/3)
- **Maximum 3 tags par note**
- Affiche tous les tags disponibles sous forme de badges cliquables
- Tags sélectionnés = style plein coloré
- Tags non sélectionnés = style outline

### 5.7 Note privée
- Checkbox : "Note privée (visible uniquement par moi)"
- Cochée = note visible uniquement par le créateur
- Non cochée = visible par les membres ayant accès au sous-espace

### 5.8 Métadonnées
- 📅 **Date et heure** : auto-remplie à la création
- 📌 **Épinglée** : toggle on/off
- 👤 **Créée par** : avatar(s) des auteurs
- 🤝 **Partagée avec** : liste des personnes ayant accès + badge "Privée" si applicable

### 5.9 Géolocalisation automatique
- À l'enregistrement, l'app capture automatiquement la **localisation** (ville + pays) de l'utilisateur
- Stockée comme métadonnée de la note (non modifiable manuellement)
- **Permission activable/désactivable dans le profil** (section Paramètres)
- Si désactivée → aucune localisation enregistrée

### 5.10 Type de note
Sélection unique parmi des types prédéfinis (+ option "Aucun"). Chaque type déclenche un **plan d'action spécifique** :

#### 📋 Réunion / compte-rendu
- ☐ Extraire les décisions prises
- ☐ Lister les actions à suivre
- ☐ Planifier le prochain point

#### 🎯 Projet / initiative
- ☐ Décomposer en jalons
- ☐ Identifier les dépendances
- ☐ Estimer les ressources nécessaires

#### ⚠️ Problème / incident
- ☐ Analyser les causes
- ☐ Proposer des solutions
- ☐ Définir un plan de contingence

#### 💡 Stratégie / réflexion
- ☐ Prioriser les options
- ☐ Évaluer les risques
- ☐ Définir les critères de succès

#### Aucun
- Pas de plan d'action spécifique

#### Actions universelles (affichées pour tous les types sauf "Aucun")
- ☐ Définir les prochaines étapes
- ☐ Assigner des responsables
- ☐ Fixer des deadlines
- ☐ Identifier les blocages

**Règle importante** : la liste des types et leurs actions sont **personnalisables dans le profil utilisateur** (ajout, modification, suppression). Pas de valeurs codées en dur.

### 5.11 Assistance IA (bas de page)
- Icône ✨ + "Assistance IA — Laissez Claude vous aider à structurer"
- 4 boutons d'action rapide :
  - Structurer la note
  - Résumer en 3 points
  - Ajouter un plan d'action
  - Traduire en anglais

### 5.12 Bouton final
- **"Enregistrer la note"** : pleine largeur, bas de page, grisé si champs obligatoires manquants

---

## 6. VUE LECTURE D'UNE NOTE

### 6.1 Header
- **Breadcrumb** : Accueil | Espace (liens cliquables)
- 3 boutons d'action (coin supérieur droit) :
  - **+** → créer une nouvelle note
  - **✏️** → passer en mode édition
  - **🗑** → supprimer la note

### 6.2 Métadonnées en haut
- **Badge espace** : "[Espace] · [Sous-espace]" + date et heure
- **Titre de la note** (gros, gras)
- **Bandeau modification** : avatar + "Modifié par [Prénom]" + timestamp relatif — fond rose, mis en avant visuellement
- **Bloc "Résumé IA"** : icône robot + résumé auto-généré (2-3 lignes, fond gris clair)

### 6.3 Corps de la note
- Rendu riche complet du contenu Tiptap (titres, listes, gras, italique, tableaux, images, vidéos)
- **Mode lecture uniquement** — pas d'édition directe du texte

### 6.4 Bloc "Type de note + Plan d'action"
- Badge type avec emoji + nom (ex : "🎯 Projet / initiative")
- Label : "PLAN D'ACTION"
- Liste de checkboxes : actions spécifiques au type + actions universelles
- **Les checkboxes SONT interactives en mode lecture** : on peut cocher/décocher directement sans passer en mode édition
- Actions cochées = fond vert clair

### 6.5 Tags
- Badges colorés des tags associés à la note

### 6.6 Assistance IA
- Même bloc que dans l'écran de création :
  - Structurer la note
  - Résumer en 3 points
  - Ajouter un plan d'action
  - Traduire en anglais

### 6.7 Barre d'outils bas
- 5 icônes de navigation rapide dans le contenu : ☰ liste | ✓ check | ⊞ tableau | A texte | ☐ bloc

---

## 7. RECHERCHE

### 7.1 Header
- Titre : **"Recherche"** (fond bleu foncé)
- Barre de recherche : "Rechercher dans toutes les notes..."
- Recherche full-text sur l'ensemble des notes

### 7.2 Filtres rapides (2 lignes de badges cliquables)

#### Ligne 1 — PAYS (lieu de création de la note)
- Badges avec drapeau + nom : 🇫🇷 France | 🇲🇦 Maroc | 🇺🇸 USA | 🌍 Autres
- Tap → filtre les notes créées dans ce pays

#### Ligne 2 — CAT. (espaces)
- Badges avec emoji + nom de chaque espace
- Liste scrollable horizontalement
- Tap → filtre les notes de cet espace

### 7.3 Comportement des filtres
- Tap sur un filtre → affiche immédiatement la liste des notes correspondantes
- Les filtres sont **combinables** (pays + espace)
- Compteur de résultats affiché : "[X] RÉSULTATS"

### 7.4 Liste des résultats
- Format de carte en liste verticale (pleine largeur)
- Chaque carte affiche :
  - Image Unsplash si tag #Important
  - Breadcrumb : [Espace] > [Sous-espace]
  - Tags (badges colorés)
  - Titre (gras)
  - Résumé IA (1-2 lignes, troncature "...")
  - 📍 Lieu (badge en bas à gauche)
  - Date + drapeau du pays (bas à droite)
- **Tri** : du plus récent au moins récent
- **Tap sur une carte** → ouverture de la note en mode lecture

---

## 8. COACH IA

### 8.1 Design
- **Thème dark** distinct du reste de l'app (fond sombre)
- S'ouvre en plein écran avec bouton "✕ Fermer" (coin supérieur gauche)
- Indicateur **"● En ligne"** (coin supérieur droit)

### 8.2 Header
- Avatar Coach IA (🧠)
- Titre : **"Coach IA"**
- Sous-titre : "Connecté à tous vos espaces Capsule [Nom]"

### 8.3 Message d'accueil
- Bulle IA : "Bonjour [Prénom] 👋 Je suis votre Coach IA. Je connais vos [X] espaces de travail et vos priorités. Que puis-je faire pour vous aujourd'hui ?"

### 8.4 Suggestions (4 actions contextuelles)
Les suggestions sont **exclusivement liées aux notes de l'utilisateur** (pas de fonctions IA génériques). Exemples dynamiques :
- 📋 "Quelles actions sont en retard dans mes notes ?"
- ✅ "Quels suivis n'ont pas été cochés ?"
- 🔴 "Résume mes notes #Important de cette semaine"
- 🔔 "Quelles notes n'ont pas été mises à jour depuis 7 jours ?"

Les suggestions sont dynamiques et contextuelles, basées sur l'état réel des notes.

### 8.5 Zone de chat
- Interface conversationnelle (bulles)
- Le Coach IA a accès à **l'ensemble des notes, espaces, tags et métadonnées** de l'utilisateur
- Champ de saisie en bas : "Posez votre question..."
- Bouton d'envoi (icône avion, violet)

### 8.6 Périmètre du Coach IA
- Analyse des notes **uniquement** (pas un assistant généraliste)
- Détection des actions en retard / non cochées
- Résumés croisés par espace, tag, période
- Alertes sur les notes non mises à jour
- Recherche intelligente dans les notes

---

## 9. PROFIL UTILISATEUR

### 9.1 Header
- Bouton "< Retour"
- Bouton **"Sauvegarder"** (bleu)
- Bouton **"Déconnexion"** (rouge)
- **Photo de profil** : circulaire, cliquable → changer la photo (redimensionnée 200×200 px, recadrage centre)
- Pastille verte = en ligne
- **"MON COMPTE"** + Prénom Nom
- 📍 Ville

### 9.2 Infos personnelles
- Bouton "Modifier" / "Fermer" pour basculer lecture ↔ édition
- Champs :
  - **Prénom** : modifiable
  - **Nom** : modifiable
  - **Email** : NON modifiable (compte Google de connexion)
  - **Ville** : modifiable (placeholder : "ex. Marrakech · Paris")
  - **Titre** : modifiable (ex : "CEO & Fondateur")
  - **Entreprise** : modifiable UNIQUEMENT par le manager
  - **Activité** : champ NON modifiable

### 9.3 Activité Capsule
- 4 cartes statistiques (calculées automatiquement, non modifiables) :
  - 📝 Notes totales
  - 📂 Espaces actifs
  - ✏️ Créées par [Prénom]
  - 🔴 Tags importants

### 9.4 Gestion des espaces
- Bouton **"+ Ajouter un espace"** (bordure pointillée)
  - Modale : "Nom du nouvel espace" → Annuler | OK
- Liste des espaces :
  - Emoji/icône + Nom + "[X] sous-catégories · [X] notes"
  - Icône **corbeille** → supprimer
- **Réordonner par drag & drop**
- **Règle de suppression** : un espace ne peut être supprimé que s'il ne contient plus aucun sous-espace
- L'espace "Non classées" ne peut jamais être supprimé

### 9.5 Collaborateurs (X/7)
- Compteur : "[X]/7" — maximum 7 collaborateurs
- Bouton **"+ Ajouter"**
- Liste des collaborateurs :
  - Icône drag & drop
  - Emoji métier + Avatar
  - Prénom + badge statut (Dispo / Congés / Malade / Aucun)
  - Titre du poste
  - Chevron ">" → fiche collaborateur

#### 9.5.1 Fiche collaborateur (écran "Modifier")
- Header : "< Profil" | "Modifier" | "Sauvegarder"
- **Section IDENTITÉ** :
  - Photo de profil (cliquable, 200×200 px) + "Supprimer la photo"
  - Prénom, Nom
  - Icône métier (dropdown)
  - Titre du poste
  - Email (non modifiable)
  - Statut : Aucun | Dispo | Congés | Malade
- **Section DROITS D'ACCÈS** :
  - "Cochez les sous-catégories que ce collaborateur peut consulter"
  - Liste de tous les espaces avec leurs sous-espaces en checkboxes
  - Bouton "Tout cocher" par espace
  - Le manager décide quels espaces/sous-espaces sont visibles pour chaque collaborateur
- Boutons : **Supprimer** (rouge) | Annuler | **Enregistrer** (bleu)

#### 9.5.2 Règles collaborateurs
- Le collaborateur peut modifier sur son profil : **sa photo, son titre et son statut**
- Le collaborateur peut créer ses propres espaces et sous-espaces **privés** (visibles uniquement par lui)
- Ses espaces personnels apparaissent **toujours APRÈS** les espaces partagés du manager
- Le collaborateur **NE PEUT PAS** :
  - Faire de drag & drop sur les espaces/sous-catégories du manager
  - Changer le nom de la société
  - Créer ou partager un espace/sous-espace avec d'autres (toute création/partage passe par le manager)
- Le **manager N'A PAS accès** aux espaces privés du collaborateur

### 9.6 Tags
- Bouton **"+ Ajouter"**
  - Modale "Nouveau tag" : champ nom + grille de 24 couleurs → Annuler | Enregistrer
- Liste des tags existants :
  - Point de couleur + Nom + badge preview (#NomDuTag)
  - Bouton ✏️ modifier (renommer, changer couleur)
  - Bouton 🗑 supprimer

### 9.7 Types de notes (personnalisables)
- Liste des types de notes avec leurs actions associées
- Possibilité d'**ajouter, modifier, supprimer** des types et leurs actions
- Chaque type a :
  - Un emoji + un nom
  - Une liste d'actions spécifiques (checkboxes)
  - Les actions universelles restent communes à tous les types

### 9.8 Paramètres
- **Notifications** : "Recevoir des notifications quand un membre crée ou modifie une note ?" → Oui | Non
- **Synchronisation** : "Enregistrer les notes en mode hors ligne ?" → Oui | Non (future feature native)
- **Confidentialité** : (à détailler)
- **Géolocalisation** : toggle activer/désactiver la capture automatique du lieu à l'enregistrement des notes
- **Se déconnecter** (rouge)

### 9.9 Sauvegarde
Toute modification dans le profil est **sauvegardée en base de données** au clic sur "Sauvegarder" ou à la fermeture de l'écran.

---

## 10. FONCTIONNALITÉS IA (TRANSVERSES)

### 10.1 Résumé automatique de note
- Déclenché automatiquement à chaque sauvegarde de note
- Génère un résumé de 2-3 lignes affiché sur les cartes notes (Home, Recherche, Espaces)
- Utilisé aussi dans le bloc "Résumé IA" en mode lecture

### 10.2 Assistance IA dans l'éditeur (bouton ✨ IA)
3 actions disponibles depuis l'éditeur :
- **Résumer** : condense le contenu de la note
- **Restructurer** : réorganise et met en forme le contenu
- **Suggestions** : propose des améliorations ou compléments

### 10.3 Assistance IA en bas de note
4 actions disponibles en création et en lecture :
- **Structurer la note** : organise le contenu en sections logiques
- **Résumer en 3 points** : extrait les 3 points clés
- **Ajouter un plan d'action** : génère des actions concrètes à partir du contenu
- **Traduire en anglais** : traduit l'intégralité de la note

### 10.4 Image automatique (notes #Important)
- Pour toute note taguée #Important, une image est automatiquement récupérée via API Unsplash/Pexels
- L'image est **en rapport avec le titre/sujet** de la note
- Affichée en haut de la carte note sur la Home et dans la Recherche

### 10.5 Coach IA
- Voir section 8 pour le détail complet
- Scope : analyse des notes uniquement, pas d'assistant généraliste

---

## 11. RÈGLES MÉTIER GLOBALES

### 11.1 Données obligatoires pour une note
- Espace + Sous-espace + Titre → sinon pas de sauvegarde possible

### 11.2 Suppression protégée
- Supprimer un sous-espace → les notes migrent vers "Non classées"
- Supprimer un espace → impossible s'il contient encore des sous-espaces
- "Non classées" → ne peut jamais être supprimé

### 11.3 Limites
- 30 notes max affichées en Home
- 3 tags max par note
- 7 collaborateurs max par workspace
- Photos : 4 Mo max
- PDF/Docs : 20 Mo max

### 11.4 Confidentialité
- Note privée = visible uniquement par son créateur
- Droits d'accès gérés au niveau sous-espace par le manager
- Le manager n'a pas accès aux espaces privés des collaborateurs

### 11.5 Géolocalisation
- Capture automatique à la sauvegarde (si activée dans les paramètres)
- Stockée comme métadonnée (ville + pays)
- Utilisée pour le filtre PAYS dans la Recherche

### 11.6 Sauvegarde
- Toutes les données sont persistées en base de données
- Le profil se sauvegarde au clic "Sauvegarder" ou à la fermeture

---

## 12. ÉCRANS RÉCAPITULATIFS

| # | Écran | Accès |
|---|-------|-------|
| 1 | Login (Google Sign-In) | Lancement app |
| 2 | Home (Notes) | Tab "Notes" |
| 3 | Espaces | Tab "Espaces" |
| 4 | Liste notes d'un sous-espace | Tap sur un sous-espace |
| 5 | Création de note | Tab "+Note" |
| 6 | Édition de note | Bouton ✏️ en lecture |
| 7 | Lecture de note | Tap sur une carte note |
| 8 | Recherche | Tab "Recherche" |
| 9 | Coach IA | Tab "Coach IA" |
| 10 | Profil utilisateur | Tap sur la photo de profil |
| 11 | Fiche collaborateur | Tap sur un collaborateur dans le profil |
| 12 | Liste notes par tag | Tap sur un tag (Home ou Recherche) |
| 13 | Modales : création sous-espace, création espace, nouveau tag | Actions dans Espaces et Profil |
| 14 | Sous-écrans paramètres : Notifications, Synchronisation, Confidentialité | Profil > Paramètres |

---

*Document généré le 28 février 2026 — Capsule AI v1.0*
*Prêt pour développement iOS natif (SwiftUI) via Cursor*
