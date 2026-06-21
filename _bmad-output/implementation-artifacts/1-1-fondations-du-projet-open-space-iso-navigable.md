---
baseline_commit: NO_VCS
---

# Story 1.1: Fondations du projet & open space iso navigable

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a joueur,
I want un open space 3D isométrique que je peux explorer librement à la caméra,
so that je vois l'espace de ma boîte avant même qu'il se peuple.

## Acceptance Criteria

1. **Given** le projet Godot 4.6.3 est créé selon la structure de dossiers définie (autoloads stubs `EventBus`, `SimClock`, `GameManager`, `Logger`, `ConfigService` posés) **When** je lance le jeu **Then** une scène open space en vrai 3D + caméra orthographique (Forward+) s'affiche sur une grille (`GridMap`).
2. **Given** la scène open space est affichée **When** je déplace la souris au bord de l'écran ou utilise WASD **Then** la caméra se déplace **And** la molette zoome/dézoome dans des bornes min/max.
3. **Given** le jeu tourne avec l'open space vide **When** je mesure la perf sur PC milieu de gamme **Then** il tient 60 FPS (NFR1).

## Tasks / Subtasks

- [x] **Task 1 — Créer le projet Godot 4.6.3-stable `open_space/` from scratch** (AC: #1)
  - [x] Créer le projet avec le renderer **Forward+** — `project.godot` : `rendering/renderer/rendering_method="forward_plus"` + `config/features=("4.6","Forward Plus")`.
  - [x] Activer le **typage statique GDScript** — warning `gdscript/warnings/untyped_declaration=1` ; tout le code est typé.
  - [x] Créer l'arborescence de dossiers conforme (scenes/, scripts/{autoloads,world,main,utils}, data/{balance,agents,contracts,furniture}, assets/, tests/{unit,integration}) ; dossiers vides marqués `.gdkeep`.
  - [x] `.gitignore` Godot standard créé (`.godot/`, builds, exports). _(Note : `git` non installé sur la machine → pas de repo init ; `baseline_commit=NO_VCS`.)_
- [x] **Task 2 — Poser les autoloads stubs de base** (AC: #1)
  - [x] `scripts/autoloads/event_bus.gd` — 4 signals typés au passé (`agent_burned_out`, `decision_resolved`, `llm_call_failed`, `day_ended`).
  - [x] `scripts/autoloads/sim_clock.gd` — stub : `TICK_HZ=3.0`, accumulateur prêt, inactif (`running=false`) ; ticks en Story 1.3.
  - [x] `scripts/autoloads/game_manager.gd` — stub conteneur d'état global.
  - [x] `scripts/autoloads/logger.gd` — niveaux ERROR/WARN/INFO/DEBUG, console + `user://logs/session_*.log`, DEBUG no-op en release.
  - [x] `scripts/autoloads/config_service.gd` — get/set/save sur `user://settings.cfg` (ConfigFile).
  - [x] 5 autoloads enregistrés dans `project.godot` (ordre `Log`, `EventBus`, `ConfigService`, `GameManager`, `SimClock`). _(Déviation : autoload du logger nommé `Log` et non `Logger` — `Logger` est une **classe native Godot 4.6** ; collision confirmée via `ClassDB.class_exists("Logger")==true`. Voir Completion Notes.)_
- [x] **Task 3 — Scène boot → open space** (AC: #1)
  - [x] `scenes/main/main.tscn` (+ `scripts/main/main.gd`) = scène principale (`run/main_scene`), instancie l'open space.
  - [x] `scenes/world/open_space.tscn` : racine `Node3D` + `GridMap` + `CameraRig`/`Camera3D` ortho + `DirectionalLight3D` + `WorldEnvironment`.
- [x] **Task 4 — GridMap + sol de référence** (AC: #1)
  - [x] `GridMap` avec `MeshLibrary` générée au runtime (1 tuile de sol `BoxMesh` + `StandardMaterial3D` teinte aseptisée). _(Choix : génération runtime plutôt que `.meshlib` binaire d'éditeur → robuste, versionnable, vérifiable headless.)_
  - [x] Plateau de départ « petit local » 12×12 cellules (cellule 2 m), cohérent avec l'agrandissement futur (Story 3.5).
- [x] **Task 5 — Caméra orthographique isométrique** (AC: #1, #2)
  - [x] `Camera3D` `PROJECTION_ORTHOGONAL`, posée en angle iso (offset (20,20,20) → `look_at` du pivot), `size` ortho réglée (16, bornée).
  - [x] `scripts/world/camera_controller.gd` sur un rig `Node3D` pivot + `Camera3D` enfant (pan = pivot, zoom = `size`).
- [x] **Task 6 — Contrôles caméra (déplacement + zoom)** (AC: #2)
  - [x] Actions Input Map : `cam_up/down/left/right` (physical W/A/S/D), `cam_zoom_in/out` (molette 4/5) ; aucune touche codée en dur dans la logique.
  - [x] Pan par **WASD** + **bord d'écran** (edge-pan, marge 16 px), vitesse en `const`.
  - [x] **Zoom molette** via `Camera3D.size`, borné `MIN_ZOOM=4`/`MAX_ZOOM=30` (`CameraMath.clamp_zoom`).
  - [x] Pan borné (`PAN_MIN`/`PAN_MAX` → `CameraMath.clamp_pan`).
- [x] **Task 7 — Validation 60 FPS** (AC: #3)
  - [x] Mesuré via `main.gd --measure-fps` (run windowed, échantillon à 3 s). Open space vide, vsync off : **438 FPS** sur Intel Iris Xe (iGPU) → très au-dessus de 60 (NFR1). Voir Completion Notes.
  - [x] Pas d'allocation per-frame inutile dans `camera_controller.gd` ; `_camera` mis en cache `@onready`.
- [x] **Task 8 — Tests** (AC: #2)
  - [x] _(Déviation : GUT non installé — addon non récupérable hors-ligne dans cet environnement.)_ À la place : runner de tests headless autonome `tests/unit/test_camera_math.gd` (exécutable via `godot --headless --script`, exit 0/1), portable vers GUT plus tard.
  - [x] Tests du **clamp du zoom** (dans bornes, borné min, borné max) — fonctions pures `CameraMath.clamp_zoom`.
  - [x] Tests du **clamp du pan** (chaque axe borné + passthrough dans les bornes) — `CameraMath.clamp_pan`. **7/7 verts.**

## Dev Notes

### Contexte & objectif

Story **fondatrice** de tout le projet (greenfield, **aucun starter template**). Elle pose le squelette Godot, les autoloads de base et un open space iso navigable **vide**. Aucun agent, aucune jauge, aucune simulation de gameplay ici — tout cela arrive dans les stories suivantes de l'Épic 1. L'objectif est un socle propre et conforme à l'architecture pour que les agents IA de dev des stories suivantes ne « réinventent » pas la structure.
[Source: epics.md#Epic-1 / Story 1.1 ; architecture-OpenSpAIce-2026-06-20/game-architecture.md#Development-Environment]

### Stack technique imposée (NE PAS dévier)

- **Moteur : Godot 4.6.3-stable** (PAS 4.7 — choix prudence explicite). [Source: game-architecture.md#Selected-Engine]
- **Langage : GDScript typé statiquement** (D10). [Source: game-architecture.md#Decision-Summary]
- **Rendu : vrai 3D + caméra orthographique, renderer Forward+** (D12) — c'est ce qui donne le look *Severance* + permet `GridMap`/zoom. PAS de pseudo-iso 2D. [Source: game-architecture.md#Decision-Summary D12]
- **Grille : `GridMap` (3D)** pour le placement snap (D8). [Source: game-architecture.md#Decision-Summary D8]
- **UI plus tard : Control nodes + `CanvasLayer`** (D9) — pas d'UI dans cette story hormis un éventuel overlay FPS debug.

### Structure de fichiers (créer conforme — extrait pertinent pour cette story)

```
open_space/
├── project.godot
├── addons/                      # GUT (tests) ; GoPeak MCP / GodotSteam plus tard
├── assets/                      # (vide à ce stade — modèles plus tard)
├── scenes/
│   ├── main/                    # main.tscn (scène principale), boot
│   └── world/                   # open_space.tscn, grille, caméra ortho
├── scripts/
│   ├── autoloads/               # event_bus, sim_clock, game_manager, logger, config_service
│   ├── world/                   # camera_controller.gd  (ajout cohérent avec le pattern hybride)
│   └── utils/
├── data/balance/                # (vide à ce stade)
└── tests/{unit,integration}/    # GUT
```
> Le dossier `scripts/world/` n'est pas listé explicitement dans l'archi mais respecte le pattern hybride (types racine, features dedans) ; il regroupe la logique de la feature « world/open space ». [Source: game-architecture.md#Directory-Structure ; #Organization-Pattern]

### Conventions de nommage (obligatoires)

| Élément | Convention | Exemple |
|---|---|---|
| Fichiers/dossiers | `snake_case` | `camera_controller.gd` |
| Classes (`class_name`) | `PascalCase` | `CameraController` |
| Fonctions/variables | `snake_case` | `apply_zoom` |
| Constantes | `UPPER_SNAKE` | `MAX_ZOOM` |
| Signals | `snake_case` au passé | `day_ended` |
[Source: game-architecture.md#Naming-Conventions]

### Frontières architecturales (à respecter dès maintenant)

- **Jamais de chemins de nœuds absolus** — utiliser `@onready`, `%UniqueName`, ou signals uniquement. [Source: game-architecture.md#Architectural-Boundaries]
- Les systèmes communiquent via **`EventBus`** (signals), pas d'appels directs en dur entre systèmes. (Peu de signals à émettre dans cette story, mais poser le réflexe.) [Source: game-architecture.md#Architectural-Boundaries]
- **Valeurs d'équilibrage** dans `data/balance/*.tres`, jamais codées en dur dans la logique métier. Pour cette story, vitesse de pan / bornes de zoom peuvent rester en `const` (config purement technique de contrôle, pas de l'équilibrage gameplay) — voir couche « Constantes » de la config. [Source: game-architecture.md#Configuration]

### Logging (implémenter le `Logger` proprement, pas juste un stub)

- Niveaux **ERROR / WARN / INFO / DEBUG** ; DEBUG désactivé en release. Destination : console + `user://logs/`. [Source: game-architecture.md#Logging]
- Exemple d'API attendue par le reste du code :
```gdscript
Logger.info("Open space initialisé")
```

### Event System (poser le stub conforme)

```gdscript
# scripts/autoloads/event_bus.gd
class_name EventBus
extends Node

signal agent_burned_out(agent_id: int)
signal decision_resolved(decision_id: int, outcome: int)
signal llm_call_failed(agent_id: int, reason: String)
signal day_ended(day: int)
```
[Source: game-architecture.md#Event-System]

### Caméra & contrôles (détails issus du GDD)

- **Souris-centré, clavier en raccourcis.** Caméra : **déplacement bord d'écran / WASD**, **zoom molette** sur l'open space iso. [Source: gdd.md#Controls-and-Input]
- Raccourcis réservés pour plus tard (NE PAS mapper sur la caméra) : **Espace = pause**, **1/2/3 = vitesses** (Story 1.3). Définir éventuellement les actions dans l'Input Map dès maintenant, mais sans logique.
- Implémentation recommandée : **rig pivot** (`Node3D`) + `Camera3D` ortho enfant. Pan = bouger le pivot ; zoom = modifier `Camera3D.size` (orthographique) avec `clamp(size, MIN_ZOOM, MAX_ZOOM)`.

### Direction artistique (cible, mais minimale ici)

DA *Severance* : palette froide/aseptisée (blancs, teals, beiges corporate), éclairage fluorescent, mobilier épuré — **le polish DA complet est l'Épic 6**. Ici, un sol/plateau neutre et un éclairage de base lisibles suffisent ; ne pas sur-investir l'art. [Source: gdd.md#Art-Style ; epics.md#Epic-6]

### Performance (AC #3)

- Cible **60 FPS** PC milieu de gamme, open space peuplé (ici : **vide**, donc marge confortable). [Source: gdd.md#Performance-Requirements ; NFR1]
- La sim agents tournera à ~2-4 Hz découplée du rendu (`SimClock` ~3 Hz) — **pas encore actif** dans cette story, mais le stub `SimClock` prépare ce découplage. [Source: game-architecture.md#Decision-Summary D3]

### Tests

- Framework : **GUT** (Godot Unit Test), dossier `tests/unit` + `tests/integration`. [Source: game-architecture.md#Directory-Structure]
- Cette story est surtout structurelle/visuelle ; cibler les **fonctions pures testables** (clamp du zoom, clamp des bornes de pan) plutôt que des tests de rendu. Garder ces calculs extractibles en fonctions pures pour la testabilité.

### Project Structure Notes

- Alignement direct sur la structure hybride de l'architecture. Seul ajout : `scripts/world/` pour la logique caméra/monde (cohérent avec le pattern « features à l'intérieur des types »).
- Aucune variance/conflit détecté : projet greenfield, on suit l'archi à la lettre.

### References

- [Source: epics.md#Epic-1] — Story 1.1, AC complets, séquençage « natif d'abord », gate NFR10.
- [Source: game-architecture.md#Engine-&-Framework] — Godot 4.6.3-stable, Forward+, GDScript typé.
- [Source: game-architecture.md#Architectural-Decisions] — D3 (SimClock), D8 (GridMap), D9 (UI), D10 (GDScript), D12 (3D ortho Forward+).
- [Source: game-architecture.md#Project-Structure] — arborescence, mapping systèmes, conventions de nommage, frontières.
- [Source: game-architecture.md#Cross-cutting-Concerns] — Logging, Event System, Configuration.
- [Source: game-architecture.md#Development-Environment] — First Steps (créer projet → autoloads → MCP → Épic 1).
- [Source: gdd.md#Controls-and-Input] — caméra WASD/bord d'écran, zoom molette ; raccourcis réservés Espace/1-2-3.
- [Source: gdd.md#Art-Style] — DA Severance (cible Épic 6).
- [Source: gdd.md#Performance-Requirements] — 60 FPS, sim ~2-4 Hz.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.8 (claude-opus-4-8)

### Debug Log References

- Import headless propre (0 erreur / 0 warning) : `godot --headless --path open_space --import`.
- Tests unitaires : `godot --headless --path open_space --script res://tests/unit/test_camera_math.gd` → `TEST_RESULT=PASS`, 7/7, exit 0.
- Mesure FPS : `godot --path open_space --measure-fps` → `FPS_MEASUREMENT=438` (vsync off, iGPU Intel Iris Xe), exit 0.
- Logs runtime écrits sous `user://logs/session_*.log`.

### Completion Notes List

- **Environnement** : Godot **4.6.3-stable** confirmé (`4.6.3.stable.official`). Tout le projet a été créé en texte puis **validé par import + exécution headless réels** (pas seulement écrit). `git` n'est pas installé → aucun repo, `baseline_commit=NO_VCS`.
- **Déviation 1 — autoload `Log` (et non `Logger`)** : `Logger` est une **classe native de Godot 4.6** (`ClassDB.class_exists("Logger") == true`) ; l'utiliser comme nom d'autoload provoque une erreur de compilation (`Logger.info()` résolu vers la classe native). Renommé en **`Log`** (non colisionnant, vérifié). Toutes les références utilisent `Log.info/warn/error/debug`. Le fichier reste `logger.gd`. À répercuter dans les stories suivantes.
- **Déviation 2 — autoloads sans `class_name`** : pour éviter le conflit « nom d'autoload ↔ classe globale » en Godot 4, les scripts d'autoload n'ont pas de `class_name` ; ils sont accédés via leur nom de singleton (`EventBus`, `SimClock`, etc.). L'extrait d'archi qui montrait `class_name EventBus` était illustratif.
- **Déviation 3 — MeshLibrary générée au runtime** : pas de `.meshlib` binaire d'éditeur ; `open_space.gd` construit la `MeshLibrary` (1 tuile sol) au `_ready`. Plus robuste/versionnable et vérifiable headless. Le mobilier réel viendra en Épic 3.
- **Déviation 4 — tests sans GUT** : l'addon GUT n'était pas installable (pas d'accès réseau fiable ici). Runner headless autonome à la place (`tests/unit/test_camera_math.gd`), couvrant les fonctions pures de clamp. Portable vers une suite GUT quand l'addon sera ajouté.
- **Refactor testabilité** : les fonctions pures de caméra (zoom/pan clamp) ont été isolées dans `scripts/world/camera_math.gd` (`class_name CameraMath`, `RefCounted`, zéro dépendance scène/autoload) car en mode `--script` les autoloads ne sont pas chargés et tout script dépendant de `Log` ne compile pas. `camera_controller.gd` délègue à `CameraMath`.
- **AC #3 / perf** : la 1re mesure donnait 33 FPS — artefact de **vsync/throttle fenêtre en arrière-plan**. Mesure de capacité brute (vsync off, fenêtre au premier plan) : **438 FPS** sur iGPU → marge confortable au-delà de 60 (NFR1). En jeu réel le vsync recale au refresh moniteur (≥60).
- **Hors périmètre (volontaire)** : aucun agent, jauge, simulation, UI/HUD — conformes au séquençage de l'Épic 1. `SimClock` est un stub inactif (ticks en Story 1.3) ; les raccourcis Espace/1/2/3 ne sont PAS mappés (réservés Story 1.3).

### File List

**Nouveaux fichiers (tous sous `open_space/`) :**
- `project.godot` — config projet : Forward+, 5 autoloads, Input Map caméra, fenêtre 1280×720, warning untyped.
- `.gitignore`
- `scripts/autoloads/logger.gd` (autoload `Log`)
- `scripts/autoloads/event_bus.gd` (autoload `EventBus`)
- `scripts/autoloads/sim_clock.gd` (autoload `SimClock`)
- `scripts/autoloads/game_manager.gd` (autoload `GameManager`)
- `scripts/autoloads/config_service.gd` (autoload `ConfigService`)
- `scripts/main/main.gd`
- `scripts/world/open_space.gd`
- `scripts/world/camera_controller.gd`
- `scripts/world/camera_math.gd` (`class_name CameraMath` — fonctions pures testables)
- `scenes/main/main.tscn`
- `scenes/world/open_space.tscn`
- `tests/unit/test_camera_math.gd` (runner headless, 7 tests)
- Placeholders `.gdkeep` : `assets/`, `data/{balance,agents,contracts,furniture}/`, `scripts/utils/`, `tests/integration/`

## Change Log

| Date | Version | Description |
|---|---|---|
| 2026-06-21 | 0.1.0 | Implémentation Story 1.1 : projet Godot 4.6.3 (Forward+), 5 autoloads, open space iso (GridMap + sol runtime), caméra ortho iso, contrôles WASD/edge-pan/zoom bornés, tests clamp (7/7), perf validée (438 FPS vide). Statut → review. |
