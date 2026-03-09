# Configuration Google Sign-In pour Capsule AI (OAuth Supabase)

L'app utilise le **flux OAuth Supabase** : ouverture du navigateur vers la page Google de Supabase, puis retour dans l'app. **Pas de nonce, pas de problème.**

## Configuration Supabase (automatique)

La redirect URL `capsuleai://**` est définie dans `supabase/config.toml` et poussée via CLI :

```bash
supabase config push --yes
```

→ **Pas besoin de configurer manuellement** si tu utilises le projet lié (`wuezwpyfxeqhbzwcmhsj`). La règle `.cursor/rules/supabase-config.mdc` demande à l'IA d'exécuter cette commande en début de session.

## Configuration manuelle (fallback)

### 1. Authentication → URL Configuration

Dans **Redirect URLs**, ajoute :
```
capsuleai://**
```

### 2. Authentication → Providers → Google

- Client ID : `150715129732-na7sn7pb3l964f88ojq1k6ektbngk6ea.apps.googleusercontent.com`
- Client Secret : (ta clé secrète Web)
- URI de redirection du client Web Google : `https://wuezwpyfxeqhbzwcmhsj.supabase.co/auth/v1/callback`

## Fonctionnement

1. L'utilisateur tape sur « Se connecter avec Google »
2. Un navigateur s’ouvre sur la page de connexion Google de Supabase
3. Après connexion, redirection vers `capsuleai://auth/callback`
4. L’app reçoit les tokens et crée la session

## Google Cloud Console

Le client **Capsule AI Web** doit avoir dans **URI de redirection autorisés** :
- `https://wuezwpyfxeqhbzwcmhsj.supabase.co/auth/v1/callback`
