---
stepsCompleted: [1, 2, 3, 4, 5, 6]
project: OpenSpAIce
date: 2026-06-21
inputDocuments:
  - '_bmad-output/planning-artifacts/gdds/gdd-OpenSpAIce-2026-06-20/gdd.md'
  - '_bmad-output/planning-artifacts/architecture-OpenSpAIce-2026-06-20/game-architecture.md'
  - '_bmad-output/planning-artifacts/epics.md'
referenceDocuments:
  - '_bmad-output/planning-artifacts/gdds/gdd-OpenSpAIce-2026-06-20/epics.md (résumé épics haut niveau du GDD)'
  - '_bmad-output/planning-artifacts/briefs/brief-OpenSpAIce-2026-06-20/brief.md (contexte)'
---

# Implementation Readiness Assessment Report

**Date:** 2026-06-21
**Project:** OpenSpAIce

## Step 1 — Document Discovery

### Documents retenus pour l'évaluation

| Type | Fichier | Format |
|---|---|---|
| GDD | `gdds/gdd-OpenSpAIce-2026-06-20/gdd.md` | Document complet |
| Architecture | `architecture-OpenSpAIce-2026-06-20/game-architecture.md` | Document complet |
| Epics & Stories | `epics.md` (racine planning-artifacts) | Document complet — spec détaillée (7 épics, 48 stories) |
| UX Design | — | Absent (couvert par le GDD + Épic 6) |

### Documents de référence (non évalués comme spec)

- `gdds/gdd-OpenSpAIce-2026-06-20/epics.md` — résumé épics haut niveau intégré au GDD (sert de squelette, pas de spec).
- `briefs/brief-OpenSpAIce-2026-06-20/brief.md` + addendum — contexte projet.

### Points relevés

- ⚠️ **Deux fichiers `epics.md`** : la spec détaillée (`planning-artifacts/epics.md`, retenue) et le résumé haut niveau du GDD (`gdds/.../epics.md`). Pas un conflit whole/sharded — ce sont deux granularités. La spec racine fait autorité ; le résumé GDD reste cohérent avec elle.
- ⚠️ **Aucun document UX dédié** — attendu (le GDD couvre l'UI/HUD et l'Épic 6 la présentation).

## Step 2 — GDD Analysis

Le GDD est un document de design narratif (pas de FRs numérotés). Les exigences ci-dessous sont **ré-extraites directement du GDD** par l'auditeur, pour validation de couverture indépendante.

### Functional Requirements (ré-extraits du GDD)

