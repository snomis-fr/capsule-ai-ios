-- Migration : importer workspace, espaces et 70 notes pour snomis@ippon.fr
-- Crée le workspace + espaces + types de notes + tags si inexistants, puis insère les notes.

DO $$
DECLARE
  uid UUID;
  ws_id UUID;
  sp_id UUID;
  sub_ids UUID[];
  tag_ids UUID[];
  i INT;
  nid UUID;
  sel_sub INT;
  nt TEXT;
  txt TEXT;
  js JSONB;
  plain TEXT;
  note_count INT;
  tag_defs TEXT[] := ARRAY['priorité','urgent','stratégie','client','suivi','archivé','relecture','validé'];
  tag_colors TEXT[] := ARRAY['#EF4444','#F59E0B','#8B5CF6','#22C55E','#06B6D4','#64748B','#EC4899','#14B8A6'];
  tag_orders INT[] := ARRAY[0,1,2,3,4,5,6,7];
  tn TEXT;
  tc TEXT;
  toi INT;
BEGIN
  -- 1. Trouver l'utilisateur snomis@ippon.fr
  SELECT id INTO uid FROM auth.users WHERE email = 'snomis@ippon.fr';
  IF uid IS NULL THEN
    RAISE NOTICE 'Utilisateur snomis@ippon.fr non trouvé dans auth.users. Migration ignorée.';
    RETURN;
  END IF;

  -- 2. S'assurer que le profil existe
  INSERT INTO profiles (id, email, first_name, last_name)
  SELECT uid, 'snomis@ippon.fr', 'Stéphane', 'Nomis'
  WHERE NOT EXISTS (SELECT 1 FROM profiles WHERE id = uid)
  ON CONFLICT (id) DO NOTHING;

  -- 3. Créer le workspace si inexistant
  SELECT id INTO ws_id FROM workspaces WHERE manager_id = uid;
  IF ws_id IS NULL THEN
    INSERT INTO workspaces (name, display_name, manager_id)
    VALUES ('Capsule Ippon', 'Ippon', uid)
    RETURNING id INTO ws_id;
    RAISE NOTICE 'Workspace créé pour snomis@ippon.fr: %', ws_id;
  END IF;

  -- 4. Créer l'espace "Non classées" si inexistant
  SELECT id INTO sp_id FROM spaces WHERE workspace_id = ws_id AND is_default = true;
  IF sp_id IS NULL THEN
    INSERT INTO spaces (workspace_id, name, emoji, color, sort_order, is_default, created_by, is_private)
    VALUES (ws_id, 'Non classées', '📁', '#6B7280', 0, true, uid, false)
    RETURNING id INTO sp_id;
    RAISE NOTICE 'Espace Non classées créé: %', sp_id;
  END IF;

  -- 5. Créer les sous-espaces Général + Poubelle si inexistants
  IF NOT EXISTS (SELECT 1 FROM sub_spaces WHERE space_id = sp_id AND is_trash = false) THEN
    INSERT INTO sub_spaces (space_id, name, emoji, sort_order, created_by, is_trash)
    VALUES (sp_id, 'Général', '📄', 0, uid, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM sub_spaces WHERE space_id = sp_id AND is_trash = true) THEN
    INSERT INTO sub_spaces (space_id, name, emoji, sort_order, created_by, is_trash)
    VALUES (sp_id, 'Poubelle', '🗑️', 1, uid, true);
  END IF;

  -- Ne mettre les notes que dans les sous-espaces non-poubelle (Général, etc.)
  SELECT ARRAY_AGG(ss.id ORDER BY ss.sort_order)
  INTO sub_ids
  FROM sub_spaces ss
  WHERE ss.space_id = sp_id AND COALESCE(ss.is_trash, false) = false;
  IF sub_ids IS NULL OR array_length(sub_ids, 1) < 1 THEN
    RAISE EXCEPTION 'Aucun sous-espace trouvé pour workspace %', ws_id;
  END IF;

  -- 6. Créer les types de notes par défaut si inexistants
  IF NOT EXISTS (SELECT 1 FROM note_types WHERE workspace_id = ws_id) THEN
    INSERT INTO note_types (workspace_id, name, emoji, sort_order) VALUES
      (ws_id, 'Réunion', '📅', 0),
      (ws_id, 'Projet', '📁', 1),
      (ws_id, 'Problème', '⚠️', 2),
      (ws_id, 'Stratégie', '🎯', 3);
  END IF;

  -- 7. Créer les tags si inexistants (éviter doublons via lower(name))
  FOR i IN 1..array_length(tag_defs, 1) LOOP
    tn := tag_defs[i];
    tc := tag_colors[i];
    toi := tag_orders[i];
    INSERT INTO tags (workspace_id, name, color, sort_order)
    SELECT ws_id, tn, tc, toi
    WHERE NOT EXISTS (SELECT 1 FROM tags WHERE workspace_id = ws_id AND lower(name) = lower(tn));
  END LOOP;

  SELECT ARRAY_AGG(t.id ORDER BY t.sort_order) INTO tag_ids FROM tags t WHERE t.workspace_id = ws_id;
  IF tag_ids IS NULL OR array_length(tag_ids, 1) < 2 THEN
    RAISE EXCEPTION 'Pas assez de tags pour workspace %', ws_id;
  END IF;

  -- 8. Mettre à jour le profil
  UPDATE profiles SET workspace_id = ws_id, role = 'manager', company = 'Ippon'
  WHERE id = uid AND (workspace_id IS NULL OR workspace_id != ws_id);

  -- 9. Insérer les 70 notes si pas déjà 70+
  SELECT COUNT(*) INTO note_count FROM notes WHERE workspace_id = ws_id;
  IF note_count >= 70 THEN
    RAISE NOTICE 'Workspace % a déjà % notes. Rien à insérer.', ws_id, note_count;
    RETURN;
  END IF;

  FOR i IN 1..70 LOOP
    sel_sub := 1 + ((i - 1) % array_length(sub_ids, 1));
    nt := (ARRAY['none','Réunion','Projet','Problème','Stratégie'])[1 + ((i-1) % 5)];
    txt := (ARRAY[
      'Convergence des objectifs Q2 : analyse des écarts et plan de rattrapage. Réunion stratégique prévue mardi prochain.',
      'Pilotage des indicateurs clés : KPIs à jour, tendances identifiées, axes d''amélioration proposés.',
      'Préparation comité exécutif : synthèse des dossiers, présentation PowerPoint, annexes chiffrées.',
      'Alignment équipes commerciales et marketing : stratégie go-to-market, messages clés, planning lancement.',
      'Revue budgétaire annuelle : hypothèses, scenarii, recommandations pour le conseil d''administration.',
      'Roadmap produit 2026 : prioritisation des features, dépendances techniques, planning prévisionnel.',
      'Analyse concurrence : benchmark tarifaire, positionnement, opportunités de différenciation.',
      'Restructuration organisationnelle : nouveau schéma, impacts RH, communication interne et externe.',
      'Audit processus achats : identification des gisements d''économies, plan d''action court terme.',
      'Formation management : programme 2026, modules prioritaires, budget et calendrier.',
      'Crise communication : gestion de la réputation, messages de cadrage, suivi des retombées.',
      'Innovation produit : veille technologique, partenariats R&D, roadmap innovation.',
      'Relation investisseurs : préparation roadshow, argumentaire, support visuel.',
      'Transformation digitale : état des lieux, chantiers en cours, planning de déploiement.',
      'Qualité et conformité : audit ISO, actions correctives, suivi des non-conformités.',
      'Développement durable : stratégie RSE, indicateurs, reporting extra-financier.',
      'Fusion-acquisition : due diligence, intégration, plan de synergies.',
      'Négociation fournisseur clé : renouvellement contrat, conditions, alternatives.',
      'Lancement nouvelle gamme : études marché, positionnement, stratégie de lancement.',
      'Réseau partenaires : cartographie, priorités, plan de développement.',
      'Gestion des conflits : médiation, résolution, suivi des engagements.',
      'Motivation équipes : enquête climat, plan d''action, initiatives reconnaissance.',
      'Performance commerciale : analyse des ventes, pipeline, objectifs révisés.',
      'Optimisation logistique : flux, stocks, coûts, prestataires.',
      'Sécurité informatique : audit, vulnérabilités, plan de remédiation.',
      'Communication interne : stratégie, canaux, plan éditorial.',
      'Recrutement postes clés : profil, sourcing, planning d''embauche.',
      'Fidélisation clients : programme de fidélité, analyse churn, actions correctives.',
      'Export international : marchés cibles, réglementations, stratégie de déploiement.',
      'Production et qualité : indicateurs, non-conformités, plan d''amélioration.',
      'Partenariat stratégique : lettre d''intention, négociation, calendrier.',
      'Renouvellement assurance : comparaison offres, recommandation, signature.',
      'Réorganisation espaces : aménagement bureaux, planning, budget.',
      'Veille réglementaire : impacts sur l''activité, conformité, actions requises.',
      'Reporting mensuel : consolidation, analyse, présentation direction.',
      'Projet pilote IA : périmètre, fournisseurs, planning et budget.',
      'Satisfaction clients : enquête NPS, analyse, plan d''action.',
      'Gestion des risques : cartographie, traitements, suivi des actions.',
      'Événement professionnel : organisation, partenaires, communication.',
      'Mise à jour référentiel : processus, documentation, formation.',
      'Webinaire commercial : contenu, cibles, promotion et suivi.',
      'Convention collective : négociation, accord, communication.',
      'Dématérialisation : projet, prestataire, planning de déploiement.',
      'Réduction empreinte carbone : bilan, objectifs, plan d''action.',
      'Crowdfunding : campagne, cibles, stratégie de levée.',
      'Agilité organisationnelle : méthodologie, formation, déploiement.',
      'Cyber-assurance : évaluation besoins, comparaison offres, souscription.',
      'Diversification activité : opportunités, analyse, recommandation.',
      'Licenciement économique : processus, communication, accompagnement.',
      'Open innovation : appel à projets, sélection, accompagnement.',
      'Révision tarifaire : analyse concurrence, stratégie, déploiement.',
      'Rationalisation SI : cartographie, consolidation, migration.',
      'Développement compétences : cartographie, plans de formation.',
      'Plan de continuité : BCP, tests, mise à jour.',
      'Prévention des risques : formation, sensibilisation, procédures.',
      'Refonte site web : cahier des charges, prestataire, planning.',
      'Intégration CRM : paramétrage, formation, déploiement.',
      'Optimisation fiscale : analyse, opportunités, mise en œuvre.',
      'Politique télétravail : cadre, outils, suivi.',
      'Stratégie content marketing : éditorial, canaux, KPIs.',
      'Révision organigramme : schéma, communication, déploiement.',
      'Tableau de bord pilotage : indicateurs, fréquence, outil.',
      'Délégation de signature : cadre, actes, suivi.',
      'Stratégie réseau social : plateformes, contenu, communauté.',
      'Réinvention modèle économique : analyse, scenarii, recommandation.',
      'Mise en conformité RGPD : état des lieux, actions, documentation.',
      'Sensibilisation bien-être : initiatives, suivi, évolution.',
      'Plateforme collaborative : choix outil, déploiement, adoption.',
      'Développement international : pays cibles, stratégie, roadmap.',
      'Réduction des déchets : diagnostic, objectifs, plan.',
      'Comité d''entreprise : ordre du jour, préparatifs, suivi.',
      'Branding corporate : charte, déclinaisons, déploiement.',
      'Accélération croissance : levée de fonds, utilisation, objectifs.'
    ])[1 + ((i-1) % 60)];

    plain := txt;
    SELECT jsonb_build_object('type','doc','content',
      (SELECT jsonb_agg(jsonb_build_object('type','paragraph','content',
        jsonb_build_array(jsonb_build_object('type','text','text',COALESCE(ln,txt)))))
         FROM unnest(string_to_array(regexp_replace(txt,'\. ', E'.\n'), E'\n')) AS ln)
    ) INTO js;

    INSERT INTO notes (workspace_id, sub_space_id, title, content, content_plain, ai_summary, note_type, is_private, is_pinned, word_count, created_by, updated_at)
    VALUES (
      ws_id, sub_ids[sel_sub],
      (ARRAY[
        'Convergence Q2', 'KPIs en vue', 'Comité exec', 'Alignement com/marketing', 'Budget 2026',
        'Roadmap produit', 'Benchmark concurrence', 'Restructuration', 'Audit achats', 'Formation managers',
        'Crise com', 'Innovation', 'Roadshow investisseurs', 'Transfo digitale', 'Audit ISO',
        'Stratégie RSE', 'M&A en cours', 'Négociation fournisseur', 'Lancement gamme', 'Partenaires',
        'Médiation conflits', 'Climat social', 'Performance commerciale', 'Logistique', 'Cybersécurité',
        'Com interne', 'Recrutement', 'Fidélisation', 'Export', 'Qualité prod',
        'Partenariat stratégique', 'Assurance', 'Réorg bureaux', 'Veille réglo', 'Reporting mensuel',
        'Pilote IA', 'NPS clients', 'Risques', 'Événement', 'Référentiel',
        'Webinaire', 'Convention collective', 'Démat', 'Carbone', 'Crowdfunding',
        'Agilité', 'Cyber-assurance', 'Diversification', 'Licenciement', 'Open innovation',
        'Révision tarifs', 'Rationalisation SI', 'Compétences', 'BCP', 'Prévention',
        'Refonte site', 'CRM', 'Fiscalité', 'Télétravail', 'Content marketing',
        'Organigramme', 'Dashboard', 'Délégation signature', 'Réseaux sociaux', 'Modèle économique',
        'RGPD', 'Bien-être', 'Collaboratif', 'International', 'Déchets',
        'CE', 'Branding', 'Levée de fonds'
      ])[1 + ((i-1) % 70)],
      js, plain, left(plain, 200), nt,
      (i % 7 = 0), (i % 11 = 0), length(plain) - length(replace(plain,' ','')) + 1,
      uid, now() - (i || ' days')::interval
    )
    RETURNING id INTO nid;

    INSERT INTO note_tags (note_id, tag_id)
    SELECT DISTINCT nid, tag_ids[1 + ((i + j - 1) % array_length(tag_ids, 1))]
    FROM generate_series(1, 2 + (i % 2)) j
    ON CONFLICT (note_id, tag_id) DO NOTHING;
  END LOOP;

  RAISE NOTICE 'Migration snomis@ippon.fr terminée : workspace %, 70 notes insérées.', ws_id;
END $$;
