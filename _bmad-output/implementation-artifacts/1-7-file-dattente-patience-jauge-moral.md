---
baseline_commit: NO_VCS
---

# Story 1.7: File d'attente, patience & jauge Moral

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a joueur,
I want que les agents fassent la queue au bureau et perdent patience quand je les fais attendre,
so that mon attention devienne une vraie ressource rare (pilier #1 « l'attention est rare »).

## Acceptance Criteria

1. **Given** plusieurs agents lèvent une sollicitation **présentielle (DESK)** pendant que je suis occupé (la 1.4 émet `EventBus.solicitation_raised(agent_id, channel)` avec `channel == Solicitation.Channel.DESK`) **When** ils convergent vers le bureau **Then** ils forment une **file d'attente physique visible** : chaque agent en file occupe un **créneau distinct** (slot 0 = au bureau, slots suivants alignés derrière), aucun empilement au même point. [Source: epics.md#Story-1.7 AC1 ; FR7 ; FR9 ; game-architecture.md#Decision-Summary D5 (état `queue`)]
2. **Given** chaque agent porte une jauge **Moral (0-100)** et une **patience (~45 s à x1, tunable `.tres`)** **When** son attente en file **dépasse** sa patience **Then** son moral **chute de -1 tous les 5 s** (temps de jeu : gelé en pause, accéléré à x2/x3 comme tout le reste, via `SimClock`). [Source: epics.md#Story-1.7 AC2 ; FR12 ; gdd.md §Jauges (Moral 0-100) ; game-architecture.md#ADR-3 (timing sur `SimClock`) ; #Configuration (équilibrage `.tres`)]
3. **Given** je **traite** enfin un agent en file (la 1.4 émet `EventBus.solicitation_opened(agent_id, channel)` au clic / à l'ouverture) **When** sa sollicitation s'ouvre **Then** il **quitte la file** et les agents restants **avancent d'un créneau**, tandis que **la patience des suivants continue de courir** (leur compteur d'attente n'est PAS remis à zéro). [Source: epics.md#Story-1.7 AC3 ; FR7]

> **Frontière de cette story (lire absolument — périmètre volontairement borné) :**
> - **1.7 FAIT** : (a) une **file d'attente physique** au bureau — créneaux distincts, avancement quand un agent est traité (nouveau système `DeskQueue` qui **écoute** `solicitation_raised`/`solicitation_opened`/`agent_departed` ; **il ne modifie PAS `SolicitationSystem`**) ; (b) la **jauge Moral (0-100)** par agent, posée **sur l'agent** (`get_morale()`/`adjust_morale()`), bornée par une logique **pure** testable (`MoraleMath`) ; (c) la **décroissance du moral par impatience** (-1 / 5 s au-delà de la patience), pilotée sur `SimClock` ; (d) le signal fondateur **`agent_morale_changed(agent_id, morale)`** (consommé plus tard par la fiche 1.9 et le HUD 1.8). Valeurs (patience, décroissance, moral initial) en `.tres` (`data/balance/sim_balance.tres` via `sim_balance.gd`).
> - **1.7 NE FAIT PAS** (ne pas déborder) :
>   - **Mapper `decision_resolved(decision_id, outcome)` → delta de moral.** La 1.6 a posé `decision_resolved` (outcome = **code abstrait**) ; brancher l'effet d'une décision sur le moral exige une **table outcome→effet** qui **n'existe pas encore**. C'est un **consommateur futur** de la jauge (point d'extension documenté ci-dessous) : **NE PAS** l'inventer ici (même esprit de bornage que la 1.6). La SEULE source de variation du moral dans cette story est **l'impatience en file** (AC2).
>   - **Le HUD / l'affichage du moral / du compteur de file** → **Story 1.8** (HUD) + Épic 6 (feedback). Ici : état + signal + logs dev uniquement (aucune UI 2D nouvelle).
>   - **La fiche agent au clic** (lecture du moral dans un panneau) → **Story 1.9**. Le clic gauche reste géré par `SelectionController` tel quel (ne PAS le toucher).
>   - **La Fatigue, le burnout, la contagion, les concertations** → **Épic 2** (FR13/FR16-FR19). Ici, **uniquement** le Moral et **uniquement** sa baisse par impatience.
>   - **Trésorerie / coûts** → **Épic 3**. **Pas** de jauge financière.
>   - **La persistance du moral / de la file** (sauvegarde) → **Épic 7** (FR41). Les agents sont **recréés chaque matin** → le moral **repart à 100 chaque jour** à ce stade (voir Dev Notes) ; ne PAS écrire de code de save.
>   - **L'art / SFX / animation d'état `queue`** → **Épic 6**. L'indicateur placeholder de sollicitation (1.4) suffit pour la lisibilité de la file.

## Tasks / Subtasks

- [x] **Task 1 — Logique PURE du moral : `MoraleMath` (testable `--script`)** (AC: #2)
  - [x] Créer `scripts/systems/morale_math.gd` (`class_name MoraleMath extends RefCounted`) — transformations **pures**, **zéro** dépendance scène/autoload (modèle `decision_resolution_math.gd` / `solicitation_math.gd`, testés en `--script`).
  - [x] `const MIN_MORALE: float = 0.0` ; `const MAX_MORALE: float = 100.0`.
  - [x] `static func clamp_morale(value: float) -> float` → `clampf(value, MIN_MORALE, MAX_MORALE)`.
  - [x] `static func patience_exceeded(wait_seconds: float, patience_seconds: float) -> bool` → `wait_seconds > patience_seconds` (au-delà strict de la patience).
  - [x] `static func decay_steps(accumulator: float, interval: float) -> int` → nombre de paliers entiers de décroissance contenus dans l'accumulateur : `int(floor(accumulator / interval))`. **Défensif** : si `interval <= 0.0`, renvoyer `0` (pas de division/boucle infinie).
  - [x] **Ne PAS** mettre de RNG, `Time`, `EventBus`, ni état mutable ici. L'accumulation concrète et l'émission vivent dans `DeskQueue` (Task 4). **→ 16/16 PASS (`test_morale`).**

- [x] **Task 2 — Jauge Moral sur l'agent : état + API + signal** (AC: #2, #3)
  - [x] **UPDATE** `scripts/autoloads/event_bus.gd` : ajouter `signal agent_morale_changed(agent_id: int, morale: int)` (commenté : émis par l'agent au changement de moral ; consommé plus tard par la fiche agent 1.9 et le HUD 1.8 ; snake_case au passé). **Préserver les 13 signaux existants** et toutes leurs signatures.
  - [x] **UPDATE** `scripts/systems/sim_balance.gd` : ajouter `@export var agent_initial_morale: float = 100.0`, `@export var queue_patience_seconds: float = 45.0`, `@export var morale_decay_per_interval: float = 1.0`, `@export var morale_decay_interval_seconds: float = 5.0`. **Tout typer** (`untyped_declaration=1` → sinon warning import). **Préserver** tous les champs existants. `data/balance/sim_balance.tres` n'a pas à être édité (il prend les défauts du script — il est vide, cf. lecture directe).
  - [x] **UPDATE** `scripts/agents/agent.gd` : ajouter `var _morale: float = 100.0`. Initialisé dans `setup()` depuis le paramètre `initial_morale` (Task 3). Ajouter :
    - `func get_morale() -> int: return roundi(_morale)` (valeur lisible pour fiche 1.9 / HUD 1.8 / test).
    - `func adjust_morale(delta: float) -> void` : `var old := _morale ; _morale = MoraleMath.clamp_morale(_morale + delta)` ; si `_morale != old` → `EventBus.agent_morale_changed.emit(agent_id, roundi(_morale))`. (Borné 0-100 ; émet **uniquement** si la valeur change.)
  - [x] **Préserver intégralement** le comportement 1.2/1.4 de l'agent (mouvement, cycle de journée, sollicitations bureau/mail, marqueur clignotant, `is_eligible_for_solicitation`).

- [x] **Task 3 — Câbler le moral initial (data-driven) via Factory + Spawner** (AC: #2)
  - [x] **UPDATE** `scripts/agents/agent.gd` : étendre `setup(id, archetype, post, exit, desk, evening_phase, initial_morale: float)` → affecter `_morale = initial_morale`. **Conserver l'ordre des paramètres existants**, ajouter `initial_morale` **en dernier**.
  - [x] **UPDATE** `scripts/agents/agent_factory.gd` : `create(...)` reçoit `initial_morale: float` (ajouté **en dernier**) et le transmet à `setup()`. **Préserver** la signature existante (ajout en fin).
  - [x] **UPDATE** `scripts/world/agent_spawner.gd` : dans `_on_day_started`, passer `_BALANCE.agent_initial_morale` à `AgentFactoryC.create(...)`. **Préserver** le reste (créneaux de porte étalés, `_clear_agents`, etc.).

- [x] **Task 4 — `DeskQueue` : file ordonnée, créneaux, patience → moral** (AC: #1, #2, #3)
  - [x] Créer `scripts/systems/desk_queue.gd` (`extends Node`, **sans `class_name`** — cohérent `solicitation_system.gd`/`decision_resolver.gd`). Doc d'en-tête + sources.
  - [x] `const _BALANCE: SimBalance = preload("res://data/balance/sim_balance.tres")`.
  - [x] `@onready var _agents_container: Node3D = %Agents` ; `@onready var _open_space: Node3D = get_parent()` (le parent porte `open_space.gd` → appel `desk_queue_slot_world(i)` ; **mirroir exact de `agent_spawner.gd`** qui appelle `_open_space.post_world_positions()` sur un `Node3D` typé).
  - [x] État : `var _queue: Array[int] = []` (agent_ids **ordonnés**, FIFO d'arrivée) ; `var _wait: Dictionary = {}` (agent_id → float, attente cumulée en s-jeu) ; `var _decay_acc: Dictionary = {}` (agent_id → float, accumulateur de décroissance au-delà de la patience).
  - [x] Override de test : `var patience_override: float = -1.0` (< 0 = valeur `.tres` ; modèle `SolicitationSystem.rate_override`).
  - [x] `_ready()` : abonnements `EventBus.solicitation_raised`/`solicitation_opened`/`agent_departed` + `SimClock.simulation_tick`. **Pas de `_process`** (événementiel + tick ; NFR1). **Ne PAS** mettre `PROCESS_MODE_ALWAYS` : la patience doit **geler en pause** (en pause, `SimClock` ne tick plus → attente figée ; les callbacks de signal restent reçus même en pause → l'ouverture en pause fonctionne).
  - [x] `_on_solicitation_raised(agent_id, channel)` : `if channel != Solicitation.Channel.DESK: return` ; ajouter à `_queue`, init `_wait[agent_id]=0.0`/`_decay_acc[agent_id]=0.0`, puis assigner le créneau = `_assign_slot(agent_id, _queue.size()-1)`.
  - [x] `_on_solicitation_opened(agent_id, channel)` : `if channel != Solicitation.Channel.DESK: return` ; `_remove(agent_id)` (retire de `_queue`/`_wait`/`_decay_acc`) puis `_reflow()` (réassigne les créneaux des restants → ils **avancent**). Le moral des restants **n'est pas** réinitialisé (AC3 : patience continue).
  - [x] `_on_agent_departed(agent_id)` : `_remove(agent_id)` + `_reflow()` (un agent qui part le soir ne laisse pas de trou).
  - [x] `_on_simulation_tick(tick_delta)` : `var patience := patience_override if patience_override >= 0.0 else _BALANCE.queue_patience_seconds` ; pour chaque `agent_id` de `_queue` : `_wait[agent_id] += tick_delta` ; si `MoraleMath.patience_exceeded(_wait[agent_id], patience)` → `_decay_acc[agent_id] += tick_delta` ; `var steps := MoraleMath.decay_steps(_decay_acc[agent_id], _BALANCE.morale_decay_interval_seconds)` ; si `steps > 0` : `var a := _find_agent(agent_id)` ; si `a != null` : `a.adjust_morale(-float(steps) * _BALANCE.morale_decay_per_interval)` ; `_decay_acc[agent_id] -= float(steps) * _BALANCE.morale_decay_interval_seconds`.
  - [x] `_assign_slot(agent_id, index)` : `var a := _find_agent(agent_id)` ; si `a != null` : `a.assign_queue_slot(_open_space.desk_queue_slot_world(index))`.
  - [x] `_reflow()` : `for i in _queue.size(): _assign_slot(_queue[i], i)`. **Itération sûre** : `_reflow` ne mute pas `_queue` pendant la boucle (lecture seule).
  - [x] Helpers/getters (pour le clic réel ET le test) : `func queue_size() -> int` ; `func front_agent_id() -> int` (`_queue[0]` ou `-1`) ; `func is_queued(agent_id) -> bool` ; `func _find_agent(agent_id) -> Agent` (mirroir `SolicitationSystem._find_agent`).
  - [x] **Garde-fou** : si `_find_agent` renvoie `null` (agent libéré entre-temps), ne rien faire (NFR11, jamais fatal).

- [x] **Task 5 — Agent : créneau de file dynamique (`assign_queue_slot`)** (AC: #1, #3)
  - [x] **UPDATE** `scripts/agents/agent.gd` : ajouter `func assign_queue_slot(slot_position: Vector3) -> void`.
    - **Garde** : `if _leaving or not _has_desk_solicitation: return` (un agent qui repart le soir, ou sans sollicitation bureau, ne doit **jamais** être ramené au bureau par un reflow).
    - `_desk_position = slot_position` (met à jour la cible bureau).
    - Si `_at_desk` (déjà en attente, on **avance** dans la file) : `_at_desk = false ; _heading_to_desk = true` (le cerveau ne réémet PAS `GO_TO_DESK` une fois `_at_desk` → il faut relancer le mouvement manuellement).
    - Si `_heading_to_desk` : `_current_target = slot_position ; _nav.target_position = slot_position ; _sm.change_to(_move_state)` (repart vers le nouveau créneau ; à l'arrivée, `_on_destination_reached` repassera `_at_desk = true` via le chemin existant).
  - [x] **Préserver** `raise_desk_solicitation`/`clear_solicitation`/`_on_destination_reached`/`_apply_action` : la 1re marche vers le bureau reste pilotée par le cerveau (`GO_TO_DESK` → cible `_desk_position`), que `DeskQueue` aura déjà mis à jour pour le bon créneau au moment du `solicitation_raised`.

- [x] **Task 6 — Géométrie des créneaux de file dans l'open space** (AC: #1)
  - [x] **UPDATE** `scripts/world/open_space.gd` : ajouter `const _DESK_QUEUE_DIR: Vector3 = Vector3(-1.0, 0.0, 0.0)` (la file s'étire depuis le coin bureau vers l'intérieur, le long du mur du fond) et `const _DESK_QUEUE_SPACING: float = 1.5` (m entre créneaux ; > `agent_radius`*2 = 0.8 → pas de chevauchement).
  - [x] Ajouter `func desk_queue_slot_world(index: int) -> Vector3: return desk_world() + _DESK_QUEUE_DIR * (_DESK_QUEUE_SPACING * float(index))`. **Slot 0 == `desk_world()`** (au bureau) ; slots suivants alignés derrière. Les positions restent sur le plateau 12×12 (`_DESK_CELL = (11,11)`, direction -X → reste dans les bornes pour ≤ 5 agents) et sur le NavMesh (marge `_NAV_MARGIN`).
  - [x] **Préserver** `cell_to_world`/`entrance_world`/`desk_world`/`post_world_positions` et toute la construction sol/nav.

- [x] **Task 7 — Instancier `%DeskQueue` dans l'open space** (AC: #1, #2, #3)
  - [x] **UPDATE** `scenes/world/open_space.tscn` : ajouter un nœud `DeskQueue` (type `Node`, nouveau `script` `desk_queue.gd`) **enfant de `OpenSpace`** (parent = OpenSpace → `get_parent()` résout vers `open_space.gd`), avec `unique_name_in_owner = true`. **Préserver** toute la structure existante (dont `%Agents`, `%SolicitationSystem`, `%DecisionPopup`, `%DecisionResolver`, `CameraRig.process_mode=3`).
  - [x] Déclarer la ressource de script avec un nouvel `id` `ext_resource` distinct (cf. ids 1-7 déjà pris). Import **0 erreur / 0 warning** à confirmer ; `%DeskQueue` présent et abonné (logs `_ready`).

- [x] **Task 8 — Tests (unitaires purs + intégration `--queue-smoke` + non-régression)** (AC: #1, #2, #3)
  - [x] Créer `tests/unit/test_morale.gd` (runner headless autonome `extends SceneTree`, `quit(0/1)`, **pas de GUT**) : `clamp_morale` (−10→0, 150→100, 50→50, bornes 0/100) ; `patience_exceeded` (44/45→false, 45/45→false, 46/45→true) ; `decay_steps` (0/5→0, 4.9/5→0, 5/5→1, 12/5→2, intervalle 0→0). Logique **pure** uniquement (autoloads absents en `--script`).
  - [x] **Intégration** `--queue-smoke` dans `scripts/main/main.gd` (compteurs/refs en **variables MEMBRES** — piège des lambdas : un local serait capturé par valeur) :
    - **AC1** : forcer plusieurs sollicitations **DESK** (`solicitations.desk_prob_override = 1.0 ; rate_override = 1.0`, attendre ~1 s, `rate_override = 0.0`) → `desk_queue.queue_size() >= 2` **et** `open_space.desk_queue_slot_world(0) != open_space.desk_queue_slot_world(1)` (créneaux distincts).
    - **AC2** : choisir un agent en file, lire `get_morale()` (=100) ; `desk_queue.patience_override = 0.0` (patience dépassée d'emblée) ; `set_speed(3)` + `_real_wait(3.0)` (≈ 9 s-jeu ≥ 1 palier de 5 s) → son `get_morale() < 100`.
    - **AC3** : `var size_before := desk_queue.queue_size()` ; choisir un **non-front** `survivor` (≠ `front_agent_id()`) et lire son moral ; `solicitations.open_solicitation(desk_queue.front_agent_id())` → `queue_size() == size_before - 1` **et** `not desk_queue.is_queued(front)` (le traité quitte la file) ; `_real_wait(2.0)` → le moral du `survivor` a **encore baissé** (la patience des suivants **continue de courir**).
    - Restaurer les overrides (`patience_override = -1.0`, `rate_override = -1.0`, `desk_prob_override = -1.0`) + état temporel neutre (`set_speed(1)`, `Engine.time_scale = 1.0`). `print("QUEUE_SMOKE ...")` + `QUEUE_SMOKE_RESULT=PASS/FAIL` + `get_tree().quit(0/1)`.
  - [x] **Non-régression** : exécuter les suites unitaires existantes (`test_camera_math`, `test_agent_sim`, `test_time_control`, `test_solicitation_math`, `test_decision`, `test_decision_resolution`, **+ `test_morale`**) → toutes PASS ; et `--sim-smoke`/`--time-smoke`/`--solicitation-smoke`/`--decision-smoke`/`--resolution-smoke`/`--measure-fps` → PASS (le **système reste fonctionnel de bout en bout** ; `--measure-fps` ≥ 60, NFR1).

## Dev Notes

### Contexte & objectif

La 1.4 a posé **deux canaux** de sollicitation (DESK = l'agent marche au bureau ; MAIL = indicateur sans déplacement) ; la 1.5 la **pop-up** ; la 1.6 la **résolution** (immédiat/différé). Mais aujourd'hui **tous les agents DESK marchent vers le MÊME point** (`desk_world()`, cellule `(11,11)`) → ils s'empileraient. La 1.7 transforme cela en **vraie file d'attente** (créneaux distincts + avancement), pose la **jauge Moral (0-100)** par agent, et la **fait baisser quand le joueur tarde** — c'est le cœur du **pilier #1 « l'attention est rare »** (FR7, FR9, FR12).
[Source: epics.md#Story-1.7 ; FR7/FR9/FR12 ; gdd.md §Jauges]

### ⚠️ La décision de conception clé : un NOUVEAU système `DeskQueue` qui n'AUCUNEMENT ne touche à `SolicitationSystem`

`SolicitationSystem` (1.4) possède déjà la **cadence** (RNG + `.tres`) et le **suivi des sollicitations actives** (`_active : agent_id → Solicitation`), et il **émet** `solicitation_raised` / `solicitation_opened`. Son propre en-tête annonce : *« la file/patience/moral la Story 1.7 »*. La 1.7 **n'a pas besoin de le modifier** : un nouveau nœud **`DeskQueue`** s'**abonne** à ses signaux et gère, en parallèle, l'**ordre de la file**, les **créneaux physiques**, la **patience** et la **décroissance du moral**.

Pourquoi ce découpage (et pas étendre `SolicitationSystem`) :
- **Séparation des préoccupations** : `SolicitationSystem` = *quand/quel canal* ; `DeskQueue` = *ordre physique au bureau + patience + moral*. Chacun reste petit et testable.
- **Zéro régression** : on ne touche pas au producteur de sollicitations (les 5 harnais de fumée existants restent verts).
- **Pattern maison respecté** : un système de scène sans `class_name` (comme `SolicitationSystem`/`DecisionResolver`), événementiel + `SimClock`, **EventBus-only**.

> **Conséquence d'ordonnancement (à connaître)** : `SolicitationSystem._raise()` appelle `agent.raise_desk_solicitation()` **puis** émet `solicitation_raised`. Donc, au moment où `DeskQueue` reçoit le signal, l'agent **n'a pas encore marché** (le 1er `GO_TO_DESK` arrive au tick `SimClock` suivant). `DeskQueue` met à jour `_desk_position` de l'agent (via `assign_queue_slot`) **avant** ce 1er mouvement → l'agent vise directement son **bon créneau**. Pour l'**avancement** (un agent déjà `_at_desk`), le cerveau ne réémet pas `GO_TO_DESK` (garde dans `_apply_action`) → c'est `assign_queue_slot` qui **relance** le mouvement (cf. Task 5). [Source: lecture directe solicitation_system.gd L53-61 ; agent.gd L110-133]

### Le flux exact : de la file à la perte de moral (qui fait quoi)

```
[1.4] SolicitationSystem (tick) → agent.raise_desk_solicitation()  (marqueur + _arrived_at_post=false)
                                → EventBus.solicitation_raised(agent_id, DESK)
[1.7] DeskQueue._on_solicitation_raised → _queue.append(id) ; _wait/_decay_acc=0
                                        → _assign_slot(id, index) → agent.assign_queue_slot(slot_world(index))
[1.2/1.4] agent (tick suivant) → NativeBrain GO_TO_DESK → marche vers _desk_position (= son créneau)
[1.7] DeskQueue._on_simulation_tick(tick_delta) → pour chaque agent en file : _wait += tick_delta
        si _wait > patience : _decay_acc += tick_delta ; steps = floor(_decay_acc/5)
                              si steps>0 : agent.adjust_morale(-steps) → EventBus.agent_morale_changed
[1.4] joueur clique → SelectionController → SolicitationSystem.open_solicitation(id)
                    → EventBus.solicitation_opened(id, DESK) ; agent.clear_solicitation() (retour poste)
[1.7] DeskQueue._on_solicitation_opened → _remove(id) ; _reflow() (les suivants avancent ; leur _wait CONTINUE)
[Futur] fiche agent (1.9) / HUD (1.8) s'abonnent à agent_morale_changed ; mapping decision_resolved→moral = futur
```

### Le moral : où vit-il, et pourquoi sur l'agent

Le **moral est un état par-agent** (0-100, FR12) que la **fiche agent (1.9)** lira, que la **contagion (Épic 2)** transférera entre agents, et que de futurs systèmes (Trésorerie/décisions) moduleront. On le pose donc **sur l'`Agent`** (`_morale` + `get_morale()`/`adjust_morale()`), comme l'agent porte déjà son propre état de sollicitation. La **règle de bornage/décroissance** reste **pure et testable** dans `MoraleMath` (`--script`), et c'est `DeskQueue` (un système de `scripts/systems/`) qui **pilote** la décroissance — cohérent avec l'archi (« les jauges vivent dans `scripts/systems/` ») : *la valeur* est sur l'entité, *la logique* est dans le système/math. [Source: game-architecture.md#System-Location-Mapping (jauges → scripts/systems/) ; #Data-Patterns]

> **`agent_morale_changed` n'est pas un signal mort** : c'est le **signal fondateur** par lequel la fiche agent (1.9) et le HUD (1.8) afficheront le moral. Son émission **est** un livrable de la 1.7 (comme `decision_resolved` l'était pour la 1.6). N'émettre **que** sur changement effectif (évite le spam à chaque tick).

### Le timing « ~45 s à x1 » = temps de jeu sur `SimClock` (pas de temps réel)

La patience s'accumule en **secondes de jeu** : on **somme `tick_delta`** reçu de `SimClock.simulation_tick`. Comme le `delta` de `_process` est mis à l'échelle par `Engine.time_scale` (géré par `GameManager`), à **x3** les ticks arrivent ~3× plus vite → 45 s-jeu ≈ **15 s réelles**, et **en pause** `SimClock` ne tick plus → la patience **gèle** (cohérent « le temps tourne sauf pause », 1.3). C'est exactement le même mécanisme que l'avancement de la phase de journée. La décroissance « -1 / 5 s » utilise un **accumulateur** + `MoraleMath.decay_steps` (gère proprement plusieurs paliers franchis en un seul tick à haute vitesse). [Source: sim_clock.gd L28-34 ; game_manager.gd (Engine.time_scale) ; game-architecture.md#ADR-3]

### Pourquoi compter la patience dès l'entrée en file (et la continuer après avancement)

- **Début du compteur** = au **`solicitation_raised`** (l'agent commence à réclamer l'attention) — pas à l'arrivée physique au créneau, pour rester robuste aux aléas de navigation et coller au pilier « l'attention est rare ».
- **AC3** impose que la patience des suivants **continue de courir** quand on traite un agent : on **ne réinitialise pas** `_wait`/`_decay_acc` lors d'un `_reflow()`. On ne réinitialise (retire) que pour l'agent **traité** ou **parti**. [Source: epics.md#Story-1.7 AC3]

### Anti-pièges (apprentissages 1.1 → 1.6 — à respecter absolument)

- **L'autoload logger s'appelle `Log`, PAS `Logger`** (`Logger` = classe native Godot 4.6 → collision). `Log.info/warn/error/debug`. (Les extraits d'archi montrant `Logger.info(...)` sont **illustratifs**.) [Source: 1-1…/1-6…md]
- **Les autoloads n'ont PAS de `class_name`** ; un **système instancié en scène** (`SolicitationSystem`, `DecisionResolver`) **non plus** → `DeskQueue` n'en a **pas**. Les **modules math purs** (`DecisionResolutionMath`, `SolicitationMath`) **ont** un `class_name` et sont appelés en global → `MoraleMath` pareil. [Source: 1-2…/1-6…md ; solicitation_system.gd ; decision_resolution_math.gd]
- **En mode `--script`, les autoloads ne sont PAS chargés** → la logique testée unitairement doit être **pure** (sans `Log`/`EventBus`/`SimClock`). D'où `MoraleMath` (pur, `--script`) vs `DeskQueue` (autoloads/scène, testé via `--queue-smoke`). [Source: 1-5…/1-6…md#Tests]
- **GUT non installé** → runner headless autonome (`tests/unit/*.gd extends SceneTree`, `quit(0/1)`). [Source: 1-1…1-6…md]
- **Pas de VCS** (`baseline_commit=NO_VCS`) → valider par **import + exécution headless réels** (jamais « au jugé ») : `godot --headless --path open_space --import` doit rester **0 erreur / 0 warning**. [Source: 1-6…md#Debug-Log-References]
- **Piège des lambdas GDScript (capture par valeur)** : dans `--queue-smoke`, compter/mémoriser via **variables membres** de `main.gd` (cf. `_sol_*`, `_resolved_count`), **jamais** des locaux capturés dans un signal. [Source: 1-4…/1-6…md#main.gd]
- **Pattern override de test** : champ membre `*_override` à `-1.0` par défaut (`SolicitationSystem.rate_override`, `DecisionResolver.immediate_prob_override`) → `DeskQueue.patience_override`. [Source: solicitation_system.gd L27-39 ; 1-6…md]
- **Callbacks de signal vs pause** : `process_mode` gèle `_process`, **pas** les callbacks de signal. `DeskQueue` n'a **pas** `PROCESS_MODE_ALWAYS` (patience gelée en pause via `SimClock`), mais `_on_solicitation_opened` (réception d'un signal émis par le clic/`SelectionController`, eux en `ALWAYS`) **fonctionne quand même en pause** → l'avancement de file s'effectue, le mouvement reprenant à la reprise. [Source: 1-6…md#Callbacks ; selection_controller.gd L17-19]
- **`.tres` — éditer prudemment** : ici on n'**ajoute que des scalaires `@export`** au **script** `sim_balance.gd` ; `sim_balance.tres` reste vide (prend les défauts). **Aucun** `Array[ExtResource]` à réécrire à la main. [Source: 1-5…/1-6…md ; lecture directe sim_balance.tres]
- **`@onready var _open_space: Node3D = get_parent()` puis appel d'une méthode du script** : pattern **déjà utilisé et validé** par `agent_spawner.gd` (`_open_space.post_world_positions()`), import 0/0 → le réutiliser tel quel pour `desk_queue_slot_world`. [Source: lecture directe agent_spawner.gd L17/L27-29]

### Lecture des fichiers UPDATE (état actuel à préserver)

- **`scripts/agents/agent.gd`** — `CharacterBody3D`. Possède : `setup(id, archetype, post, exit, desk, evening_phase)` ; décision sur `simulation_tick` (`_decide` → `BrainComponent` → `_apply_action`) ; **mouvement** par frame (`follow_path`/`_on_destination_reached`) ; API sollicitations 1.4 (`raise_desk_solicitation`/`raise_mail_solicitation`/`clear_solicitation`/`has_open_solicitation`/`is_eligible_for_solicitation`) ; champs d'état `_arrived_at_post`/`_leaving`/`_heading_to_desk`/`_at_desk`/`_desk_position` ; marqueur clignotant via `_process`. **Ajouter** `_morale` + `get_morale()`/`adjust_morale()` + `assign_queue_slot()` + param `initial_morale` à `setup`. **Ne RIEN casser** du flux existant ; en particulier `_apply_action(GO_TO_DESK)` garde sa garde `if not _heading_to_desk and not _at_desk`. [Source: lecture directe agent.gd]
- **`scripts/decisions/solicitation_system.gd`** — **NE PAS MODIFIER**. On consomme ses signaux `solicitation_raised(agent_id, channel)` / `solicitation_opened(agent_id, channel)` (channel = `Solicitation.Channel`, 0=DESK). `open_solicitation(agent_id)` reste le point d'entrée commun clic/test. [Source: lecture directe solicitation_system.gd]
- **`scripts/decisions/solicitation.gd`** — enum `Channel { DESK = 0, MAIL = 1 }` = **source unique** du canal ; `DeskQueue` la réutilise (`Solicitation.Channel.DESK`). **NE PAS MODIFIER**. [Source: lecture directe solicitation.gd]
- **`scripts/world/open_space.gd`** — `Node3D` (script du nœud `OpenSpace`, **sans `class_name`**). Expose `cell_to_world`/`entrance_world`/`desk_world`/`post_world_positions` ; `_DESK_CELL = (11,11)` ; grille 12×12, `CELL=2`, NavMesh runtime. **Ajouter** `desk_queue_slot_world(index)` + consts de file. **Préserver** tout le reste. [Source: lecture directe open_space.gd]
- **`scripts/agents/agent_factory.gd`** / **`scripts/world/agent_spawner.gd`** — factory `create(id, archetype, post, exit, desk, evening_phase)` → `setup(...)` ; spawner peuple sur `day_started` en lisant `_BALANCE` + `_open_space` (postes/entrée/bureau). **Ajouter** `initial_morale` (factory : param en fin → `setup` ; spawner : `_BALANCE.agent_initial_morale`). **Préserver** créneaux de porte étalés et `_clear_agents`. [Source: lecture directe agent_factory.gd / agent_spawner.gd]
- **`scripts/systems/sim_balance.gd`** — `SimBalance extends Resource`. Champs existants : `day_duration_seconds`/`evening_phase`/`agent_count` + `solicitation_rate_per_tick`/`desk_channel_probability` + `decision_immediate_probability`/`decision_deferred_min_days`/`decision_deferred_max_days`. **Ajouter** `agent_initial_morale`/`queue_patience_seconds`/`morale_decay_per_interval`/`morale_decay_interval_seconds`. **Préserver** l'existant. [Source: lecture directe sim_balance.gd]
- **`scripts/autoloads/event_bus.gd`** — **13 signaux** (fondateurs + cycle/agents + temps + sollicitations + `decision_chosen` + `decision_committed`). **Ajouter** `agent_morale_changed(agent_id, morale)`. **Préserver les 13** et leurs signatures. [Source: lecture directe event_bus.gd]
- **`scenes/world/open_space.tscn`** — `OpenSpace`(open_space.gd) avec enfants `GridMap`/`NavigationRegion3D`/`Agents(%)`/`AgentSpawner`/`SolicitationSystem(%)`/`SelectionController`/`DecisionPopup(%)`/`DecisionResolver(%)`/`WorldEnvironment`/`DirectionalLight3D`/`CameraRig(process_mode=3)/Camera3D`. **Ajouter** `%DeskQueue` (Node + script, enfant d'`OpenSpace`). **Préserver** tout. [Source: lecture directe open_space.tscn]
- **`scripts/main/main.gd`** — 6 harnais (`--measure-fps`/`--sim-smoke`/`--time-smoke`/`--solicitation-smoke`/`--decision-smoke`/`--resolution-smoke`) + helpers `_force_desk_solicitation`/`_open_first_active`/`_min_agent_distance_to`/`_real_wait` + compteurs membres. **Ajouter** `--queue-smoke` (+ branche dans `_ready`) + refs/compteurs membres. **Préserver les 6 harnais** et helpers (réutiliser `_force_desk_solicitation`/`_real_wait`). [Source: lecture directe main.gd]
- **NE PAS MODIFIER** : `solicitation_system.gd`, `solicitation.gd`, `decision_popup.gd`, `decision_resolver.gd`, `selection_controller.gd`, `game_manager.gd`, `sim_clock.gd`, `native_brain.gd`, `agent_context.gd`, `action_registry.gd` (aucune **nouvelle action** n'est requise : la file réutilise `GO_TO_DESK` en changeant seulement la **cible**). [Source: game-architecture.md#Architectural-Boundaries]

> **Important** : une story doit laisser le système **fonctionnel de bout en bout**. Au-delà des AC, caméra (1.1), agents (1.2), temps (1.3), sollicitations (1.4), pop-up (1.5) et résolution (1.6) doivent rester pleinement opérationnels.

### Point d'extension documenté (NE PAS implémenter ici) — `decision_resolved` → moral

La 1.6 émet `decision_resolved(decision_id, outcome)` où `outcome` est un **code abstrait** (1-10 dans le catalogue). Quand on voudra qu'une décision **affecte le moral**, un futur système s'abonnera à `decision_resolved` et appliquera `agent.adjust_morale(delta)` via une **table outcome→effet** (data-driven `.tres`). Cette table **n'existe pas** et l'implémenter ici = inventer du contenu hors périmètre (même piège que la 1.6). **Ici, la seule source de variation du moral est l'impatience en file (AC2).** [Source: 1-6…md (decision_resolved fondateur) ; epics.md#Story-1.7 (AC = patience uniquement)]

### Note de conception — réinitialisation quotidienne du moral

Le spawner **recrée les agents chaque matin** (`_clear_agents` + `create`) → à ce stade le moral **repart à `agent_initial_morale` (100) chaque jour**. C'est acceptable pour le MVP ; la **continuité inter-jours** et la **persistance** relèvent d'Épic 2/7. Ne PAS chercher à conserver le moral entre les jours dans cette story. [Source: agent_spawner.gd L25-43 ; epics.md#Épic-7]

### Performance (NFR1)

`DeskQueue` est **événementiel + tick** (`simulation_tick` ~3 Hz), **aucun `_process`**, et n'itère que sur `_queue` (≤ `agent_count` = 5). Coût par frame **nul**, coût par tick négligeable. 60 FPS open space inchangés. [Source: NFR1 ; sim_balance.gd agent_count ; 1-6…md (145 FPS)]

### Direction artistique / UI

**Aucune UI 2D nouvelle.** La file est matérialisée par les **positions distinctes** des agents + leur **marqueur de sollicitation** placeholder (1.4). L'affichage chiffré du moral (fiche 1.9, HUD 1.8) et l'animation d'état `queue` / le juice (Épic 6) viennent plus tard. [Source: epics.md#Story-1.8/1.9 ; #Épic-6]

### Project Structure Notes

- Nouveaux fichiers conformes à la structure hybride : `scripts/systems/morale_math.gd`, `scripts/systems/desk_queue.gd`, `tests/unit/test_morale.gd`.
- Fichiers modifiés : `scripts/agents/agent.gd`, `scripts/agents/agent_factory.gd`, `scripts/world/agent_spawner.gd`, `scripts/systems/sim_balance.gd`, `scripts/world/open_space.gd`, `scripts/autoloads/event_bus.gd`, `scenes/world/open_space.tscn`, `scripts/main/main.gd`.
- Aucune nouvelle dépendance, aucun addon. `MoraleMath` = `class_name` + pur (`--script`) ; `DeskQueue` = nœud de scène **sans** `class_name` (cohérent `SolicitationSystem`/`DecisionResolver`).

### Project Context Rules

- _Aucun `project-context.md` présent dans le dépôt._ Règles applicables (archi + stories 1.1-1.6) : **`EventBus`-only** (snake_case au passé, pas d'appel dur entre systèmes) ; **pas de chemins de nœuds absolus** (`@onready`/`%UniqueName`/signals) ; **`.tres` pour le contenu/équilibrage** (zéro magic number / texte en dur) ; **GDScript typé** (import 0/0) ; autoload **`Log`** (pas `Logger`) ; **pas de `class_name`** sur autoloads ni systèmes de scène ; **logique pure isolée** (`--script`) vs intégration (`--*-smoke`) ; **erreurs non fatales** (NFR11) ; **60 FPS** (NFR1) ; un agent ne parle jamais directement à `LLMService` (sans objet ici).
- **Outillage MCP** (Gopeak Godot MCP + Context7) prévu par l'archi — **non bloquant** ici. [Source: game-architecture.md#AI-Development-Tooling]

### References

- [Source: epics.md#Story-1.7] — AC : file physique au bureau ; Moral 0-100 + patience ~45 s (tunable) → -1/5 s au-delà ; traitement d'un agent le sort de la file, la patience des suivants continue.
- [Source: epics.md#Story-1.4] — `solicitation_raised`/`solicitation_opened` (canal DESK/MAIL) ; `open_solicitation` ; l'agent marche au bureau (`GO_TO_DESK`) ; *« la file/patience/moral la Story 1.7 »*.
- [Source: epics.md#Story-1.8] — HUD/compteur d'attention : affichage **hors périmètre** (consommera `agent_morale_changed`).
- [Source: epics.md#Story-1.9] — fiche agent : lecture du moral **hors périmètre** (consommera `get_morale()`).
- [Source: epics.md#Épic-2] — Fatigue/burnout/contagion/concertations : **hors périmètre**.
- [Source: gdd.md §Jauges] — Moral (0-100) ; pilier #1 « l'attention est une ressource rare ».
- [Source: game-architecture.md#Decision-Summary D3/D5/D6/D10] — `SimClock` ~3 Hz ; State Machine (état `queue`) ; `.tres` data-driven ; GDScript typé.
- [Source: game-architecture.md#ADR-3] — timing (patience/décroissance) ordonnancé sur `SimClock` découplé du rendu.
- [Source: game-architecture.md#System-Location-Mapping ; #Data-Patterns] — jauges → `scripts/systems/` ; accès data-driven.
- [Source: game-architecture.md#Event-System ; #Architectural-Boundaries ; #Configuration ; #Error-Handling] — EventBus typé, pas de chemins absolus, `.tres` équilibrage, erreur non fatale (NFR11).
- [Source: lecture directe] — `agent.gd`, `solicitation_system.gd`, `solicitation.gd`, `open_space.gd`, `open_space.tscn`, `agent_factory.gd`, `agent_spawner.gd`, `sim_balance.gd`, `sim_balance.tres`, `event_bus.gd`, `sim_clock.gd`, `game_manager.gd`, `native_brain.gd`, `agent_context.gd`, `action_registry.gd`, `selection_controller.gd`, `decision_popup.gd`, `main.gd`.
- [Source: 1-6…md] — autoload `Log` ; pas de `class_name` sur systèmes de scène ; modules math purs avec `class_name` ; pas de GUT (runner headless) ; pas de VCS (valider headless) ; pure `--script` vs smoke d'intégration ; piège des lambdas (compteurs membres) ; pattern override de test ; prudence `.tres` ; signal fondateur dont l'émission est le livrable.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.8 (claude-opus-4-8)

### Debug Log References

- Moteur : Godot 4.6.3-stable (`Godot_v4.6.3-stable_win64_console.exe`), exécution **headless réelle** (pas de VCS sur `open_space/`, validation par import + run).
- **Baseline avant dev** (état de départ vert) : import 0/0 ; 6 suites unitaires PASS ; 5 smokes PASS.
- Import après implémentation : `godot --headless --path open_space --import` → **0 erreur / 0 warning** ; `MoraleMath`/`SimBalance`/`Agent` enregistrés.
- Unitaire moral : `--script res://tests/unit/test_morale.gd` → `TEST_RESULT=PASS`, **16/16** (`clamp_morale` bornes 0/100 ; `patience_exceeded` borne exclusive 45=45→false ; `decay_steps` 0/4.9/5/9/12 + intervalle 0/négatif défensif).
- Intégration file : `godot --headless --path open_space -- --queue-smoke` → `QUEUE_SMOKE queue=4 slots_distinct=true morale_before=100 morale_after=99 left_ok=true surv_before=99 surv_after=98`, `QUEUE_SMOKE_RESULT=PASS`. Couvre AC1 (file ≥ 2 + créneaux distincts), AC2 (moral 100→99 par impatience), AC3 (front traité quitte la file `left_ok` + patience des suivants qui continue : survivant 99→98).
- Preuve visible en logs (canal réel SolicitationSystem → DeskQueue) : `File bureau : agent 0/1/2/3 rejoint (position 0/1/2/3)` puis `File bureau : agent 0 traité, 3 en attente`.
- **Non-régression** : 7 suites unitaires PASS (6 existantes + `test_morale`) ; 6 smokes PASS (`--sim-smoke`/`--time-smoke`/`--solicitation-smoke`/`--decision-smoke`/`--resolution-smoke`/`--queue-smoke`).
- Perf (NFR1) : `--measure-fps` → `FPS_MEASUREMENT=144` (≥ 60 ; `DeskQueue` événementiel + tick, aucun `_process`).
- Note : les 2 warnings runtime de navigation (`open_space.gd::_build_navigation`, code Story 1.2 non modifié) restent pré-existants, hors périmètre ; l'**import** reste 0/0.

### Completion Notes List

- **File d'attente livrée sans toucher à `SolicitationSystem`** : le nouveau nœud `%DeskQueue` (`scripts/systems/desk_queue.gd`, sans `class_name`, cohérent `SolicitationSystem`/`DecisionResolver`) **s'abonne** à `solicitation_raised`/`solicitation_opened`/`agent_departed` + `SimClock.simulation_tick`. Zéro modification du producteur de sollicitations → zéro régression (5 smokes hérités verts).
- **Créneaux physiques distincts** : `open_space.desk_queue_slot_world(index)` aligne la file depuis le bureau (`_DESK_CELL (11,11)`) vers l'intérieur (-X, espacement 1.5 m > 2× agent_radius). Slot 0 = au bureau ; avancement par `_reflow()` quand un agent est traité/part (les restants reçoivent `assign_queue_slot`).
- **Jauge Moral (0-100) sur l'agent** : `_morale` + `get_morale()`/`adjust_morale()` (bornage `MoraleMath.clamp_morale`, émission de `agent_morale_changed` **uniquement sur changement réel**). Moral initial data-driven (`SimBalance.agent_initial_morale`) câblé via `AgentFactory.create` → `Agent.setup` (params ajoutés en fin, défauts rétro-compatibles).
- **Décroissance par impatience (AC2)** pilotée sur `SimClock` : `_wait += tick_delta` ; au-delà de la patience (`MoraleMath.patience_exceeded`), `_decay_acc` accumule et `MoraleMath.decay_steps` applique « -1 / 5 s » par paliers entiers (robuste aux multiples paliers franchis en un tick à x3). Patience en **secondes de jeu** → gelée en pause (SimClock figé), accélérée à x2/x3, ~45 s à x1 (tunable `.tres`).
- **AC3 — patience des suivants continue** : sur traitement/`reflow`, on **ne réinitialise pas** `_wait`/`_decay_acc` des restants (uniquement de l'agent retiré). Vérifié : survivant 99→98 après l'ouverture du front.
- **`assign_queue_slot` robuste** : garde `if _leaving or not _has_desk_solicitation: return` (un agent qui repart le soir n'est jamais ramené au bureau par un reflow) ; relance le mouvement quand un agent déjà `_at_desk` avance (le cerveau ne réémet pas `GO_TO_DESK` une fois arrivé).
- **Bornes respectées** : aucune UI/HUD (1.8), pas de fiche agent (1.9), pas de Fatigue/burnout/contagion (Épic 2), pas de Trésorerie (Épic 3), pas de mapping `decision_resolved`→moral (point d'extension futur documenté), pas de persistance (le moral repart à 100 chaque matin — agents recréés). `solicitation_system.gd`/`solicitation.gd`/`decision_popup.gd`/`decision_resolver.gd`/`selection_controller.gd`/`game_manager.gd`/`sim_clock.gd`/`native_brain.gd`/`agent_context.gd`/`action_registry.gd` **non modifiés** ; aucune nouvelle action (réutilisation de `GO_TO_DESK`).
- **Système fonctionnel de bout en bout** : caméra (1.1), agents (1.2), temps (1.3), sollicitations (1.4), pop-up (1.5), résolution (1.6) restent opérationnels (7 suites + 6 smokes PASS, 144 FPS, import 0/0).

### File List

**Nouveaux fichiers (sous `open_space/`) :**
- `scripts/systems/morale_math.gd` (`class_name MoraleMath` — `clamp_morale`/`patience_exceeded`/`decay_steps` purs)
- `scripts/systems/desk_queue.gd` (système de file : créneaux, patience → moral, avancement ; abonné EventBus + SimClock)
- `tests/unit/test_morale.gd` (runner headless, 16 tests purs)

**Fichiers modifiés :**
- `scripts/agents/agent.gd` (jauge `_morale` + `get_morale()`/`adjust_morale()` + `assign_queue_slot()` ; param `initial_morale` à `setup` ; comportement 1.2/1.4 préservé)
- `scripts/agents/agent_factory.gd` (param `initial_morale` ajouté en fin → `setup`)
- `scripts/world/agent_spawner.gd` (passe `_BALANCE.agent_initial_morale` à `create`)
- `scripts/systems/sim_balance.gd` (`agent_initial_morale`/`queue_patience_seconds`/`morale_decay_per_interval`/`morale_decay_interval_seconds` ajoutés ; existant préservé)
- `scripts/world/open_space.gd` (`desk_queue_slot_world()` + consts `_DESK_QUEUE_DIR`/`_DESK_QUEUE_SPACING`)
- `scripts/autoloads/event_bus.gd` (signal `agent_morale_changed` ajouté ; 13 signaux existants préservés)
- `scenes/world/open_space.tscn` (instance `%DeskQueue` ajoutée ; structure préservée)
- `scripts/main/main.gd` (harnais `--queue-smoke` + helper `_find_agent_by_id` ; 6 harnais existants + helpers préservés)

## Change Log

| Date | Version | Description |
|---|---|---|
| 2026-06-22 | 0.7.0 | Implémentation Story 1.7 : file d'attente physique au bureau, patience & jauge Moral. `MoraleMath` pur (`clamp_morale`/`patience_exceeded`/`decay_steps`, testé `--script`). Nouveau système `%DeskQueue` (abonné à `solicitation_raised`/`solicitation_opened`/`agent_departed` + `SimClock`, **sans modifier `SolicitationSystem`**) : créneaux distincts via `open_space.desk_queue_slot_world`, avancement (`_reflow`) au traitement/départ, décroissance « -1/5 s » au-delà de la patience (~45 s à x1, tunable `.tres`). Jauge Moral (0-100) portée par l'`Agent` (`get_morale`/`adjust_morale`, signal fondateur `agent_morale_changed`), moral initial data-driven câblé via Factory/Spawner. Tests : 16/16 `test_morale` + `--queue-smoke` PASS (file ≥ 2 + créneaux distincts ; moral 100→99 par impatience ; front traité retiré + patience des suivants qui continue 99→98) ; non-régression 7 suites unitaires + 6 smokes PASS ; 144 FPS (NFR1) ; import 0/0. `solicitation_system.gd`/`agent_context.gd`/`native_brain.gd`/`game_manager.gd`/`sim_clock.gd` non modifiés. Statut → review. |