- FR1 Open space iso navigable (caméra, grille, zoom) — *Controls/Level Design*
- FR2 Agents natifs : spawn, pathfinding, arrivée matin/départ soir — *Core Loop*
- FR3 Horloge temps réel pausable x1/x2/x3 + journées ouvrées — *Core Loop*
- FR4 Sollicitation bureau vs mail — *Core Loop*
- FR5 Pop-up de décision 2-3 options — *Core Loop / Mécanique 1*
- FR6 Résolution immédiate (~60 %) vs différée (~40 %, 1-2 j) — *Mécanique 1*
- FR7 File d'attente + patience ~45 s → moral — *Tension d'attention*
- FR8 Mails (canal asynchrone parallèle) — *Core Loop*
- FR9 Ressource Attention (file + mails) — *Pilier 1 / Mécanique 2*
- FR10 Trésorerie (revenus/dépenses, salaires, faillite) — *Mécanique 2 / Economic Loops*
- FR11 Deadline de mission par contrat — *Mécanique 2*
- FR12 Moral par agent (0-100) — *Mécanique 2*
- FR13 Fatigue par agent (0-100, burnout) — *Mécanique 2 / 5*
- FR14 HUD persistant jauges globales — *Controls*
- FR15 Bilan de fin de journée — *Core Loop*
- FR16 Burnout (indispo + malus + contagion) — *Mécanique 2*
- FR17 Heures sup / jours off / départ anticipé — *Mécanique 5*
- FR18 Concertations visibles entre agents — *Mécanique 4*
- FR19 Contagion du moral par échanges — *Mécanique 4*
- FR20 Événements de vie perso — *Mécanique 5*
- FR21 Garde-fous d'émergence — *Limites de l'émergence*
- FR22 Recrutement d'agents (embauche + salaire) — *Building/Construction*
- FR23 Placement mobilier snap-to-grid — *Building/Construction*
- FR24 Effets de zone du mobilier — *Building/Construction*
- FR25 Agrandissement open space par paliers — *Level Progression*
- FR26 Système de contrats/missions — *Mécanique 6*
- FR27 Avancement mission (productivité + deadline) — *Simulation systems*
- FR28 Jalons de croissance & déblocages — *Progression and Unlocks*
- FR29 Victoire IPO + écran d'IPO — *Win/Loss*
- FR30 Défaite (faillite / effondrement) — *Win/Loss*
- FR31 Écran de création de partie (nom + but) — *Sandbox vs Scenario*
- FR32 Brancher/débrancher LLM (UI, signe, -15 moral + cooldown) — *Mécanique 3*
- FR33 Budget IA (ressource dédiée) — *Mécanique 3 / Economic Loops*
- FR34 Bonus branché (+50 % + initiatives) — *Mécanique 3*
- FR35 Dérapage ~20 %, modulé moral, 4 formes — *Mécanique 3*
- FR36 Déblocage LLM après 1er jalon — *Progression and Unlocks*
- FR37 BYOK (saisie + stockage local sécurisé) — *Platform-Specific*
- FR38 Abstraction `Agent.brain` (natif ⇄ LLM, tools partagés) — *Mécanique 3*
- FR39 Mode scénario (~3 h vers IPO) — *Sandbox vs Scenario*
- FR40 Mode infini (difficulté croissante, score) — *Sandbox vs Scenario*
- FR41 Sauvegarde/chargement état complet — *Technical Specs*
- FR42 Tutoriel / onboarding doux — *Difficulty Curve*
- FR43 Fiche agent / sélection — *Controls*
- FR44 Contrôles souris + raccourcis clavier — *Controls*

**Total FRs : 44**

### Non-Functional Requirements (ré-extraits du GDD)

