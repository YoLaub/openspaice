# Decision Log — GDD: OpenSpAIce

## 2026-06-20

- **Intent:** Create. Input principal = game brief (`_bmad-output/planning-artifacts/briefs/brief-OpenSpAIce-2026-06-20/brief.md`) + addendum + brainstorming session 2026-06-20.
- **Game type:** Simulation (gestion / tycoon de bureau). Complexité: HAUTE → doit documenter systems_map, balance_long_tail, emergence_boundaries, end_state.
- **Workspace créé:** gdd.md (skeleton template), epics.md (à venir), decision-log.md.
- **Game type confirmé:** Simulation. **Mode de travail:** Facilitatif léger (piliers + boucle + mécaniques chiffrées + systèmes simulation marchés ensemble ; reste en Express).
- **Piliers (4, reformulés depuis le brief):** 1) L'attention du patron = ressource rare ; 2) Décider sans filet (urgence+incertitude) ; 3) Brancher un LLM = pari génie/chaos ; 4) Une boîte qui vit toute seule (émergence sociale). Pilier "4 pressions entremêlées" du brief fusionné dans #1/#2 (jugé conséquence, pas pilier autonome). Validé par l'utilisateur.
- **Pilier non-négociable = #4 (boîte vivante/émergence).** Boussole du GDD : le jeu doit être vivant et fun en IA native pure ; le LLM est l'amplificateur, pas le fondement. Cohérent avec MVP "natif d'abord".
- **Boucle cœur :** temps réel tycoon pausable (x1/x2/x3), journées ouvrées (~5 min/jour tunable), pop-up décision 2-3 options, ~40% résultats différés, file d'attente avec patience ~45s. Validé.
- **Nouveau système — Bien-être/Burnout** (ajout utilisateur, ton Severance) : jauge Fatigue/agent (heures sup +15/j, repos -25/j ; ≥80 risque burnout, =100 craque + indispo + contagion). Événements de vie perso colorent les agents (divorce, deuil, dort au bureau). Valeurs de départ tunables validées.
- **Conditions :** Victoire scénario = IPO (seuils valo/contrats/stabilité) ; Défaite = faillite ou effondrement moral/burnout ; Mode infini = pas de victoire, score/jalons.
- **Mécanique LLM (validée) :** branchement coûte crédits IA (budget dédié) ; +50% efficacité + initiatives autonomes ; ~20%/jour dérapage modulé par moral ; 4 formes de dérapage ; débrancher = -15 moral + cooldown 1j, pas de coût argent.
- **Contagion du moral (validée) :** pilotée par échanges/concertations (pas un rayon) ; agent instable perturbe le travail + transfère moral négatif (~-5) selon type d'échange ; agents positifs remontent les autres.
- **Contrôles :** PC souris-centré, pause/vitesses (Espace, 1/2/3), caméra iso WASD+molette, HUD jauges globales (trésorerie, budget IA, moral moyen, deadline).
- **Simulation (validée) :** agencement/construction (recrutement, meubles à effets de zone, grille snap, open space extensible) ; progression IA native → LLM débloqué après 1er jalon ; garde-fous émergence (max 1 dérapage majeur/agent/jour, contagion profondeur limitée) ; carte des systèmes documentée.
- **Express :** reste du GDD (progression/équilibrage, level design, art/audio, technique, épics, métriques, hors-scope, hypothèses) rédigé d'un trait à partir des décisions ci-dessus + du brief.
- **Finalisation :** utilisateur a validé (option A). Passe discipline OK (mécaniques chiffrées, piliers distincts, conventions genre documentées, pas de fuite d'implémentation). Pas de doc_standards/reviewers/handoffs configurés. Pas de flag narratif (genre simulation). Statut gdd.md → `final`. Items ouverts reportés : monétisation [ASSUMPTION], valeurs à équilibrer, liste contrats / écran IPO / archétypes agents / choix LLM.
