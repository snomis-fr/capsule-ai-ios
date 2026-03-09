-- Insère les 70 notes de test dans TOUS les workspaces (pour que chaque utilisateur les voie sur son tél)
-- La migration précédente n'en mettait que dans le 1er workspace

DO $$
DECLARE
  r RECORD;
  ws_id UUID;
  mgr_id UUID;
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
BEGIN
  FOR r IN
    SELECT w.id AS ws_id, w.manager_id AS mgr_id
    FROM workspaces w
    WHERE EXISTS (SELECT 1 FROM spaces s JOIN sub_spaces ss ON ss.space_id = s.id WHERE s.workspace_id = w.id)
  LOOP
    ws_id := r.ws_id;
    mgr_id := r.mgr_id;

    SELECT COUNT(*) INTO note_count FROM notes WHERE workspace_id = ws_id;
    IF note_count >= 70 THEN CONTINUE; END IF;

    SELECT ARRAY_AGG(ss.id ORDER BY ss.sort_order) INTO sub_ids FROM sub_spaces ss
      JOIN spaces s ON s.id = ss.space_id WHERE s.workspace_id = ws_id;
    IF sub_ids IS NULL OR array_length(sub_ids, 1) < 1 THEN CONTINUE; END IF;

    SELECT ARRAY_AGG(t.id) INTO tag_ids FROM tags t WHERE t.workspace_id = ws_id;
    IF tag_ids IS NULL OR array_length(tag_ids, 1) < 2 THEN
      INSERT INTO tags (workspace_id, name, color, sort_order) VALUES
        (ws_id, 'priorité', '#EF4444', 0), (ws_id, 'urgent', '#F59E0B', 1),
        (ws_id, 'stratégie', '#8B5CF6', 2), (ws_id, 'client', '#22C55E', 3),
        (ws_id, 'suivi', '#06B6D4', 4), (ws_id, 'archivé', '#64748B', 5),
        (ws_id, 'relecture', '#EC4899', 6), (ws_id, 'validé', '#14B8A6', 7)
      ON CONFLICT (workspace_id, name) DO NOTHING;
      SELECT ARRAY_AGG(t.id) INTO tag_ids FROM tags t WHERE t.workspace_id = ws_id;
    END IF;
    IF tag_ids IS NULL OR array_length(tag_ids, 1) < 2 THEN CONTINUE; END IF;

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
        mgr_id, now() - (i || ' days')::interval
      )
      RETURNING id INTO nid;

      INSERT INTO note_tags (note_id, tag_id)
      SELECT DISTINCT nid, tag_ids[1 + ((i + j - 1) % array_length(tag_ids, 1))]
      FROM generate_series(1, 2 + (i % 2)) j
      ON CONFLICT (note_id, tag_id) DO NOTHING;
    END LOOP;
  END LOOP;
END $$;
