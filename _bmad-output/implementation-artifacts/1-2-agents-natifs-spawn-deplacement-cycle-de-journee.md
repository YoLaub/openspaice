---
baseline_commit: NO_VCS
---

# Story 1.2: Agents natifs — spawn, déplacement & cycle de journée

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a joueur,
I want voir des agents apparaître et circuler dans l'open space au fil de la journée,
so that la boîte semble vivante.

## Acceptance Criteria

1. **Given** des archétypes d'agents existent en Resources `.tres` **When** une journée démarre **Then** un `AgentFactory` instancie les agents (chacun avec un `BrainComponent` + `NativeBrain`) et ils arrivent le matin.
2. **Given** un agent est dans l'open space **When** la simulation tourne **Then** il se déplace par pathfinding vers une destination (poste/bureau) sans traverser le mobilier **And** il est animé par une State Machine de base (idle/work).
3. **Given** la journée avance vers le soir **When** l'heure de fin approche **Then** les agents repartent (certains plus tôt, d'autres plus tard) **And** la logique d'agent est évaluée à basse fréquence via `SimClock` (NFR2), découplée du rendu.

## Tasks / Subtasks

- [x] **Task 1 — Activer `SimClock` (émission de ticks de simulation)** (AC: #3 ; pré-requis de toute la logique agent)
  - [x] Ajouter un signal typé `simulation_tick(tick_delta: float)` dans `sim_clock.gd` (snake_case ; émis dans la boucle d'accumulateur existante, à la place du `TODO(Story 1.3)`).
  - [x] Passer `running = true` au démarrage (méthode `start()` appelée par `GameManager` au lancement de partie, OU `running = true` par défaut pour cette story — voir Dev Notes « Découplage temporel »).
  - [x] **Ne PAS** implémenter pause / vitesses x1-x2-x3 ici : c'est la Story 1.3. Garder l'API minimale et extensible (voir Dev Notes « Frontière avec Story 1.3 »).
  - [x] Conserver `TICK_HZ = 3.0` (NFR2). Aucune logique métier dans `SimClock` lui-même — il ne fait qu'émettre le tick.
- [x] **Task 2 — Source minimale de cycle de journée (matin → soir)** (AC: #1, #3)
  - [x] Introduire une **phase de journée** normalisée `0.0 → 1.0` (matin → soir) avancée par `simulation_tick`, exposée de façon lisible (ex. `GameManager.day_phase` ou un petit nœud `DayCycle`). Empreinte **minimale** : la Story 1.3 reprend et formalise l'horloge pausable, le compteur de jours et la durée de journée tunable.
  - [x] Émettre des jalons exploitables par les agents : début de matinée (spawn) et approche du soir (départ). Préférer des signaux `EventBus` (`day_started`, `evening_approaching`) plutôt qu'un couplage direct — voir Dev Notes « Event System ».
  - [x] Durée de la « journée » de cette story : valeur **tunable en `.tres`** (`data/balance/*.tres`), pas de magic number. Valeur de départ courte pour itérer (ex. ~60 s), affinée en 1.3 (~5 min cible).
- [x] **Task 3 — Fondation Dual-Mode Brain (natif uniquement)** (AC: #1 ; ADR-1)
  - [x] `scripts/agents/brain/agent_brain.gd` — `class_name AgentBrain extends RefCounted`, interface `decide(ctx: AgentContext) -> AgentAction` (corps de base = `push_error` + retour null).
  - [x] `scripts/agents/brain/native_brain.gd` — `class_name NativeBrain extends AgentBrain` ; logique de règles **déterministe et instantanée** produisant les actions de cette story (aller au poste, travailler, idle, repartir). **Aucune action codée en dur** : toutes via `ActionRegistry`.
  - [x] `scripts/agents/brain/agent_context.gd` (`class_name AgentContext`) — snapshot minimal lu par le brain (position, destination courante, état SM, phase de journée / signal de départ). Extensible (moral/fatigue viennent plus tard).
  - [x] `scripts/agents/brain/agent_action.gd` (`class_name AgentAction`) — description d'action (type + payload léger).
  - [x] `scripts/agents/tools/action_registry.gd` (`class_name ActionRegistry`) — fabrique/registre central des actions partagées (`make(name, ...)`). **Source unique de vérité** des capacités d'agent (parité natif ↔ LLM garantie en Épic 5).
  - [x] `scripts/agents/brain/brain_component.gd` — `class_name BrainComponent extends Node` ; détient `_brain: AgentBrain = NativeBrain.new()`, expose `tick(ctx) -> AgentAction`. **Ne PAS** créer `LLMBrain` / `connect_llm()` ici (Épic 5) — mais ne rien faire qui empêchera de les ajouter (voir Dev Notes « Parité & async »).
- [x] **Task 4 — State Machine de base (idle / work)** (AC: #2)
  - [x] `scripts/agents/states/state_machine.gd` + `state.gd` (classe `State` de base) — pattern « un nœud `State` par état » sous un `StateMachine`.
  - [x] États requis pour cette story : `idle`, `work`, plus la prise en charge du **déplacement** (état `move`/`walk` OU mouvement piloté depuis idle→work — au choix, voir Dev Notes). Architecture cible aussi `confer/queue/fatigue/burnout` : **ne PAS** les implémenter ici (Épic 2), mais structurer la SM pour les accueillir sans refonte.
  - [x] La SM consomme l'`AgentAction` retournée par le `BrainComponent` pour décider des transitions.
- [x] **Task 5 — Scène agent + pathfinding obstacle-aware** (AC: #1, #2)
  - [x] `scenes/agents/agent.tscn` + `scripts/agents/agent.gd` (`class_name Agent`) : racine `CharacterBody3D`, enfants `MeshInstance3D` (capsule/box placeholder — DA réelle en Épic 6), `NavigationAgent3D`, `BrainComponent`, `StateMachine`.
  - [x] Pathfinding via **`NavigationServer3D`** : ajouter une `NavigationRegion3D` dans `open_space.tscn` avec un `NavigationMesh` couvrant le plateau 12×12 ; l'agent navigue avec `NavigationAgent3D` (`set_target_position` / `get_next_path_position`).
  - [x] **Obstacle-aware par conception** : même sans mobilier (Épic 3), la navigation doit être bake-based pour que le mobilier futur s'intègre (re-bake du NavMesh ou `NavigationObstacle3D`). Documenter ce point d'extension. AC #2 « sans traverser le mobilier » = la voie de nav doit respecter les obstacles dès que présents.
  - [x] **Découplage rendu/sim** : le **choix de destination** (brain) se fait sur `simulation_tick` (~3 Hz) ; le **suivi du chemin** (mouvement le long du path) se fait par frame (`_physics_process`) pour rester fluide à 60 FPS. Voir Dev Notes « Découplage temporel » — c'est la clé de NFR2 + NFR1.
- [x] **Task 6 — `AgentFactory` data-driven + archétypes `.tres`** (AC: #1)
  - [x] `scripts/agents/agent_archetype.gd` (`class_name AgentArchetype extends Resource`) : champs data-driven (ex. `display_name`, `move_speed`, teinte/variation visuelle placeholder, décalage de départ du soir). Zéro magic number dans la logique.
  - [x] Créer au moins **2 archétypes** en `data/agents/*.tres` (variété visible : vitesses/teintes différentes).
  - [x] `scripts/agents/agent_factory.gd` (`class_name AgentFactory`) : lit un `AgentArchetype.tres`, instancie `agent.tscn`, configure l'agent (id unique, archétype, `BrainComponent` + `NativeBrain`) et le place sous le conteneur `Agents` de l'open space.
- [x] **Task 7 — Spawn matin / départ soir (« certains plus tôt, d'autres plus tard »)** (AC: #1, #3)
  - [x] Au jalon « matin », l'`AgentFactory` instancie N agents (N tunable `.tres`, modeste pour le petit local — ex. 4-6) à un/des point(s) d'entrée ; ils pathfindent vers une **position de poste placeholder** (cellules cibles assignées ; les vrais bureaux arrivent en Épic 3).
  - [x] À l'approche du soir, chaque agent repart vers une **sortie** puis est retiré/désactivé, avec un **décalage de départ par agent** (issu de l'archétype ou tiré dans des bornes `.tres`) → départs échelonnés.
  - [x] Ajouter un conteneur `Agents` (`Node3D`) dans `open_space.tscn` ; aucun chemin de nœud absolu (utiliser `@onready` / `%UniqueName` / signals).
- [x] **Task 8 — Perf & non-régression** (AC: #2, #3 ; NFR1, NFR2)
  - [x] Vérifier 60 FPS avec l'open space peuplé (N agents en mouvement) via le harnais `--measure-fps` existant (cf. Story 1.1). Pas d'allocation per-frame inutile (mettre en cache `@onready`, réutiliser les buffers de path).
  - [x] Confirmer que la logique de décision tourne bien sur `simulation_tick` (~3 Hz) et non par frame (instrumenter/loguer le compte de ticks vs frames si besoin).
  - [x] Non-régression Story 1.1 : caméra (WASD/edge-pan/zoom borné), import headless **0 erreur / 0 warning**, scène open space toujours fonctionnelle.
- [x] **Task 9 — Tests** (AC: #1, #2, #3)
  - [x] **Pas de GUT** (addon non installé — cf. Story 1.1) : réutiliser le pattern de runner headless autonome (`tests/unit/*.gd extends SceneTree`, exit 0/1).
  - [x] Isoler la **logique pure testable** hors scène/autoload (comme `camera_math.gd`) : décision `NativeBrain` selon un `AgentContext` donné, `ActionRegistry.make/parse`, math de phase de journée, calcul d'heure de départ échelonnée. **Rappel critique** : en mode `--script`, les autoloads ne sont PAS chargés → la logique testée ne doit dépendre ni de `Log` ni d'aucun autoload.
  - [x] Cas couverts a minima : (a) `NativeBrain` renvoie « aller au poste » quand pas encore arrivé, « travailler » une fois au poste, « repartir » quand le signal soir est actif ; (b) phase de journée monotone 0→1 ; (c) départ échelonné distinct selon archétype.

## Dev Notes

### Contexte & objectif

Cette story **fait vivre** l'open space vide posé en Story 1.1 : des agents natifs apparaissent le matin, circulent par pathfinding vers leur poste, travaillent, puis repartent le soir. Elle pose **trois fondations architecturales majeures** réutilisées par tout le reste du projet :
1. La **boucle de simulation active** (`SimClock` émet enfin des ticks).
2. Le **Dual-Mode Agent Brain** en version native (ADR-1) — la pierre angulaire sur laquelle l'Épic 5 branchera le LLM **sans toucher au reste de l'agent**.
3. La **State Machine** d'agent et le **pathfinding** obstacle-aware.

Aucune jauge de gameplay (moral/fatigue), aucune sollicitation/pop-up, aucun HUD ici — tout cela arrive dans les stories suivantes de l'Épic 1. Rester strictement dans le périmètre : un open space **vivant mais silencieux**.
[Source: epics.md#Epic-1 / Story 1.2 ; game-architecture.md#Implementation-Patterns ; gdd.md#Core-Simulation-Systems]

### Stack technique imposée (NE PAS dévier)

- **Moteur : Godot 4.6.3-stable**, **GDScript typé statiquement** (warning `untyped_declaration=1` déjà actif → tout le code typé). [Source: game-architecture.md#Selected-Engine ; #Decision-Summary D10]
- **Vrai 3D + caméra orthographique (Forward+)** déjà en place — les agents sont des nœuds 3D dans cette scène. [Source: game-architecture.md#Decision-Summary D12]
- **Pathfinding = `NavigationServer3D`** (API native Godot 4.6 : `NavigationRegion3D` + `NavigationMesh` baké, `NavigationAgent3D` sur l'agent). Aucune lib externe. [Source: game-architecture.md (Pathfinding + rendu iso) ; epics.md FR2]
- **Données data-driven en Resources `.tres`** (archétypes d'agents) ; valeurs d'équilibrage isolées dans `data/balance/*.tres`. **Zéro magic number** dans la logique. [Source: game-architecture.md#Decision-Summary D6 ; #Configuration]

### ⚠️ Apprentissages critiques de la Story 1.1 (à respecter absolument)

- **L'autoload du logger s'appelle `Log`, PAS `Logger`** (`Logger` est une classe native de Godot 4.6 → collision de compilation). Utiliser **`Log.info/warn/error/debug`** partout. [Source: 1-1….md#Completion-Notes — Déviation 1]
- **Les autoloads n'ont PAS de `class_name`** (évite le conflit « nom d'autoload ↔ classe globale »). On y accède par leur nom de singleton (`EventBus`, `SimClock`, `GameManager`, `ConfigService`, `Log`). Les extraits d'archi montrant `class_name EventBus` étaient **illustratifs**. [Source: 1-1….md#Completion-Notes — Déviation 2]
- **GUT n'est pas installé** (pas d'accès réseau fiable). Utiliser le **runner headless autonome** (`tests/unit/*.gd extends SceneTree`, `quit(0/1)`), portable vers GUT plus tard. [Source: 1-1….md#Completion-Notes — Déviation 4 ; `tests/unit/test_camera_math.gd`]
- **En mode `--script`, les autoloads ne sont pas chargés** → toute logique testable doit être **isolée en fonctions/classes pures sans dépendance autoload** (modèle `scripts/world/camera_math.gd` → `class_name CameraMath extends RefCounted`). Appliquer le même découpage à la logique de décision des agents. [Source: 1-1….md#Completion-Notes — Refactor testabilité]
- **Pas de VCS** : `git` non installé, `baseline_commit=NO_VCS`. Valider par **import + exécution headless réels**, pas seulement en écrivant le code. [Source: 1-1….md#Debug-Log-References]
- **Mesure FPS** : harnais `main.gd --measure-fps` déjà présent (la 1re mesure peut être faussée par le throttle de fenêtre en arrière-plan ; mesurer fenêtre au premier plan, vsync off pour la capacité brute). [Source: 1-1….md#Completion-Notes — AC #3]

### Découplage temporel (le cœur de NFR2 + NFR1)

Deux horloges distinctes, à ne pas mélanger :
- **`SimClock` ~3 Hz** → **décisions** (le brain choisit la destination, l'état). Basse fréquence = perf + prépare l'async LLM (un agent LLM « réfléchit » sur plusieurs ticks sans bloquer). [Source: game-architecture.md#ADR-3 ; #Decision-Summary D3]
- **`_physics_process` (60 FPS)** → **mouvement** (suivre le chemin renvoyé par `NavigationAgent3D`, interpoler la position). Fluide à l'écran sans recalculer une décision par frame.

Pattern recommandé : l'agent s'abonne à `SimClock.simulation_tick` → construit un `AgentContext` → `brain_component.tick(ctx)` → applique l'`AgentAction` (ex. fixe `navigation_agent.target_position`). Entre deux ticks, `_physics_process` consomme le chemin et déplace le `CharacterBody3D`.

### Frontière avec la Story 1.3 (éviter le double travail)

Story 1.3 = **Horloge de jeu pausable & journées ouvrées** (Espace = pause, 1/2/3 = vitesses, compteur de jours, durée ~5 min tunable). Cette story 1.2 doit poser le **strict minimum** temporel pour faire vivre les agents, sans empiéter :
- **1.2 fait** : activer l'émission de `simulation_tick` ; une phase de journée matin→soir minimale ; spawn/départ.
- **1.3 fera** : pause (gel agents + jauges), vitesses x1/x2/x3 (mise à l'échelle du temps), compteur de jours, `EventBus.day_ended`, durée de journée définitive.
- **Conception** : garder `SimClock` agnostique (il émet un tick ; la mise à l'échelle vitesse/pause s'ajoutera dans `_process` en 1.3). Garder la phase de journée pilotée par le tick, pour que 1.3 puisse remplacer la source de temps sans réécrire les agents. **Ne pas** mapper Espace/1/2/3 (réservés 1.3).
[Source: epics.md#Epic-1 / Story 1.3 ; sim_clock.gd (stub TODO Story 1.3)]

### Architecture compliance — frontières à respecter

- **Communication via `EventBus`** (signals typés, snake_case au passé) ; **jamais** d'appels directs en dur entre systèmes. Un agent ne connaît pas le `DayCycle`/`GameManager` en dur → il écoute des signals (`day_started`, `evening_approaching`). [Source: game-architecture.md#Architectural-Boundaries ; #Event-System]
- **Jamais de chemins de nœuds absolus** — `@onready`, `%UniqueName`, ou signals uniquement. [Source: game-architecture.md#Architectural-Boundaries]
- **Toute action d'agent passe par `ActionRegistry`** — aucune action codée en dur dans un brain (règle d'or de parité natif ↔ LLM). [Source: game-architecture.md#Consistency-Rules ; #Novel-Pattern]
- **`AgentFactory`** lit l'archétype `.tres` et configure l'agent instancié (pattern Entity Patterns ; pas d'object pooling en v1). [Source: game-architecture.md#Entity-Patterns]
- **State Machine** : un nœud `State` par état sous un `StateMachine`. [Source: game-architecture.md#State-Patterns ; #Decision-Summary D5]
- **Équilibrage en `data/balance/*.tres`** ; les valeurs purement techniques (ex. tolérances de nav) peuvent rester en `const`. [Source: game-architecture.md#Configuration]

### Parité & async (préparer l'Épic 5 sans le construire)

L'archi montre `BrainComponent.tick()` avec `await _brain.decide(ctx)` car `LLMBrain` sera **asynchrone**. Pour cette story (NativeBrain seul, **synchrone et instantané**) :
- Garder l'interface `decide(ctx) -> AgentAction`. Le `NativeBrain` renvoie immédiatement.
- Concevoir `BrainComponent.tick()` pour qu'on puisse y introduire `await` en Épic 5 **sans changer les appelants** (l'Épic 5 ajoutera `LLMBrain`, `connect_llm()`/`disconnect_llm()`, le fallback natif et l'`ActionRegistry.schema()`/`parse(raw)`).
- **Ne pas** créer de stub LLM, ni de signal LLM, ni de dépendance à `LLMService` ici. [Source: game-architecture.md#Novel-Pattern ; ADR-1 ; epics.md Story 5.3]

### Structure de fichiers (créer conforme — extrait pertinent)

```
open_space/
├── scenes/
│   ├── world/open_space.tscn        # UPDATE : + NavigationRegion3D + conteneur Agents
│   └── agents/agent.tscn            # NEW : CharacterBody3D + Mesh + NavAgent3D + BrainComponent + StateMachine
├── scripts/
│   ├── autoloads/
│   │   ├── sim_clock.gd             # UPDATE : émet simulation_tick, running=true
│   │   ├── event_bus.gd             # UPDATE (si besoin) : + signals agent/journée
│   │   └── game_manager.gd          # UPDATE (option) : day_phase / start()
│   ├── agents/
│   │   ├── agent.gd                 # NEW (class_name Agent)
│   │   ├── agent_factory.gd         # NEW (class_name AgentFactory)
│   │   ├── agent_archetype.gd       # NEW (class_name AgentArchetype extends Resource)
│   │   ├── brain/                   # NEW : agent_brain, native_brain, agent_context, agent_action, brain_component
│   │   ├── tools/action_registry.gd # NEW (class_name ActionRegistry)
│   │   └── states/                  # NEW : state_machine, state, idle, work (+ move)
│   └── world/open_space.gd          # UPDATE : exposer/baker la nav, conteneur Agents
├── data/
│   ├── agents/*.tres                # NEW : ≥2 archétypes
│   └── balance/*.tres               # NEW : N agents, durée de journée, bornes de départ
└── tests/unit/*.gd                  # NEW : tests headless (brain, phase, départ)
```
[Source: game-architecture.md#Directory-Structure ; #System-Location-Mapping]

### Conventions de nommage (rappel obligatoire)

`snake_case` fichiers/dossiers · `PascalCase` `class_name` · `snake_case` fonctions/vars · `UPPER_SNAKE` constantes · **signals `snake_case` au passé**. [Source: game-architecture.md#Naming-Conventions]

### Lecture des fichiers UPDATE (état actuel à préserver)

- **`scripts/autoloads/sim_clock.gd`** — aujourd'hui : `TICK_HZ=3.0`, accumulateur prêt, `running=false`, boucle `_process` avec un `TODO(Story 1.3)` à l'endroit exact où émettre le tick. **À changer** : remplacer le `pass`/TODO par l'émission `simulation_tick`, activer `running`. **À préserver** : la constante `TICK_HZ`, le découplage rendu, l'esprit « SimClock ne porte aucune logique métier ».
- **`scripts/autoloads/event_bus.gd`** — aujourd'hui : 4 signals (`agent_burned_out`, `decision_resolved`, `llm_call_failed`, `day_ended`). **À préserver** : ces 4 signals. **À ajouter (si nécessaire)** : signals de cette story (ex. `day_started`, `evening_approaching`, `agent_spawned`, `agent_departed`) en respectant snake_case/passé. N'ajouter que ce qui est réellement émis.
- **`scripts/autoloads/game_manager.gd`** — aujourd'hui : stub vide (conteneur d'état). Peut accueillir la phase de journée minimale et/ou `start()`. Garder léger ; 1.3 l'étoffera.
- **`scenes/world/open_space.tscn` + `scripts/world/open_space.gd`** — aujourd'hui : `OpenSpace (Node3D)` → `GridMap`, `WorldEnvironment`, `DirectionalLight3D`, `CameraRig/Camera3D`. `open_space.gd` construit le sol 12×12 (cellule 2 m) via MeshLibrary runtime. **À ajouter** : `NavigationRegion3D` (NavMesh baké sur le plateau) + conteneur `Agents (Node3D)`. **À préserver** : construction du sol, caméra, lumière, environnement — non-régression Story 1.1.
[Source: lecture directe des fichiers `open_space/…` ; 1-1….md#File-List]

> **Important** : une story doit laisser le système **fonctionnel de bout en bout**. Au-delà des AC, la caméra et l'open space de la Story 1.1 doivent rester pleinement opérationnels après cette story.

### Pathfinding Godot 4.6 — notes d'implémentation

- `NavigationRegion3D` avec une `NavigationMesh` bakée couvrant le sol 12×12 (le sol est plat → bake simple). `NavigationAgent3D` sur l'agent : `target_position` fixée par le brain ; suivre via `get_next_path_position()` dans `_physics_process`, déplacer le `CharacterBody3D` (mouvement kinématique, pas de physique temps réel — cohérent « physique peu sollicitée »).
- **Extension mobilier (Épic 3)** : le mobilier deviendra obstacle via re-bake du NavMesh ou `NavigationObstacle3D`. Concevoir la nav pour que ce branchement soit trivial (documenter dans le code). AC #2 « sans traverser le mobilier » est satisfaite par construction dès qu'un obstacle existe.
- La navigation s'initialise sur le 1er `physics_frame` : attendre `await get_tree().physics_frame` avant de fixer une 1re cible si nécessaire (piège classique Godot 4 : carte de nav pas encore prête au `_ready`).
[Source: game-architecture.md (Pathfinding) ; epics.md FR2 ; Story 3.3 pour le mobilier]

### Direction artistique (minimale ici)

Agents = **placeholders** lisibles (capsule/box teintée selon l'archétype) ; les modèles 3D, variations et animations réelles sont l'**Épic 6** (Story 6.2). Ne pas sur-investir l'art ; viser la lisibilité (NFR7) et la variété minimale (vitesses/teintes distinctes). [Source: gdd.md#Art-Style ; epics.md#Epic-6 / Story 6.2]

### Performance (AC #2/#3 ; NFR1/NFR2)

- Cible **60 FPS** open space peuplé (petit local → N modeste). Décisions sur `simulation_tick` (~3 Hz), mouvement par frame. Pas d'allocation per-frame inutile (cache `@onready`, réutiliser les buffers de path). [Source: gdd.md#Performance-Requirements ; NFR1/NFR2]
- Pas d'object pooling en v1 (effectifs modestes) — instanciation/destruction directe via `AgentFactory`. [Source: game-architecture.md#Entity-Patterns]

### Tests (sans GUT)

- Runner headless `extends SceneTree` (modèle `test_camera_math.gd`), `quit(0/1)`, lancé par `godot --headless --path open_space --script res://tests/unit/<fichier>.gd`.
- Cibler les **fonctions pures** : décision `NativeBrain(ctx)`, `ActionRegistry.make/parse`, math de phase de journée, calcul de départ échelonné. Garder ces calculs **hors autoload/scène** pour la testabilité (le brain natif doit être instanciable et interrogeable sans arbre de scène ni `Log`).
[Source: 1-1….md (pattern de test) ; game-architecture.md#Directory-Structure]

### Project Structure Notes

- Alignement direct sur la structure hybride de l'architecture (`scripts/agents/{brain,tools,states}`, `scenes/agents/`, `data/agents`, `data/balance`). Aucune variance attendue : on suit l'archi à la lettre.
- Seuls ajouts « de confort » cohérents avec le pattern hybride : conteneur `Agents` dans la scène monde et, éventuellement, un petit `DayCycle` si on préfère ne pas charger `GameManager` (décision du dev — garder minimal et signal-driven).

### Project Context Rules

- _Aucun `project-context.md` présent dans le dépôt._ Les règles projet applicables proviennent donc de l'architecture et sont déjà listées ci-dessus : `EventBus`-only, pas de chemins absolus, `ActionRegistry` source unique, `.tres` pour l'équilibrage, GDScript typé, autoload `Log` (pas `Logger`), pas de `class_name` sur les autoloads.
- **Outillage MCP** (Gopeak Godot MCP + Context7) prévu par l'archi pour le dev assisté IA — **non bloquant** ici (à configurer si disponible ; vérifier l'activité des repos avant install). [Source: game-architecture.md#AI-Development-Tooling ; #Development-Environment]

### References

- [Source: epics.md#Epic-1 / Story 1.2] — AC complets (spawn/`AgentFactory`/`BrainComponent`+`NativeBrain`, pathfinding sans traverser le mobilier, SM idle/work, départ échelonné, basse fréquence `SimClock`/NFR2).
- [Source: epics.md#Epic-1 / Story 1.3] — frontière temporelle (pause/vitesses/jours) à NE PAS implémenter ici.
- [Source: epics.md FR1, FR2] — open space iso + agents natifs (spawn, pathfinding, arrivée/départ).
- [Source: game-architecture.md#Architectural-Decisions] — D3 (`SimClock` ~3 Hz), D5 (State Machine), D6 (`.tres`), D10 (GDScript typé), D12 (3D ortho).
- [Source: game-architecture.md#ADR-1 ; #Novel-Pattern] — Dual-Mode Agent Brain : `AgentBrain`/`NativeBrain`/`BrainComponent`/`ActionRegistry` (fondation à poser ici, LLM en Épic 5).
- [Source: game-architecture.md#ADR-3] — découplage `SimClock`/rendu.
- [Source: game-architecture.md#Project-Structure ; #System-Location-Mapping ; #Naming-Conventions ; #Architectural-Boundaries] — emplacements, conventions, frontières.
- [Source: game-architecture.md#Entity-Patterns ; #State-Patterns ; #Event-System ; #Configuration] — `AgentFactory`, SM, `EventBus`, couches de config.
- [Source: gdd.md#Core-Gameplay-Loop ; #Core-Simulation-Systems] — structure de journée (arrivée matin / départ soir, heures sup'/départ tôt), tick ~2-4 Hz.
- [Source: gdd.md#Art-Style ; #Performance-Requirements] — placeholders lisibles (art réel Épic 6) ; 60 FPS, sim basse fréquence.
- [Source: 1-1-fondations-du-projet-open-space-iso-navigable.md] — état du socle, autoload `Log`, pas de `class_name` autoload, pas de GUT (runner headless), pas de VCS, harnais `--measure-fps`, fonctions pures testables.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.8 (claude-opus-4-8)

### Debug Log References

- Import headless propre (0 erreur / 0 warning) : `godot --headless --path open_space --import`.
- Tests unitaires agents : `godot --headless --path open_space --script res://tests/unit/test_agent_sim.gd` → `TEST_RESULT=PASS`, 18/18.
- Non-régression Story 1.1 : `… --script res://tests/unit/test_camera_math.gd` → `TEST_RESULT=PASS`, 7/7.
- Test d'intégration de la simulation : `godot --headless --path open_space -- --sim-smoke` → `SIM_SMOKE spawned=10 departed=5 max_disp=16.54`, `SIM_SMOKE_RESULT=PASS` (journée accélérée à 30 s ; spawn matin → pathfinding vers postes → travail → départ échelonné du soir → despawn).
- Mesure FPS (open space peuplé) : `godot --path open_space -- --measure-fps` → `FPS_MEASUREMENT=453` (vsync off, iGPU Intel Iris Xe), exit 0 → bien au-delà de 60 (NFR1).
- Logs runtime sous `user://logs/session_*.log`.

### Completion Notes List

- **`SimClock` activé** : ajout du signal `simulation_tick(tick_delta)`, méthodes `start()/stop()`, émission à cadence fixe (`TICK_HZ=3.0`) dans la boucle d'accumulateur. `GameManager` le démarre au `_ready`. La pause / vitesses / journées ouvrées restent réservées à la Story 1.3 (frontière respectée).
- **Découplage rendu/sim (NFR2)** : les **décisions** des agents (NativeBrain) tombent sur `simulation_tick` (~3 Hz) ; le **mouvement** (suivi de chemin `NavigationAgent3D`) tourne par frame physique. Confirmé par le smoke test + 453 FPS peuplé (NFR1).
- **Fondation Dual-Mode Brain (ADR-1)** posée en natif : `AgentBrain`→`NativeBrain`, `BrainComponent`, `AgentContext`, `AgentAction`, et `ActionRegistry` comme source unique des actions. Aucune action codée en dur dans un brain. `BrainComponent.tick()` est prêt à accueillir `await`/`LLMBrain` en Épic 5 sans changer les appelants.
- **`GameManager` possède la durée active du jour** (`day_duration_seconds`, seedée depuis l'équilibrage) plutôt que de relire la ressource à chaque tick. Choix pris après avoir constaté un comportement de cache/timing trompeur en mutant la `.tres` partagée au runtime : faire de `GameManager` le propriétaire de l'horloge est plus net et anticipe la Story 1.3.
- **Pathfinding (Godot 4.6)** : `NavigationRegion3D` + NavMesh **baké au runtime** depuis une géométrie source plate (`NavigationMeshSourceGeometryData3D` + `bake_from_source_geometry_data`) → déterministe et vérifiable headless (pas de bake d'éditeur). Le mobilier (Épic 3) viendra carver des obstacles (re-bake / `NavigationObstacle3D`).
- **Pièges NavigationAgent3D résolus** (documentés dans le code) : (1) la 1re requête de chemin part à vide si elle précède la synchro de la carte de nav → l'agent attend 2 `physics_frame` avant sa 1re décision ; (2) le NavMesh baké se place ~0.5 m au-dessus du plan des cibles, donc `is_navigation_finished()` ne se déclenche jamais de façon fiable → l'**arrivée est jugée sur la distance horizontale** à la cible (`get_next_path_position` ne sert qu'au pilotage) ; (3) `motion_mode = FLOATING` (agent top-down, pas de gravité/sol).
- **Anti-empilement** : chaque agent reçoit un **créneau de porte** distinct (étalement à l'entrée ET à la sortie) ; sans cela, les agents visant le même point d'entrée/sortie se bloquent par collision.
- **Carryovers Story 1.1 respectés** : autoload `Log` (jamais `Logger`), autoloads sans `class_name`, pas de GUT (runner headless `extends SceneTree`), logique pure isolée pour la testabilité en `--script` (`day_phase_math.gd`, brain), pas de VCS (`baseline_commit=NO_VCS`).
- **Équilibrage** : `data/balance/sim_balance.tres` (durée de jour 45 s, seuil du soir 0.6, 5 agents) + 2 archétypes `data/agents/*.tres` (vitesses, teintes, décalage de départ distincts → variété + départs échelonnés). L'offset « heures sup » a été ramené à 0.15 pour que la cohorte du jour ait la marge de rejoindre la sortie avant la bascule de journée.
- **Hors périmètre (volontaire)** : aucune jauge moral/fatigue, aucune sollicitation/pop-up/HUD, aucune fiche agent, aucun stub LLM. Conforme au séquençage de l'Épic 1.
- **Harnais de test** : `--sim-smoke` ajouté à `main.gd` (même esprit que `--measure-fps` de la Story 1.1) pour valider la boucle complète en headless ; il accélère la journée via `GameManager.day_duration_seconds`.

### File List

**Nouveaux fichiers (sous `open_space/`) :**
- `scripts/agents/brain/agent_action.gd` (`class_name AgentAction`)
- `scripts/agents/tools/action_registry.gd` (`class_name ActionRegistry`)
- `scripts/agents/brain/agent_context.gd` (`class_name AgentContext`)
- `scripts/agents/brain/agent_brain.gd` (`class_name AgentBrain`)
- `scripts/agents/brain/native_brain.gd` (`class_name NativeBrain`)
- `scripts/agents/brain/brain_component.gd` (`class_name BrainComponent`)
- `scripts/agents/day_phase_math.gd` (`class_name DayPhaseMath` — fonctions pures)
- `scripts/agents/agent.gd` (`class_name Agent`)
- `scripts/agents/agent_factory.gd` (`class_name AgentFactory`)
- `scripts/agents/agent_archetype.gd` (`class_name AgentArchetype extends Resource`)
- `scripts/agents/states/state.gd` (`class_name AgentState`)
- `scripts/agents/states/state_machine.gd` (`class_name AgentStateMachine`)
- `scripts/agents/states/idle_state.gd` (`class_name AgentIdleState`)
- `scripts/agents/states/work_state.gd` (`class_name AgentWorkState`)
- `scripts/agents/states/move_state.gd` (`class_name AgentMoveState`)
- `scripts/systems/sim_balance.gd` (`class_name SimBalance extends Resource`)
- `scripts/world/agent_spawner.gd` (spawn matin / nettoyage de journée)
- `scenes/agents/agent.tscn`
- `data/agents/archetype_steady.tres`, `data/agents/archetype_overtimer.tres`
- `data/balance/sim_balance.tres`
- `tests/unit/test_agent_sim.gd` (runner headless, 18 tests)

**Fichiers modifiés :**
- `scripts/autoloads/sim_clock.gd` (émission `simulation_tick`, `start()/stop()`, `running=true`)
- `scripts/autoloads/event_bus.gd` (signals `day_started`, `agent_spawned`, `agent_departed`)
- `scripts/autoloads/game_manager.gd` (cycle de journée minimal : `day_phase`/`day_count`/`day_duration_seconds`, démarre `SimClock`)
- `scripts/world/open_space.gd` (NavMesh runtime + helpers géométrie : `cell_to_world`, `entrance_world`, `post_world_positions`)
- `scenes/world/open_space.tscn` (`NavigationRegion3D`, conteneur `Agents`, `AgentSpawner`)
- `scripts/main/main.gd` (harnais `--sim-smoke` ; libellé FPS « peuplé »)

> Note d'écart au plan : le registre d'actions a été placé sous `scripts/agents/tools/` (conforme à l'archi `scripts/agents/tools/`) et non `brain/`, comme prévu par la structure cible.

## Change Log

| Date | Version | Description |
|---|---|---|
| 2026-06-21 | 0.2.0 | Implémentation Story 1.2 : `SimClock` actif (`simulation_tick` ~3 Hz) ; cycle de journée minimal (`GameManager`) ; fondation Dual-Mode Brain native (`AgentBrain`/`NativeBrain`/`BrainComponent`/`AgentContext`/`AgentAction`/`ActionRegistry`) ; State Machine idle/work/move ; agents `CharacterBody3D` + pathfinding `NavigationServer3D` (NavMesh baké runtime) ; `AgentFactory` + 2 archétypes `.tres` ; spawn matin / départ échelonné du soir. Tests : 18/18 unitaires agents + 7/7 régression caméra + smoke d'intégration PASS (5 spawn / 5 départs) ; 453 FPS peuplé (NFR1). Statut → review. |
