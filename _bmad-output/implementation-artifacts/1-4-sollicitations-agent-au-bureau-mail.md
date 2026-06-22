---
baseline_commit: NO_VCS
---

# Story 1.4: Sollicitations : agent au bureau & mail

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a joueur,
I want que les agents me sollicitent de deux façons (en personne au bureau, ou par « mail » asynchrone),
so that je ressens la tension de l'attention (la file qui se forme + les mails qui clignotent).

## Acceptance Criteria

1. **Given** un agent à son poste a une **décision importante** à remonter **When** la sollicitation se déclenche **Then** il se déplace de son poste jusqu'au **bureau du joueur** (canal synchrone / présentiel) **And** il y reste en attente jusqu'à ce que le joueur le traite (il ne retourne pas travailler tant que la sollicitation est ouverte).
2. **Given** un agent a une **sollicitation moins urgente** **When** elle se déclenche **Then** un **« mail » clignotant** apparaît (canal asynchrone) **sans déplacer l'agent** (il continue de travailler à son poste).
3. **Given** une sollicitation existe (bureau **ou** mail) **When** je l'observe **Then** je peux l'**identifier visuellement** (indicateur distinct par canal) **et l'ouvrir d'un clic gauche** ; l'ouverture émet `EventBus.solicitation_opened(...)` (consommé par la pop-up de décision, Story 1.5) et **retire l'indicateur**.
4. **Given** la cadence d'apparition des sollicitations (et la répartition bureau/mail) **When** on l'ajuste **Then** elle se règle **uniquement** via `data/balance/sim_balance.tres` (zéro magic number dans la logique).

> **Frontière de cette story (lire absolument — périmètre volontairement borné) :**
> - **1.4 fait** : générer les sollicitations (2 canaux), amener l'agent au bureau (canal présentiel), afficher des indicateurs clignotants identifiables, rendre la sollicitation **cliquable**, émettre `solicitation_opened` à l'ouverture, retirer l'indicateur. Pacing data-driven `.tres`.
> - **1.4 NE FAIT PAS** (ne pas déborder) :
>   - **La pop-up de décision (contexte + 2-3 options)** → **Story 1.5**. Ici, ouvrir = émettre `solicitation_opened` + nettoyer l'indicateur. La 1.5 s'abonnera à ce signal pour afficher la pop-up.
>   - **File d'attente physique, patience (~45 s), jauge Moral** → **Story 1.7**. Ici : un seul point d'approche au bureau, pas de file ordonnée, pas de perte de patience/moral. Garder la cadence **basse** pour que deux agents se présentent rarement en même temps (chevauchement toléré et résolu en 1.7).
>   - **Le HUD persistant / compteur de file + mails en attente** → **Story 1.8**. Ici, on possède les **indicateurs individuels** (au-dessus des agents) ; la 1.8 ajoutera le **compteur agrégé** en s'abonnant à `solicitation_raised` / `solicitation_opened`.
>   - **La fiche agent au clic** → **Story 1.9**. Ici, le clic gauche n'ouvre **que** les sollicitations ; cliquer un agent **sans** sollicitation ouverte = **no-op** (la 1.9 étendra ce même handler de clic pour ouvrir la fiche).
>   - **Les vrais indicateurs au-dessus des têtes (art) & SFX de mail** → **Épic 6**. Ici : marqueur placeholder lisible (capsule/sprite teinté), pas d'art final.

## Tasks / Subtasks

- [x] **Task 1 — Modèle de données pur : `Solicitation` + canaux (testable `--script`)** (AC: #1, #2)
  - [x] Créer `scripts/decisions/solicitation.gd` (`class_name Solicitation extends RefCounted`) : champs `agent_id: int`, `channel: int`, `id: int` (identifiant incrémental). Définir l'enum **dans cette classe** : `enum Channel { DESK = 0, MAIL = 1 }` (source unique de vérité du canal, réutilisée par EventBus/UI/tests). Objet de données pur — **aucune** dépendance scène/autoload (modèle `agent_action.gd` / `agent_context.gd`).
  - [x] Créer `scripts/decisions/solicitation_math.gd` (`class_name SolicitationMath extends RefCounted`) : fonctions **pures** — `should_raise(roll: float, rate_per_tick: float) -> bool` (vrai si `roll < clamp(rate, 0, 1)`), `channel_for_roll(roll: float, desk_probability: float) -> int` (→ `Channel.DESK` si `roll < clamp(desk_probability,0,1)`, sinon `Channel.MAIL`). Pas d'autre logique ici (le RNG et le choix des agents vivent dans le système, Task 4). Modèle : `time_control.gd` / `day_phase_math.gd` (mapping/clamp purs, testables sans autoload).

- [x] **Task 2 — Enregistrer l'action `GO_TO_DESK` (parité natif ↔ LLM, ADR-1)** (AC: #1)
  - [x] Ajouter `GO_TO_DESK: StringName = &"go_to_desk"` à `scripts/agents/tools/action_registry.gd` et l'inclure dans `KNOWN`. **Règle d'or** : toute nouvelle capacité de locomotion d'agent passe par le registre, jamais codée en dur dans un brain (garantit qu'en Épic 5 le `LLMBrain` aura exactement la même action). **Préserver** les 4 actions existantes (`GO_TO_POST`, `WORK`, `IDLE`, `LEAVE`).
  - [x] **Ne PAS** créer d'action « raise_mail / raise_desk » côté brain : le **déclenchement** d'une sollicitation est une décision de **cadence/équilibrage** pilotée par le système (Task 4), pas une action de locomotion du FSM. Le brain consomme seulement l'**état** « j'ai une sollicitation bureau en cours » pour décider d'aller au bureau (Task 3). Voir Dev Notes « Pourquoi le pacing est dans le système, pas dans le brain ».

