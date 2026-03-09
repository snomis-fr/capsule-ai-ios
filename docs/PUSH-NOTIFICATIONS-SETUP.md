# Configuration des notifications push

Ce document décrit comment activer les notifications push dans Capsule AI : quand un collaborateur crée ou modifie une note, les autres collaborateurs (et le manager) reçoivent une notification sur leur téléphone.

---

## 1. Sur l’iPhone — Paramètres système

L’utilisateur doit activer les notifications pour l’app :

1. **Réglages** > **Notifications**
2. Sélectionner **Capsule AI**
3. Activer **Autoriser les notifications**
4. Optionnel : activer **Accrochage** (écran de verrouillage), **Centre de notifications** et **Bannières**
5. Conserver ** Sons** activé si souhaité

---

## 2. Dans l’app Capsule AI — Paramètres Profil

1. Aller dans **Profil** (onglet)
2. Section **Paramètres**
3. Activer le toggle **Notifications**

Si désactivé, l’app ne demandera pas la permission système et aucun push ne sera envoyé.

---

## 3. Côté Apple Developer — Clé APNs

1. Aller sur [Apple Developer > Certificates, Identifiers & Profiles > Keys](https://developer.apple.com/account/resources/authkeys/list)
2. Créer une clé : **+** → nom « APNs Capsule » → cocher **Apple Push Notifications service (APNs)** → Continuer → Enregistrer
3. Télécharger le fichier `.p8` (une seule fois)
4. Noter :
   - **Key ID** (ex. `ABC123XY`)
   - **Team ID** (Identifiant d’équipe dans le compte Apple Developer)
   - Contenu du fichier `.p8`

---

## 4. Supabase — Secrets de l’Edge Function

```bash
supabase secrets set APNS_KEY_ID="VOTRE_KEY_ID"
supabase secrets set APNS_TEAM_ID="VOTRE_TEAM_ID"
supabase secrets set APNS_KEY_P8="-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...
-----END PRIVATE KEY-----"
```

Pour la **production** (App Store / TestFlight) :

```bash
supabase secrets set APNS_PRODUCTION="true"
```

Pour le développement (Xcode direct sur un appareil) : ne pas définir `APNS_PRODUCTION` ou mettre `false`.

---

## 5. Base de données — Migration et webhook

### Migration

```bash
cd /Users/stephanenomis/Documents/GitHub/capsule-ai-ios
supabase db push
```

Cela crée la table `device_tokens`.

### Webhook (Supabase Dashboard)

1. Aller sur [Supabase Dashboard](https://supabase.com/dashboard) > projet
2. **Database** > **Webhooks** > **Create a new hook**
3. Configuration :
   - **Name** : `note-notify`
   - **Table** : `notes`
   - **Events** : cocher **Insert** et **Update**
   - **Type** : **Supabase Edge Functions**
   - **Function** : `note-notify`
4. **Add auth header with service key** (pour autoriser l’appel)
5. Créer le webhook

---

## 6. Déploiement de l’Edge Function

```bash
supabase functions deploy note-notify
```

---

## 7. Capability Push Notifications dans Xcode

1. Ouvrir le projet dans Xcode
2. Cible **CapsuleAI** > **Signing & Capabilities**
3. Vérifier que **Push Notifications** est présent (ajouté automatiquement via `CapsuleAI.entitlements`)

Si la capability n’apparaît pas :
- **+ Capability** > **Push Notifications**
- Vérifier que le **Bundle ID** correspond à celui configuré pour APNs sur Apple Developer

---

## Résumé du flux

1. L’utilisateur se connecte → l’app demande l’autorisation de notifications (si activées dans Profil)
2. Si l’utilisateur accepte → le device token est enregistré dans `device_tokens`
3. Lorsqu’une note est créée ou modifiée → le webhook déclenche `note-notify`
4. L’Edge Function récupère les destinataires (manager + collaborateurs du sous-espace, sauf l’auteur)
5. Elle envoie une notification APNs à chaque device token des utilisateurs concernés (qui ont les notifications activées)

---

## Vérifications rapides

| Étape                                   | Vérification                                                  |
|----------------------------------------|---------------------------------------------------------------|
| Paramètres iPhone                      | Réglages > Notifications > Capsule AI activé                 |
| Paramètres app                         | Profil > Notifications activé                                |
| Table `device_tokens`                  | Au moins une ligne par utilisateur test                      |
| Secrets Supabase                       | `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_KEY_P8` définis         |
| Webhook                                | Actif sur `notes` (Insert + Update)                          |
| Entitlement                            | `aps-environment` présent dans CapsuleAI.entitlements        |
