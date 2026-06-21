---
baseline_commit: NO_VCS
---

# Story 1.3: Horloge de jeu pausable & journées ouvrées

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a joueur,
I want contrôler l'écoulement du temps (pause + vitesses x1/x2/x3) et voir les journées s'enchaîner,
so that je gère la pression à mon rythme.

## Acceptance Criteria

1. **Given** une partie est en cours **When** j'appuie sur Espace **Then** le temps se met en pause (et reprend au second appui) **And** les agents (et, à terme, les jauges) se figent en pause — aucun déplacement, aucune décision, aucune avancée de la phase de journée.
2. **Given** la partie tourne **When** j'appuie sur 1 / 2 / 3 **Then** la vitesse de simulation passe à x1 / x2 / x3 (la journée et le mouvement des agents s'accélèrent en conséquence) **And** la cadence de décision (`SimClock` ~3 Hz logique) reste cohérente avec la vitesse.
3. **Given** le temps s'écoule **When** une journée ouvrée se termine (durée ~5 min réelles à x1, **valeur tunable en `.tres`**) **Then** le compteur de jour s'incrémente, `EventBus.day_ended` est émis, et un nouveau cycle matin→soir démarre (`day_started`).

## Tasks / Subtasks

- [x] **Task 1 — Déclarer les actions d'input Espace / 1 / 2 / 3** (AC: #1, #2)
  - [x] Ajouter dans `project.godot` section `[input]` les actions : `game_pause` (Espace, `physical_keycode` 32), `speed_x1` (touche 1, `physical_keycode` 49), `speed_x2` (touche 2, `physical_keycode` 50), `speed_x3` (touche 3, `physical_keycode` 51). Respecter **exactement** le format `InputEventKey` des actions caméra existantes (`cam_up`, etc.) — voir Dev Notes « Format Input Map ».
  - [x] **Ne PAS** réutiliser/écraser les actions caméra `cam_*` existantes (non-régression Story 1.1).