- [x] **Task 3 — Le `NativeBrain` envoie l'agent au bureau quand une sollicitation présentielle est en cours** (AC: #1, #2)
  - [x] Ajouter à `scripts/agents/brain/agent_context.gd` un champ `has_desk_solicitation: bool = false` (et le paramètre correspondant dans `_init`, en **conservant** l'ordre/les valeurs par défaut des champs existants `arrived_at_post`, `evening` pour ne pas casser les appels actuels — ajouter le nouveau **en dernier**).
  - [x] Modifier `scripts/agents/brain/native_brain.gd` — **priorité exacte** : `evening` → `LEAVE` ; **sinon** `has_desk_solicitation` → `GO_TO_DESK` ; **sinon** `not arrived_at_post` → `GO_TO_POST` ; **sinon** `WORK`. (Le soir prime : un agent qui doit partir ne va pas au bureau.) Garder le brain **pur** (aucun autoload). Voir Dev Notes pour le pseudo-code exact.
  - [x] **MAIL** : aucun changement de brain — l'agent au poste reste en `WORK`. Le canal mail ne déplace **jamais** l'agent (AC#2). Seul le système (Task 4) pose/retire l'indicateur mail.

- [x] **Task 4 — `SolicitationSystem` : cadence, RNG, suivi des sollicitations actives** (AC: #1, #2, #3, #4)
  - [x] Créer `scripts/decisions/solicitation_system.gd` (nœud, pas autoload) et l'instancier dans `scenes/world/open_space.tscn` à côté d'`AgentSpawner` (même schéma : nœud `Node` enfant d'`OpenSpace`). C'est l'**orchestrateur** des sollicitations (le `SimClock` et les agents restent agnostiques).
  - [x] S'abonner à `SimClock.simulation_tick`. À chaque tick : pour chaque agent **éligible** (à son poste, pas le soir, **sans** sollicitation déjà ouverte, **pas** déjà en route vers le bureau), tirer `roll = _rng.randf()` puis `SolicitationMath.should_raise(roll, balance.solicitation_rate_per_tick)`. Si vrai, tirer un 2ᵉ `randf()` → `SolicitationMath.channel_for_roll(...)` pour le canal, créer une `Solicitation`, l'enregistrer comme **active** (clé = `agent_id`), et l'appliquer (DESK ou MAIL). Émettre `EventBus.solicitation_raised(agent_id, channel)`.
  - [x] RNG **seedé** (`var _rng := RandomNumberGenerator.new()` ; `_rng.seed = ...` fixé pour reproductibilité des tests, ou `randomize()` au runtime — **documenter** le choix ; le harnais d'intégration force un état déterministe). **Une seule** sollicitation active par agent à la fois.
  - [x] **DESK** : appeler une API publique de l'agent (Task 5) qui pose `has_desk_solicitation = true` (→ le brain l'enverra au bureau au prochain tick) et qui demande à l'agent d'afficher son indicateur « bureau ». **MAIL** : appeler l'API qui affiche l'indicateur « mail » **sans** rien changer à la locomotion.
  - [x] Exposer `open_solicitation(agent_id: int) -> bool` : si une sollicitation active existe pour cet agent → émettre `EventBus.solicitation_opened(agent_id, channel)`, **retirer** l'indicateur, demander à l'agent de **repartir au poste** (clear de `has_desk_solicitation`), supprimer l'entrée active, retourner `true` ; sinon `false`. **C'est le point d'entrée commun du clic ET du test d'intégration** (l'injection souris est peu fiable en headless — voir Dev Notes « Tester le clic en headless »).

- [x] **Task 5 — Agent : aller au bureau, attendre, repartir + porter ses indicateurs** (AC: #1, #2, #3)
  - [x] `scripts/agents/agent.gd` — passer `has_desk_solicitation` dans le `AgentContext` construit par `_decide()`. Ajouter le cas `ActionRegistry.GO_TO_DESK` dans `_apply_action` : cible = `_desk_position` (fournie au `setup`, Task 6), `_sm.change_to(_move_state)`. Gérer l'**arrivée au bureau** dans `_on_destination_reached` via un flag dédié (`_at_desk`/`_heading_to_desk`) **distinct** de `_leaving` et `_arrived_at_post` → à l'arrivée : `halt()` + passer en attente (`_idle_state` ou `_work_state` immobile). **Ne pas** déclencher la logique « arrivé au poste » par erreur.
  - [x] API publiques appelées par le système (Task 4) : `raise_desk_solicitation()` (pose `has_desk_solicitation=true`, **et** `_arrived_at_post=false` pour qu'après résolution le brain réémette `GO_TO_POST` et ramène l'agent à son poste — réutilise la boucle existante), affiche l'indicateur DESK ; `raise_mail_solicitation()` affiche l'indicateur MAIL **sans** toucher la locomotion ; `clear_solicitation()` retire l'indicateur, `has_desk_solicitation=false`, et **réinitialise l'état d'approche bureau** (`_at_desk=false`) pour que l'agent retourne travailler (via `GO_TO_POST`→`WORK`). Ajouter `has_open_solicitation() -> bool` (utile au clic et au test).
  - [x] **Indicateur visuel placeholder, clignotant, par canal** : un nœud enfant `Node3D`/`Sprite3D`/`MeshInstance3D` **billboardé** au-dessus de la capsule (couleur/forme distincte DESK vs MAIL — ex. bulle « ! » vs « ✉ », ou simple cube teinté rouge/bleu). Clignotement via `_process(delta)` (oscillation de `modulate`/`visible`) → **pausable** (gèle proprement en pause, cohérent Story 1.3) et **scale avec `Engine.time_scale`**. Créer/retirer le marqueur dans les API ci-dessus. **Pas d'art final** (Épic 6).
  - [x] **Cible de clic** = le **corps de l'agent** (`CollisionShape3D` déjà présent sur la capsule) : le raycast caméra (Task 7) frappe l'agent ; pas besoin de collision sur le marqueur (purement visuel). Modèle unifié : cliquer l'agent porteur d'une sollicitation (bureau **ou** mail) l'ouvre.

- [x] **Task 6 — Position du « bureau du joueur » dans l'open space** (AC: #1)
  - [x] `scripts/world/open_space.gd` : ajouter `const _DESK_CELL: Vector2i = Vector2i(11, 11)` (coin du plateau 12×12, **hors** des `_POST_CELLS` et de `_ENTRANCE_CELL`) et une méthode `desk_world() -> Vector3` (modèle `entrance_world()`). Vérifier que la cellule est bien sur le NavMesh (le plateau entier est navigable) pour que l'agent puisse l'atteindre.
  - [x] Propager la position du bureau jusqu'à l'agent : `AgentSpawner._on_day_started` lit `_open_space.desk_world()` et la passe à `AgentFactoryC.create(...)` → `Agent.setup(...)`. **Étendre la signature** de `agent_factory.gd::create` et `agent.gd::setup` avec un paramètre `desk_position: Vector3` (stocké en `_desk_position`). **Préserver** tous les paramètres existants et l'ordre d'appel.

- [x] **Task 7 — Clic gauche : sélection par raycast caméra → ouvrir la sollicitation** (AC: #3)
  - [x] Déclarer l'action d'input `select_click` (bouton gauche souris, `button_index` 1) dans `project.godot` section `[input]`, au **format `InputEventMouseButton` exact** des actions `cam_zoom_*` existantes (voir Dev Notes « Format Input Map clic »). **Préserver** toutes les actions existantes (`cam_*`, `game_pause`, `speed_x*`). Jamais de bouton codé en dur dans la logique.
  - [x] Implémenter le handler de clic : soit dans `SolicitationSystem`, soit un petit nœud dédié `scripts/world/selection_controller.gd` dans `open_space.tscn`. Sur `select_click` (dans `_unhandled_input`), faire un **raycast caméra** : `var cam := get_viewport().get_camera_3d()` ; `from = cam.project_ray_origin(mpos)` ; `to = from + cam.project_ray_normal(mpos) * RAY_LEN` ; `get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))`. Si le collider (ou un de ses ancêtres) est un `Agent` → `SolicitationSystem.open_solicitation(agent.agent_id)`. Cliquer dans le vide ou un agent sans sollicitation = **no-op** (1.9 étendra). Pas de chemin de nœud absolu.
  - [x] **⚠️ Le handler de clic DOIT être `PROCESS_MODE_ALWAYS`** : on doit pouvoir ouvrir une sollicitation **même en pause** (le joueur met en pause pour réfléchir — cohérent avec le piège n°1 de la Story 1.3 sur l'input en pause). Régler `process_mode = Node.PROCESS_MODE_ALWAYS` sur ce nœud.

- [x] **Task 8 — Signaux EventBus pour 1.5 / 1.8** (AC: #3)
  - [x] Ajouter à `scripts/autoloads/event_bus.gd` : `signal solicitation_raised(agent_id: int, channel: int)` et `signal solicitation_opened(agent_id: int, channel: int)` (snake_case, au passé). **Préserver** les 9 signaux existants. Émettre **uniquement** ces signaux réellement utilisés (pas de signal mort).
  - [x] Documenter en commentaire que `solicitation_opened` est consommé par la **pop-up de décision (Story 1.5)** et que les deux signaux alimenteront le **compteur HUD (Story 1.8)**.

- [x] **Task 9 — Équilibrage data-driven** (AC: #4)
  - [x] Étendre `scripts/systems/sim_balance.gd` (`SimBalance`) avec : `@export var solicitation_rate_per_tick: float = 0.01` (probabilité qu'un agent éligible lève une sollicitation **par tick** ~3 Hz ; 0.01 ≈ ~1 sollicitation toutes ~33 s par agent — volontairement **rare** pour ne pas saturer avant la file 1.7) et `@export var desk_channel_probability: float = 0.4` (≈40 % bureau / 60 % mail, cohérent GDD : le présentiel = décisions importantes, plus rares). **Préserver** les champs existants (`day_duration_seconds`, `evening_phase`, `agent_count`).
  - [x] `data/balance/sim_balance.tres` : le fichier ne stocke que le `script` (les valeurs viennent des défauts `@export`). Vérifier après import que les nouveaux champs apparaissent. Si on veut des valeurs explicites dans le `.tres`, les y écrire — sinon les défauts du script suffisent (cohérent avec l'état actuel du `.tres`).

- [x] **Task 10 — Tests** (AC: #1, #2, #3, #4)
  - [x] **Pas de GUT** (addon non installé) : runner headless autonome `tests/unit/*.gd extends SceneTree`, `quit(0/1)`. **Rappel : en mode `--script`, AUCUN autoload n'est chargé** → ne tester que de la logique pure (sans `Log`/`EventBus`/`SimClock`/`GameManager`).
  - [x] `tests/unit/test_solicitation_math.gd` : `should_raise` (roll < / >= rate ; clamp rate hors [0,1]) ; `channel_for_roll` (→ DESK sous le seuil, MAIL au-dessus ; bornes 0.0/1.0) ; vérifier les valeurs d'enum `Solicitation.Channel.DESK/MAIL`.
  - [x] **Intégration (avec autoloads)** : ajouter un harnais `--solicitation-smoke` à `scripts/main/main.gd` (même esprit que `--sim-smoke` / `--time-smoke`). Forcer un état déterministe : `solicitation_rate_per_tick` élevé (ex. forcer la valeur sur l'instance `SimBalance` chargée par le système, ou seeder le RNG), journée assez longue pour ne pas wrapper. Vérifier : (a) au moins **1 sollicitation DESK** et **1 MAIL** émises via `EventBus.solicitation_raised` ; (b) un agent sollicité au **bureau s'est rapproché** de `desk_world()` (déplacement mesuré, modèle `--sim-smoke`) ; (c) `SolicitationSystem.open_solicitation(agent_id)` sur une sollicitation active **émet `solicitation_opened`** et **retire** l'état actif (`has_open_solicitation()` repasse à false). Imprimer `SOLICITATION_SMOKE adv... raised_desk=.. raised_mail=.. opened=..` + `SOLICITATION_SMOKE_RESULT=PASS/FAIL`, `quit(0/1)`.
  - [x] **Non-régression** : `test_agent_sim.gd`, `test_camera_math.gd`, `test_time_control.gd` toujours PASS ; `--sim-smoke`, `--time-smoke`, `--measure-fps` toujours PASS (l'ajout des sollicitations ne doit casser ni le cycle de journée, ni le contrôle du temps, ni la perf).

- [x] **Task 11 — Non-régression & état par défaut** (AC: tous ; NFR1, NFR2)
  - [x] Au lancement : aucune sollicitation active, aucun indicateur affiché, les agents arrivent/travaillent/repartent comme en 1.2/1.3. Les sollicitations n'apparaissent qu'une fois les agents **à leur poste**.
  - [x] Une sollicitation **gèle proprement en pause** (le système est abonné à `SimClock` qui ne tick plus en pause → aucune nouvelle sollicitation ; les indicateurs cessent de clignoter ; le clic d'ouverture reste possible). À `x2`/`x3`, la cadence suit naturellement (plus de ticks → plus de tirages) — cohérent avec `Engine.time_scale`.
  - [x] Import headless **0 erreur / 0 warning** (`untyped_declaration=1` → tout typer). Confirmer **60 FPS** open space peuplé avec indicateurs (`--measure-fps`).
  - [x] **Laisser le système fonctionnel de bout en bout** : caméra (1.1), simulation d'agents (1.2) et contrôle du temps (1.3) restent pleinement opérationnels après cette story.

## Dev Notes

### Contexte & objectif

Cette story branche la **première brique de la boucle cœur** (pilier #1 « l'attention du patron est LA ressource rare ») : les agents commencent à **solliciter le joueur**. Deux canaux, fidèles au GDD :
- **Bureau (présentiel, synchrone)** : décision importante → l'agent **quitte son poste et marche jusqu'au bureau du joueur**, où il attend. C'est la future tête de file (1.7).
- **Mail (asynchrone)** : sollicitation moins urgente → un **indicateur clignotant** apparaît **sans déplacer l'agent**.

La story s'arrête à : *générer*, *rendre identifiable*, *rendre cliquable*, *émettre `solicitation_opened`*. **Le contenu de la décision (pop-up 2-3 options) est la Story 1.5** ; la **file/patience/moral la 1.7** ; le **compteur HUD la 1.8** ; la **fiche agent la 1.9**. Respecter cette frontière est essentiel (voir l'encadré en tête).
[Source: epics.md#Story-1.4 ; gdd.md §Boucle-cœur (1. agent au bureau ou mail) ; gdd.md §Piliers #1]

### Stack technique imposée (NE PAS dévier)

- **Moteur : Godot 4.6.3-stable**, **GDScript typé statiquement** (`untyped_declaration=1` → **tout typer**, sinon warning à l'import). [Source: game-architecture.md#Decision-Summary D10]
- **Communication via `EventBus`** (signals typés, snake_case au passé) ; jamais d'appel direct en dur entre systèmes. [Source: game-architecture.md#Event-System ; #Architectural-Boundaries]
- **Jamais de chemins de nœuds absolus** — `@onready`, `%UniqueName`, signals, ou référence parent→enfant connue uniquement. [Source: game-architecture.md#Architectural-Boundaries]
- **Capacités d'agent via `ActionRegistry`** (golden rule ADR-1 : parité natif ↔ LLM). [Source: game-architecture.md#Novel-Pattern ; #Consistency-Rules]
- **Décisions/pop-ups → `scripts/decisions/`** (emplacement archi pour ce système). [Source: game-architecture.md#System-Location-Mapping]
- **Équilibrage `.tres`** dans `data/balance/` ; zéro magic number dans la logique. [Source: game-architecture.md#Configuration ; #Consistency-Rules]
- **Input = Input Map** (`project.godot`), jamais de scancode/bouton codé en dur. [Source: game-architecture.md#Engine-Provided-Architecture]

### ⚠️ Apprentissages critiques des Stories 1.1 → 1.3 (à respecter absolument)

- **L'autoload du logger s'appelle `Log`, PAS `Logger`** (`Logger` est une classe native Godot 4.6 → collision). Utiliser `Log.info/warn/error/debug`. (Les extraits d'archi montrant `Logger.info(...)` sont **illustratifs**.) [Source: 1-1…md ; 1-2…md ; 1-3…md#Apprentissages]
- **Les autoloads n'ont PAS de `class_name`** — accès par nom de singleton (`EventBus`, `SimClock`, `GameManager`, `ConfigService`, `Log`). [Source: 1-2…md ; 1-3…md]
- **GUT non installé** → runner headless autonome (`tests/unit/*.gd extends SceneTree`, `quit(0/1)`). [Source: 1-1/1-2/1-3…md ; `tests/unit/test_*.gd`]
- **En mode `--script`, les autoloads ne sont PAS chargés** → toute logique testée unitairement doit être **pure**, sans dépendance autoload. D'où la séparation : `solicitation_math.gd` + `solicitation.gd` (purs, testés en `--script`) vs `SolicitationSystem`/agent (testés via le harnais d'intégration `--solicitation-smoke`). [Source: 1-1…md#Refactor-testabilité ; 1-3…md#Tests]
- **Pas de VCS** (`git` absent, `baseline_commit=NO_VCS`) → valider par **import + exécution headless réels**, jamais « au jugé » en écrivant le code. [Source: 1-1…md#Debug-Log-References ; 1-3…md]
- **Pause = `get_tree().paused`** (Story 1.3) : tout nœud pausable gèle (`SimClock` n'émet plus → aucune nouvelle sollicitation ; indicateurs figés). Pour qu'un input fonctionne **en pause**, son nœud doit être `PROCESS_MODE_ALWAYS` (cf. le handler de clic, Task 7 — même piège que l'input « Espace » en 1.3). [Source: 1-3…md#Piège-n°1 ; game_manager.gd]

### Pourquoi le pacing est dans le système, pas dans le brain (décision clé)

Le `NativeBrain` est **pur et déterministe** (testable `--script`, partagé avec le futur `LLMBrain`). La **cadence d'apparition** des sollicitations est un réglage de **game design / équilibrage** (combien de fois par minute les agents dérangent le joueur) → elle vit dans `SolicitationSystem` (RNG seedé + valeurs `.tres`), **pas** dans le brain.

Le brain, lui, reste responsable d'une seule chose nouvelle : *« si j'ai une sollicitation bureau en cours → je vais au bureau »* (action `GO_TO_DESK`, lue depuis le **contexte**, pas tirée au sort). Ce découpage :
1. garde le brain pur (zéro RNG, zéro autoload) ;
2. garde la **parité natif ↔ LLM** sur la *locomotion* (en Épic 5, le `LLMBrain` pourra lui aussi émettre `GO_TO_DESK`) ;
3. concentre l'équilibrage en un seul endroit data-driven.

> **Note Épic 5** : quand le LLM décidera *lui-même* de solliciter (« je veux poser une question au boss »), on ajoutera une/des action(s) de type `raise_solicitation` à `ActionRegistry` ; le `SolicitationSystem` deviendra alors le **récepteur** de ces actions plutôt que le seul déclencheur. Rien à faire ici, mais ne pas verrouiller le design contre cette évolution. [Source: game-architecture.md#Novel-Pattern (golden rule) ; ADR-1 ; native_brain.gd (pur)]

### NativeBrain — pseudo-code exact (priorité)

```gdscript
func decide(ctx: AgentContext) -> AgentAction:
    if ctx.evening:
        return ActionRegistry.make(ActionRegistry.LEAVE)
    if ctx.has_desk_solicitation:
        return ActionRegistry.make(ActionRegistry.GO_TO_DESK)
    if not ctx.arrived_at_post:
        return ActionRegistry.make(ActionRegistry.GO_TO_POST)
    return ActionRegistry.make(ActionRegistry.WORK)
```

Le **retour au poste après résolution** réutilise la boucle existante : `clear_solicitation()`/`raise_desk_solicitation()` remettent `_arrived_at_post=false` → le brain réémet `GO_TO_POST` → l'agent marche à son poste → arrivée → `WORK`. Aucun nouvel état FSM n'est strictement nécessaire (l'attente au bureau peut réutiliser `IdleState`/`WorkState` immobile). [Source: native_brain.gd ; agent.gd `_on_destination_reached`/`_apply_action`]

### Flux d'arrivée au bureau (piège — ne pas confondre les cibles)

`agent.gd` distingue aujourd'hui deux arrivées dans `_on_destination_reached()` via `_leaving` (sortie) et `_arrived_at_post` (poste). **Ajouter une 3ᵉ cible (bureau) sans casser les deux autres** :
- introduire un flag `_heading_to_desk: bool` posé dans `_apply_action(GO_TO_DESK)` (target = `_desk_position`) ;
- dans `_on_destination_reached()`, **tester `_leaving` d'abord** (départ), **puis `_heading_to_desk`** (→ `halt()`, attente au bureau, `_heading_to_desk=false`, `_at_desk=true`), **puis** le cas poste existant. Ordre important pour ne pas déclencher la logique « arrivé au poste » au bureau.
- à la résolution (`clear_solicitation()`), remettre `_at_desk=false` + `_arrived_at_post=false` → l'agent repart au poste au prochain `_decide()`.
[Source: agent.gd lignes 77-125 (lecture directe) ]

### Lecture des fichiers UPDATE (état actuel à préserver)

- **`scripts/agents/tools/action_registry.gd`** — 4 actions (`GO_TO_POST/WORK/IDLE/LEAVE`) dans `KNOWN`, `make()` assert. **Ajouter** `GO_TO_DESK`. **Préserver** les 4 + `make`/`is_known`.
- **`scripts/agents/brain/agent_context.gd`** — champs `arrived_at_post`, `evening` + `_init(p_arrived_at_post=false, p_evening=false)`. **Ajouter** `has_desk_solicitation` **en dernier** (défaut `false`) pour ne pas casser l'appel actuel `AgentContext.new(_arrived_at_post, _is_evening())` (qui restera valide ; mettre à jour cet appel dans `agent.gd` pour passer le 3ᵉ argument).
- **`scripts/agents/brain/native_brain.gd`** — `decide()` actuel (evening→LEAVE / not arrived→GO_TO_POST / WORK). **Insérer** le cas `has_desk_solicitation→GO_TO_DESK` (priorité ci-dessus). Reste **pur**.
- **`scripts/agents/agent.gd`** — possède `_post_position`, `_exit_position`, `_arrived_at_post`, `_leaving`, `_current_target`, `_apply_action`, `_on_destination_reached`, `_decide` (construit le `AgentContext`). **Ajouter** `_desk_position`, flags `_heading_to_desk`/`_at_desk`, le cas `GO_TO_DESK`, l'indicateur visuel + API publiques (`raise_desk/mail_solicitation`, `clear_solicitation`, `has_open_solicitation`). **Étendre** `setup()` avec `desk_position`. **Préserver** tout le cycle 1.2/1.3 (spawn/poste/travail/départ, deux horloges découplées).
- **`scripts/agents/agent_factory.gd`** — `create(id, archetype, post, exit, evening_phase)`. **Étendre** avec `desk_position`. **Préserver** l'ordre des autres paramètres.
- **`scripts/world/agent_spawner.gd`** — `_on_day_started` lit `post_world_positions()`/`entrance_world()` et appelle `AgentFactoryC.create(...)`. **Ajouter** la lecture de `desk_world()` + passage à `create(...)`. **Préserver** le nettoyage `_clear_agents`, les créneaux de porte, le `mini(agent_count, posts.size())`.
- **`scripts/world/open_space.gd`** — `_POST_CELLS`, `_ENTRANCE_CELL`, `cell_to_world`, `entrance_world`, `post_world_positions`. **Ajouter** `_DESK_CELL` + `desk_world()`. **Préserver** grille/NavMesh/postes/entrée. (Vérifier que `(11,11)` est navigable — le plateau entier l'est.)
- **`scripts/autoloads/event_bus.gd`** — 9 signaux (4 fondateurs + `day_started`/`agent_spawned`/`agent_departed` + `game_paused`/`speed_changed`). **Ajouter** `solicitation_raised`, `solicitation_opened`. **Préserver les 9.**
- **`scripts/systems/sim_balance.gd`** + **`data/balance/sim_balance.tres`** — `day_duration_seconds`, `evening_phase`, `agent_count`. **Ajouter** `solicitation_rate_per_tick`, `desk_channel_probability`. **Préserver** les 3 champs.
- **`scenes/world/open_space.tscn`** — nœuds `OpenSpace/GridMap/NavigationRegion3D/Agents/AgentSpawner/WorldEnvironment/DirectionalLight3D/CameraRig(>process_mode=3)/Camera3D`. **Ajouter** le nœud `SolicitationSystem` (et éventuellement `SelectionController`, `PROCESS_MODE_ALWAYS`). **Préserver** la structure et `CameraRig.process_mode=3`.
- **`scenes/agents/agent.tscn`** — `Agent(CharacterBody3D)` + `Mesh`/`CollisionShape3D`/`NavigationAgent3D`/`BrainComponent`/`StateMachine`(+ `IdleState`/`WorkState`/`MoveState`). **Option** : ajouter un nœud marqueur de sollicitation (sinon le créer en code). **Préserver** la hiérarchie ; la `CollisionShape3D` existante sert de cible de clic.
- **`scripts/main/main.gd`** — harnais `--measure-fps`/`--sim-smoke`/`--time-smoke`. **Ajouter** `--solicitation-smoke`. **Préserver** les 3 existants.
- **`project.godot`** — section `[input]` (`cam_*`, `game_pause`, `speed_x*`). **Ajouter** `select_click` (bouton gauche). **Préserver** tout le reste (autoloads, display, warnings).
[Source: lecture directe des fichiers `open_space/…` ; 1-2…md/1-3…md#File-List]

> **Important** : une story doit laisser le système **fonctionnel de bout en bout**. Au-delà des AC, caméra (1.1), simulation (1.2) et contrôle du temps (1.3) doivent rester pleinement opérationnels.

### Format Input Map clic (copier le motif `cam_zoom_*` à la lettre)

Le clic gauche se déclare comme les actions molette existantes (`InputEventMouseButton`), avec `button_index` = **1** (bouton gauche) :

```
select_click={
"deadzone": 0.5,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":1,"canceled":false,"pressed":false,"double_click":false,"script":null)
]
}
```

Idéalement éditer via l'UI Godot (Project Settings → Input Map) pour garantir le format ; sinon répliquer le bloc. Vérifier ensuite par import headless 0/0. [Source: project.godot section `[input]` (motif `cam_zoom_in/out`)]

### Raycast caméra — points d'attention (Godot 4.6, caméra orthographique)

- La caméra est **orthographique** (`projection = 1`, `size = 16`) et enfant de `CameraRig` (lui-même `PROCESS_MODE_ALWAYS`). `project_ray_origin/normal` fonctionnent en ortho (le rayon est parallèle, l'origine varie selon le pixel) — pas de cas particulier à coder.
- Récupérer la caméra **active** via `get_viewport().get_camera_3d()` (pas de chemin absolu). Longueur de rayon `RAY_LEN` large (ex. 1000.0).
- L'agent est un `CharacterBody3D` avec `CollisionShape3D` → présent dans l'espace physique 3D ; `intersect_ray` le frappe. Remonter du `collider` à l'`Agent` (le collider **est** l'agent ici, ou via `collider.get_parent()`/`find_parent` selon la hiérarchie). Filtrer : n'agir que si `collider is Agent`.
- Si plusieurs agents se chevauchent (rare à cette cadence), prendre le premier hit ; la désambiguïsation fine est hors périmètre (1.7/1.9).
[Source: camera_controller.gd (caméra ortho, CameraRig) ; agent.tscn (CollisionShape3D) ]

### Tester le clic en headless (injection souris peu fiable)

Comme pour l'input clavier en 1.3, **on teste la mécanique, pas l'input**. `SolicitationSystem.open_solicitation(agent_id)` est le **point d'entrée commun** : le handler de clic l'appelle après le raycast, et le harnais `--solicitation-smoke` l'appelle **directement** (exactement ce que le clic déclenche en jeu). On valide ainsi l'ouverture + l'émission de `solicitation_opened` + le nettoyage, sans dépendre d'un vrai clic. [Source: 1-3…md (pattern API-driven du `--time-smoke` appelant `GameManager.set_paused/set_speed`) ]

### Direction artistique / UI

**Pas d'UI 2D ni d'art final ici.** Indicateurs = **marqueurs 3D placeholder** billboardés au-dessus de l'agent, distincts par canal (forme/couleur). Le clignotement = oscillation simple en `_process(delta)` (donc pausable + scalé par `time_scale`). Les vrais « indicateurs au-dessus des têtes », l'icône mail soignée et les **SFX** (sonnerie de mail) sont l'**Épic 6**. Le HUD (compteur) est la **Story 1.8**. [Source: gdd.md §Direction-artistique (indicateurs au-dessus des têtes = Épic 6 ; sonneries de mail) ; epics.md#Story-1.8 ]

### Performance (NFR1/NFR2)

- 60 FPS open space peuplé avec indicateurs actifs. Pas d'allocation per-frame dans le clignotement (modifier `modulate`/`visible`, pas recréer de matériau chaque frame). Le marqueur peut partager un matériau ou n'animer que l'alpha.
- Le tirage de sollicitation tombe sur le **tick SimClock (~3 Hz)**, pas par frame → coût négligeable. Boucler sur ≤ 5 agents par tick.
- Le raycast n'a lieu **qu'au clic** (événementiel), jamais par frame. [Source: gdd.md#Performance-Requirements ; NFR1/NFR2 ; sim_clock.gd ~3 Hz ; 1-3…md (428 FPS peuplé)]

### Project Structure Notes

- Nouveaux fichiers conformes à la structure hybride : `scripts/decisions/solicitation.gd`, `scripts/decisions/solicitation_math.gd`, `scripts/decisions/solicitation_system.gd` (le dossier `decisions/` est prévu par l'archi pour ce système), `tests/unit/test_solicitation_math.gd`, éventuellement `scripts/world/selection_controller.gd`.
- Aucune nouvelle dépendance, aucun addon. Pas de `class_name` sur les autoloads. Logique pure isolée pour la testabilité `--script`.

### Project Context Rules

- _Aucun `project-context.md` présent dans le dépôt._ Les règles applicables proviennent de l'architecture et des stories 1.1-1.3, listées ci-dessus : `EventBus`-only, pas de chemins absolus, `.tres` pour l'équilibrage, GDScript typé, autoload `Log` (pas `Logger`), pas de `class_name` autoload, capacités d'agent via `ActionRegistry`, logique pure isolée, input via Input Map, nœud d'input actif en pause = `PROCESS_MODE_ALWAYS`.
- **Outillage MCP** (Gopeak Godot MCP + Context7) prévu par l'archi — **non bloquant** ici. [Source: game-architecture.md#AI-Development-Tooling]

### References

- [Source: epics.md#Story-1.4] — AC : sollicitation bureau (déplacement), mail clignotant (sans déplacement), identifiable + ouvrable d'un clic.
- [Source: epics.md#Story-1.5] — Pop-up de décision (2-3 options) : **consomme `solicitation_opened`** ; **hors périmètre ici**.
- [Source: epics.md#Story-1.7] — File/patience/Moral : **hors périmètre** (cadence basse ici, un seul point d'approche bureau).
- [Source: epics.md#Story-1.8] — HUD persistant + compteur file/mails : s'abonnera à `solicitation_raised`/`solicitation_opened` ; **hors périmètre ici**.
- [Source: epics.md#Story-1.9] — Fiche agent au clic : étendra le même handler de clic ; **hors périmètre ici**.
- [Source: gdd.md §Boucle-cœur (étape 1 : bureau ou mail) ; §Piliers #1 (attention = ressource rare) ; §Direction-artistique (indicateurs/SFX = Épic 6)].
- [Source: game-architecture.md#Novel-Pattern ; ADR-1 ; #Consistency-Rules] — `ActionRegistry` source unique des capacités (parité natif↔LLM) → `GO_TO_DESK`.
- [Source: game-architecture.md#System-Location-Mapping ; #Project-Structure] — décisions/pop-ups dans `scripts/decisions/`.
- [Source: game-architecture.md#Event-System ; #Architectural-Boundaries] — `EventBus` signals typés snake_case passé ; pas de chemins absolus.
- [Source: game-architecture.md#Configuration ; #Consistency-Rules] — pacing en `.tres`, zéro magic number.
- [Source: 1-3…md#Piège-n°1 ; game_manager.gd] — input actif en pause = `PROCESS_MODE_ALWAYS` (handler de clic).
- [Source: 1-2…md/1-3…md] — autoload `Log`, pas de `class_name` autoload, pas de GUT (runner headless), pas de VCS, logique pure testable `--script`, harnais d'intégration `--*-smoke`.
- [Source: lecture directe] — `agent.gd`, `native_brain.gd`, `agent_context.gd`, `action_registry.gd`, `agent_spawner.gd`, `open_space.gd`, `event_bus.gd`, `sim_balance.gd`, `main.gd`, `camera_controller.gd`, `agent.tscn`, `open_space.tscn`, `project.godot`.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.8 (claude-opus-4-8)

### Debug Log References

- Import headless propre (**0 erreur / 0 warning**) : `godot --headless --path open_space --import`.
- Tests unitaires sollicitations : `--script res://tests/unit/test_solicitation_math.gd` → `TEST_RESULT=PASS`, **12/12** (`should_raise` + clamp, `channel_for_roll` + bornes, valeurs d'enum `Channel`).
- Non-régression unitaire : `test_agent_sim` → PASS ; `test_camera_math` → PASS ; `test_time_control` → PASS.
- Intégration sollicitations : `godot --headless --path open_space -- --solicitation-smoke` → `SOLICITATION_SMOKE raised_desk=4 raised_mail=2 moved_to_desk=true opened=1 opened_ok=true`, `SOLICITATION_SMOKE_RESULT=PASS`. Couvre AC#1 (canal bureau → agent rapproché du bureau : distance min 15.98 m → **0.49 m**), AC#2 (canal mail émis sans déplacement), AC#3 (`open_solicitation` émet `solicitation_opened` **et** vide l'état actif + retire l'indicateur).
- Non-régression intégration : `--sim-smoke` → `SIM_SMOKE_RESULT=PASS` ; `--time-smoke` → `TIME_SMOKE_RESULT=PASS`.
- Perf (NFR1) : `--measure-fps` → `FPS_MEASUREMENT=145`, exit 0 → bien au-delà de 60.
- **Bug corrigé en cours de dev (capture des lambdas GDScript)** : les compteurs du harnais `--solicitation-smoke` étaient des variables **locales** ; or une lambda GDScript capture les locaux **par valeur** → `+= 1` n'incrémentait que des copies (compteurs restaient à 0 alors que les sollicitations étaient bien levées). Corrigé en passant par des **variables membres** de `main.gd` (`_sol_raised_desk/_mail/_opened`), comme le fait déjà `--sim-smoke` (`_spawned`/`_departed`). Cadence/canal du test pilotés par des **overrides explicites** sur le nœud `SolicitationSystem` (`rate_override`/`desk_prob_override`, défaut `-1` = valeurs `.tres`) plutôt qu'en mutant la Resource partagée.
- Note : les warnings runtime de navigation (« parse RenderingServer meshes… » / « agent_radius… ») proviennent de `open_space.gd::_build_navigation` (code Story 1.2 **non modifié**) — pré-existants, hors périmètre 1.4, sans impact fonctionnel (déjà documentés en 1.3).

### Completion Notes List

- **Deux canaux, fidèles au GDD** : DESK (présentiel) = l'agent quitte son poste et marche jusqu'au **bureau du joueur** (`desk_world()` = cellule `(11,11)`), y patiente (`_at_desk`, état idle) jusqu'à traitement ; MAIL (asynchrone) = **indicateur clignotant sans déplacement** (l'agent continue de travailler). AC#1/#2.
- **Locomotion via `ActionRegistry` (golden rule ADR-1)** : ajout de l'action `GO_TO_DESK` (parité natif↔LLM garantie pour l'Épic 5). Le `NativeBrain` reste **pur** : priorité `evening → has_desk_solicitation → arrived_at_post → work`. Le **pacing** (RNG seedé + taux `.tres`) vit dans `SolicitationSystem`, **pas** dans le brain — découplage documenté.
- **`SolicitationSystem`** (nœud de scène dans `scripts/decisions/`, conforme à l'archi) : orchestre cadence + suivi des sollicitations actives (1 max/agent), émet `solicitation_raised`, expose `open_solicitation(agent_id)` (point d'entrée **commun** au clic et au test). Nettoie l'état sur `agent_departed` (fin de journée).
- **Retour au poste après résolution** : `raise_desk_solicitation()` repasse `_arrived_at_post=false` → après `clear_solicitation()`, le brain réémet `GO_TO_POST` → l'agent retourne travailler. Réutilise la boucle de mouvement existante (1.2), aucun nouvel état FSM requis. Vérifié : les agents bureau redeviennent éligibles (canal mail levé ensuite dans le smoke).
- **Clic gauche → ouverture** : `SelectionController` (`PROCESS_MODE_ALWAYS` → ouvrable **même en pause**, comme l'input « Espace » en 1.3) fait un **raycast caméra** (ortho) sur le corps de l'agent (`CollisionShape3D` existant) ; si l'agent a une sollicitation active → `open_solicitation`. Cliquer dans le vide / un agent sans sollicitation = **no-op** (la fiche agent au clic est la Story 1.9, qui étendra ce handler). Action d'input `select_click` (bouton gauche) ajoutée à `project.godot`.
- **Indicateurs visuels placeholder** (art final = Épic 6) : `QuadMesh` billboardé au-dessus de l'agent, **couleur distincte par canal** (rouge = bureau / bleu = mail), **clignotement** par oscillation d'alpha dans `_process(delta)` → **pausable** (gèle en pause, cohérent 1.3) et scalé par `Engine.time_scale`. Créé/retiré par les API agent ; pas d'allocation per-frame (seul l'alpha d'un matériau existant est modifié).
- **Signaux EventBus** : `solicitation_raised(agent_id, channel)` (compteur HUD Story 1.8) et `solicitation_opened(agent_id, channel)` (pop-up de décision Story 1.5 + HUD 1.8). Les 9 signaux existants préservés.
- **Équilibrage data-driven (AC#4)** : `SimBalance` étendu avec `solicitation_rate_per_tick` (0.01 ≈ rare, avant la file 1.7) et `desk_channel_probability` (0.4 ≈ 40 % bureau / 60 % mail). Zéro magic number dans la logique ; les overrides du système sont **réservés aux tests** (défaut `-1` = valeurs `.tres`).
- **Frontières respectées (volontairement hors périmètre)** : pas de pop-up de décision (1.5), pas de file/patience/moral (1.7 — cadence basse, un seul point d'approche bureau), pas de HUD/compteur (1.8 — on possède les indicateurs individuels), pas de fiche agent au clic (1.9), pas d'art/SFX final (Épic 6).
- **Non-régression** : caméra (1.1), simulation d'agents (1.2) et contrôle du temps (1.3) restent pleinement opérationnels (smokes `--sim-smoke`/`--time-smoke` PASS, FPS 145).

### File List

**Nouveaux fichiers (sous `open_space/`) :**
- `scripts/decisions/solicitation.gd` (`class_name Solicitation` — données pures + enum `Channel`)
- `scripts/decisions/solicitation_math.gd` (`class_name SolicitationMath` — `should_raise`/`channel_for_roll` purs)
- `scripts/decisions/solicitation_system.gd` (orchestrateur : cadence/RNG/suivi + `open_solicitation`)
- `scripts/world/selection_controller.gd` (clic gauche → raycast → ouverture, `PROCESS_MODE_ALWAYS`)
- `tests/unit/test_solicitation_math.gd` (runner headless, 12 tests)

**Fichiers modifiés :**
- `scripts/agents/tools/action_registry.gd` (action `GO_TO_DESK` + ajout à `KNOWN`)
- `scripts/agents/brain/agent_context.gd` (champ `has_desk_solicitation`)
- `scripts/agents/brain/native_brain.gd` (priorité `GO_TO_DESK` quand sollicitation bureau)
- `scripts/agents/agent.gd` (param `desk` dans `setup`, cible/flux `GO_TO_DESK`, indicateurs clignotants `_process`, API `raise_desk/mail_solicitation`/`clear_solicitation`/`has_open_solicitation`/`is_eligible_for_solicitation`)
- `scripts/agents/agent_factory.gd` (param `desk_position` dans `create`)
- `scripts/world/agent_spawner.gd` (lecture `desk_world()` + passage à `create`)
- `scripts/world/open_space.gd` (`_DESK_CELL` + `desk_world()`)
- `scripts/autoloads/event_bus.gd` (signaux `solicitation_raised`, `solicitation_opened`)
- `scripts/systems/sim_balance.gd` (champs `solicitation_rate_per_tick`, `desk_channel_probability`)
- `scripts/main/main.gd` (harnais `--solicitation-smoke` + compteurs membres `_sol_*`)
- `scenes/world/open_space.tscn` (nœuds `SolicitationSystem` %unique + `SelectionController`)
- `project.godot` (action d'input `select_click`, bouton gauche)

## Change Log

| Date | Version | Description |
|---|---|---|
| 2026-06-21 | 0.4.0 | Implémentation Story 1.4 : sollicitations agent au bureau & mail. Deux canaux via `SolicitationSystem` (cadence `.tres` + RNG) : DESK → action `GO_TO_DESK` (registre, parité natif↔LLM) menant l'agent au bureau du joueur où il patiente puis repart travailler ; MAIL → indicateur clignotant sans déplacement. Indicateurs placeholder billboardés (couleur par canal, blink pausable). Clic gauche → raycast caméra → `open_solicitation` (actif en pause) émettant `solicitation_opened` (Story 1.5) et retirant l'indicateur. Signaux `solicitation_raised`/`solicitation_opened` ajoutés. Tests : 12/12 unitaires `SolicitationMath` + `--solicitation-smoke` PASS (desk 15.98 m→0.49 m, mail sans déplacement, open émet+nettoie) ; non-régression 3 suites unitaires + `--sim-smoke` + `--time-smoke` PASS ; 145 FPS (NFR1) ; import 0/0. Statut → review. |
