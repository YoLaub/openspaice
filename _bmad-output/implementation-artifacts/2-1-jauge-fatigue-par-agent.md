---
baseline_commit: 17a1bf743b7bbe370a86cc508b0222aa2bb0b047
---

# Story 2.1: Jauge Fatigue par agent

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a joueur,
I want que **chaque agent accumule de la fatigue** au fil de sa journée de travail, qu'il en **récupère la nuit**, que les **heures sup' la fassent grimper**, et que cette jauge soit **lisible sur sa fiche** — le tout **persistant d'un jour à l'autre** (les mêmes agents reviennent chaque matin avec leur fatigue de la veille),
so that je dois **gérer l'endurance de mon équipe** dans la durée — première brique de la spirale fatigue → burnout (Story 2.2) et du levier de gestion du temps de travail (Story 2.3).

## Acceptance Criteria

1. **Given** chaque agent possède une **jauge Fatigue (0-100)** **When** il **travaille** une journée standard (≈ phase de travail de la journée) **Then** sa fatigue **monte progressivement** selon un taux **data-driven `.tres`** (calcul sur `SimClock`, cf. AC3), et **récupère −25 par nuit** (repos entre deux journées) ; **And** la valeur est **visible sur sa fiche** (`AgentCard`, 1.9) — libellé « Fatigue : NN », mise à jour **en direct** quand elle change. [Source: epics.md#Story-2.1 AC1 ; FR13 (Fatigue 0-100, repos −25/j) ; game-architecture.md#Decision-Summary D5 (états agents) ; 1-7…md (patron jauge Moral) ; 1-9…md (fiche agent)]

2. **Given** un agent **fait des heures sup'** (à ce stade : déterminé par son **archétype** — l'archétype « Heures sup », le réglage joueur arrive en Story 2.3) **When** sa **journée se termine** **Then** **+15 fatigue** lui sont appliqués pour la nuit (en plus du repos −25). *(Le « +prod du jour » de l'épic est **hors périmètre** : aucune production/économie avant l'Épic 3 — voir Frontière.)* [Source: epics.md#Story-2.1 AC2 ; FR13 (heures sup +15/j) ; archetype_overtimer.tres (« Heures sup », `departure_offset=0.15`)]

3. **Given** la fatigue évolue **When** la simulation tourne **Then** elle est **calculée via `SimClock`** (dans `_on_simulation_tick`, ~3 Hz — **pas** dans `_process`/`_physics_process`), **sans coût de perf notable** (NFR2 : 60 FPS préservés, `--measure-fps` ≥ 60) et de façon **cohérente à toutes les vitesses** (x1/x2/x3) et **gelée en pause** (la fatigue progresse proportionnellement à l'avance de la phase de journée, comme `day_phase`). [Source: epics.md#Story-2.1 AC3 ; NFR2 (calculs sur `SimClock`) ; NFR1 ; sim_clock.gd ; day_phase_math.gd#advance]

4. **Given** la **persistance du roster** (choix de conception validé : portée « roster persistant ») **When** une nouvelle journée démarre (`day_started`, après validation du bilan 1.10) **Then** **les mêmes agents** (mêmes `agent_id`, mêmes archétypes) réapparaissent au matin **en conservant leur fatigue** de la veille (à laquelle on applique repos −25 et, le cas échéant, heures sup' +15) — **fini** le « cohorte neuve à ids neufs chaque matin » de l'Épic 1. **And** rien de la boucle 1.1→1.10 n'est cassé (spawn matinal, départs du soir, HUD, fiche, bilan, sollicitations, file/moral). [Source: décision de portée 2.1 (roster persistant) ; agent_spawner.gd (spawn/clear sur `day_started`) ; FR16/FR17 (burnout multi-jours, jour off → exigent un roster stable) ; 1-10…md (enchaînement des journées gaté)]

> **Frontière de cette story (lire absolument — périmètre volontairement borné) :**
> - **2.1 FAIT** :
>   - **(a)** un **module pur `FatigueMath`** (`scripts/systems/fatigue_math.gd`, **modèle exact `MoraleMath`**) : bornage 0-100, **accrual par tick** (proportionnel à l'avance de la phase de journée → cohérent vitesses/pause, NFR2), **récupération de nuit** (repos −25, +15 si heures sup'). Logique pure testable `--script` ;
>   - **(b)** une **jauge Fatigue sur l'`Agent`** (`_fatigue`, `get_fatigue()`, `adjust_fatigue()`), **strictement** calquée sur la jauge Moral (1.7) : accumulation **dans `_on_simulation_tick`** quand l'agent **travaille** (à son poste, pas en route/au bureau/en partance/le soir), émission d'un **nouveau signal `EventBus.agent_fatigue_changed(agent_id, fatigue)`** **uniquement sur variation réelle** (anti-spam, modèle `agent_morale_changed`) ;
>   - **(c)** la **persistance du roster** dans `AgentSpawner` : un roster stable {`id`, `archetype`, `fatigue`} reconstruit chaque matin **avec les mêmes ids**, fatigue **reportée** d'un jour à l'autre (suivie en direct via `agent_fatigue_changed`, recalculée la nuit via `FatigueMath`) ;
>   - **(d)** l'affichage **Fatigue sur la fiche** (`AgentCard`, 1.9) : nouveau `%FatigueLabel`, lu à l'ouverture (`agent.get_fatigue()`) et **suivi en direct** par `agent_fatigue_changed` **filtré** sur l'agent affiché ;
>   - **(e)** un **drapeau d'archétype `does_overtime`** (data-driven) — `true` sur l'archétype « Heures sup » — pour décider l'application du +15 de nuit ;
>   - **(f)** un **test unitaire pur** (`test_fatigue.gd`) + un **smoke d'intégration `--fatigue-smoke`** (accumulation au travail, affichage fiche, report inter-jour avec −25/+15, mêmes ids).
> - **2.1 NE FAIT PAS** (ne pas déborder) :
>   - **Aucun seuil/indicateur de burnout** : « ≥80 = risque », « =100 = craquage », état `burnout`/`fatigue` de la State Machine, indicateur visuel de risque, `EventBus.agent_burned_out` = **Story 2.2**. La fiche affiche la valeur **sans** couleur de seuil (pas de seuil `.tres` de fatigue ici — contrairement au Moral qui a ses seuils HUD). **NE PAS** créer de seuil de fatigue.
>   - **Aucun réglage joueur du temps de travail** : imposer des heures sup'/jour off/départ anticipé via la fiche = **Story 2.3**. Ici, « heures sup' » = **propriété d'archétype** (lecture seule). Les boutons « Jour off » de la fiche **restent désactivés** (placeholder 1.9).
>   - **Aucune production / économie** : le « +prod du jour » (AC2 de l'épic) n'a **pas** de système support avant l'Épic 3/4 → **non implémenté** (noté). **NE PAS** inventer de jauge de prod.
>   - **Aucune contagion / concertation / événement de vie** : Stories 2.4/2.5/2.6.
>   - **Aucune persistance disque / sauvegarde** : le roster vit **en mémoire** dans `AgentSpawner` pour la session courante ; la sauvegarde de l'état complet = `SaveManager`, **Épic 7** (D7). Pas de report du roster entre deux lancements du jeu.
>   - **Aucun report du Moral entre jours** : la portée « roster persistant » de 2.1 concerne **la fatigue**. Le Moral continue de **repartir à sa valeur initiale** chaque matin (comportement Épic 1 inchangé) — le report/la dynamique du moral inter-jour relèvent de 2.2/2.5. **NE PAS** faire persister le moral (hors périmètre, éviterait une régression de comportement non demandée).
>   - **Aucun nouveau HUD global de fatigue** : la fatigue est **par-agent** (fiche). Pas d'agrégat HUD (le HUD 1.8 reste inchangé).

## Tasks / Subtasks

- [x] **Task 1 — Module pur `FatigueMath` (`scripts/systems/fatigue_math.gd`)** (AC: #1, #2, #3)
  - [x] Créer `scripts/systems/fatigue_math.gd` : `class_name FatigueMath extends RefCounted`. **Modèle EXACT = `scripts/systems/morale_math.gd`** (logique pure, sans état, sans dépendance scène/autoload → testable `--script`). Doc d'en-tête + sources.
  - [x] `const MIN_FATIGUE: float = 0.0` / `const MAX_FATIGUE: float = 100.0`.
  - [x] `static func clamp_fatigue(value: float) -> float` → `clampf(value, MIN_FATIGUE, MAX_FATIGUE)` (modèle `clamp_morale`).
  - [x] **`static func accrual_per_tick(rate_per_day: float, tick_delta: float, day_duration_seconds: float) -> float`** : fatigue gagnée en un tick de travail = `rate_per_day * (tick_delta / day_duration_seconds)`. **Défensif** : `day_duration_seconds <= 0.0` → `0.0` (cohérent `DayPhaseMath.advance`). → la fatigue avance **au même rythme que `day_phase`** : cohérente x1/x2/x3 (via `Engine.time_scale` sur le delta) et gelée en pause (plus de tick). [Source: day_phase_math.gd#advance]
  - [x] **`static func overnight_recovery(end_fatigue: float, rest_per_day: float, overtime_bonus: float, did_overtime: bool) -> float`** : fatigue du lendemain matin = `clamp_fatigue(end_fatigue + (overtime_bonus if did_overtime else 0.0) - rest_per_day)`. (Le +15 heures sup' et le −25 repos sont appliqués **ensemble** au passage de nuit ; bornage final.)
  - [x] **Aucune** autre responsabilité ici (pas de seuil de risque = Story 2.2).

- [x] **Task 2 — Champs d'équilibrage Fatigue dans `SimBalance` (`scripts/systems/sim_balance.gd`)** (AC: #1, #2)
  - [x] **UPDATE** `scripts/systems/sim_balance.gd` : ajouter une section Story 2.1 avec `@export` typés + valeurs par défaut (le `.tres` reste vide → défauts du script, comme pour 1.7/1.8 ; **NE PAS éditer `sim_balance.tres`**) :
    - `@export var agent_initial_fatigue: float = 0.0` (fatigue de départ au tout premier matin) ;
    - `@export var fatigue_work_per_day: float = 25.0` (fatigue accumulée sur une **journée complète de travail** ; ~équilibre avec le repos pour un agent standard) ;
    - `@export var fatigue_rest_per_day: float = 25.0` (récupération par nuit — « repos −25/j », FR13) ;
    - `@export var fatigue_overtime_bonus: float = 15.0` (heures sup' — « +15/j », FR13).
  - [x] Commentaires `##` explicites (data-driven, tunables, zéro magic number). **Ne PAS** ajouter de seuil de risque/burnout (Story 2.2).

- [x] **Task 3 — Nouveau signal `EventBus.agent_fatigue_changed`** (AC: #1, #4)
  - [x] **UPDATE** `scripts/autoloads/event_bus.gd` : ajouter, dans une section « Story 2.1 », **un seul** signal **typé** `signal agent_fatigue_changed(agent_id: int, fatigue: int)` avec doc `##` (modèle **exact** `agent_morale_changed` : émis par l'agent **uniquement sur variation réelle** ; consommé par la fiche 1.9 et l'`AgentSpawner` pour le report inter-jour). **NE RIEN d'autre** modifier dans `event_bus.gd`.

- [x] **Task 4 — Jauge Fatigue sur l'`Agent` (`scripts/agents/agent.gd`)** (AC: #1, #2, #3)
  - [x] **UPDATE** `scripts/agents/agent.gd`. **Préserver** tout le comportement existant (mouvement, sollicitations, moral, états, cycle de journée). Ajouts **strictement calqués sur la jauge Moral** :
    - `var _fatigue: float = 0.0` (doc : jauge Fatigue 0-100, Story 2.1 ; lue par la fiche).
    - **`setup(...)`** : ajouter un paramètre `initial_fatigue: float = 0.0` (après `initial_morale`) → `_fatigue = FatigueMath.clamp_fatigue(initial_fatigue)`. `const FatigueMathC := preload(...)` **ou** usage direct du `class_name FatigueMath` (cohérent `MoraleMath`, qui est utilisé via son `class_name`). **Préserver** la signature existante en ajoutant le paramètre **en dernier avec défaut** (rétrocompat des appels).
    - **`func get_fatigue() -> int: return roundi(_fatigue)`** (modèle `get_morale`).
    - **`func adjust_fatigue(delta: float) -> void`** : `var old := _fatigue` ; `_fatigue = FatigueMath.clamp_fatigue(_fatigue + delta)` ; `if _fatigue != old: EventBus.agent_fatigue_changed.emit(agent_id, roundi(_fatigue))` (modèle **exact** `adjust_morale` — émission **sur variation réelle uniquement**).
  - [x] **Accumulation au travail dans `_on_simulation_tick`** (AC3, NFR2) : utiliser le paramètre `tick_delta` (actuellement ignoré → le **renommer** de `_tick_delta` en `tick_delta` et l'utiliser). Quand l'agent **travaille effectivement** — réutiliser une condition cohérente avec `is_eligible_for_solicitation` **moins** la contrainte « pas de sollicitation » : c.-à-d. `_arrived_at_post and not _leaving and not _at_desk and not _heading_to_desk and not _is_evening()` → `adjust_fatigue(FatigueMath.accrual_per_tick(_BALANCE.fatigue_work_per_day, tick_delta, GameManager.day_duration_seconds))`.
    - **Préloader `_BALANCE`** : ajouter `const _BALANCE: SimBalance = preload("res://data/balance/sim_balance.tres")` (modèle HUD/AgentCard/GameManager) si absent.
    - **Ne PAS** ajouter de `_process`/`_physics_process` pour la fatigue (NFR1/NFR2 : 100 % sur `SimClock`).
  - [x] **Ne RIEN modifier d'autre** : `_decide`, mouvement, sollicitations, moral, départ restent inchangés (le départ `_depart()` continue d'émettre `agent_departed` puis `queue_free` — la fatigue finale a déjà été propagée par `agent_fatigue_changed` au fil du travail, cf. report inter-jour Task 6).

- [x] **Task 5 — Archétype : drapeau `does_overtime` + fabrique (`agent_archetype.gd`, `agent_factory.gd`, `.tres`)** (AC: #2, #4)
  - [x] **UPDATE** `scripts/agents/agent_archetype.gd` : ajouter `@export var does_overtime: bool = false` avec doc `##` (« fait des heures sup' par défaut → +15 fatigue/nuit, Story 2.1 ; le réglage joueur est la Story 2.3 »). **Purement additif.**
  - [x] **UPDATE** `data/agents/archetype_overtimer.tres` : ajouter `does_overtime = true` (archétype « Heures sup »). **Ne PAS** toucher `archetype_steady.tres` (`does_overtime` reste à `false` par défaut).
  - [x] **UPDATE** `scripts/agents/agent_factory.gd` : `create(...)` reçoit un paramètre `initial_fatigue: float = 0.0` (en dernier, défaut) et le transmet à `agent.setup(...)`. **Préserver** la signature existante + les autres paramètres.

- [x] **Task 6 — Roster persistant dans `AgentSpawner` (`scripts/world/agent_spawner.gd`)** (AC: #1, #2, #4)
  - [x] **UPDATE** `scripts/world/agent_spawner.gd`. **Préserver** : `_clear_agents()`, l'usage de `_ARCHETYPES`/`_BALANCE`, `post_world_positions`/`entrance_world`/`desk_world`, l'instanciation via `AgentFactoryC.create` + `add_child` + placement `door_slot`. **Objectif** : au lieu de créer une **cohorte neuve à ids neufs** chaque matin, **réutiliser un roster stable** (mêmes ids/archétypes) en **reportant la fatigue**.
  - [x] État ajouté :
    - `var _roster: Array = []` — entrées `{ "id": int, "archetype": AgentArchetype, "fatigue": float }`.
    - `var _fatigue_by_id: Dictionary = {}` — `id → float`, **suivi en direct** de la fatigue courante de chaque agent présent (modèle HUD `_morale_by_agent`).
    - `var _roster_built: bool = false`.
  - [x] `_ready()` : **préserver** `EventBus.day_started.connect(_on_day_started)` ; **ajouter** `EventBus.agent_fatigue_changed.connect(_on_agent_fatigue_changed)`.
  - [x] `_on_agent_fatigue_changed(agent_id, fatigue)` : `_fatigue_by_id[agent_id] = float(fatigue)` (mémorise la dernière fatigue connue **avant** que l'agent ne parte le soir — modèle « instantané robuste » du bilan 1.10 : un agent qui `queue_free` le soir a déjà propagé sa fatigue par signal).
  - [x] `_on_day_started(day)` :
    1. `_clear_agents()` (inchangé).
    2. **Construire le roster au tout premier matin** (`if not _roster_built:`) : pour `i` dans `count = mini(_BALANCE.agent_count, posts.size())`, créer une entrée `{ id = _next_id++, archetype = _ARCHETYPES[i % size], fatigue = _BALANCE.agent_initial_fatigue }`. `_roster_built = true`.
    3. **Sinon (jours suivants) : report inter-jour** — pour chaque entrée du roster : `var end_f := _fatigue_by_id.get(rec.id, rec.fatigue)` ; `rec.fatigue = FatigueMath.overnight_recovery(end_f, _BALANCE.fatigue_rest_per_day, _BALANCE.fatigue_overtime_bonus, rec.archetype.does_overtime)`.
    4. **(Ré)instancier les agents du roster** : pour chaque entrée (index `i` → réutiliser `posts[i]`, `door_slot` étalé comme aujourd'hui), `AgentFactoryC.create(rec.id, rec.archetype, posts[i], entrance/door_slot, desk, _BALANCE.evening_phase, _BALANCE.agent_initial_morale, rec.fatigue)` ; placer + `add_child`. **Réinitialiser** `_fatigue_by_id[rec.id] = rec.fatigue` (reseed pour le suivi du nouveau jour).
    5. `Log.info(...)` (jour, nb agents, éventuellement fatigues — utile au debug).
  - [x] **Garde-fou** : le `_next_id` n'incrémente **que** lors de la construction initiale du roster (plus d'ids neufs chaque jour). Le nombre d'agents est figé par le roster (recrutement = Épic 3).
  - [x] **Ne PAS** émettre de nouveau signal ici ; `agent_spawned`/`agent_departed` restent émis par l'`Agent` (inchangé) → HUD/fiche/bilan continuent de fonctionner.

- [x] **Task 7 — Affichage Fatigue sur la fiche (`scripts/ui/agent_card.gd` + `scenes/ui/agent_card.tscn`)** (AC: #1)
  - [x] **UPDATE** `scenes/ui/agent_card.tscn` : ajouter un `Label` **`%FatigueLabel`** (`unique_name_in_owner = true`, `text = "Fatigue : —"`) dans `Card/Margin/VBox`, **juste après** `%MoraleLabel` (avant `%ActionsHint`). **Préserver** tous les nœuds existants (Card/Margin/VBox, NameLabel, MoraleLabel, ActionsHint, LinkButton, DayOffButton, CloseButton).
  - [x] **UPDATE** `scripts/ui/agent_card.gd`. **Préserver** tout le comportement Moral/fermeture/anti-fantôme. Ajouts calqués sur le Moral :
    - `@onready var _fatigue_label: Label = %FatigueLabel`.
    - `var _shown_fatigue: int = -1`.
    - `_ready()` : **ajouter** `EventBus.agent_fatigue_changed.connect(_on_agent_fatigue_changed)` (abonnement persistant, filtré sur `_agent_id` comme le moral).
    - `show_for(agent)` : après `_render_morale(...)`, **ajouter** `_render_fatigue(agent.get_fatigue())`.
    - `hide_card()` : **ajouter** `_shown_fatigue = -1`.
    - `_on_agent_fatigue_changed(agent_id, fatigue)` : `if agent_id == _agent_id and is_showing(): _render_fatigue(fatigue)` (live).
    - `_render_fatigue(fatigue: int)` : `_shown_fatigue = fatigue` ; `_fatigue_label.text = "Fatigue : %d" % fatigue`. **PAS de couleur de seuil** (le signal visuel de risque ≥80 est la Story 2.2 — ne pas anticiper de seuil).
    - **Getter de test** : `func displayed_fatigue() -> int: return _shown_fatigue`.
  - [x] **Mettre à jour la doc d'en-tête** de `agent_card.gd` : mentionner l'ajout de la jauge Fatigue (lecture + live), en précisant que le **seuil de risque (couleur/indicateur) est la Story 2.2**.

- [x] **Task 8 — Test unitaire pur `tests/unit/test_fatigue.gd`** (AC: #1, #2, #3)
  - [x] Créer `tests/unit/test_fatigue.gd` (`extends SceneTree`, **modèle EXACT `tests/unit/test_morale.gd`** : runner headless `--script`, `_check`, `TEST_RESULT=PASS/FAIL`, `quit(0/1)`).
  - [x] `const FM := preload("res://scripts/systems/fatigue_math.gd")`.
  - [x] `_test_clamp_fatigue()` : −10 → 0 ; 150 → 100 ; 50 → 50 ; bornes 0/100 incluses.
  - [x] `_test_accrual_per_tick()` : sur une journée complète, la somme des accruals = `rate_per_day` (ex. `accrual_per_tick(25, dt, D)` × (D/dt) ≈ 25 — vérifier 1 tick : `accrual_per_tick(25, 1.0, 10.0) == 2.5`) ; **défensif** : `day_duration <= 0` → `0.0`.
  - [x] `_test_overnight_recovery()` : sans heures sup' : `overnight_recovery(40, 25, 15, false) == 15` ; avec heures sup' : `overnight_recovery(40, 25, 15, true) == 30` ; bornage bas : `overnight_recovery(10, 25, 15, false) == 0` ; bornage haut : `overnight_recovery(95, 25, 15, true) == 85` (95+15-25). 
  - [x] **Note `--script`** : en mode `--script`, les autoloads ne sont PAS chargés → `FatigueMath` est pur (aucune dépendance autoload), donc OK (comme `MoraleMath`).

- [x] **Task 9 — Smoke d'intégration `--fatigue-smoke` (`scripts/main/main.gd`)** (AC: #1, #2, #3, #4)
  - [x] **UPDATE** `scripts/main/main.gd` : ajouter `_run_fatigue_smoke_and_quit()` (modèle `_run_card_smoke_and_quit` / `_run_report_smoke_and_quit` ; réutiliser `_real_wait`, `_find_agent_by_id`). Récupérer `agents_root`, `solicitations`, `selection` (`SelectionController`), `card` (`AgentCard`), `report` (`DayReport`).
    - **Pré** : `solicitations.rate_override = 0.0` (pas de sollicitation parasite), `set_speed(3)`, `await _real_wait(4.0)` (agents arrivés, au travail). Mémoriser un agent et son id ; capturer `fatigue0 = agent.get_fatigue()` (≈ 0 au tout premier matin).
    - **(AC1 accumulation)** : `await _real_wait(2.0)` (travail) → `agent.get_fatigue() > fatigue0` (la fatigue monte au travail).
    - **(AC1 fiche)** : `selection.handle_agent_click(agent)` → `card.is_showing()` et `card.displayed_fatigue() == agent.get_fatigue()` ; baisser/monter via le travail encore un peu et vérifier que `card.displayed_fatigue()` **suit** (live via `agent_fatigue_changed`). Refermer (`selection.handle_empty_click()`).
    - **(AC4 report inter-jour + AC2 heures sup')** : mémoriser, pour un agent **« Heures sup »** (archétype `does_overtime`) et un agent **« Stable »**, leur `agent_id` et leur fatigue de fin de journée (`f_end`). Forcer la fin de journée : `GameManager.day_duration_seconds = 1.0`, `set_speed(3)`, `await _real_wait(2.0)` → bilan affiché (`report.is_showing()`), `GameManager.is_awaiting_day_review()`. Valider : `report.confirm()` (→ `start_next_day` → nouveau matin). `await _real_wait(2.0)` (agents du nouveau matin spawnés).
      - **Mêmes ids** : `_find_agent_by_id(agents_root, stable_id) != null` **et** `_find_agent_by_id(agents_root, overtime_id) != null` (le roster a ramené les **mêmes** agents).
      - **Report + repos** : pour l'agent **Stable**, fatigue du nouveau matin ≈ `clamp(f_end_stable - 25)` (repos −25, pas d'heures sup').
      - **Heures sup'** : pour l'agent **« Heures sup »**, fatigue du nouveau matin ≈ `clamp(f_end_overtime + 15 - 25)` (= `f_end_overtime - 10`). Comparer le **différentiel** Heures-sup vs Stable (l'overtimer doit avoir **+15** de fatigue de nuit relative, à `f_end` comparable) **ou** vérifier la formule directement avec une tolérance ±1-2 (la fatigue de fin de journée peut différer légèrement selon le temps de travail). *(Préférer une assertion robuste : `overtime_morning - stable_morning_equiv` cohérent avec +15, ou vérifier `morning ≈ FatigueMath.overnight_recovery(f_end, 25, 15, does_overtime)` recomputé.)*
    - Restaurer overrides (`rate_override = -1.0`, etc.), `set_speed(1)`, `Engine.time_scale = 1.0`. **Respiration** `await _real_wait(0.5)` avant `quit` (agents du dernier matin fraîchement spawnés — éviter le faux « resources still in use at exit », cf. apprentissage 1.10). `print("FATIGUE_SMOKE ...")` + `FATIGUE_SMOKE_RESULT=PASS/FAIL` + `get_tree().quit(0/1)`.
  - [x] Brancher `--fatigue-smoke` dans `_ready()` (nouvelle branche `elif args.has("--fatigue-smoke")`) **sans toucher aux 10 branches existantes** (`--measure-fps`/`--sim`/`--time`/`--solicitation`/`--decision`/`--resolution`/`--queue`/`--hud`/`--card`/`--report`).
  - [x] **Piège lambda GDScript (capture par valeur)** : tout compteur/mémo via **variables membres** de `main.gd` (apprentissages 1.4/1.6/1.7). Ici on lit surtout des getters → peu de captures.
  - [x] **Non-régression** : **9 suites unitaires** PASS (les 8 existantes + `test_fatigue`) ; **11 smokes** PASS (les 10 existants + `--fatigue`). Vérifier **explicitement** que la persistance du roster ne casse **pas** `--sim-smoke` (compte `spawned>=5`/`departed>=5` : un agent qui part le soir émet toujours `agent_departed` ; le matin suivant ré-émet `agent_spawned` pour les mêmes ids → comptes ≥ 5 sur > 1 journée) ni `--report-smoke`/`--time-smoke` (enchaînement des journées 1.10). `--measure-fps` → **≥ 60** (NFR1/NFR2).

## Dev Notes

### Contexte & objectif

L'Épic 1 a livré la **boucle native complète** (agents, temps, sollicitations, décisions, file/Moral, HUD, fiche, **bilan + enchaînement des journées** gaté en 1.10). L'Épic 2 « fait vivre » l'open space ; la **Story 2.1** pose la **première jauge par-agent de bien-être** : la **Fatigue (0-100)**, qui monte au travail, récupère la nuit, grimpe avec les heures sup', et se lit sur la fiche. C'est la **fondation** de la spirale fatigue → **burnout** (2.2) et du **levier de gestion du temps de travail** (2.3). [Source: epics.md#Épic-2 ; #Story-2.1 ; FR13]

### ⚠️ Décision de conception clé n°1 : **roster persistant** (mêmes agents d'un jour à l'autre)

**Choix validé avec le porteur (portée « roster persistant »).** L'Épic 1 recrée une **cohorte neuve à ids neufs** chaque matin (`AgentSpawner._on_day_started` incrémente `_next_id` à chaque spawn). Or la Fatigue n'a de sens que **dans la durée** : « repos −25/**jour** », « heures sup' +15 en **fin de journée** », et les stories suivantes l'exigent explicitement (**2.2** burnout « indispo **plusieurs jours** », **2.3** « **jour off** »). 2.1 introduit donc un **roster stable** dans `AgentSpawner` : un tableau d'entrées `{id, archetype, fatigue}` construit **une seule fois** (premier matin) puis **réutilisé** chaque matin (mêmes ids/archétypes), avec la **fatigue reportée** d'un jour à l'autre.

**Comment la fatigue survit au départ du soir** (même piège que l'instantané moral du bilan 1.10) : les agents `queue_free()` le soir (départ échelonné **avant** le `day_ended`). On ne peut donc pas lire leur fatigue « au moment du bilan ». Solution : `AgentSpawner` **suit la fatigue en direct** via le nouveau signal `agent_fatigue_changed` (`_fatigue_by_id[id] = fatigue`), qui porte toujours la **dernière valeur connue** avant le départ. À `day_started`, on recalcule la fatigue de nuit (`FatigueMath.overnight_recovery`) et on respawn. [Source: agent_spawner.gd ; 1-10…md (instantané robuste aux départs) ; agent.gd#_depart]

> **Portée bornée du report** : seule la **fatigue** est reportée. Le **Moral repart à sa valeur initiale** chaque matin (comportement Épic 1 **inchangé** — éviter une régression de comportement non demandée ; la dynamique du moral inter-jour est 2.2/2.5). La persistance est **en mémoire** (session) ; la sauvegarde disque est `SaveManager`/Épic 7.

### ⚠️ Décision de conception clé n°2 : la jauge Fatigue est un **jumeau de la jauge Moral**

Tout est déjà en place pour le Moral (1.7) : valeur sur l'`Agent` (`_morale`/`get_morale`/`adjust_morale`), bornage par module pur (`MoraleMath`), émission **sur variation réelle** d'un signal `EventBus` (`agent_morale_changed`), affichage **live** sur la fiche (filtré sur `_agent_id`). La Fatigue **réplique ce patron à l'identique** (`_fatigue`/`get_fatigue`/`adjust_fatigue`, `FatigueMath`, `agent_fatigue_changed`, `%FatigueLabel`). **Réutiliser le patron, ne pas en inventer un autre.** Différences : (a) l'**accumulation** de la fatigue vit **dans l'`Agent`** (au travail, sur `SimClock`), alors que celle du moral vivait dans `DeskQueue` (impatience) ; (b) **pas de seuil/couleur** pour la fatigue en 2.1 (le signal de risque ≥80 est 2.2). [Source: agent.gd L24-26/L229-244 ; morale_math.gd ; event_bus.gd L51-56 ; agent_card.gd L69-94]

### ⚠️ Décision de conception clé n°3 : accumulation **proportionnelle à la phase de journée** (NFR2)

La fatigue monte **dans `_on_simulation_tick`** (pas de `_process`) **uniquement quand l'agent travaille**. Pour rester **cohérente à toutes les vitesses et gelée en pause** sans dépendre du nombre de ticks, on l'incrémente **proportionnellement à l'avance de `day_phase`** : `accrual_per_tick = rate_per_day * (tick_delta / day_duration_seconds)` — exactement la fraction de journée écoulée ce tick (cf. `DayPhaseMath.advance`). Ainsi une **journée complète de travail** ajoute ≈ `fatigue_work_per_day`, quelle que soit la durée de journée ou la vitesse (le `tick_delta` est déjà scalé par `Engine.time_scale`, et en pause `SimClock` n'émet plus → fatigue gelée). Le `tick_delta` est **déjà fourni** par `SimClock.simulation_tick` mais **actuellement ignoré** par l'agent (`_on_simulation_tick(_tick_delta)`) → le **renommer et l'utiliser**. [Source: sim_clock.gd#simulation_tick ; day_phase_math.gd#advance ; game_manager.gd#_on_simulation_tick ; NFR2]

### Quand l'agent « travaille » (condition d'accumulation)

Réutiliser la sémantique d'éligibilité déjà éprouvée (`is_eligible_for_solicitation`) **sans** la contrainte « pas de sollicitation » : `_arrived_at_post and not _leaving and not _at_desk and not _heading_to_desk and not _is_evening()`. Un agent qui se déplace, attend au bureau, repart, ou est en soirée **n'accumule pas** (ou plus). *(Un agent en sollicitation/au bureau ne « travaille » pas à son poste ; l'inclure ou non est un détail d'équilibrage — pour 2.1, on n'accumule qu'au poste, simple et lisible.)* [Source: agent.gd#is_eligible_for_solicitation L221-223]

### « Heures sup' » en 2.1 = propriété d'archétype (le réglage joueur est 2.3)

L'AC2 parle d'un agent qui « fait des heures sup' ». En 2.1, **aucun réglage joueur** (= Story 2.3) : on s'appuie sur l'**archétype**. L'archétype « Heures sup » (`archetype_overtimer.tres`, `departure_offset=0.15` → part plus tard) reçoit un drapeau **data-driven** `does_overtime = true` ; à la nuit, ces agents prennent le **+15** (en plus du −25 repos). Les boutons « Jour off » de la fiche **restent désactivés** (placeholder 1.9). Le « **+prod du jour** » de l'épic est **hors périmètre** (aucune production avant l'Épic 3). [Source: epics.md#Story-2.1 AC2 / #Story-2.3 ; archetype_overtimer.tres ; agent_archetype.gd ; 1-9…md (boutons fiche désactivés)]

### Lecture des fichiers UPDATE (état actuel à préserver)

- **`scripts/agents/agent.gd`** — `class_name Agent extends CharacterBody3D` ; jauge Moral complète (`_morale`/`get_morale`/`adjust_morale`/`agent_morale_changed`) ; `setup(id, archetype, post, exit, desk, evening_phase, initial_morale=100.0)` ; `_on_simulation_tick(_tick_delta)` → `_decide()` (le `tick_delta` est **ignoré**) ; `is_eligible_for_solicitation()`. **Ajouter** la jauge Fatigue (jumelle du Moral) + l'accumulation dans le tick + le préchargement `_BALANCE`. **Préserver** mouvement/sollicitations/moral/états/départ. [Source: lecture directe agent.gd]
- **`scripts/world/agent_spawner.gd`** — `_on_day_started` : `_clear_agents()` + crée `agent_count` agents avec `_next_id++` (ids neufs chaque jour). **Remplacer** la cohorte neuve par le **roster persistant** (mêmes ids, fatigue reportée) ; **suivre** `agent_fatigue_changed`. **Préserver** positions/porte étalée/`AgentFactoryC.create`. [Source: lecture directe agent_spawner.gd]
- **`scripts/agents/agent_factory.gd`** — `create(id, archetype, post, exit, desk, evening_phase, initial_morale=100.0)`. **Ajouter** `initial_fatigue=0.0` (dernier, défaut) et le transmettre à `setup`. [Source: lecture directe agent_factory.gd]
- **`scripts/agents/agent_archetype.gd`** — `display_name`/`move_speed`/`tint`/`departure_offset`. **Ajouter** `does_overtime: bool = false` (additif). [Source: lecture directe agent_archetype.gd]
- **`data/agents/archetype_overtimer.tres`** — archétype « Heures sup », `departure_offset=0.15`. **Ajouter** `does_overtime = true`. **Ne pas** toucher `archetype_steady.tres`. [Source: lecture directe .tres]
- **`scripts/systems/sim_balance.gd`** — Resource d'équilibrage (le `.tres` est **vide** → défauts du script). **Ajouter** les 4 champs Fatigue. **Ne PAS** éditer `sim_balance.tres`. [Source: lecture directe sim_balance.gd ; sim_balance.tres]
- **`scripts/autoloads/event_bus.gd`** — signaux typés snake_case au passé. **Ajouter** `agent_fatigue_changed(agent_id, fatigue)` (jumeau de `agent_morale_changed`). **Ne RIEN d'autre** modifier. [Source: lecture directe event_bus.gd L51-56]
- **`scripts/ui/agent_card.gd`** + **`scenes/ui/agent_card.tscn`** — fiche avec `%MoraleLabel` (live via `agent_morale_changed` filtré). **Ajouter** `%FatigueLabel` + son rendu live (jumeau du Moral, **sans** couleur de seuil). **Préserver** identité/moral/fermeture/anti-fantôme/boutons désactivés. [Source: lecture directe agent_card.gd/.tscn]
- **`scripts/main/main.gd`** — 10 harnais + helpers (`_find_agent_by_id`/`_real_wait`/…). **Ajouter** `--fatigue-smoke` (+ branche `_ready`) en réutilisant les helpers. **Préserver** les 10 harnais (dont `--time`/`--resolution`/`--report` modifiés en 1.10). [Source: lecture directe main.gd]
- **`tests/unit/test_morale.gd`** — modèle **exact** du runner `--script` pour `test_fatigue.gd`. [Source: lecture directe test_morale.gd]

> **Important** : une story doit laisser le système **fonctionnel de bout en bout**. Au-delà des AC, toute la boucle 1.1→1.10 doit rester opérationnelle — **et le passage au roster persistant ne doit casser ni les comptes spawn/départ (`--sim-smoke`), ni l'enchaînement des journées (`--time`/`--resolution`/`--report`-smoke), ni le HUD/la fiche/le bilan** (qui consomment `agent_spawned`/`agent_departed`/`agent_morale_changed` — toujours émis).

### Performance (NFR1/NFR2)

L'accumulation de fatigue est **100 % sur `SimClock`** (~3 Hz, `_on_simulation_tick`), une simple addition bornée par agent : coût négligeable. **Aucun `_process`/`_physics_process`** ajouté. La fiche reste événementielle. 60 FPS attendus inchangés (1.10 mesurait 144 FPS). [Source: NFR1/NFR2 ; 1-9…/1-10…md]

### Direction artistique / UI

La fiche affiche « Fatigue : NN » en texte natif (DA claire « Severance »), **sans** signal de seuil couleur (le risque ≥80 — couleur/indicateur au-dessus de la tête, état avachi — est la Story 2.2 / Épic 6). Aucun juice ici. [Source: epics.md#Story-2.2/#Épic-6 ; NFR7]

### Project Structure Notes

- Nouveau module pur conforme à la structure (`scripts/systems/` pour la logique pure d'équilibrage, cf. `morale_math.gd`/`hud_math.gd`) : `scripts/systems/fatigue_math.gd`. Nouveau test : `tests/unit/test_fatigue.gd` (modèle `test_morale.gd`).
- Fichiers modifiés : `scripts/agents/agent.gd`, `scripts/world/agent_spawner.gd`, `scripts/agents/agent_factory.gd`, `scripts/agents/agent_archetype.gd`, `data/agents/archetype_overtimer.tres`, `scripts/systems/sim_balance.gd`, `scripts/autoloads/event_bus.gd`, `scripts/ui/agent_card.gd`, `scenes/ui/agent_card.tscn`, `scripts/main/main.gd`.
- Aucune nouvelle dépendance/addon. `FatigueMath` a un `class_name` (module pur, comme `MoraleMath`/`HudMath`) ; aucun nouveau nœud de scène (donc pas de `class_name` interdit). Le `.tres` d'équilibrage **n'est pas édité** (défauts du script). [Source: game-architecture.md#Project-Structure ; #System-Location-Mapping ; #Consistency-Rules (`MAX_FATIGUE` en UPPER_SNAKE)]

### Project Context Rules

- _Aucun `project-context.md` présent dans le dépôt._ Règles applicables (archi + stories 1.1-1.10) : **`EventBus`-only** (snake_case au passé ; nouveau `agent_fatigue_changed` émis par l'agent sur variation réelle) ; **pas de chemins de nœuds absolus** (`@onready`/`%UniqueName`) ; **`.tres` pour l'équilibrage** (zéro magic number — 4 champs fatigue ajoutés au script, `.tres` vide) ; **logique pure dans des modules `*_math.gd` avec `class_name`** (testables `--script`) ; **GDScript typé** (import 0/0) ; autoload **`Log`** (pas `Logger`) ; **pas de `class_name` sur un nœud de scène** ; **erreurs non fatales** (NFR11) ; **calculs de sim sur `SimClock`** (NFR2) ; **60 FPS** (NFR1) ; en mode `--script` les autoloads ne sont **pas** chargés (les modules purs n'en dépendent pas). [Source: game-architecture.md#Event-System/#Configuration/#Data-Patterns/#Consistency-Rules ; 1-7…/1-8…/1-10…md]
- **Outillage MCP** (GoPeak Godot MCP + Context7) prévu par l'archi — **non bloquant** ici. [Source: game-architecture.md#AI-Development-Tooling]

### References

- [Source: epics.md#Story-2.1] — jauge Fatigue 0-100 ; évolue au travail, repos −25/j ; heures sup' +15 en fin de journée (+prod) ; visible sur la fiche ; calcul via `SimClock` (NFR2).
- [Source: epics.md#FR13] — « Chaque agent possède une jauge Fatigue (0-100) : heures sup +15/j, repos -25/j ; ≥80 = risque de burnout ; =100 = craquage (indispo plusieurs jours + malus moral + contagion). » *(≥80/=100 = Story 2.2.)*
- [Source: epics.md#Story-2.2] — burnout (seuil ≥80, craquage =100, indispo plusieurs jours, `agent_burned_out`) : **hors périmètre 2.1** (exige le roster persistant que 2.1 pose).
- [Source: epics.md#Story-2.3] — réglage joueur du temps de travail (heures sup'/jour off/départ anticipé) : **hors périmètre 2.1** ; « heures sup' » ici = archétype.
- [Source: epics.md#Story-1.7] — jauge Moral (patron exact répliqué pour la Fatigue) : `get_morale`/`adjust_morale`/`agent_morale_changed`/`MoraleMath`.
- [Source: epics.md#Story-1.9] — fiche agent (affichage live d'une jauge par signal filtré ; boutons d'actions futures désactivés).
- [Source: epics.md#Story-1.10] — enchaînement gaté des journées (bilan → `start_next_day` → `day_started`) : c'est le **point d'application** du report inter-jour de la fatigue ; instantané robuste aux départs du soir (modèle pour `_fatigue_by_id`).
- [Source: game-architecture.md#Decision-Summary D5] — États agents en State Machine (idle/work/confer/queue/**fatigue/burnout**) : les **états** fatigue/burnout sont la Story 2.2 ; 2.1 ne pose que la **jauge**.
- [Source: game-architecture.md#Consistency-Rules] — constantes `UPPER_SNAKE` (`MAX_FATIGUE`) ; [#Configuration] équilibrage en `.tres` ; [#Data-Patterns] logique pure en modules ; [#Event-System] `EventBus` typé.
- [Source: game-architecture.md#NFR (NFR2)] — calculs de simulation sur `SimClock` sans coût notable.
- [Source: lecture directe] — `agent.gd` (jauge Moral + `_on_simulation_tick` + `is_eligible_for_solicitation`), `agent_spawner.gd` (cohorte neuve à remplacer par roster), `agent_factory.gd`/`agent_archetype.gd`/`.tres` (overtime), `morale_math.gd`/`test_morale.gd` (modèles), `event_bus.gd` (`agent_morale_changed`), `agent_card.gd`/`.tscn` (jauge live filtrée), `sim_balance.gd` (défauts), `main.gd` (harnais + helpers).
- [Source: 1-10…md] — apprentissage « respiration avant `quit()` » dans les smokes qui respawnent des agents juste avant de quitter (faux « resources still in use at exit »).

## Dev Agent Record

### Agent Model Used

Claude Opus 4.8 (claude-opus-4-8)

### Debug Log References

- Moteur : Godot 4.6.3-stable (`Godot_v4.6.3-stable_win64_console.exe`), exécution **headless réelle** (import + run, jamais « au jugé »).
- **Baseline avant dev** : import 0/0 (commit `17a1bf7`).
- Import après implémentation : `godot --headless --path open_space --import` → **0 erreur / 0 warning**. Nouvelle classe globale `FatigueMath` enregistrée ; `fatigue_math.gd`/`test_fatigue.gd` reconnus.
- Unitaire pur : `--script res://tests/unit/test_fatigue.gd` → `TEST_RESULT=PASS` (clamp 0-100 ; `accrual_per_tick` proportionnel à la phase + défensif durée≤0 ; `overnight_recovery` repos −25 / +15 heures sup' / bornage haut-bas).
- Intégration : `godot --headless --path open_space -- --fatigue-smoke` → `FATIGUE_SMOKE accrual=true f=2->5 card=true live=true report=true same_roster=true morn_stable=0 morn_overtime=13`, `FATIGUE_SMOKE_RESULT=PASS`. Couvre AC1 (la fatigue monte au travail ; la fiche l'affiche et la suit en direct via `agent_fatigue_changed`), AC4 (les **mêmes ids** reviennent au matin = roster persistant), AC2 (l'agent « Heures sup » porte **+13** de fatigue de nuit de plus que le « Stable » → +15 heures sup' visible malgré le plancher 0 ; `morn_overtime=13>0` prouve le **report** ≠ reset).
- **Bug attrapé dans le smoke lui-même** (corrigé) : 1re version laissait `day_duration=1.0` + x3 pendant l'attente post-`confirm()` → le **jour 2 rebouclait aussitôt** et ses agents repartaient le soir (départs échelonnés : le « Stable » part avant le « Heures sup ») → roster introuvable (`same_roster=false`, `morn_stable=-1`). Fix : **restaurer une journée longue + vitesse normale AVANT** d'inspecter le nouveau matin.
- **Anti-spam fatigue** : `adjust_fatigue` n'émet `agent_fatigue_changed` que si la valeur **entière affichée** change (la fatigue s'accumule par fractions à chaque tick → comparer l'`int` évite un signal par tick, contrairement au moral qui varie par paliers entiers).
- **Non-régression** : **9 suites unitaires** PASS (8 existantes + `test_fatigue`) ; **10 smokes** PASS (`--sim`/`--time`/`--solicitation`/`--decision`/`--resolution`/`--queue`/`--hud`/`--card`/`--report`/`--fatigue`) — **aucun leak** au shutdown ; le passage au **roster persistant** ne casse ni les comptes spawn/départ (`--sim-smoke`) ni l'enchaînement des journées (`--time`/`--resolution`/`--report`). Perf : `--measure-fps` → **145** (≥ 60, NFR1/NFR2 ; accumulation 100 % sur `SimClock`, aucun `_process` ajouté).

### Completion Notes List

- **Jauge Fatigue livrée comme jumelle de la jauge Moral** : module pur `FatigueMath` (`clamp_fatigue`, `accrual_per_tick`, `overnight_recovery`), jauge `_fatigue` sur l'`Agent` (`get_fatigue`/`adjust_fatigue`), nouveau signal `EventBus.agent_fatigue_changed`, affichage `%FatigueLabel` sur la fiche (live, filtré). **Zéro réinvention** : patron 1.7/1.9 répliqué.
- **AC1 — accumulation sur `SimClock` (NFR2)** : la fatigue monte **dans `_on_simulation_tick`** uniquement quand l'agent travaille à son poste (pas en route/au bureau/en partance/le soir), proportionnellement à l'avance de la phase de journée (`accrual_per_tick = rate * tick_delta/day_duration`) → cohérente x1/x2/x3 et gelée en pause. Aucun `_process`/`_physics_process` ajouté. Visible et live sur la fiche.
- **AC2 — heures sup'** : drapeau d'archétype **data-driven** `does_overtime` (= `true` sur « Heures sup ») → +15 fatigue appliqués **la nuit** (en plus du repos −25) via `FatigueMath.overnight_recovery`. Le « +prod du jour » de l'épic est **hors périmètre** (aucune production avant l'Épic 3) — noté.
- **AC3 — perf** : 145 FPS, accumulation événementielle légère (une addition bornée par agent par tick à ~3 Hz).
- **AC4 / Décision n°1 — roster persistant** : `AgentSpawner` maintient un **roster stable** {id, archetype, fatigue} ; les **mêmes agents (mêmes ids)** reviennent chaque matin avec leur **fatigue reportée** (repos −25/nuit, +15 si heures sup'). La fatigue survit au `queue_free` du soir car elle est **suivie en direct** via `agent_fatigue_changed` (`_fatigue_by_id`), comme l'instantané robuste du bilan 1.10. `_next_id` n'incrémente plus qu'à la construction initiale.
- **Bornes respectées** : aucun seuil/indicateur de burnout (≥80/=100 = Story 2.2 — la fiche affiche la fatigue **sans couleur**) ; aucun réglage joueur du temps de travail (Story 2.3 — boutons « Jour off » de la fiche restent désactivés) ; aucune production ; aucune contagion/événement de vie ; **aucun report du Moral** (le moral repart à l'initial chaque matin, comportement Épic 1 inchangé) ; pas de sauvegarde disque (Épic 7) ; aucun nouvel agrégat HUD.
- **Système de bout en bout** : toute la boucle 1.1→1.10 reste opérationnelle (9 suites + 10 smokes PASS, 145 FPS, import 0/0) ; le roster persistant n'a cassé ni les comptes spawn/départ ni l'enchaînement des journées.

### File List

**Nouveaux fichiers (sous `open_space/`) :**
- `scripts/systems/fatigue_math.gd` (logique pure : `clamp_fatigue`, `accrual_per_tick`, `overnight_recovery`)
- `scripts/systems/fatigue_math.gd.uid`
- `tests/unit/test_fatigue.gd` (suite unitaire pure, modèle `test_morale.gd`)

**Fichiers modifiés :**
- `scripts/agents/agent.gd` (jauge `_fatigue` jumelle du moral : `get_fatigue`/`adjust_fatigue` + émission `agent_fatigue_changed` sur variation entière ; accumulation au travail dans `_on_simulation_tick` via `FatigueMath` ; param `initial_fatigue` dans `setup` ; preload `_BALANCE`)
- `scripts/world/agent_spawner.gd` (roster persistant : mêmes ids/archétypes, fatigue reportée la nuit ; suivi `agent_fatigue_changed`)
- `scripts/agents/agent_factory.gd` (param `initial_fatigue` transmis à `setup`)
- `scripts/agents/agent_archetype.gd` (drapeau `does_overtime`)
- `data/agents/archetype_overtimer.tres` (`does_overtime = true`)
- `scripts/systems/sim_balance.gd` (4 champs Fatigue : initial / work_per_day / rest_per_day / overtime_bonus ; `.tres` non édité)
- `scripts/autoloads/event_bus.gd` (signal `agent_fatigue_changed(agent_id, fatigue)`)
- `scripts/ui/agent_card.gd` (jauge Fatigue live filtrée + getter `displayed_fatigue` ; sans couleur de seuil)
- `scenes/ui/agent_card.tscn` (`%FatigueLabel`)
- `scripts/main/main.gd` (harnais `--fatigue-smoke` + branche `_ready` ; 10 harnais existants préservés)

## Change Log

| Date | Version | Description |
|---|---|---|
| 2026-06-23 | 0.11.0 | Implémentation Story 2.1 : Jauge Fatigue par agent + roster persistant. Nouveau module pur `FatigueMath` (bornage, accrual proportionnel à la phase de journée, récupération de nuit) ; jauge `_fatigue` sur l'`Agent` (jumelle du Moral) accumulée au travail sur `SimClock` (NFR2, aucun `_process`) ; nouveau signal `EventBus.agent_fatigue_changed` ; affichage Fatigue live sur la fiche (`%FatigueLabel`, sans couleur de seuil — le risque ≥80 est la Story 2.2). **Roster persistant** dans `AgentSpawner` : les mêmes agents (mêmes ids/archétypes) reviennent chaque matin avec leur fatigue reportée (repos −25/nuit, +15 heures sup' via le drapeau d'archétype `does_overtime`), la fatigue survivant au départ du soir grâce au suivi `agent_fatigue_changed`. Le Moral reste réinitialisé chaque matin (comportement Épic 1 inchangé). Tests : `test_fatigue` (unitaire pur) PASS ; `--fatigue-smoke` PASS (accumulation, fiche live, mêmes ids au matin, +15 heures sup' visible) ; non-régression 9 suites + 10 smokes PASS, 145 FPS, import 0/0. Hors périmètre (bornes posées) : burnout/seuils (2.2), réglage joueur du temps de travail (2.3), production (Épic 3), persistance disque (Épic 7). Statut → review. |