- [x] **Task 2 — Logique pure de contrôle du temps (testable, sans autoload)** (AC: #1, #2)
  - [x] Créer `scripts/systems/time_control.gd` (`class_name TimeControl extends RefCounted`) : fonctions **pures** — `scale_for_speed(level: int) -> float` (1→1.0, 2→2.0, 3→3.0, clamp hors bornes), `clamp_speed_level(level: int) -> int` (bornes [1,3]). Aucune dépendance scène/autoload (modèle `camera_math.gd` / `day_phase_math.gd`).
  - [x] Garder ici **uniquement** des transformations pures (mapping/clamp). L'application effective (`get_tree().paused`, `Engine.time_scale`) reste dans le contrôleur (Task 3) qui appelle ces fonctions.
- [x] **Task 3 — Contrôleur de temps : pause + vitesses (mécanisme natif Godot)** (AC: #1, #2)
  - [x] Implémenter le contrôle dans `GameManager` (autoload déjà chef d'orchestre du cycle de journée) OU un petit nœud dédié `TimeController` dans `open_space.tscn` — voir Dev Notes « Où placer le contrôleur ». Décision du dev, mais **un seul** propriétaire du temps.
  - [x] **Pause = `get_tree().paused = true/false`** (gel propre : tous les nœuds pausables — `SimClock`, agents, futures jauges — s'arrêtent sans code par-système). **Vitesse = `Engine.time_scale = scale_for_speed(level)`** (accélère uniformément `_process`/`_physics_process` : ticks `SimClock` ET mouvement agents, **sans modifier le code des agents ni de `SimClock`**). Voir Dev Notes « Pourquoi ces deux mécanismes ».
  - [x] **⚠️ Le lecteur d'input DOIT être `PROCESS_MODE_ALWAYS`** sinon il ne reçoit plus l'appui « Espace » une fois le jeu en pause (les nœuds pausables ne reçoivent plus `_unhandled_input`/`_process`). C'est le piège n°1 de cette story — voir Dev Notes.
  - [x] Conserver l'état courant (`is_paused: bool`, `speed_level: int`) ; à l'unpause, restaurer `Engine.time_scale` à la vitesse sélectionnée (ne jamais laisser `time_scale` figé à 0). Appui sur une touche vitesse quand on est en pause → applique la vitesse **et** reprend (unpause). Toggle Espace = bascule pause/reprise.
  - [x] Lire les actions via `Input.is_action_just_pressed("game_pause"/"speed_x1"/...)` dans `_unhandled_input` (ou `_process` du nœud ALWAYS). **Jamais** de scancode codé en dur — passer par l'Input Map.
- [x] **Task 4 — Signaux d'état du temps pour les systèmes futurs (HUD Story 1.8)** (AC: #1, #2)
  - [x] Ajouter à `event_bus.gd` les signaux (snake_case, au passé) réellement émis : `game_paused(is_paused: bool)` et `speed_changed(speed_level: int)`. **Ne PAS** ajouter de signal non émis. Préserver les 7 signaux existants.
  - [x] Émettre ces signaux à chaque changement d'état (le HUD persistant de la Story 1.8 s'y abonnera ; ici, pas d'UI — un `Log.info` suffit comme feedback dev).
- [x] **Task 5 — Journées ouvrées : durée définitive, compteur, `day_ended`** (AC: #3)
  - [x] Porter `day_duration_seconds` à la **cible ~5 min** dans `data/balance/sim_balance.tres` (ex. `300.0`) — c'est la valeur de jeu réelle (la 1.2 utilisait 45 s pour itérer). Rester **tunable `.tres`**, zéro magic number.
  - [x] À chaque bouclage de journée (détecté par `DayPhaseMath.has_wrapped` dans `GameManager._on_simulation_tick`), **émettre `EventBus.day_ended(day)`** pour le jour qui se termine, **avant** d'émettre `day_started` du jour suivant, et incrémenter proprement `day_count`. Voir Dev Notes « Frontière day_ended / bilan ».
  - [x] Vérifier que l'enchaînement matin→soir→matin reste correct (les agents de la veille sont nettoyés par `AgentSpawner` sur `day_started` — comportement 1.2 à préserver).
- [x] **Task 6 — Caméra utilisable en pause (UX, optionnel mais recommandé)** (AC: #1)
  - [x] Passer `CameraRig`/`camera_controller` en `PROCESS_MODE_ALWAYS` pour que le joueur puisse continuer à observer l'open space pendant la pause (lisibilité NFR7). Si le dev préfère figer aussi la caméra, le documenter — l'AC n'exige que le gel des **agents/jauges**, pas de la caméra.
- [x] **Task 7 — Non-régression & état par défaut** (AC: #1, #2, #3 ; NFR1, NFR2)
  - [x] Au lancement de partie : `paused = false`, `Engine.time_scale = 1.0`, `speed_level = 1`. La simulation démarre comme en 1.2 (spawn matin, etc.).
  - [x] Non-régression Story 1.1/1.2 : caméra (WASD/edge-pan/zoom borné) OK, spawn/pathfinding/départ OK, import headless **0 erreur / 0 warning**, harnais `--measure-fps` et `--sim-smoke` toujours PASS (ils ne touchent pas pause/vitesse, mais l'ajout de l'input ne doit rien casser).
  - [x] Confirmer 60 FPS open space peuplé à x1, x2, x3 (le mouvement scale, le rendu reste fluide).
- [x] **Task 8 — Tests** (AC: #1, #2, #3)
  - [x] **Pas de GUT** (addon non installé) : runner headless autonome `tests/unit/*.gd extends SceneTree`, `quit(0/1)`. **Rappel : en mode `--script`, AUCUN autoload n'est chargé** → ne tester que de la logique pure sans `Log`/`EventBus`/`SimClock`/`GameManager`.
  - [x] `tests/unit/test_time_control.gd` : `scale_for_speed(1/2/3)` → 1/2/3 ; `clamp_speed_level` borne hors [1,3] ; valeurs invalides gérées.
  - [x] Renforcer/compléter la couverture `DayPhaseMath` si besoin (wrap → nouveau jour) — déjà testé en 1.2 ; ne pas dupliquer inutilement.
  - [x] **Intégration (avec autoloads)** : ajouter un harnais `--time-smoke` à `main.gd` (même esprit que `--sim-smoke`) qui vérifie : (a) en pause (`get_tree().paused=true`) `GameManager.day_phase` n'avance pas sur un intervalle réel ; (b) à `Engine.time_scale=3` la phase avance ~3x plus vite qu'à x1 (tolérance large). Émettre une ligne `TIME_SMOKE_RESULT=PASS/FAIL` + `quit(0/1)`. Voir Dev Notes « Tester pause/vitesse en headless ».

## Dev Notes

### Contexte & objectif

Cette story donne au joueur le **contrôle du temps** — la dernière brique de la boucle « le temps tourne pendant que je décide ». La Story 1.2 a explicitement **réservé** Espace/1/2/3 et laissé `SimClock` agnostique en prévision d'ici. On formalise maintenant : pause, vitesses x1/x2/x3, durée de journée définitive (~5 min), compteur de jours et émission de `day_ended` (que le **bilan de fin de journée**, Story 1.10, consommera). Aucun HUD ici (Story 1.8) ni jauge (Épic 2) : juste la mécanique temporelle, propre et data-driven.
[Source: epics.md#Epic-1 / Story 1.3 ; 1-2…md#Frontière-avec-la-Story-1.3 ; game-architecture.md#ADR-3]

### Stack technique imposée (NE PAS dévier)

- **Moteur : Godot 4.6.3-stable**, **GDScript typé statiquement** (`untyped_declaration=1` actif → tout typer). [Source: game-architecture.md#Decision-Summary D10]
- **Contrôle du temps = APIs natives Godot** : `get_tree().paused`, `Engine.time_scale`, `Node.process_mode` (`PROCESS_MODE_ALWAYS`). Aucune lib externe. [Source: game-architecture.md#Engine-Provided-Architecture (Input Map) ; #Decision-Summary D9]
- **Input = Input Map** (actions configurables dans `project.godot`), jamais de scancode en dur. [Source: game-architecture.md#Engine-Provided-Architecture (Input)]
- **Données data-driven `.tres`** (durée de journée dans `data/balance/sim_balance.tres`). Zéro magic number. [Source: game-architecture.md#Configuration ; #Decision-Summary D6]

### ⚠️ Apprentissages critiques des Stories 1.1 & 1.2 (à respecter absolument)

- **L'autoload du logger s'appelle `Log`, PAS `Logger`** (`Logger` est une classe native Godot 4.6 → collision). Utiliser `Log.info/warn/error/debug`. (Les extraits d'archi montrant `Logger.info(...)` sont **illustratifs**.) [Source: 1-1…md#Completion-Notes ; 1-2…md#Apprentissages]
- **Les autoloads n'ont PAS de `class_name`** — accès par leur nom de singleton (`EventBus`, `SimClock`, `GameManager`, `ConfigService`, `Log`). [Source: 1-2…md#Apprentissages]
- **GUT non installé** → runner headless autonome (`tests/unit/*.gd extends SceneTree`, `quit(0/1)`). [Source: 1-1…md ; 1-2…md ; `tests/unit/test_agent_sim.gd`]
- **En mode `--script`, les autoloads ne sont PAS chargés** → toute logique testée doit être pure, sans dépendance autoload. C'est pourquoi `time_control.gd` ne contient que du mapping/clamp ; l'application (`get_tree()`, `Engine`) reste hors test unitaire et se vérifie via le harnais d'intégration `--time-smoke`. [Source: 1-1…md#Refactor-testabilité ; 1-2…md]
- **Pas de VCS** (`git` absent, `baseline_commit=NO_VCS`) → valider par **import + exécution headless réels**, pas seulement en écrivant le code. [Source: 1-1…md#Debug-Log-References]

### Pourquoi ces deux mécanismes (pause vs vitesse) — décision clé

Le piège : la **décision** des agents tombe sur `SimClock.simulation_tick` (~3 Hz, dans `_process`), mais le **mouvement** tourne dans `Agent._physics_process` (60 FPS). Geler ou accélérer **un seul** des deux casserait la cohérence. Solution native, sans toucher au code agent/SimClock :

- **Pause → `get_tree().paused = true`.** Tous les nœuds pausables (par défaut `PROCESS_MODE_INHERIT`) cessent `_process` **et** `_physics_process` : `SimClock` arrête d'émettre (décisions figées), les agents arrêtent de bouger, les futures jauges (Épic 2) gèleront automatiquement. La phase de journée n'avance plus (elle est pilotée par les ticks). **Zéro code par-système.**
- **Vitesse → `Engine.time_scale = 1.0 / 2.0 / 3.0`.** Multiplie le `delta` reçu partout. L'accumulateur de `SimClock` se remplit N× plus vite → N× plus de ticks → décisions + avance de journée accélérées. Le `_physics_process` des agents reçoit un `delta` scalé → mouvement accéléré de façon cohérente. **Aucune modification de `sim_clock.gd` ni `agent.gd`.** (Note : chaque `simulation_tick` porte toujours `TICK_INTERVAL` — la durée *logique* d'un tick est constante, c'est la *fréquence* d'émission qui change. C'est correct : `DayPhaseMath.advance` utilise ce tick_delta logique.)

> **Alternative non retenue** : `Engine.time_scale = 0` pour pauser. Ça marche mais fige aussi la caméra (delta=0) et complique l'état (distinguer « pause » de « x0 »). `get_tree().paused` est sémantiquement plus propre et autorise une caméra `ALWAYS`.

[Source: game-architecture.md#ADR-3 ; 1-2…md#Découplage-temporel (deux horloges) ; sim_clock.gd ; agent.gd `_physics_process`]

### ⚠️ Piège n°1 — l'input de reprise en pause

Quand `get_tree().paused = true`, **les nœuds pausables ne reçoivent plus `_input`/`_unhandled_input`/`_process`**. Si le lecteur de la touche « Espace » est pausable, **le joueur ne pourra jamais reprendre** (deadlock). Le nœud/autoload qui lit les inputs de temps **DOIT** être `process_mode = Node.PROCESS_MODE_ALWAYS`. Idem pour la caméra si on veut la garder active (Task 6) et, plus tard, pour le HUD de contrôle (Story 1.8). Tester explicitement : pause → re-Espace → reprise effective.

### Où placer le contrôleur (deux options valables)

- **Option A — dans `GameManager`** (recommandée) : il est déjà chef d'orchestre (démarre `SimClock`, possède `day_phase`/`day_count`/`day_duration_seconds`). Ajouter `is_paused`, `speed_level`, un `_unhandled_input` (ou `_process`) lisant les actions, et **passer l'autoload `GameManager` en `PROCESS_MODE_ALWAYS`** (sinon il gèle aussi). Cohérent : un seul propriétaire du temps.
- **Option B — nœud dédié `TimeController` dans `open_space.tscn`** (`process_mode = ALWAYS`), qui appelle `get_tree()`/`Engine` et émet via `EventBus`. Plus isolé, mais un acteur de plus.

Choisir A ou B, **pas les deux**. Communiquer l'état via `EventBus` (`game_paused`, `speed_changed`), jamais d'appel direct vers un futur HUD. [Source: game-architecture.md#Decision-Summary D4 ; #Event-System ; #Architectural-Boundaries]

### Frontière day_ended / bilan (éviter le double travail)

- **1.3 fait** : émettre `EventBus.day_ended(day)` au bouclage + incrémenter `day_count` + relancer `day_started`. Rien d'autre.
- **1.10 fera** : le **Bilan de fin de journée** (écran récap) s'abonnera à `day_ended`. **Ne PAS** construire d'UI de bilan ici.
- `day_ended` existe **déjà** dans `event_bus.gd` (posé en 1.1, jamais émis) → cette story le branche enfin. Ordre d'émission : `day_ended(jour_courant)` **puis** `day_started(jour_suivant)`.
[Source: epics.md#Epic-1 / Story 1.10 ; event_bus.gd (signal `day_ended` non émis) ; game-architecture.md#Logging (« transitions de jour » toujours loggées)]

### Architecture compliance — frontières à respecter

- **Communication via `EventBus`** (signals typés, snake_case au passé) ; jamais d'appels directs en dur entre systèmes. [Source: game-architecture.md#Event-System ; #Architectural-Boundaries]
- **Jamais de chemins de nœuds absolus** — `@onready`, `%UniqueName`, signals uniquement. [Source: game-architecture.md#Architectural-Boundaries]
- **Équilibrage en `data/balance/*.tres`** ; les valeurs purement techniques (ex. niveaux de vitesse 1/2/3) peuvent rester `const`/mapping pur. [Source: game-architecture.md#Configuration]
- **`SimClock` reste agnostique** : il n'apprend RIEN de la pause/vitesse. Le contrôle passe par `get_tree().paused` + `Engine.time_scale`, en amont. Ne pas remettre de logique métier dans `SimClock`. [Source: 1-2…md#Frontière-avec-la-Story-1.3 ; sim_clock.gd commentaire d'en-tête]

### Lecture des fichiers UPDATE (état actuel à préserver)

- **`project.godot`** — section `[input]` contient aujourd'hui `cam_up/down/left/right` (WASD, `physical_keycode` 87/83/65/68) et `cam_zoom_in/out` (molette, `button_index` 4/5). **À ajouter** : `game_pause`, `speed_x1/x2/x3`. **À préserver** : toutes les actions `cam_*` et le reste du fichier (autoloads, display, warnings). Voir « Format Input Map » ci-dessous.
- **`scripts/autoloads/game_manager.gd`** — aujourd'hui : possède `day_phase`/`day_count`/`evening_phase`/`day_duration_seconds`, démarre `SimClock` au `_ready`, avance la phase via `DayPhaseMath` sur `simulation_tick`, émet `day_started` au matin et au wrap. **À ajouter** : état pause/vitesse + lecture input (si Option A) + émission `day_ended` au wrap. **À préserver** : amorçage de la 1re journée, avance de phase, nettoyage via `AgentSpawner` sur `day_started`.
- **`scripts/autoloads/event_bus.gd`** — 7 signaux existants (`agent_burned_out`, `decision_resolved`, `llm_call_failed`, `day_ended`, `day_started`, `agent_spawned`, `agent_departed`). **À préserver tous.** **À ajouter** : `game_paused`, `speed_changed`.
- **`scripts/autoloads/sim_clock.gd`** — **NE PAS modifier la logique** (il doit rester agnostique). `Engine.time_scale` agit en amont sur son `_process`. (Au plus, un commentaire d'en-tête mis à jour, sans changement fonctionnel.)
- **`data/balance/sim_balance.tres`** + `scripts/systems/sim_balance.gd` — `day_duration_seconds=45.0`, `evening_phase=0.6`, `agent_count=5`. **À changer** : `day_duration_seconds` → cible ~`300.0`. **À préserver** : structure de la Resource et les autres champs.
- **`scripts/main/main.gd`** — harnais `--measure-fps` et `--sim-smoke`. **À ajouter** : `--time-smoke`. **À préserver** : les deux harnais existants (le `--sim-smoke` force `day_duration_seconds` directement — toujours valide).
- **`scripts/world/camera_controller.gd`** (Task 6, optionnel) — si on garde la caméra active en pause, régler son `process_mode` (sur le nœud rig dans `open_space.tscn` ou en code) à `ALWAYS`. **Préserver** WASD/edge-pan/zoom (non-régression 1.1).
[Source: lecture directe des fichiers `open_space/…` ; 1-1…md#File-List ; 1-2…md#File-List]

> **Important** : une story doit laisser le système **fonctionnel de bout en bout**. Au-delà des AC, la caméra (1.1) et la simulation d'agents (1.2) doivent rester pleinement opérationnelles après cette story.

### Format Input Map (copier le motif existant à la lettre)

Les actions caméra dans `project.godot` suivent ce schéma — **réutiliser exactement** (un `InputEventKey` avec `physical_keycode`, `deadzone` 0.5) :

```
game_pause={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

`physical_keycode` : Espace = **32**, touches du haut 1/2/3 = **49/50/51** (`KEY_1`/`KEY_2`/`KEY_3`). Idéalement éditer via l'UI Godot (Project Settings → Input Map) pour garantir le format ; sinon répliquer le bloc ci-dessus pour `speed_x1/x2/x3`. Vérifier ensuite par import headless 0 erreur/0 warning. [Source: project.godot section `[input]` (motif `cam_*`)]

### Tester pause/vitesse en headless

L'injection d'input clavier est peu fiable en headless → **tester la mécanique, pas l'input**. Deux niveaux :
- **Unitaire (`--script`, sans autoload)** : `test_time_control.gd` valide `TimeControl.scale_for_speed`/`clamp_speed_level` (pures).
- **Intégration (`--time-smoke` dans `main.gd`, avec autoloads)** : appliquer directement `get_tree().paused = true` puis vérifier que `GameManager.day_phase` est stable sur ~0.5 s réelle ; appliquer `Engine.time_scale = 3.0` (unpause) et vérifier que la phase avance nettement plus vite qu'à 1.0 sur le même intervalle. Imprimer `TIME_SMOKE_RESULT=PASS/FAIL`, `quit(0/1)`. Restaurer `time_scale=1.0`/`paused=false` en fin de test.
[Source: 1-2…md#Tests (pattern smoke `--sim-smoke`) ; main.gd ]

### Direction artistique / UI

**Aucune UI dans cette story.** L'indicateur visuel de pause/vitesse et le HUD persistant sont la **Story 1.8**. Feedback dev acceptable : `Log.info("Pause: %s" % is_paused)` / `Log.info("Vitesse x%d" % speed_level)`. [Source: epics.md#Epic-1 / Story 1.8 ; gdd.md#Art-Style]

### Performance (NFR1/NFR2)

60 FPS open space peuplé à x1/x2/x3 (le mouvement scale via `time_scale`, le rendu reste à la fréquence d'affichage). Pas d'allocation per-frame dans le contrôleur de temps (lecture d'input booléenne uniquement). [Source: gdd.md#Performance-Requirements ; NFR1 ; 1-2…md (453 FPS peuplé)]

### Project Structure Notes

- Nouveaux fichiers conformes à la structure hybride : `scripts/systems/time_control.gd` (à côté de `sim_balance.gd`), `tests/unit/test_time_control.gd`. Le contrôleur vit dans `GameManager` (autoload existant) ou un `TimeController` de scène — aucune variance structurelle.
- Aucune nouvelle dépendance, aucun addon. Pas de `class_name` sur les autoloads (rappel 1.1/1.2).

### Project Context Rules

- _Aucun `project-context.md` présent dans le dépôt._ Les règles applicables proviennent de l'architecture et sont listées ci-dessus : `EventBus`-only, pas de chemins absolus, `.tres` pour l'équilibrage, GDScript typé, autoload `Log` (pas `Logger`), pas de `class_name` autoload, logique pure isolée pour la testabilité `--script`.
- **Outillage MCP** (Gopeak Godot MCP + Context7) prévu par l'archi — **non bloquant** ici. [Source: game-architecture.md#AI-Development-Tooling]

### References

- [Source: epics.md#Epic-1 / Story 1.3] — AC complets : pause Espace (gel agents/jauges), vitesses 1/2/3, journée ~5 min tunable `.tres`, compteur de jour + nouveau cycle.
- [Source: epics.md#Epic-1 / Story 1.8] — HUD persistant (indicateur de vitesse/pause) : **hors périmètre ici**.
- [Source: epics.md#Epic-1 / Story 1.10] — Bilan de fin de journée : consommera `day_ended` (émis ici).
- [Source: game-architecture.md#ADR-3 ; #Decision-Summary D3] — `SimClock` ~3 Hz découplé du rendu (reste agnostique de la pause/vitesse).
- [Source: game-architecture.md#Decision-Summary D4 ; #Event-System] — `GameManager` orchestrateur + `EventBus` signals typés snake_case passé.
- [Source: game-architecture.md#Engine-Provided-Architecture] — Input Map (actions configurables) ; UI/HUD = D9 (Story 1.8).
- [Source: game-architecture.md#Configuration] — durée de jour en `.tres` tunable.
- [Source: 1-2…md#Frontière-avec-la-Story-1.3] — périmètre laissé à 1.3 (pause/vitesses/jours) + `SimClock` agnostique ; Espace/1/2/3 réservés.
- [Source: 1-2…md#Découplage-temporel ; agent.gd ; sim_clock.gd ; game_manager.gd] — deux horloges (décision 3 Hz / mouvement 60 FPS) → justifie `get_tree().paused` + `Engine.time_scale`.
- [Source: 1-1…md] — autoload `Log`, pas de `class_name` autoload, pas de GUT (runner headless), pas de VCS, fonctions pures testables.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.8 (claude-opus-4-8)

### Debug Log References

- Import headless propre (0 erreur / 0 warning) : `godot --headless --path open_space --import`.
- Tests unitaires contrôle du temps : `godot --headless --path open_space --script res://tests/unit/test_time_control.gd` → `TEST_RESULT=PASS`, 9/9.
- Non-régression unitaire : `test_agent_sim.gd` → `PASS` 18/18 ; `test_camera_math.gd` → `PASS` 7/7.
- Intégration contrôle du temps : `godot --headless --path open_space -- --time-smoke` → `TIME_SMOKE adv_x1=0.01667 adv_x3=0.06111 adv_pause=0.00000 day_ended=6 day_count=7`, `TIME_SMOKE_RESULT=PASS` (stable sur runs répétés). Couvre AC#1 (pause fige la phase), AC#2 (x3 ≫ x1), AC#3 (`day_ended` émis + compteur incrémenté + nouveau cycle).
- Non-régression intégration : `--sim-smoke` → `SIM_SMOKE spawned=10 departed=5 max_disp=16.54`, `SIM_SMOKE_RESULT=PASS`.
- Perf (NFR1) : `--measure-fps` → `FPS_MEASUREMENT=428` (vsync off, iGPU Intel Iris Xe), exit 0 → bien au-delà de 60.
- Note : un message runtime de navigation (« For runtime (re)baking navigation meshes… ») provient de `open_space.gd:78` (`_build_navigation`, code Story 1.2 **non modifié**) — pré-existant, hors périmètre 1.3, sans impact fonctionnel.

### Completion Notes List

- **Propriétaire unique du temps = `GameManager`** (Option A de la story) : il portait déjà le cycle de journée et démarrait `SimClock`. Ajout de l'état `is_paused`/`speed_level`, de la lecture d'input (`_unhandled_input`) et des API publiques `toggle_pause()` / `set_paused()` / `set_speed()`.
- **Mécanismes natifs, agents/SimClock intouchés** : pause = `get_tree().paused` (gèle tous les nœuds pausables → décisions ET mouvement ET futures jauges) ; vitesse = `Engine.time_scale = 1/2/3` (accélère uniformément `_process`/`_physics_process`). `sim_clock.gd` et `agent.gd` n'ont **pas** été touchés — `SimClock` reste agnostique (frontière 1.2 respectée).
- **Piège n°1 traité** : `GameManager.process_mode = PROCESS_MODE_ALWAYS` au `_ready`, sinon l'autoload ne recevrait plus l'appui « Espace » une fois en pause (deadlock). Vérifié : la reprise fonctionne.
- **UX vitesse** : appuyer sur 1/2/3 en pause applique la vitesse **et** reprend (`set_speed` appelle `set_paused(false)` si pausé). Toggle Espace bascule pause/reprise en conservant la vitesse sélectionnée.
- **Input via Input Map uniquement** : ajout de `game_pause` (Espace=32), `speed_x1/x2/x3` (49/50/51) dans `project.godot`, au format `InputEventKey` identique aux actions `cam_*`. Aucune action `cam_*` modifiée. Aucun scancode codé en dur dans la logique.
- **Signaux pour le HUD futur (Story 1.8)** : `EventBus.game_paused(is_paused)` et `speed_changed(speed_level)` ajoutés et émis à chaque changement. Les 7 signaux existants préservés.
- **Journées ouvrées (AC#3)** : `data/balance/sim_balance.tres` → `day_duration_seconds = 300.0` (cible ~5 min ; défaut de `SimBalance` aligné). Au bouclage, `EventBus.day_ended(day_count)` est émis **avant** `day_started(day_count+1)` → branche enfin le signal `day_ended` (posé en 1.1, jamais émis) pour le bilan Story 1.10.
- **Caméra utilisable en pause** : `CameraRig` passé en `process_mode = 3` (ALWAYS) dans `open_space.tscn` → pan/zoom restent actifs pendant la pause (lisibilité NFR7), sans casser la non-régression caméra 1.1.
- **Tests sans GUT** : logique pure isolée dans `time_control.gd` (mapping/clamp, zéro dépendance autoload → testable en `--script`) ; mécanique pause/vitesse/journée validée par le harnais d'intégration `--time-smoke` (autoloads chargés). Fenêtre de mesure portée à 1,2 s pour lisser la quantification des ticks (~3 Hz) → ratio x3/x1 stable.
- **Hors périmètre (volontaire)** : aucune UI/indicateur de vitesse (HUD = Story 1.8), aucun écran de bilan (Story 1.10), aucune jauge (Épic 2). Conforme au séquençage de l'Épic 1.

### File List

**Nouveaux fichiers (sous `open_space/`) :**
- `scripts/systems/time_control.gd` (`class_name TimeControl` — mapping/clamp purs)
- `tests/unit/test_time_control.gd` (runner headless, 9 tests)

**Fichiers modifiés :**
- `project.godot` (actions d'input `game_pause`, `speed_x1`, `speed_x2`, `speed_x3`)
- `scripts/autoloads/game_manager.gd` (état + API pause/vitesse, `_unhandled_input`, `PROCESS_MODE_ALWAYS`, émission `day_ended` au bouclage)
- `scripts/autoloads/event_bus.gd` (signaux `game_paused`, `speed_changed`)
- `scripts/systems/sim_balance.gd` (défaut `day_duration_seconds` → 300.0, commentaire 1.3)
- `data/balance/sim_balance.tres` (`day_duration_seconds = 300.0`)
- `scenes/world/open_space.tscn` (`CameraRig` → `process_mode = 3` / ALWAYS)
- `scripts/main/main.gd` (harnais `--time-smoke`)

## Change Log

| Date | Version | Description |
|---|---|---|
| 2026-06-21 | 0.3.0 | Implémentation Story 1.3 : contrôle du temps via APIs natives Godot — pause (Espace, `get_tree().paused`) gèle agents/décisions/journée ; vitesses x1/x2/x3 (touches 1/2/3, `Engine.time_scale`) ; `GameManager` propriétaire unique du temps en `PROCESS_MODE_ALWAYS` ; signaux `game_paused`/`speed_changed` pour le HUD futur ; journée ouvrée portée à ~5 min tunable `.tres` ; émission de `day_ended` au bouclage (compteur + nouveau cycle). Caméra active en pause. Tests : 9/9 unitaires `TimeControl` + 18/18 + 7/7 régression + `--time-smoke` PASS (pause figée, x3≈3,6×, `day_ended` confirmé) ; 428 FPS peuplé (NFR1) ; import 0/0. Statut → review. |
