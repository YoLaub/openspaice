---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - '_bmad-output/planning-artifacts/gdds/gdd-OpenSpAIce-2026-06-20/gdd.md'
  - '_bmad-output/planning-artifacts/gdds/gdd-OpenSpAIce-2026-06-20/epics.md'
  - '_bmad-output/planning-artifacts/architecture-OpenSpAIce-2026-06-20/game-architecture.md'
---

# OpenSpAIce - Epic Breakdown

## Overview

Ce document fournit le découpage complet en épics et stories pour OpenSpAIce, décomposant les exigences du GDD et les décisions d'Architecture en stories implémentables. Séquence dérisquée : **boucle native fun d'abord, LLM ensuite.**

## Requirements Inventory

### Functional Requirements

**Boucle cœur & open space**
- FR1: Le jeu affiche un open space en 3D isométrique (caméra orthographique) navigable : déplacement caméra (bord d'écran / WASD), zoom molette, sur une grille de placement.
- FR2: Des agents natifs apparaissent (spawn), se déplacent par pathfinding dans l'open space, arrivent le matin et repartent le soir (certains font des heures sup', d'autres partent tôt).
- FR3: Une horloge de jeu en temps réel, pausable, propose des vitesses x1/x2/x3 et découpe la partie en jours ouvrés (~5 min réelles à x1, tunable).
- FR4: Un agent sollicite le joueur soit en se déplaçant jusqu'au bureau (décision importante), soit en envoyant un « mail » depuis son poste (asynchrone, moins urgent).
- FR5: Une pop-up de décision présente 2-3 options ; le temps continue de tourner sauf pause.
- FR6: La résolution des décisions est ~60 % immédiate et ~40 % différée (effet appliqué 1-2 jours plus tard).
- FR7: Plusieurs agents peuvent faire la queue physiquement au bureau ; chaque agent en file a une patience (~45 s à x1) ; au-delà, son moral chute (-1 / 5 s).
- FR8: Un mail en attente clignote et constitue une sollicitation parallèle (canal asynchrone).

**Jauges & systèmes humains**
- FR9: La ressource Attention du joueur est matérialisée par la file d'attente au bureau + les mails en attente.
- FR10: Une jauge Trésorerie (€) suit revenus (contrats) et dépenses (salaires, embauches, mobilier, crédits IA) ; faillite si < 0 au-delà d'un délai de grâce.
- FR11: Chaque contrat possède une jauge Deadline de mission qui glisse si les agents sous-performent.
- FR12: Chaque agent possède une jauge Moral (0-100) affectée par l'attente, les décisions, la contagion et les événements perso.
- FR13: Chaque agent possède une jauge Fatigue (0-100) : heures sup +15/j, repos -25/j ; ≥80 = risque de burnout ; =100 = l'agent craque (indispo plusieurs jours + malus moral + contagion).
- FR14: Un HUD persistant affiche les jauges globales (trésorerie, budget IA, moral moyen, deadline en cours).
- FR15: Un bilan de fin de journée récapitule trésorerie, moral moyen et avancement mission.
- FR16: Le burnout rend l'agent indisponible plusieurs jours, applique un gros malus moral et déclenche de la contagion.
- FR17: Le joueur gère le temps de travail des agents : heures sup' (+prod, +fatigue), jours off, départ anticipé.
- FR18: Les agents tiennent des concertations visibles (échanges entre agents) dans l'open space.
- FR19: La contagion du moral est pilotée par les échanges entre agents : un agent au moral bas/instable perturbe le travail d'un collègue et lui transfère du moral négatif (ex. -5) ; un agent au top peut remonter un collègue.
- FR20: Des événements de vie perso (divorce, deuil, dort au bureau) colorent les agents et leurs réactions (ex. dormir au bureau : +deadline mais +30 fatigue/nuit).
- FR21: Des garde-fous bornent l'émergence : max 1 dérapage majeur par agent et par jour (cooldown sur les crises) ; profondeur de contagion limitée (pas de chaîne infinie le même jour).

**Économie & agencement**
- FR22: Le joueur recrute des agents (coût d'embauche + salaire récurrent).
- FR23: Le joueur place du mobilier sur une grille (snap-to-grid) dans l'open space.
- FR24: Le mobilier produit des effets de zone (salle de repos → -fatigue à proximité ; machine à café → +moral ; etc.).
- FR25: L'open space s'agrandit par paliers de croissance (petit local → étage → plateau), débloquant surface, agents et zones.

**Missions & progression**
- FR26: Un système de contrats/missions enchaîne des objectifs qui font grandir la boîte et débloquent du contenu.
- FR27: L'avancement d'une mission est lié à la productivité des agents et à sa deadline.
- FR28: Des jalons de croissance débloquent progressivement capacité d'agents, plafond de crédits IA, contrats plus lucratifs et améliorations d'aménagement.
- FR29: La condition de victoire (mode scénario) est l'atteinte des seuils d'IPO (valorisation / contrats livrés / stabilité), présentée par un écran d'IPO.
- FR30: Les conditions de défaite sont la faillite (trésorerie < 0 au-delà du délai de grâce) ou l'effondrement (moral collectif au plancher / vague de burnouts faisant échouer une mission critique).
- FR31: Un écran de création de partie permet de nommer la boîte et de fixer son but.

**Intégration LLM (le hook)**
- FR32: Le joueur peut brancher/débrancher un agent sur un LLM via l'UI (fiche agent), avec signe visuel « branché » au-dessus de l'agent ; débrancher coûte -15 moral + cooldown 1 jour.
- FR33: Un Budget IA (crédits), ressource dédiée distincte de la trésorerie, est consommé par jour et par agent branché et borne le nombre d'agents tenus branchés.
- FR34: Un agent branché bénéficie de +50 % d'efficacité sur ses tâches et débloque des initiatives autonomes (il agit sans demander).
- FR35: Chaque jour, un agent branché a ~20 % de probabilité de dérapage, modulée par son moral, prenant 4 formes : initiative coûteuse non demandée 💸, contamination des collègues 🗣️, réponse créative/hors-sujet à arbitrer 🎭, crise à gérer en urgence 🔥.
- FR36: Le branchement LLM ne se débloque qu'après le 1er jalon de progression (départ en IA native uniquement).
- FR37: Le mode BYOK permet la saisie et le stockage local sécurisé de la clé API du joueur, jamais transmise ailleurs qu'au fournisseur choisi.
- FR38: Les agents exposent une abstraction `Agent.brain` (NativeBrain ⇄ LLMBrain) partageant exactement les mêmes tools/actions via un `ActionRegistry` commun ; le natif reste le fallback.

**Modes, méta & contrôles**
- FR39: Un mode scénario (~3 h) propose objectifs et contraintes, de la création de la boîte jusqu'à l'IPO.
- FR40: Un mode infini sans état de fin propose gestion/optimisation sur la durée, difficulté croissante, score/jalons pour l'auto-défi.
- FR41: Le jeu sauvegarde et recharge l'état complet de la simulation.
- FR42: Un tutoriel / onboarding doux introduit progressivement la boucle (peu d'agents, IA native, peu de sollicitations).
- FR43: Cliquer un agent ouvre sa fiche (jauges, brancher/débrancher, jour off) ; clic gauche sélectionne / valide une option.
- FR44: Les contrôles sont souris-centrés avec raccourcis clavier (Espace = pause, 1/2/3 = vitesses, WASD = caméra) ; HUD persistant pour les jauges globales.

### NonFunctional Requirements

- NFR1: Le jeu tient 60 FPS sur PC de milieu de gamme avec un open space peuplé (jusqu'à la taille max d'agents).
- NFR2: La simulation des agents tourne à basse fréquence (~2-4 Hz, `SimClock` ~3 Hz) découplée du rendu 60 FPS.
- NFR3: Les appels LLM sont 100 % asynchrones et non bloquants (timeout ~10 s) ; l'interface ne gèle jamais ; un fallback natif transparent prend le relais sur échec/time-out.
- NFR4: La clé API BYOK est stockée localement et chiffrée (`user://`), jamais relayée ailleurs qu'au fournisseur LLM choisi.
- NFR5: Le mode natif est entièrement jouable hors-ligne, sans clé API.
- NFR6: Les temps de chargement et de sauvegarde restent acceptables (< quelques secondes).
- NFR7: Les signaux visuels (branché, instabilité, fatigue/burnout, concertations) sont lisibles d'un coup d'œil.
- NFR8: Le scope reste tenable pour un solo dev assisté d'agents IA (séquence MVP « natif d'abord »).
- NFR9: Le système décourage le save-scum (résultats différés + RNG des dérapages rendent le rechargement peu fiable).
- NFR10: La boucle native pure doit être jugée « fun » en playtest **avant** toute intégration LLM (validation du pilier #4).
- NFR11: Une erreur ne met jamais le jeu en pause et n'est jamais fatale pour la simulation (gestion hybride `Result`/codes + `EventBus`).

### Additional Requirements

_Exigences techniques issues de l'Architecture (game-architecture.md) impactant le découpage et l'implémentation._

- **Projet greenfield (pas de starter template).** Aucun template de démarrage : le projet Godot `open_space/` est créé from scratch selon la structure de dossiers définie. → impacte **Épic 1, Story 1** (setup).
- **Moteur : Godot 4.6.3-stable**, GDScript typé statiquement ; rendu **vrai 3D + caméra orthographique** (Forward+).
- **Autoloads de base à poser tôt :** `GameManager`, `EventBus`, `SimClock`, `LLMService`, `SaveManager`, `AudioManager`, `Logger`, `ConfigService`.
- **Communication via `EventBus`** (signals typés, `snake_case` au passé) ; jamais d'appels directs en dur entre systèmes ; jamais de chemins de nœuds absolus.
- **Pattern Dual-Mode Brain :** `AgentBrain` → `NativeBrain` / `LLMBrain` via `BrainComponent` ; toute nouvelle capacité d'agent passe par `ActionRegistry` (parité natif ↔ LLM garantie).
- **State Machine agents** (idle / work / confer / queue / fatigue / burnout), un nœud `State` par état.
- **Données data-driven en Resources `.tres`** (archétypes d'agents, contrats, mobilier) ; valeurs d'équilibrage isolées dans `data/balance/*.tres` (zéro magic number).
- **Placement grille via `GridMap` (3D)** pour le mobilier snap.
- **Sauvegarde locale via `SaveManager`** (binaire/JSON), état complet de la sim ; Steam Cloud plus tard.
- **`LLMService` (autoload)** : `HTTPRequest` non bloquant, file de requêtes, timeout ~10 s, retry limité, fallback `NativeBrain` ; un agent **ne parle jamais directement** à `LLMService` (toujours via `BrainComponent`).
- **Fournisseur/SDK LLM exact** = [NOTE] non bloquant, à trancher au démarrage de l'Épic 5.
- **Intégration Steam (GodotSteam)** prévue en **Épic 7** (succès / Cloud / achievements).
- **Outillage IA de dev (MCP) :** Gopeak Godot MCP + Context7 (à configurer au setup ; vérifier l'activité des repos avant install).
- **Cross-cutting :** logging (`user://logs/`, niveaux ERROR/WARN/INFO/DEBUG), config 3 couches (`const` / `.tres` balance / `settings.cfg`), console de debug (toggle F1, dev only).

### UX Design Requirements

_Aucun document UX dédié n'existe. Les exigences d'interface sont couvertes par le GDD (« Controls and Input », « Art and Audio Direction ») et reflétées dans les FR/NFR ci-dessus (FR5, FR14, FR43, FR44, NFR7) ainsi que dans l'Épic 6 (Art, audio & game feel)._

### FR Coverage Map

- FR1: Épic 1 — Open space iso navigable
- FR2: Épic 1 — Agents natifs (spawn, pathfinding, arrivée/départ)
- FR3: Épic 1 — Horloge pausable x1/x2/x3 + journées
- FR4: Épic 1 — Requêtes (bureau / mail)
- FR5: Épic 1 — Pop-up de décision 2-3 options
- FR6: Épic 1 — Résolution immédiate vs différée
- FR7: Épic 1 — File d'attente + patience → moral
- FR8: Épic 1 — Mails (sollicitation parallèle asynchrone)
- FR9: Épic 1 — Ressource Attention (file + mails)
- FR10: Épic 3 — Trésorerie complète (revenus/dépenses, faillite)
- FR11: Épic 4 — Deadline de mission par contrat
- FR12: Épic 1 — Jauge Moral de base (impact patience)
- FR13: Épic 2 — Jauge Fatigue
- FR14: Épic 1 — HUD persistant des jauges globales
- FR15: Épic 1 — Bilan de fin de journée
- FR16: Épic 2 — Burnout (indispo + malus + contagion)
- FR17: Épic 2 — Heures sup / jours off / départ anticipé
- FR18: Épic 2 — Concertations entre agents
- FR19: Épic 2 — Contagion du moral via échanges
- FR20: Épic 2 — Événements de vie perso
- FR21: Épic 2 — Garde-fous d'émergence
- FR22: Épic 3 — Recrutement d'agents
- FR23: Épic 3 — Placement mobilier snap-to-grid
- FR24: Épic 3 — Effets de zone du mobilier
- FR25: Épic 3 — Agrandissement de l'open space
- FR26: Épic 4 — Système de contrats/missions
- FR27: Épic 4 — Avancement mission (productivité + deadline)
- FR28: Épic 4 — Jalons de croissance & déblocages
- FR29: Épic 4 — Victoire IPO + écran d'IPO
- FR30: Épic 4 — Conditions de défaite (faillite / effondrement)
- FR31: Épic 4 — Écran de création de partie
- FR32: Épic 5 — Brancher/débrancher LLM (UI, signe, -15 moral + cooldown)
- FR33: Épic 5 — Budget IA (ressource dédiée)
- FR34: Épic 5 — Bonus branché (+50 % + initiatives)
- FR35: Épic 5 — Dérapage (~20 %, 4 formes)
- FR36: Épic 5 — Déblocage LLM après 1er jalon
- FR37: Épic 5 — BYOK (saisie + stockage local sécurisé)
- FR38: Épic 5 — Abstraction `Agent.brain` (LLMBrain + swap ; fondation `NativeBrain` posée en Épic 1)
- FR39: Épic 4 — Mode scénario (~3 h vers IPO)
- FR40: Épic 7 — Mode infini
- FR41: Épic 7 — Sauvegarde/chargement état complet
- FR42: Épic 7 — Tutoriel / onboarding
- FR43: Épic 1 — Fiche agent / sélection
- FR44: Épic 1 — Contrôles souris + raccourcis clavier

_NFRs : NFR1/NFR2 transverses (établis dès Épic 1, validés Épic 7) ; NFR3/NFR4/NFR5 → Épic 5 ; NFR6 → Épic 7 ; NFR7 → Épic 6 ; NFR8 transverse (séquençage) ; NFR9 → Épics 1+5 ; NFR10 → gate de fin d'Épic 1 ; NFR11 transverse (cross-cutting archi)._

## Epic List

### Épic 1: Open space & boucle cœur (MVP)
Le joueur peut diriger une boîte en IA native pure : des agents circulent dans un open space iso, le sollicitent (bureau ou mail), et il tranche des décisions sous pression pendant que le temps tourne. Prouve le fun du pilier #4 — jouable et complet sans aucun LLM.
**FRs covered:** FR1, FR2, FR3, FR4, FR5, FR6, FR7, FR8, FR9, FR12, FR14, FR15, FR43, FR44

### Épic 2: Bien-être & émergence
L'open space prend vie : fatigue et burnout, concertations visibles entre agents, contagion du moral, événements de vie perso — avec des garde-fous pour que le chaos raconte des histoires sans autodétruire un run. Bâtit sur les agents de l'Épic 1.
**FRs covered:** FR13, FR16, FR17, FR18, FR19, FR20, FR21

### Épic 3: Économie & agencement
Le joueur gère la trésorerie et l'espace : il recrute des agents, place du mobilier à effets de zone sur grille, et agrandit l'open space par paliers. Ajoute le levier tycoon, autonome.
**FRs covered:** FR10, FR22, FR23, FR24, FR25

### Épic 4: Missions & progression vers l'IPO
Le jeu a un but et une fin : un système de contrats avec deadlines fait grandir la boîte via des jalons, jusqu'à la victoire (IPO) ou la défaite (faillite/effondrement), depuis l'écran de création de partie. Boucle scénario complète.
**FRs covered:** FR11, FR26, FR27, FR28, FR29, FR30, FR31, FR39

### Épic 5: Intégration LLM (le hook)
Le joueur peut brancher un vrai LLM sur un agent : pari génie/chaos (bonus +50 % vs dérapages), budget IA dédié, BYOK, le tout en appels async non bloquants avec fallback natif. L'amplificateur signature, isolé (risque n°1), bâti sur la fondation `brain` de l'Épic 1.
**FRs covered:** FR32, FR33, FR34, FR35, FR36, FR37, FR38

### Épic 6: Art, audio & game feel
L'identité *Severance* et le juice : DA 3D iso aseptisée, animations d'agents, indicateurs au-dessus des têtes, audio adaptatif, polish de feedback et lisibilité. Couche de présentation transverse.
**FRs covered:** (présentation — réalise NFR7 + GDD Art/Audio ; aucun FR fonctionnel propre)

### Épic 7: Modes, méta & polish
Complétude et release : mode infini, sauvegarde/chargement, tutoriel doux, équilibrage par playtest, intégration Steam, build démo itch.io.
**FRs covered:** FR40, FR41, FR42

## Epic 1: Open space & boucle cœur (MVP)

Le joueur peut diriger une boîte en IA native pure : des agents circulent dans un open space iso, le sollicitent (bureau ou mail), et il tranche des décisions sous pression pendant que le temps tourne. Prouve le fun du pilier #4 — jouable et complet sans aucun LLM. **FRs couverts :** FR1-9, FR12, FR14, FR15, FR43, FR44. **NFRs pertinents :** NFR1 (60 FPS), NFR2 (SimClock ~3 Hz découplé), NFR9 (anti save-scum), NFR10 (boucle native « fun » — gate de sortie d'épic).

### Story 1.1: Fondations du projet & open space iso navigable

As a joueur,
I want un open space 3D isométrique que je peux explorer librement à la caméra,
So that je vois l'espace de ma boîte avant même qu'il se peuple.

**Acceptance Criteria:**

**Given** le projet Godot 4.6.3 est créé selon la structure de dossiers définie (autoloads stubs `EventBus`, `SimClock`, `GameManager`, `Logger`, `ConfigService` posés)
**When** je lance le jeu
**Then** une scène open space en vrai 3D + caméra orthographique (Forward+) s'affiche sur une grille (`GridMap`)

**Given** la scène open space est affichée
**When** je déplace la souris au bord de l'écran ou utilise WASD
**Then** la caméra se déplace
**And** la molette zoome/dézoome dans des bornes min/max

**Given** le jeu tourne avec l'open space vide
**When** je mesure la perf sur PC milieu de gamme
**Then** il tient 60 FPS (NFR1)

### Story 1.2: Agents natifs : spawn, déplacement & cycle de journée

As a joueur,
I want voir des agents apparaître et circuler dans l'open space au fil de la journée,
So that la boîte semble vivante.

**Acceptance Criteria:**

**Given** des archétypes d'agents existent en Resources `.tres`
**When** une journée démarre
**Then** un `AgentFactory` instancie les agents (chacun avec un `BrainComponent` + `NativeBrain`) et ils arrivent le matin

**Given** un agent est dans l'open space
**When** la simulation tourne
**Then** il se déplace par pathfinding vers une destination (poste/bureau) sans traverser le mobilier
**And** il est animé par une State Machine de base (idle/work)

**Given** la journée avance vers le soir
**When** l'heure de fin approche
**Then** les agents repartent (certains plus tôt, d'autres plus tard)
**And** la logique d'agent est évaluée à basse fréquence via `SimClock` (NFR2), découplée du rendu

### Story 1.3: Horloge de jeu pausable & journées ouvrées

As a joueur,
I want contrôler l'écoulement du temps,
So that je gère la pression à mon rythme.

**Acceptance Criteria:**

**Given** une partie est en cours
**When** j'appuie sur Espace
**Then** le temps se met en pause (et reprend)
**And** les agents et jauges se figent en pause

**Given** la partie tourne
**When** j'appuie sur 1/2/3
**Then** la vitesse passe à x1/x2/x3

**Given** le temps s'écoule
**When** une journée ouvrée (~5 min réelles à x1, valeur tunable en `.tres`) se termine
**Then** le compteur de jour s'incrémente et un nouveau cycle matin→soir démarre

### Story 1.4: Sollicitations : agent au bureau & mail

As a joueur,
I want que les agents me sollicitent de deux façons (en personne ou par mail),
So that je ressens la tension de l'attention.

**Acceptance Criteria:**

**Given** un agent a une décision importante à remonter
**When** la sollicitation se déclenche
**Then** il se déplace jusqu'au bureau du joueur

**Given** un agent a une sollicitation moins urgente
**When** elle se déclenche
**Then** un « mail » clignotant apparaît (canal asynchrone) sans déplacer l'agent

**Given** une sollicitation existe (bureau ou mail)
**When** je l'observe
**Then** je peux l'identifier visuellement et l'ouvrir d'un clic

### Story 1.5: Pop-up de décision (2-3 options)

As a joueur,
I want trancher des décisions via des pop-ups à 2-3 options,
So that je pilote la boîte sous pression.

**Acceptance Criteria:**

**Given** j'ouvre une sollicitation
**When** la pop-up de décision s'affiche
**Then** elle présente le contexte + 2 à 3 options actionnables

**Given** la pop-up est ouverte
**When** le temps n'est pas en pause
**Then** il continue de tourner (la décision a un coût d'attention)

**Given** je choisis une option d'un clic gauche
**When** je valide
**Then** la pop-up se ferme et l'agent repart agir selon mon choix

### Story 1.6: Résolution immédiate vs différée

As a joueur,
I want que certaines décisions aient un effet immédiat et d'autres différé,
So that je décide sans filet (pilier #2).

**Acceptance Criteria:**

**Given** je tranche une décision
**When** elle est de type immédiat (~60 %)
**Then** son effet s'applique tout de suite (jauges/état)

**Given** je tranche une décision de type différé (~40 %)
**When** 1 à 2 jours de jeu s'écoulent
**Then** son effet se résout à l'échéance via l'ordonnancement `SimClock`

**Given** une décision différée est en attente
**When** je consulte l'état du jeu
**Then** rien ne révèle prématurément son issue (anti save-scum, NFR9)

### Story 1.7: File d'attente, patience & jauge Moral

As a joueur,
I want que les agents fassent la queue et perdent patience,
So that mon attention est une vraie ressource rare (pilier #1).

**Acceptance Criteria:**

**Given** plusieurs agents me sollicitent au bureau
**When** je suis occupé
**Then** ils forment une file d'attente physique visible

**Given** chaque agent a une jauge Moral (0-100) et une patience (~45 s à x1, tunable)
**When** son attente dépasse la patience
**Then** son moral chute (-1 / 5 s)

**Given** je traite enfin un agent en file
**When** la pop-up se résout
**Then** il quitte la file et la patience des suivants continue de courir

### Story 1.8: HUD persistant & ressource Attention

As a joueur,
I want un HUD qui montre l'état global et ma charge d'attention,
So that je priorise d'un coup d'œil.

**Acceptance Criteria:**

**Given** une partie est en cours
**When** je joue
**Then** un HUD persistant affiche les jauges globales (trésorerie, moral moyen, jour en cours)

**Given** des sollicitations sont en attente
**When** la file et/ou des mails s'accumulent
**Then** la pression d'attention est matérialisée (compteur de file + mails en attente)

**Given** une jauge globale franchit un seuil notable
**When** ça se produit
**Then** le HUD le signale visuellement (lisibilité, NFR7)

### Story 1.9: Fiche agent & sélection

As a joueur,
I want cliquer un agent pour voir sa fiche,
So that je comprends son état individuel.

**Acceptance Criteria:**

**Given** des agents sont dans l'open space
**When** je clique gauche sur l'un d'eux
**Then** sa fiche s'ouvre (jauges : moral ; identité)

**Given** la fiche est ouverte
**When** je la consulte
**Then** elle réserve l'emplacement des actions futures (brancher/débrancher, jour off — désactivées à ce stade)

**Given** une fiche est ouverte
**When** je clique ailleurs / ferme
**Then** elle se referme proprement

### Story 1.10: Bilan de fin de journée

As a joueur,
I want un récapitulatif en fin de journée,
So that je mesure ma performance et anticipe le lendemain.

**Acceptance Criteria:**

**Given** une journée ouvrée se termine
**When** le soir arrive
**Then** un écran de bilan affiche trésorerie, moral moyen et avancement (placeholder mission à ce stade)

**Given** le bilan est affiché
**When** je le valide
**Then** la journée suivante démarre

**Given** la boucle native complète tourne (1.1→1.10)
**When** elle est jouée en playtest
**Then** elle est jugée « fun » avant toute intégration LLM (NFR10 — gate de sortie de l'Épic)

## Epic 2: Bien-être & émergence

L'open space prend vie : fatigue et burnout, concertations visibles entre agents, contagion du moral, événements de vie perso — avec des garde-fous pour que le chaos raconte des histoires sans autodétruire un run. Bâtit sur les agents de l'Épic 1. **FRs couverts :** FR13, FR16, FR17, FR18, FR19, FR20, FR21. **NFRs pertinents :** NFR2 (calculs sur `SimClock`), NFR7 (états lisibles).

### Story 2.1: Jauge Fatigue par agent

As a joueur,
I want que chaque agent accumule de la fatigue,
So that je dois gérer leur endurance.

**Acceptance Criteria:**

**Given** chaque agent a une jauge Fatigue (0-100)
**When** il travaille une journée standard (~8 h-jeu)
**Then** sa fatigue évolue selon les règles `.tres` (repos -25/j)
**And** la jauge est visible sur sa fiche

**Given** un agent fait des heures sup'
**When** la journée se termine
**Then** +15 fatigue sont appliqués (et +prod du jour)

**Given** la fatigue évolue
**When** la sim tourne
**Then** elle est calculée via `SimClock` sans coût de perf notable (NFR2)

### Story 2.2: Burnout : seuil de risque & craquage

As a joueur,
I want que la fatigue extrême ait des conséquences,
So that pousser mes agents est un vrai risque.

**Acceptance Criteria:**

**Given** un agent atteint une fatigue ≥80
**When** ce seuil est franchi
**Then** un indicateur de risque de burnout apparaît

**Given** un agent atteint une fatigue =100
**When** il craque
**Then** il devient indisponible plusieurs jours, subit un gros malus moral, et déclenche de la contagion (`EventBus.agent_burned_out`)

**Given** un agent est en burnout
**When** je consulte l'open space
**Then** son état est lisible visuellement (avachi/absent)

### Story 2.3: Gestion du temps de travail

As a joueur,
I want régler les horaires de mes agents,
So that j'arbitre productivité vs fatigue.

**Acceptance Criteria:**

**Given** la fiche d'un agent est ouverte
**When** je lui impose des heures sup'
**Then** sa prod du jour augmente et sa fatigue grimpe (+15/j)

**Given** la fiche est ouverte
**When** je lui accorde un jour off
**Then** il est absent ce jour-là et récupère de la fatigue/du moral

**Given** un agent a un départ anticipé
**When** le soir approche
**Then** il quitte plus tôt avec une prod réduite mais moins de fatigue

### Story 2.4: Concertations visibles entre agents

As a joueur,
I want voir les agents se concerter,
So that je lis les dynamiques sociales de la boîte.

**Acceptance Criteria:**

**Given** deux agents proches sont disponibles
**When** une concertation se déclenche
**Then** ils interagissent visiblement (bulles/anim de concertation) pendant une durée bornée

**Given** une concertation a lieu
**When** elle se produit
**Then** elle émet un événement (`EventBus`) exploitable par le système de contagion

**Given** un agent est en concertation
**When** la sim tourne
**Then** son état passe par l'état `confer` de la State Machine

### Story 2.5: Contagion du moral par les échanges

As a joueur,
I want que l'humeur circule entre agents via leurs échanges,
So that des histoires émergent (pilier #4).

**Acceptance Criteria:**

**Given** une concertation a lieu entre deux agents
**When** l'un est au moral bas/instable
**Then** il perturbe le travail de l'autre (interruption/temps perdu) et lui transfère du moral négatif (ex. -5) selon le type d'échange

**Given** un agent est au top moral
**When** il se concerte avec un collègue au moral bas
**Then** il peut le remonter (transfert positif)

**Given** la contagion s'applique
**When** elle se propage
**Then** elle passe par les échanges réels (pas un rayon de proximité)

### Story 2.6: Événements de vie perso

As a joueur,
I want que des événements de vie touchent mes agents,
So that ils ont une personnalité et des réactions imprévues.

**Acceptance Criteria:**

**Given** un agent vit un événement perso (divorce, deuil…)
**When** il survient
**Then** il colore son moral et ses réactions pour une durée donnée

**Given** un agent dort au bureau
**When** la nuit passe
**Then** il gagne un peu de deadline mais +30 fatigue/nuit (amorce de spirale de burnout)

**Given** un événement perso est actif
**When** je consulte la fiche de l'agent
**Then** il est indiqué

### Story 2.7: Garde-fous d'émergence

As a joueur,
I want que le chaos reste racontable mais non auto-destructeur,
So that un run ne s'effondre pas instantanément.

**Acceptance Criteria:**

**Given** une chaîne de contagion se déclenche
**When** un agent vient d'être contaminé
**Then** il ne relance pas une chaîne infinie le même jour (profondeur limitée)

**Given** une crise grave (burnout en cascade) survient
**When** elle se résout
**Then** un cooldown empêche son enchaînement immédiat

**Given** le framework de garde-fous est en place
**When** l'Épic 5 ajoutera les dérapages LLM
**Then** la règle « max 1 dérapage majeur par agent et par jour » s'y branchera (point d'extension prévu ici)

## Epic 3: Économie & agencement

Le joueur gère la trésorerie et l'espace : il recrute des agents, place du mobilier à effets de zone sur grille, et agrandit l'open space par paliers. Ajoute le levier tycoon, autonome. **FRs couverts :** FR10, FR22, FR23, FR24, FR25. **NFRs pertinents :** NFR1 (60 FPS open space peuplé).

### Story 3.1: Trésorerie : revenus, dépenses & faillite

As a joueur,
I want une trésorerie qui suit mes revenus et dépenses,
So that je gère la santé financière de la boîte.

**Acceptance Criteria:**

**Given** une partie est en cours
**When** des revenus (livraison de contrat — placeholder à ce stade) ou des dépenses (salaires) tombent
**Then** la trésorerie (€) est mise à jour et affichée au HUD

**Given** les salaires sont dus
**When** une échéance de paie arrive
**Then** ils sont prélevés automatiquement sur la trésorerie

**Given** la trésorerie passe < 0
**When** le délai de grâce est dépassé
**Then** la condition de faillite est levée (`EventBus`), prête à être consommée par l'Épic 4 (game over)

### Story 3.2: Recrutement d'agents

As a joueur,
I want recruter de nouveaux agents,
So that j'augmente la capacité de production de la boîte.

**Acceptance Criteria:**

**Given** j'ai accès à l'écran de recrutement
**When** j'embauche un agent
**Then** un coût d'embauche est prélevé immédiatement et un salaire récurrent s'ajoute aux dépenses

**Given** un agent vient d'être recruté
**When** la journée suivante démarre
**Then** il apparaît dans l'open space (via `AgentFactory`) et participe à la boucle

**Given** la surface/capacité d'agents est atteinte
**When** je tente de recruter au-delà
**Then** l'action est bloquée avec un retour clair (lié à l'agrandissement, Story 3.5)

### Story 3.3: Placement de mobilier snap-to-grid

As a joueur,
I want placer du mobilier sur une grille,
So that j'aménage mon open space.

**Acceptance Criteria:**

**Given** je suis en mode aménagement
**When** je sélectionne un meuble (bureau, salle de repos, café, sieste, cloison…)
**Then** il s'accroche à la grille (`GridMap`, snap-to-grid) à la position du curseur

**Given** je place un meuble
**When** je confirme
**Then** son coût est prélevé sur la trésorerie et il devient un obstacle pris en compte par le pathfinding

**Given** une case est occupée ou hors surface débloquée
**When** je tente d'y placer un meuble
**Then** le placement est refusé visuellement

### Story 3.4: Effets de zone du mobilier

As a joueur,
I want que le mobilier influence mes agents,
So that l'aménagement est un levier de gestion.

**Acceptance Criteria:**

**Given** un meuble à effet de zone est placé (ex. salle de repos)
**When** un agent est à proximité
**Then** l'effet s'applique (salle de repos → -fatigue ; machine à café → +moral ; etc.) selon les valeurs `.tres`

**Given** plusieurs effets de zone se chevauchent
**When** un agent est dans la zone
**Then** les effets se cumulent selon les règles définies

**Given** un meuble est retiré/déplacé
**When** je modifie l'agencement
**Then** ses effets de zone cessent/migrent en conséquence

### Story 3.5: Agrandissement de l'open space par paliers

As a joueur,
I want agrandir mon open space,
So that j'accueille plus d'agents et de zones en grandissant.

**Acceptance Criteria:**

**Given** j'atteins un palier de croissance
**When** je débloque une extension (petit local → étage → plateau)
**Then** de la surface de grille supplémentaire devient disponible (coût sur trésorerie)

**Given** une extension est débloquée
**When** elle s'ouvre
**Then** la capacité max d'agents et le nombre de zones placeables augmentent

**Given** l'open space s'agrandit
**When** il est peuplé au max
**Then** la perf reste à 60 FPS (NFR1)

## Epic 4: Missions & progression vers l'IPO

Le jeu a un but et une fin : un système de contrats avec deadlines fait grandir la boîte via des jalons, jusqu'à la victoire (IPO) ou la défaite (faillite/effondrement), depuis l'écran de création de partie. Boucle scénario complète. **FRs couverts :** FR11, FR26, FR27, FR28, FR29, FR30, FR31, FR39.

### Story 4.1: Écran de création de partie

As a joueur,
I want nommer ma boîte et fixer son but au démarrage,
So that je m'approprie ma partie.

**Acceptance Criteria:**

**Given** je lance une nouvelle partie
**When** l'écran de création s'affiche
**Then** je peux saisir un nom de boîte et choisir/fixer un but

**Given** j'ai renseigné nom + but
**When** je valide
**Then** la partie démarre en mode scénario avec ces paramètres persistés dans l'état de jeu

**Given** un champ requis est vide
**When** je tente de valider
**Then** la validation est bloquée avec un retour clair

### Story 4.2: Système de contrats/missions

As a joueur,
I want recevoir des contrats à livrer,
So that j'ai des objectifs qui font grandir la boîte.

**Acceptance Criteria:**

**Given** des contrats existent en Resources `.tres`
**When** un contrat devient actif
**Then** ses objectifs, sa récompense (€) et sa deadline sont affichés

**Given** un contrat est livré (objectifs atteints)
**When** la livraison se résout
**Then** la récompense est créditée à la trésorerie et le contrat suivant peut s'enchaîner

**Given** plusieurs contrats peuvent exister
**When** je consulte l'état du jeu
**Then** le(s) contrat(s) actif(s) et leur progression sont lisibles au HUD

### Story 4.3: Avancement de mission & deadline

As a joueur,
I want que l'avancement dépende de la productivité de mes agents et coure contre une deadline,
So that je ressens la pression du temps.

**Acceptance Criteria:**

**Given** un contrat est actif avec une jauge Deadline
**When** le temps s'écoule
**Then** la deadline progresse vers l'échéance

**Given** des agents travaillent sur le contrat
**When** ils produisent
**Then** l'avancement de mission monte proportionnellement à leur productivité (modulée par moral/fatigue)
**And** s'ils sous-performent, la deadline glisse / le risque d'échec monte

**Given** la deadline est atteinte sans livraison
**When** l'échéance tombe
**Then** le contrat échoue avec ses conséquences (perte de récompense / pénalité)

### Story 4.4: Jalons de croissance & déblocages

As a joueur,
I want franchir des jalons qui débloquent du contenu,
So that je sens la boîte monter en puissance.

**Acceptance Criteria:**

**Given** je livre des contrats / fais croître la boîte
**When** un jalon de croissance est atteint
**Then** des déblocages s'activent (capacité d'agents, plafond de crédits IA, contrats plus lucratifs, améliorations d'aménagement)

**Given** le 1er jalon est franchi
**When** il se valide
**Then** il émet l'événement qui débloquera le branchement LLM (consommé en Épic 5, Story 5.6)

**Given** un déblocage est obtenu
**When** je consulte le jeu
**Then** le nouveau contenu/option devient accessible et signalé

### Story 4.5: Mode scénario : enchaînement vers l'IPO

As a joueur,
I want un run scénario d'environ 3 h structuré vers l'IPO,
So that j'ai une progression rythmée.

**Acceptance Criteria:**

**Given** une partie scénario est lancée
**When** je progresse
**Then** les contrats et jalons s'enchaînent selon une courbe de difficulté montante (vers les seuils d'IPO)

**Given** le run avance
**When** je m'approche de la fin
**Then** la pression (sollicitations, deadlines) s'intensifie conformément à la courbe de difficulté du GDD

**Given** un run typique
**When** il est joué
**Then** sa durée vise ~3 h (valeur d'équilibrage tunable, affinée en Épic 7)

### Story 4.6: Condition de victoire : seuils & écran d'IPO

As a joueur,
I want atteindre l'IPO pour gagner,
So that j'ai un objectif final clair.

**Acceptance Criteria:**

**Given** les seuils d'IPO sont définis (valorisation / contrats livrés / stabilité)
**When** je les atteins tous
**Then** la condition de victoire est levée

**Given** la victoire est atteinte
**When** elle se déclenche
**Then** un écran d'IPO s'affiche récapitulant la performance du run

**Given** l'écran d'IPO est affiché
**When** je le valide
**Then** je peux quitter / relancer (et, plus tard, basculer en mode infini)

### Story 4.7: Conditions de défaite : faillite / effondrement

As a joueur,
I want pouvoir perdre,
So that mes décisions ont un enjeu réel.

**Acceptance Criteria:**

**Given** la faillite est levée (Story 3.1 : trésorerie < 0 au-delà du délai de grâce)
**When** l'événement est reçu
**Then** la partie se termine en défaite (écran de game over)

**Given** le moral collectif s'effondre / une vague de burnouts fait échouer une mission critique
**When** la condition d'effondrement est atteinte
**Then** la partie se termine en défaite

**Given** une défaite survient
**When** l'écran de fin s'affiche
**Then** il indique la cause et propose de relancer

## Epic 5: Intégration LLM (le hook)

Le joueur peut brancher un vrai LLM sur un agent : pari génie/chaos (bonus +50 % vs dérapages), budget IA dédié, BYOK, le tout en appels async non bloquants avec fallback natif. L'amplificateur signature, isolé (risque n°1), bâti sur la fondation `brain` de l'Épic 1. **FRs couverts :** FR32, FR33, FR34, FR35, FR36, FR37, FR38. **NFRs pertinents :** NFR3 (async/fallback), NFR4 (BYOK local chiffré), NFR5 (natif offline), NFR9 (anti save-scum). **[NOTE archi]** Fournisseur/SDK LLM exact à trancher au démarrage de l'épic (non bloquant).

### Story 5.1: BYOK : saisie & stockage local sécurisé de la clé

As a joueur,
I want fournir ma propre clé API LLM en toute sécurité,
So that j'active le mode branché sans risque pour mes identifiants.

**Acceptance Criteria:**

**Given** j'ouvre les réglages LLM
**When** je saisis ma clé API et choisis un fournisseur
**Then** la clé est stockée localement chiffrée (`user://settings.cfg`), jamais transmise ailleurs qu'au fournisseur choisi (NFR4)

**Given** aucune clé n'est renseignée
**When** je joue
**Then** le mode natif reste pleinement jouable hors-ligne (NFR5)

**Given** une clé est enregistrée
**When** je relance le jeu
**Then** elle est rechargée depuis le stockage local sans être affichée en clair

### Story 5.2: `LLMService` async + fallback natif

As a joueur,
I want que les appels au LLM ne gèlent jamais le jeu,
So that l'expérience reste fluide même en cas de latence ou d'échec réseau.

**Acceptance Criteria:**

**Given** `LLMService` (autoload) reçoit une requête de décision
**When** il appelle l'API via `HTTPRequest`
**Then** l'appel est non bloquant (file de requêtes) et le jeu continue de tourner (NFR3)

**Given** un appel échoue ou dépasse le timeout (~10 s)
**When** le résultat n'arrive pas
**Then** un fallback `NativeBrain` prend le relais pour ce tick (log WARN + `EventBus.llm_call_failed`), transparent pour le joueur

**Given** un appel réussit (HTTP 200)
**When** la réponse arrive
**Then** elle est parsée et validée contre l'`ActionRegistry` avant application

### Story 5.3: `LLMBrain` & swap à chaud via `BrainComponent`

As a joueur,
I want qu'un agent branché raisonne via le LLM avec exactement les mêmes capacités qu'en natif,
So that le branchement change le comportement, pas les règles.

**Acceptance Criteria:**

**Given** un agent porte un `BrainComponent` (fondation posée en Épic 1)
**When** `connect_llm()` est appelé
**Then** son cerveau devient un `LLMBrain` qui décide via `LLMService` en utilisant le même `ActionRegistry` que le `NativeBrain`

**Given** un agent branché
**When** `disconnect_llm()` est appelé
**Then** son cerveau redevient `NativeBrain` (le fallback) sans état incohérent

**Given** une nouvelle capacité d'agent est ajoutée
**When** elle passe par l'`ActionRegistry`
**Then** la parité natif ↔ LLM est garantie (aucune action codée en dur dans un brain)

### Story 5.4: Budget IA (ressource dédiée)

As a joueur,
I want un budget IA distinct de ma trésorerie,
So that brancher des agents est un arbitrage de ressource à part entière.

**Acceptance Criteria:**

**Given** une partie est en cours
**When** je consulte le HUD
**Then** un Budget IA (crédits) s'affiche, distinct de la trésorerie

**Given** un ou plusieurs agents sont branchés
**When** une journée passe
**Then** des crédits IA sont consommés par jour et par agent branché

**Given** le Budget IA est épuisé
**When** il tombe à zéro
**Then** je ne peux plus tenir d'agents branchés (débranchement forcé / branchement bloqué) avec retour clair

### Story 5.5: Brancher / débrancher (UI, signe visuel, coût)

As a joueur,
I want brancher/débrancher un agent depuis sa fiche,
So that je pilote le pari génie/chaos.

**Acceptance Criteria:**

**Given** la fiche d'un agent est ouverte et le branchement est débloqué
**When** je le branche
**Then** un signe visuel « branché » apparaît au-dessus de l'agent et des crédits IA commencent à être consommés

**Given** un agent est branché
**When** je le débranche
**Then** reprise de contrôle immédiate, coût = -15 moral (agent « rétrogradé ») + cooldown 1 jour avant rebranchement, sans coût en argent

**Given** un agent est en cooldown de débranchement
**When** je tente de le rebrancher
**Then** l'action est bloquée jusqu'à la fin du cooldown

### Story 5.6: Déblocage du LLM après le 1er jalon

As a joueur,
I want que le branchement LLM ne s'ouvre qu'après un premier jalon,
So that la boîte « mûrit » vers l'IA (cohérence fiction + montée en puissance).

**Acceptance Criteria:**

**Given** la partie démarre
**When** je joue avant le 1er jalon
**Then** l'action brancher/débrancher est verrouillée (départ en IA native uniquement)

**Given** le 1er jalon de progression est franchi (événement émis en Story 4.4)
**When** il est reçu
**Then** le branchement LLM se débloque et est signalé au joueur

**Given** le LLM est débloqué
**When** je rouvre une fiche agent
**Then** l'action brancher/débrancher est disponible (sous réserve de clé BYOK + budget IA)

### Story 5.7: Bonus branché : +50 % efficacité & initiatives

As a joueur,
I want qu'un agent branché soit plus performant et autonome,
So that le branchement vaille son coût/risque.

**Acceptance Criteria:**

**Given** un agent est branché et stable
**When** il exécute ses tâches
**Then** il bénéficie de +50 % d'efficacité

**Given** un agent branché
**When** la sim tourne
**Then** il débloque des initiatives autonomes (il agit sans demander, via l'`ActionRegistry`)

**Given** un agent branché agit en autonomie
**When** une initiative significative se produit
**Then** elle est lisible par le joueur (feedback)

### Story 5.8: Dérapage : le pari génie/chaos

As a joueur,
I want qu'un agent branché puisse déraper,
So that le risque IA est un vrai moteur de gameplay (pilier #3).

**Acceptance Criteria:**

**Given** un agent est branché
**When** une journée passe
**Then** il a ~20 % de probabilité de dérapage, modulée par son moral (moral haut → plus fiable ; moral bas → plus de chaos)
**And** un indicateur d'instabilité apparaît quand le moral baisse

**Given** un dérapage se déclenche
**When** il survient
**Then** il prend l'une des 4 formes : initiative coûteuse non demandée 💸, contamination des collègues 🗣️, réponse créative/hors-sujet à arbitrer 🎭, ou crise à gérer en urgence 🔥

**Given** les garde-fous de l'Épic 2 sont en place
**When** les dérapages s'enchaînent
**Then** la règle « max 1 dérapage majeur par agent et par jour » est respectée (cooldown sur les crises)
**And** le RNG des dérapages contribue à l'anti save-scum (NFR9)

## Epic 6: Art, audio & game feel

L'identité *Severance* et le juice : DA 3D iso aseptisée, animations d'agents, indicateurs au-dessus des têtes, audio adaptatif, polish de feedback et lisibilité. Couche de présentation transverse qui habille les comportements des Épics 1-5. **FRs couverts :** aucun FR fonctionnel propre — réalise NFR7 (lisibilité), NFR1 (60 FPS) + la direction Art/Audio du GDD.

### Story 6.1: Direction artistique 3D iso (DA Severance)

As a joueur,
I want un open space à l'esthétique corporate aseptisée,
So that je ressens l'ambiance pince-sans-rire et légèrement inquiétante du jeu.

**Acceptance Criteria:**

**Given** la scène open space
**When** elle est rendue
**Then** elle applique la palette froide/aseptisée (blancs, teals, beiges corporate), l'éclairage fluorescent et le mobilier épuré décrits au GDD

**Given** les assets 3D iso (agents, mobilier modulaire)
**When** ils sont intégrés
**Then** la lisibilité prime (formes claires, identification d'un coup d'œil — NFR7)

**Given** la DA est appliquée
**When** l'open space est peuplé au max
**Then** la perf reste à 60 FPS (NFR1)

### Story 6.2: Animations d'agents

As a joueur,
I want des agents animés selon leur état,
So that je lis leur situation sans ouvrir leur fiche.

**Acceptance Criteria:**

**Given** un agent change d'état (State Machine)
**When** il passe en marche / travail / concertation / fatigue / sommeil / craquage
**Then** l'animation correspondante se joue

**Given** des variations d'agents existent
**When** ils peuplent l'open space
**Then** ils présentent des variations visuelles (pas tous identiques)

**Given** une transition d'état survient
**When** elle se joue
**Then** elle est fluide et lisible

### Story 6.3: Indicateurs au-dessus des têtes

As a joueur,
I want des indicateurs clairs au-dessus des agents,
So that je repère instantanément les états critiques.

**Acceptance Criteria:**

**Given** un agent est branché
**When** je regarde l'open space
**Then** le signe « branché » est visible au-dessus de lui (FR32)

**Given** un agent devient instable (moral bas / branché à risque)
**When** ça se produit
**Then** un indicateur d'instabilité apparaît

**Given** un agent a une humeur/fatigue notable
**When** je survole l'open space
**Then** son état (humeur, fatigue/burnout) est signalé de façon lisible (NFR7)

### Story 6.4: Audio adaptatif

As a joueur,
I want une ambiance sonore qui réagit à la tension,
So that je renforce le malaise et l'urgence.

**Acceptance Criteria:**

**Given** une partie calme
**When** je joue
**Then** l'ambiance feutrée tourne (nappes douces, bips corporate, brouhaha étouffé, sonneries de mail, jingle d'ascenseur)

**Given** une deadline approche ou une crise survient
**When** la tension monte
**Then** la musique monte en tension en conséquence

**Given** des événements de jeu se produisent (mail, décision, burnout, dérapage)
**When** ils surviennent
**Then** des SFX corporate appropriés se déclenchent

### Story 6.5: Polish de feedback & lisibilité

As a joueur,
I want un feedback soigné sur mes actions,
So that le jeu soit agréable et clair à manipuler.

**Acceptance Criteria:**

**Given** j'interagis (pop-ups, sélection, validation)
**When** l'action se produit
**Then** des transitions/feedbacks (juice) accompagnent l'interaction

**Given** une information importante change (jauge critique, résolution différée)
**When** elle survient
**Then** elle est mise en valeur visuellement sans surcharger l'écran

**Given** l'ensemble du game feel
**When** il est playtesté
**Then** la lisibilité d'un coup d'œil est confirmée (NFR7)

## Epic 7: Modes, méta & polish

Complétude et release : mode infini, sauvegarde/chargement, tutoriel doux, équilibrage par playtest, intégration Steam, build démo itch.io. **FRs couverts :** FR40, FR41, FR42. **NFRs / réf. :** NFR6 (save/load rapide), NFR9 (anti save-scum), NFR11 (erreurs non fatales), Archi D11 (GodotSteam).

### Story 7.1: Sauvegarde / chargement de l'état complet

As a joueur,
I want sauvegarder et reprendre ma partie,
So that je joue mes runs en plusieurs sessions.

**Acceptance Criteria:**

**Given** une partie est en cours
**When** je sauvegarde
**Then** `SaveManager` écrit l'état complet de la simulation en local (agents, jauges, contrats, économie, agencement, jour) en < quelques secondes (NFR6)

**Given** une sauvegarde existe
**When** je la charge
**Then** la partie reprend exactement dans l'état sauvegardé

**Given** un fichier de save corrompu/incompatible
**When** je tente de le charger
**Then** l'échec est géré proprement (message clair, pas de crash — NFR11)

### Story 7.2: Mode infini (difficulté croissante, score)

As a joueur,
I want un mode sans fin qui monte en difficulté,
So that je me lance des défis de longévité.

**Acceptance Criteria:**

**Given** je choisis le mode infini
**When** la partie démarre
**Then** il n'y a pas d'état de victoire ; gestion/optimisation sur la durée

**Given** je progresse en mode infini
**When** le temps passe
**Then** la difficulté monte (coûts croissants, contrats plus exigeants) pour éviter une domination triviale

**Given** je joue en mode infini
**When** je consulte ma performance
**Then** un score/des jalons matérialisent l'auto-défi (longévité, taille atteinte)

### Story 7.3: Tutoriel / onboarding doux

As a nouveau joueur,
I want être introduit progressivement à la boucle,
So that j'apprends sans être submergé.

**Acceptance Criteria:**

**Given** je démarre ma première partie
**When** l'onboarding se lance
**Then** il commence avec peu d'agents, IA native, peu de sollicitations simultanées (apprentissage de la boucle attention/file)

**Given** je franchis les premières étapes
**When** je maîtrise une mécanique
**Then** la suivante est introduite progressivement (jusqu'au déblocage du LLM)

**Given** je connais déjà le jeu
**When** je le souhaite
**Then** je peux passer/réduire le tutoriel

### Story 7.4: Équilibrage par playtest

As a joueur,
I want une difficulté et une économie justes,
So that mes décisions soient pertinentes et le run satisfaisant.

**Acceptance Criteria:**

**Given** les valeurs d'équilibrage vivent dans `data/balance/*.tres`
**When** je les ajuste (durée de jour, % dérapage, coûts, jauges)
**Then** elles s'appliquent sans toucher au code (zéro magic number)

**Given** des playtests sont menés
**When** j'analyse les résultats
**Then** la durée d'un run scénario s'approche de la cible (~3 h) et la courbe de difficulté est validée

**Given** l'anti save-scum (résultats différés + RNG dérapage)
**When** un joueur recharge systématiquement
**Then** le rechargement reste peu fiable (NFR9)

### Story 7.5: Intégration Steam

As a joueur,
I want les fonctionnalités Steam,
So that je profite des succès et de la sauvegarde Cloud.

**Acceptance Criteria:**

**Given** GodotSteam est intégré
**When** le jeu tourne sur Steam
**Then** les succès/achievements se débloquent aux jalons appropriés

**Given** Steam Cloud est configuré
**When** je sauvegarde
**Then** la sauvegarde peut se synchroniser sur le Cloud

**Given** le jeu tourne hors Steam (ex. itch.io)
**When** Steam est indisponible
**Then** le jeu fonctionne sans erreur (dégradation propre)

### Story 7.6: Build démo itch.io & options/accessibilité

As a joueur curieux,
I want une démo accessible et des options de base,
So that je découvre le jeu et l'ajuste à mon confort.

**Acceptance Criteria:**

**Given** la branche démo
**When** je l'exporte
**Then** un build itch.io (PC/HTML5) jouable est produit, orienté collecte de wishlists Steam

**Given** je suis dans le jeu
**When** j'ouvre les options
**Then** je peux régler les paramètres de base (audio, vitesse, accessibilité de base) + accéder aux écrans méta

**Given** la démo et les options
**When** elles sont testées
**Then** elles fonctionnent sans régression sur la build principale