- NFR1 60 FPS sur PC milieu de gamme, open space peuplé
- NFR2 Sim agents basse fréquence ~2-4 Hz, découplée du rendu
- NFR3 Appels LLM 100 % async non bloquants + fallback natif (timeout)
- NFR4 BYOK : clé stockée localement, jamais relayée ailleurs
- NFR5 Mode natif jouable hors-ligne sans clé
- NFR6 Temps de chargement/sauvegarde < quelques secondes
- NFR7 Lisibilité visuelle des signaux d'un coup d'œil
- NFR8 Scope tenable solo dev (séquence MVP natif d'abord)
- NFR9 Anti save-scum (résultats différés + RNG dérapage)
- NFR10 Boucle native pure « fun » en playtest **avant** LLM
- NFR11 Erreurs jamais fatales/bloquantes (cross-cutting archi)

**Total NFRs : 11**

### Additional Requirements / Contraintes

- **Moteur Godot 4.6.3-stable**, GDScript typé, vrai 3D + caméra orthographique.
- **PC/Steam prioritaire**, build itch.io démo ; pas de mobile/console/multi en v1.0.
- **Dépendance externe** : disponibilité d'un SDK/API LLM pour le mode branché ; natif sans dépendance.

### Open Design Items (⚠️ relevés par l'auditeur — contenu non encore défini)

Le GDD marque explicitement plusieurs éléments comme non résolus (`[NOTE FOR DESIGNER]`, `[ASSUMPTION]`) :

1. **Liste concrète des contrats/missions** — « à définir » (FR26 s'appuie dessus).
2. **Détail de l'écran d'IPO** + seuils chiffrés de victoire — à préciser (FR29).
3. **Archétypes / personnalités d'agents** — à définir (FR2, data `.tres`).
4. **Choix du/des LLM cibles + modèle natif** — non tranché (FR38, Épic 5 ; cohérent avec [NOTE] archi).
5. **Modèle économique** (premium Steam + BYOK) = `[ASSUMPTION]` à reverrouiller (risque n°1 du brief).
6. **Valeurs chiffrées** (durée jour, % dérapage, coûts, jauges) = points de départ à affiner en équilibrage.

### GDD Completeness Assessment

GDD **complet et cohérent** sur la vision, les piliers, les mécaniques et les specs techniques. Les lacunes ne sont pas des oublis mais du **contenu de design différé** (contrats, archétypes, seuils IPO, LLM) — normal à ce stade, mais à tracer comme dette de contenu avant/pendant la production (à résoudre au fil des Épics 4 et 5).

## Step 3 — Epic Coverage Validation

### Coverage Matrix (GDD FR → Story)

| FR | Story | Statut | FR | Story | Statut |
|---|---|---|---|---|---|
| FR1 | 1.1 | ✓ | FR23 | 3.3 | ✓ |
| FR2 | 1.2 | ✓ | FR24 | 3.4 | ✓ |
| FR3 | 1.3 | ✓ | FR25 | 3.5 | ✓ |
| FR4 | 1.4 | ✓ | FR26 | 4.2 | ✓ |
| FR5 | 1.5 | ✓ | FR27 | 4.3 | ✓ |
| FR6 | 1.6 | ✓ | FR28 | 4.4 | ✓ |
| FR7 | 1.7 | ✓ | FR29 | 4.6 | ✓ |
| FR8 | 1.4 | ✓ | FR30 | 4.7 | ✓ |
| FR9 | 1.8 | ✓ | FR31 | 4.1 | ✓ |
| FR10 | 3.1 | ✓ | FR32 | 5.5 | ✓ |
| FR11 | 4.3 | ✓ | FR33 | 5.4 | ✓ |
| FR12 | 1.7 | ✓ | FR34 | 5.7 | ✓ |
| FR13 | 2.1 | ✓ | FR35 | 5.8 | ✓ |
| FR14 | 1.8 | ✓ | FR36 | 5.6 | ✓ |
| FR15 | 1.10 | ✓ | FR37 | 5.1 | ✓ |
| FR16 | 2.2 | ✓ | FR38 | 5.2, 5.3 | ✓ |
| FR17 | 2.3 | ✓ | FR39 | 4.5 | ✓ |
| FR18 | 2.4 | ✓ | FR40 | 7.2 | ✓ |
| FR19 | 2.5 | ✓ | FR41 | 7.1 | ✓ |
| FR20 | 2.6 | ✓ | FR42 | 7.3 | ✓ |
| FR21 | 2.7 | ✓ | FR43 | 1.9 | ✓ |
| FR22 | 3.2 | ✓ | FR44 | 1.1, 1.3 | ✓ |

### Missing Requirements

**Aucun.** Tous les FRs du GDD sont tracés vers au moins une story. Aucun FR présent dans les épics sans origine GDD (pas de scope creep).

### Coverage Statistics

- Total GDD FRs : **44**
- FRs couverts dans les épics : **44**
- **Couverture : 100 %**
- NFRs adressés (référencés dans les ACs/épics) : 11/11

> Note : la couverture FR est totale au niveau **spec**. La réserve réelle n'est pas une lacune d'exigence mais la **dette de contenu** relevée au Step 2 (contrats, archétypes, seuils IPO, LLM) — à instancier en données `.tres` au moment d'implémenter les Épics 4 et 5.

## Step 4 — UX Alignment Assessment

### UX Document Status

**Not Found** — aucun document UX dédié (`*ux*.md`). L'UI est cependant **fortement impliquée** par le GDD.

### UI impliquée par le GDD (vérifié)

HUD persistant (jauges globales), pop-ups de décision 2-3 options, fiche agent (jauges + actions brancher/jour off), indicateurs au-dessus des têtes (branché/instabilité/humeur), file d'attente visible, écran de création de partie, écran d'IPO, écrans de game over, mode aménagement (placement grille), options/accessibilité, menus méta.

### UX ↔ Architecture Alignment

- ✅ **L'architecture supporte l'UI** : D9 « UI/HUD = Control nodes + `CanvasLayer` », dossier `scenes/ui/` explicitement prévu (hud, pop-ups décision, fiche agent, écrans méta, écran IPO).
- ✅ **Performance/réactivité** : appels LLM async (NFR3) garantissent que l'UI ne gèle jamais ; rendu 60 FPS découplé de la sim (NFR2).
- ✅ **Lisibilité** : NFR7 + Épic 6 (indicateurs, polish de feedback) adressent l'expérience visuelle.

### UX ↔ GDD Alignment

- ✅ Les besoins UI du GDD sont reflétés dans les stories (FR5 pop-ups, FR14 HUD, FR43 fiche agent, FR44 contrôles) et habillés par l'Épic 6.

### Warnings

- ⚠️ **Absence de spec UX dédiée (DESIGN.md / EXPERIENCE.md)** — **non bloquant** pour ce projet : l'UI est couverte de bout en bout par GDD + Architecture (D9) + Épic 6, et le scope solo dev ne justifie pas un artefact UX séparé. **Recommandation (optionnelle)** : si des écrans complexes posent question en production (notamment l'**écran d'IPO** et le **mode aménagement**), envisager un passage léger de `gds-ux` (CU) pour cadrer ces flux avant de coder les Épics 3 et 4.

### Verdict UX : ✅ ALIGNÉ (avertissement mineur, optionnel)

## Step 5 — Epic Quality Review

Revue rigoureuse contre les standards `create-epics-and-stories` (valeur joueur, indépendance, dépendances avant, sizing, ACs, timing des données).

### A. Valeur joueur par épic

| Épic | Centré joueur ? | Verdict |
|---|---|---|
| 1 Open space & boucle cœur | Diriger la boîte en natif | ✅ |
| 2 Bien-être & émergence | Vivre/gérer l'humeur de la boîte | ✅ |
| 3 Économie & agencement | Gérer argent/espace | ✅ |
| 4 Missions & IPO | But & fin du jeu | ✅ |
| 5 Intégration LLM | Le hook signature | ✅ |
| 6 Art, audio & game feel | Expérience/ambiance (player-facing) | ✅ (présentation, pas de milestone technique creux) |
| 7 Modes, méta & polish | Modes & release | ✅ |

→ **Aucun épic « technique creux »** (pas de « Setup DB », « API », « Infra »). L'Épic 6 est une couche de présentation player-facing assumée (rationale documenté dans `epics.md`).

### B. Indépendance des épics

- ✅ Chaque épic délivre une fonctionnalité complète et **n'exige aucun épic futur** pour fonctionner.
- ✅ Les liens inter-épics sont des **points d'extension orientés passé→futur** (l'antérieur n'attend jamais le postérieur) :
  - 2.7 (garde-fous) → étendu par 5.8 (dérapages) — E2 fonctionne sans E5.
  - 4.4 (1er jalon) émet l'event consommé par 5.6 (déblocage LLM) — E4 fonctionne sans E5.
  - 3.1 (faillite) émet l'event consommé par 4.7 (défaite) — E3 fonctionne sans E4.
- ✅ Aucune dépendance circulaire.

### C. Dépendances intra-épic (forward references)

- ✅ Toutes les stories sont ordonnées sans référence à une story future. Vérifié épic par épic (ex. E5 : 5.4 budget avant 5.5 brancher qui le consomme ; 5.6 verrouille/déverrouille 5.5 ; aucune story ne « attend » une story ultérieure).

### D. Timing de création des données

- ✅ Conforme : `.tres` créés **au besoin** — archétypes agents (1.2), contrats (4.2), mobilier (3.3), balance (7.4). **Aucune création massive en amont.**

### E. Greenfield / Starter template

- ✅ Projet **greenfield, sans starter template**. Story 1.1 fait office de setup initial (projet Godot + autoloads + scène navigable) tout en livrant de la valeur visible — pas une story « setup » creuse.

### Findings par sévérité

#### 🔴 Critical — aucun

#### 🟠 Major — aucun

#### 🟡 Minor / points de vigilance

1. **Sizing de la Story 1.1** — elle empile création du projet + 5 autoloads + caméra ortho + `GridMap` + contrôles. Dense pour une seule session de dev agent. *Reco :* envisager un split 1.1a (fondations/autoloads) / 1.1b (caméra & open space navigable) au moment du `gds-create-story`.
2. **`ActionRegistry` implicite** — la parité natif↔LLM repose sur l'`ActionRegistry`, posé de fait en 1.2 (NativeBrain) mais non nommé dans l'AC. *Reco :* rendre l'`ActionRegistry` explicite dans la Story 1.2 pour garantir la parité dès le natif (clé pour que l'Épic 5 reste un simple ajout).
3. **Setup outillage dev (MCP, env)** — les « First Steps » de l'archi (serveurs MCP Gopeak/Context7, env de dev) ne sont pas capturés en story. *Reco :* les ajouter comme tâches de la Story 1.1 (ou une story 1.0 d'amorçage env).
4. **ACs de playtest non automatisables** — NFR10 (« boucle native jugée fun ») en 1.10 et NFR7 (« lisibilité confirmée ») en 6.5 sont des **gates de playtest subjectifs**, pas des tests automatisés. Acceptable et voulu, mais à acter comme jalons de validation humaine.
5. **Cas d'erreur inégaux** — certaines stories couvrent bien les chemins d'échec (5.1 sans clé, 7.1 save corrompue, 3.3 case occupée) ; d'autres restent happy-path (ex. 4.5 enchaînement scénario, 6.x). *Reco :* enrichir les cas limites lors du `gds-create-story`.

