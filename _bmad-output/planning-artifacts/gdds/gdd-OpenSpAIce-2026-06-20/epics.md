---
title: 'Development Epics — OpenSpAIce'
created: 2026-06-20
updated: 2026-06-20
---

# OpenSpAIce — Development Epics & High-Level Stories

Séquence dérisquée : **boucle native fun d'abord, LLM ensuite.** Chaque épic liste des stories haut niveau (à détailler dans `gds-create-story`).

---

## Épic 1 — Open space & boucle cœur (MVP)

**But :** prouver que « arbitrer sous pression » est fun, en IA native pure.

- 1.1 Scène open space iso navigable (caméra WASD + zoom, grille).
- 1.2 Agents natifs : spawn, déplacement (pathfinding), arrivée matin / départ soir.
- 1.3 Horloge de jeu : temps réel pausable, vitesses x1/x2/x3, découpage en journées (~5 min).
- 1.4 Système de requêtes : un agent vient au bureau OU envoie un mail.
- 1.5 Pop-up de décision (2-3 options) ; effets immédiats vs différés (~40 %).
- 1.6 File d'attente au bureau + jauge de patience (~45 s) → impact moral.
- 1.7 Jauges de base : trésorerie, moral (par agent), HUD persistant.
- 1.8 Bilan de fin de journée.

## Épic 2 — Bien-être & émergence

**But :** rendre l'open space vivant (pilier #4).

- 2.1 Jauge Fatigue par agent (heures sup +15/j, repos -25/j).
- 2.2 Burnout : seuil 80 (risque) / 100 (craque, indispo, malus).
- 2.3 Heures sup' / jours off / départ anticipé (gestion du temps de travail).
- 2.4 Concertations entre agents (échanges visibles).
- 2.5 Contagion du moral via échanges (perturbation du travail + transfert négatif/positif).
- 2.6 Événements de vie perso (divorce, deuil, dort au bureau) qui colorent les agents.
- 2.7 Garde-fous : profondeur de contagion limitée.

## Épic 3 — Économie & agencement

**But :** ajouter le levier tycoon trésorerie/espace.

- 3.1 Trésorerie : revenus/dépenses, salaires, faillite.
- 3.2 Recrutement d'agents (coût embauche + salaire récurrent).
- 3.3 Placement de mobilier sur grille (snap-to-grid).
- 3.4 Effets de zone (salle de repos -fatigue, café +moral, etc.).
- 3.5 Agrandissement de l'open space par paliers.

## Épic 4 — Missions & progression vers l'IPO

**But :** donner un but et une fin.

- 4.1 Système de contrats/missions (liste de contenu — à définir).
- 4.2 Avancement de mission lié à la productivité des agents + deadline.
- 4.3 Jalons de croissance & déblocages.
- 4.4 Condition de victoire : seuils d'IPO + écran d'IPO.
- 4.5 Conditions de défaite : faillite / effondrement moral-burnout.
- 4.6 Écran de création de partie : nommer la boîte + fixer son but.

## Épic 5 — Intégration LLM (le hook)

**But :** ajouter l'amplificateur, sans casser le natif.

- 5.1 Abstraction `Agent.brain` (natif ⇄ LLM partagent les mêmes tools/actions). _(détail dans l'architecture)_
- 5.2 Budget IA (ressource dédiée, consommation par agent branché).
- 5.3 Brancher/débrancher (UI, signe visuel, -15 moral + cooldown 1j).
- 5.4 Appels LLM **async non bloquants** + fallback natif sur échec/time-out.
- 5.5 Bonus branché : +50 % efficacité + initiatives autonomes.
- 5.6 Dérapage : ~20 %/jour modulé par moral ; 4 formes ; garde-fou 1 majeur/agent/jour.
- 5.7 BYOK : saisie + stockage local sécurisé de la clé API.
- 5.8 Déblocage du LLM après le 1er jalon de progression.

## Épic 6 — Art, audio & game feel

**But :** l'identité *Severance* et le juice.

- 6.1 DA 3D iso (palette aseptisée, mobilier, éclairage).
- 6.2 Animations d'agents (marche, travail, concertation, fatigue, sommeil, craquage).
- 6.3 Indicateurs au-dessus des têtes (branché, instabilité, humeur).
- 6.4 Audio adaptatif (ambiance feutrée, tension montante, SFX corporate).
- 6.5 Polish de feedback (pop-ups, transitions, lisibilité).

## Épic 7 — Modes, méta & polish

**But :** complétude et release.

- 7.1 Mode infini (difficulté croissante, score/jalons).
- 7.2 Équilibrage (jour, jauges, % dérapage, coûts) via playtest.
- 7.3 Tutoriel / onboarding doux.
- 7.4 Sauvegarde/chargement.
- 7.5 Build démo itch.io (collecte de wishlists Steam).
- 7.6 Options, accessibilité de base, écrans méta.