### Checklist de conformité (global)

- [x] Épics délivrent de la valeur joueur
- [x] Épics indépendants
- [x] Stories correctement dimensionnées (1 vigilance : 1.1)
- [x] Pas de dépendance avant
- [x] Données créées au besoin
- [x] ACs claires (Given/When/Then testables)
- [x] Traçabilité aux FRs maintenue (100 %)

### Verdict qualité : ✅ CONFORME — 0 critique, 0 majeur, 5 points mineurs (raffinables au `gds-create-story`)

## Summary and Recommendations

### Overall Readiness Status

# ✅ READY

OpenSpAIce est **prêt à entrer en Phase 4 (Production)**. Les artefacts de planification (GDD, Architecture, Epics & Stories) sont complets, cohérents et alignés.

### Tableau de bord

| Contrôle | Résultat |
|---|---|
| Inventaire documents | ✅ GDD + Archi + Epics/Stories présents |
| Couverture FR (GDD → stories) | ✅ 44/44 (100 %) |
| Couverture NFR | ✅ 11/11 référencés |
| Alignement UX (GDD ↔ Archi) | ✅ Aligné (pas de spec UX dédiée — non bloquant) |
| Qualité épics/stories | ✅ 0 critique · 0 majeur · 5 mineurs |
| Indépendance & dépendances | ✅ Aucune dépendance avant, aucun cycle |
| Timing données `.tres` | ✅ Création au besoin |

### Critical Issues Requiring Immediate Action

**Aucun.** Pas d'issue critique ni majeure. Rien ne bloque le démarrage de la production.

### Réserves à tracer (non bloquantes)

1. **Dette de contenu de design** (relevée au Step 2, marquée `[NOTE]`/`[ASSUMPTION]` dans le GDD) : liste concrète des contrats, archétypes/personnalités d'agents, seuils chiffrés de l'IPO, choix du fournisseur LLM, valeurs d'équilibrage. → à instancier en données `.tres` au fil des Épics 4 et 5, pas avant.
2. **Risque n°1 (brief)** : modèle économique premium + BYOK = `[ASSUMPTION]` à reverrouiller.
3. **5 points mineurs de qualité** (Step 5) à raffiner au `gds-create-story`.

### Recommended Next Steps

1. **Lancer `gds-sprint-planning`** (SP, requis) pour générer `sprint-status.yaml` à partir des 7 épics.
2. **Lancer `gds-create-story`** (CS) sur la **Story 1.1** — en appliquant les recos du Step 5 : split possible 1.1a/1.1b, expliciter l'`ActionRegistry` (1.2), capturer le setup env/MCP.
3. **(Optionnel) `gds-generate-project-context`** (PC) pour produire `project-context.md` — utile vu le setup solo dev + agents IA de dev.
4. **Au démarrage de l'Épic 5** : trancher le fournisseur/SDK LLM ([NOTE] archi) et prototyper tôt sur 1 agent (risque n°1).
5. **(Optionnel) `gds-ux`** si l'écran d'IPO ou le mode aménagement méritent un cadrage avant de coder les Épics 3-4.

### Final Note

Cette évaluation a parcouru 6 contrôles et identifié **0 issue bloquante** et **8 réserves non bloquantes** (3 dettes de contenu + 5 points qualité mineurs). Le projet peut **procéder en l'état**. Les réserves sont des éléments à résoudre au fil de la production, pas des préalables.

**Assesseur :** Game Producer / Scrum Master (BMad GDS) · **Date :** 2026-06-21
