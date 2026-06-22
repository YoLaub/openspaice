---
baseline_commit: NO_VCS
---

# Story 1.5: Pop-up de décision (2-3 options)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a joueur,
I want trancher des décisions via des pop-ups présentant un contexte et 2-3 options,
so that je pilote la boîte sous pression (le temps tourne pendant que je réfléchis).

## Acceptance Criteria

1. **Given** j'ouvre une sollicitation (clic sur un agent porteur d'une sollicitation → `EventBus.solicitation_opened(agent_id, channel)` est émis par la Story 1.4) **When** la pop-up de décision s'affiche **Then** elle présente un **contexte textuel** + **2 à 3 options actionnables** (boutons cliquables), distinctes et lisibles. Le nombre d'options est **toujours dans [2, 3]** (jamais 0/1/4+).
2. **Given** la pop-up est ouverte **When** le temps **n'est pas** en pause **Then** il **continue de tourner** (`SimClock` tick toujours, la phase de journée avance, les agents bougent) — la décision a un **coût d'attention**. La pop-up **ne met JAMAIS le jeu en pause** d'elle-même.
3. **Given** la pop-up est ouverte **And** le joueur appuie sur **Espace** (pause, Story 1.3) **When** il clique ensuite une option **Then** le clic **fonctionne quand même** (la pop-up reste interactive en pause — le joueur met en pause *pour* réfléchir).
4. **Given** je choisis une option **d'un clic gauche** **When** je valide **Then** la pop-up **se ferme**, l'événement `EventBus.decision_chosen(decision_id, option_index)` est émis (consommé par la **résolution immédiate/différée, Story 1.6**), et l'agent **repart agir** (comportement de retour au poste déjà posé en 1.4 — voir Dev Notes).
5. **Given** le contenu des décisions (textes de contexte + libellés d'options) **When** on l'édite **Then** il vit **uniquement** dans des Resources `.tres` (`data/decisions/`), **zéro contenu codé en dur** dans la logique (data-driven, cohérent D6).

> **Frontière de cette story (lire absolument — périmètre volontairement borné) :**
> - **1.5 FAIT** : afficher la pop-up sur `solicitation_opened` ; montrer **contexte + 2-3 options** (boutons) **data-driven** `.tres` ; laisser le temps tourner (sauf pause) ; rester interactif **en pause** ; sur choix d'option → fermer la pop-up + émettre `decision_chosen(decision_id, option_index)`. C'est la **première UI 2D** du projet (CanvasLayer + Control, D9).
> - **1.5 NE FAIT PAS** (ne pas déborder) :
>   - **L'EFFET de la décision (jauges/état) et le clivage ~60 % immédiat / ~40 % différé** → **Story 1.6**. Ici on **émet seulement** `decision_chosen` ; **aucun** effet appliqué, **aucun** RNG immédiat/différé, **aucun** ordonnancement `SimClock`. La 1.6 s'abonnera à `decision_chosen` pour résoudre et émettra `decision_resolved`.
>   - **La file d'attente physique, la patience (~45 s), la jauge Moral, le « l'agent attend au bureau jusqu'à résolution »** → **Story 1.7**. Ici, l'agent **repart dès l'ouverture** (timing 1.4 **conservé**, voir Dev Notes « Tension 1.4 ↔ 1.7 ») ; ne PAS changer ce timing.
>   - **Le HUD persistant / compteur d'attention** → **Story 1.8** (s'abonnera à `solicitation_raised`/`solicitation_opened`/`decision_chosen`).
>   - **La fiche agent au clic** → **Story 1.9**.
>   - **L'art final de la pop-up, animations d'apparition, SFX, juice** → **Épic 6**. Ici : Control natif fonctionnel, lisible, **sans** thème/skin final.

## Tasks / Subtasks

- [x] **Task 1 — Modèle de données PUR : `DecisionOption` + `Decision` (`.tres`, testable `--script`)** (AC: #1, #5)
  - [x] Créer `scripts/decisions/decision_option.gd` (`class_name DecisionOption extends Resource`) : `@export var label: String = ""`. **Objet de données pur** (juste le libellé affiché sur le bouton à ce stade). Les champs d'effet (montant €, type immédiat/différé…) seront **ajoutés par la Story 1.6** — ne PAS les anticiper ici, mais ne pas verrouiller le design contre (laisser `DecisionOption` extensible).
  - [x] Créer `scripts/decisions/decision.gd` (`class_name Decision extends Resource`) : `@export var context_text: String = ""`, `@export var options: Array[DecisionOption] = []`. **Tout typer** (`untyped_declaration=1` → sinon warning import). Ce sont des **templates de contenu** (le `decision_id` runtime et l'`agent_id` sont portés par le contrôleur, Task 4 — PAS dans le `.tres`).
  - [x] Créer `scripts/decisions/decision_math.gd` (`class_name DecisionMath extends RefCounted`) : fonctions **pures** — `is_valid_option_count(n: int) -> bool` (vrai si `2 <= n <= 3`), `pick_index(roll: float, count: int) -> int` (→ index borné `clampi(floori(roll * count), 0, count-1)`, pour choisir un template de façon déterministe/testable). **Aucune** dépendance scène/autoload. Modèle : `solicitation_math.gd` / `day_phase_math.gd` (purs, testés en `--script`).

- [x] **Task 2 — Catalogue de décisions data-driven (`.tres`) sélectionnable par canal** (AC: #1, #5)
  - [x] Créer `scripts/decisions/decision_catalog.gd` (`class_name DecisionCatalog extends Resource`) : `@export var desk_decisions: Array[Decision] = []`, `@export var mail_decisions: Array[Decision] = []`, et une méthode **pure** `pick(channel: int, roll: float) -> Decision` qui choisit dans la liste du canal (`Solicitation.Channel.DESK`/`MAIL`) via `DecisionMath.pick_index(roll, list.size())`. Si la liste du canal est vide → fallback sur l'autre liste, sinon `null` (le contrôleur gère le `null` défensivement, Task 4). **Réutiliser l'enum canal** `Solicitation.Channel` (source unique de vérité, Story 1.4) — ne PAS redéclarer d'enum canal.
  - [x] Créer le dossier `data/decisions/` et y poser :
    - `data/decisions/decision_catalog.tres` (référence le script + ses deux listes de templates).
    - Au moins **2 décisions DESK** et **2 décisions MAIL** en `.tres` (sous-ressources ou fichiers `.tres` séparés référencés par le catalogue). Contenu **placeholder mais crédible**, fidèle au GDD. Inclure l'exemple canonique du GDD comme décision DESK : contexte « Le client menace de partir. » + options `[Rassurer]`, `[Baisser le prix -500 €]`, `[Ignorer]` (**3 options**). Prévoir au moins une décision à **2 options** pour exercer la borne basse. Les décisions MAIL : sollicitations « moins urgentes » (ex. « Demande de jour de congé », « Question sur le process ») à 2-3 options. **Aucun effet chiffré réel** (les montants comme « -500 € » sont du **texte d'habillage** ici ; l'application réelle = Story 1.6).
  - [x] Vérifier après import que le catalogue et les décisions apparaissent **0 erreur / 0 warning**.

- [x] **Task 3 — Scène pop-up : CanvasLayer + Control natif (première UI 2D du projet)** (AC: #1, #2, #3)
  - [x] Créer `scenes/ui/decision_popup.tscn` (créer le dossier `scenes/ui/`). Racine = **`CanvasLayer`** (rend par-dessus la 3D quelle que soit sa position dans l'arbre — D9). Sous-arbre :
    - Un **fond bloquant** (`Control`/`ColorRect` plein écran, `mouse_filter = STOP`) → **empêche le clic de traverser** la pop-up et d'atteindre un agent derrière (sinon le `SelectionController` 1.4 ouvrirait une autre sollicitation). Semi-transparent léger pour focaliser sans masquer (pas d'art final).
    - Un **`Panel`** centré contenant : un **`Label`** (contexte, `autowrap`), puis un conteneur (`VBoxContainer`) qui **recevra dynamiquement** les boutons d'options (créés en code, Task 4 — un `Button` par option). Ne PAS coder en dur 2 ou 3 boutons dans la scène : le contrôleur les instancie selon `Decision.options.size()`.
  - [x] La racine `CanvasLayer` (et son contenu) doit pouvoir traiter le clic **en pause** : régler `process_mode = Node.PROCESS_MODE_ALWAYS` sur la **racine de la pop-up** (le GUI input des `Control` est sinon gelé quand `get_tree().paused` — même piège que l'input « Espace »/clic en 1.3/1.4). **La pop-up commence cachée** (`visible = false`).
  - [x] Instancier `scenes/ui/decision_popup.tscn` dans `scenes/world/open_space.tscn` avec un **nom unique** `%DecisionPopup` (même schéma d'accès que `%SolicitationSystem`/`%Agents`, pour que le harnais d'intégration puisse la récupérer, Task 6). **Préserver** toute la structure existante d'`open_space.tscn` (`OpenSpace/GridMap/NavigationRegion3D/Agents/AgentSpawner/SolicitationSystem/SelectionController/WorldEnvironment/DirectionalLight3D/CameraRig(>process_mode=3)/Camera3D`).

- [x] **Task 4 — Contrôleur pop-up : afficher sur `solicitation_opened`, construire les boutons, gérer le choix** (AC: #1, #2, #4)
  - [x] Créer `scripts/decisions/decision_popup.gd` (script de la racine `CanvasLayer`). Charger le catalogue : `const _CATALOG: DecisionCatalog = preload("res://data/decisions/decision_catalog.tres")`. RNG seedé (`var _rng := RandomNumberGenerator.new()` ; `randomize()` au runtime / seed fixe pour le test — **documenter**, comme `solicitation_system.gd`).
  - [x] Dans `_ready()` : `process_mode = Node.PROCESS_MODE_ALWAYS`, masquer la pop-up, s'abonner à `EventBus.solicitation_opened.connect(_on_solicitation_opened)`.
  - [x] `_on_solicitation_opened(agent_id: int, channel: int)` : sélectionner un `Decision` via `_CATALOG.pick(channel, _rng.randf())`. Si `null` → log WARN + ne rien afficher (défensif). Sinon **afficher** via `_show_decision(agent_id, channel, decision)`.
  - [x] `_show_decision(...)` : assigner un `decision_id` runtime **incrémental** (`_next_decision_id`), mémoriser `_current_agent_id`/`_current_decision_id`, remplir le `Label` de contexte, **vider** le `VBoxContainer` puis **créer un `Button` par option** (`decision.options[i].label`), connecter chaque bouton à `choose_option(i)` (via `bind(i)`), rendre la pop-up visible. **Assert/garde** : `DecisionMath.is_valid_option_count(decision.options.size())` (un template mal formé ne doit pas s'afficher).
  - [x] **`choose_option(index: int) -> void`** = **POINT D'ENTRÉE COMMUN** du clic bouton ET du test d'intégration (l'injection souris/clic GUI est peu fiable en headless — même approche que `open_solicitation()` en 1.4). Effet : émettre `EventBus.decision_chosen(_current_decision_id, index)`, **cacher** la pop-up, vider l'état courant, puis **dépiler** une éventuelle sollicitation en attente (Task 5). **Ne PAS** appliquer d'effet de jeu ici (c'est la 1.6). **Ne PAS** toucher à l'agent (son retour est déjà géré en 1.4).
  - [x] **`is_showing() -> bool`** (utile au clic/test) : vrai si la pop-up est visible.

- [x] **Task 5 — Une seule pop-up à la fois : file d'attente minimale (anti-perte de décision)** (AC: #1, #4)
  - [x] Comme la 1.4 lève les sollicitations **rarement**, deux ouvertures simultanées sont rares — mais possibles (clic sur un 2ᵉ agent porteur pendant qu'une pop-up est ouverte). **Ne jamais empiler deux pop-ups** ni **perdre** une décision : si `is_showing()` est vrai quand `_on_solicitation_opened` arrive, **enfiler** `(agent_id, channel)` dans une FIFO `_pending: Array` plutôt que d'écraser.
  - [x] Sur `choose_option(...)` (fermeture), si `_pending` n'est pas vide → **dépiler** et afficher la décision suivante. **Garde-fou** : pas de file riche (patience/moral/ordre physique = **Story 1.7**) ; ici une simple FIFO en mémoire qui empêche de perdre une sollicitation déjà ouverte par 1.4.
  - [x] Documenter en commentaire que cette FIFO est un **garde-fou minimal** que la Story 1.7 remplacera/intègrera par la vraie file d'attente (patience + moral + ordre au bureau).

- [x] **Task 6 — Signal EventBus pour 1.6 / 1.8** (AC: #4)
  - [x] Ajouter à `scripts/autoloads/event_bus.gd` : `signal decision_chosen(decision_id: int, option_index: int)` (snake_case, au passé). **Préserver les 11 signaux existants** (4 fondateurs `agent_burned_out`/`decision_resolved`/`llm_call_failed`/`day_ended` + `day_started`/`agent_spawned`/`agent_departed` + `game_paused`/`speed_changed` + `solicitation_raised`/`solicitation_opened`).
  - [x] **Ne PAS** émettre `decision_resolved` ici (il appartient à la **résolution**, Story 1.6) ; **ne pas** créer de signal mort. Documenter en commentaire que `decision_chosen` est **consommé par la résolution immédiate/différée (Story 1.6)** et alimentera le **HUD (Story 1.8)**.

- [x] **Task 7 — Tests** (AC: #1, #2, #4, #5)
  - [x] **Pas de GUT** (addon non installé) : runner headless autonome `tests/unit/*.gd extends SceneTree`, `quit(0/1)`. **Rappel : en mode `--script`, AUCUN autoload n'est chargé** → ne tester que de la logique **pure** (sans `Log`/`EventBus`/`SimClock`/`GameManager`).
  - [x] `tests/unit/test_decision.gd` (runner headless) : `DecisionMath.is_valid_option_count` (faux à 0/1/4, vrai à 2/3) ; `DecisionMath.pick_index` (bornes 0.0/0.999…, jamais hors `[0, count-1]`) ; construction `Decision`/`DecisionOption` via `.new()` (sans IO) et `DecisionCatalog.pick(channel, roll)` sur des listes construites en mémoire → renvoie un template du **bon canal**, gère le **fallback** (canal vide) et le **catalogue vide** (`null`). **Vérifier que chaque décision construite a 2-3 options** (invariant AC#1).
  - [x] **Intégration (avec autoloads)** : ajouter un harnais `--decision-smoke` à `scripts/main/main.gd` (même esprit que `--solicitation-smoke`). Récupérer `%DecisionPopup` via `$OpenSpace`. Forcer un agent à son poste, **émettre/déclencher** une sollicitation (réutiliser `SolicitationSystem` avec `rate_override`/`desk_prob_override` comme le smoke 1.4, OU appeler directement `SolicitationSystem.open_solicitation(agent_id)` sur une sollicitation active). Vérifier : (a) après `solicitation_opened`, **la pop-up est visible** (`is_showing()` == true) **et** présente **2-3 boutons** ; (b) **le temps continue** : mesurer que `GameManager.day_phase` **avance** pendant que la pop-up est ouverte (jeu non en pause) ; (c) `choose_option(0)` **émet `decision_chosen`** (capté via **variable membre**, cf. piège des lambdas) **et** referme la pop-up (`is_showing()` == false) ; (d) **pause OK** : `GameManager.set_paused(true)` puis `choose_option(0)` fonctionne toujours (referme la pop-up) — valide l'interactivité en pause. Imprimer `DECISION_SMOKE shown=.. options=.. advanced=.. chosen=.. closed=..` + `DECISION_SMOKE_RESULT=PASS/FAIL`, `quit(0/1)`.
  - [x] **Non-régression** : `test_solicitation_math.gd`, `test_agent_sim.gd`, `test_camera_math.gd`, `test_time_control.gd` toujours PASS ; `--sim-smoke`, `--time-smoke`, `--solicitation-smoke`, `--measure-fps` toujours PASS (l'ajout de la pop-up ne doit casser ni le cycle de journée, ni le temps, ni les sollicitations, ni la perf).

- [x] **Task 8 — Non-régression, pause & état par défaut** (AC: tous ; NFR1)
  - [x] Au lancement : **aucune pop-up affichée**, les agents arrivent/travaillent/repartent comme en 1.2/1.3/1.4 ; les sollicitations apparaissent et sont **ouvrables au clic** (1.4) ; ouvrir une sollicitation **affiche désormais la pop-up** (nouveau).
  - [x] **Le clic sur un bouton d'option ne doit PAS déclencher le raycast du `SelectionController`** : le `Control` consomme le clic GUI (input « handled ») → `_unhandled_input` du `SelectionController` ne le voit pas. Le **fond bloquant** (Task 3) garantit aussi qu'un clic *à côté* des boutons mais *sur* la pop-up n'ouvre pas une sollicitation derrière. Vérifier ce non-conflit.
  - [x] **La pop-up ne met jamais le jeu en pause** (AC#2) ; et **reste interactive si le joueur met en pause** (AC#3, `PROCESS_MODE_ALWAYS`). Vérifier les deux.
  - [x] Import headless **0 erreur / 0 warning** (`untyped_declaration=1` → tout typer). Confirmer **60 FPS** open space peuplé avec pop-up active (`--measure-fps`). Pas d'allocation per-frame côté pop-up (les boutons sont créés **à l'ouverture**, pas par frame).
  - [x] **Laisser le système fonctionnel de bout en bout** : caméra (1.1), simulation d'agents (1.2), contrôle du temps (1.3) et sollicitations (1.4) restent pleinement opérationnels après cette story.

## Dev Notes

### Contexte & objectif

Cette story pose la **deuxième brique de la boucle cœur** : après que l'agent a sollicité le joueur (Story 1.4, deux canaux), le joueur **tranche** via une **pop-up de décision**. C'est la **première interface 2D** du projet (jusqu'ici tout était 3D + input). Fidèle au GDD :

> « Une **pop-up de décision** s'ouvre avec **2-3 options** (ex. « Le client menace de partir → [Rassurer] / [Baisser le prix -500 €] / [Ignorer] »). Le temps continue de tourner (sauf pause). »

La story s'arrête à : *afficher la pop-up*, *montrer contexte + 2-3 options data-driven*, *laisser le temps tourner*, *rester cliquable en pause*, *émettre `decision_chosen` au choix*, *refermer*. **L'EFFET de la décision (immédiat ~60 % / différé ~40 %) est la Story 1.6** ; la **file/patience/moral la 1.7** ; le **HUD la 1.8** ; la **fiche agent la 1.9**. Respecter cette frontière est essentiel (voir l'encadré en tête).
[Source: epics.md#Story-1.5 ; gdd.md §Boucle-cœur (étape 2 : pop-up 2-3 options) ; gdd.md §Piliers #1 (attention) & #2 (décider sans filet)]

### Stack technique imposée (NE PAS dévier)

- **Moteur : Godot 4.6.3-stable**, **GDScript typé statiquement** (`untyped_declaration=1` → **tout typer**, sinon warning à l'import). [Source: game-architecture.md#Decision-Summary D10]
- **UI/HUD = Control nodes + `CanvasLayer`** (natif Godot). [Source: game-architecture.md#Decision-Summary D9]
- **Décisions (pop-ups)** : logique dans **`scripts/decisions/`**, scène dans **`scenes/ui/`**. [Source: game-architecture.md#System-Location-Mapping ; #Project-Structure (`scenes/ui/` = pop-ups décision ; `scripts/decisions/` = decision_popup logic)]
- **Communication via `EventBus`** (signals typés, snake_case au passé) ; jamais d'appel direct en dur entre systèmes. [Source: game-architecture.md#Event-System ; #Architectural-Boundaries]
- **Jamais de chemins de nœuds absolus** — `@onready`, `%UniqueName`, signals, ou référence parent→enfant connue uniquement. [Source: game-architecture.md#Architectural-Boundaries]
- **Contenu/équilibrage en `.tres`** (`data/decisions/`, `data/balance/`) ; **zéro magic number / zéro texte codé en dur** dans la logique. [Source: game-architecture.md#Configuration ; #Consistency-Rules ; D6]
- **Une erreur n'est jamais fatale et ne met jamais le jeu en pause** (catalogue vide / template invalide → log WARN + dégradation propre). [Source: game-architecture.md#Error-Handling ; NFR11]

### ⚠️ Apprentissages critiques des Stories 1.1 → 1.4 (à respecter absolument)

- **L'autoload du logger s'appelle `Log`, PAS `Logger`** (`Logger` est une classe native Godot 4.6 → collision). Utiliser `Log.info/warn/error/debug`. (Les extraits d'archi montrant `Logger.info(...)` sont **illustratifs**.) [Source: 1-1…md ; 1-4…md#Apprentissages]
- **Les autoloads n'ont PAS de `class_name`** — accès par nom de singleton (`EventBus`, `SimClock`, `GameManager`, `ConfigService`, `Log`). [Source: 1-2…md ; 1-4…md]
- **GUT non installé** → runner headless autonome (`tests/unit/*.gd extends SceneTree`, `quit(0/1)`). [Source: 1-1…1-4…md ; `tests/unit/test_*.gd`]
- **En mode `--script`, les autoloads ne sont PAS chargés** → toute logique testée unitairement doit être **pure**, sans dépendance autoload. D'où la séparation : `decision_math.gd` + `decision.gd`/`decision_option.gd`/`decision_catalog.gd` (purs, testés en `--script`) vs le **contrôleur** `decision_popup.gd` (autoloads/scène, testé via le harnais `--decision-smoke`). [Source: 1-4…md#Tests (math pur vs smoke d'intégration)]
- **Pas de VCS** (`git` absent, `baseline_commit=NO_VCS`) → valider par **import + exécution headless réels**, jamais « au jugé ». [Source: 1-4…md#Debug-Log-References]
- **Pause = `get_tree().paused`** (Story 1.3) : tout nœud pausable gèle ; **le GUI input des Control est gelé aussi**. Pour qu'une pop-up reste **cliquable en pause**, sa racine doit être `PROCESS_MODE_ALWAYS` (même piège que l'input « Espace » en 1.3 et le clic en 1.4 — `SelectionController`/`GameManager` sont `PROCESS_MODE_ALWAYS`). [Source: 1-3…md#Piège-n°1 ; 1-4…md#Task-7 ; game_manager.gd ; selection_controller.gd]
- **Piège des lambdas GDScript (capture par valeur)** : pour compter des événements dans un harnais smoke, utiliser des **variables membres** de `main.gd` (cf. `_sol_raised_desk`/`_sol_opened`), **jamais** des locaux (capturés par valeur → jamais incrémentés). [Source: 1-4…md#Debug-Log-References (bug corrigé)]

### Le flux exact : de l'ouverture au choix (qui fait quoi)

```
[Story 1.4]  clic agent → SelectionController.raycast → SolicitationSystem.open_solicitation(agent_id)
             → émet EventBus.solicitation_opened(agent_id, channel)
             → (1.4) retire l'indicateur + agent.clear_solicitation()  [l'agent repart vers son poste]
[Story 1.5]  DecisionPopup._on_solicitation_opened(agent_id, channel)
             → DecisionCatalog.pick(channel, rng) → Decision (contexte + 2-3 options)
             → affiche la pop-up (Label contexte + 1 Button par option)   [le temps continue de tourner]
             → joueur clique une option → choose_option(index)
             → émet EventBus.decision_chosen(decision_id, index) → ferme la pop-up
[Story 1.6]  (futur) s'abonne à decision_chosen → applique l'effet (immédiat ~60 % / différé ~40 %)
             → émet EventBus.decision_resolved(decision_id, outcome)
```

**`choose_option(index)` est le point d'entrée commun** du bouton (en jeu) et du harnais `--decision-smoke` (en test) — exactement le pattern `open_solicitation()` de 1.4 (l'injection de clic GUI est peu fiable en headless). [Source: 1-4…md (point d'entrée commun clic/test) ; selection_controller.gd ; solicitation_system.gd]

### Tension 1.4 ↔ 1.7 : l'agent repart **dès l'ouverture** (NE PAS « corriger » ici)

Dans `solicitation_system.gd::open_solicitation()` (Story 1.4), l'agent est **déjà** remis en route vers son poste (`agent.clear_solicitation()`) **au moment où la sollicitation est ouverte** — donc **avant** que le joueur choisisse une option. L'AC#4 « l'agent repart agir selon mon choix » est **déjà satisfaite** par ce comportement 1.4 : à la fermeture de la pop-up, l'agent est déjà reparti travailler.

Le raffinement « l'agent **attend au bureau** (en file) jusqu'à ce que le joueur tranche, avec patience + perte de moral » est la **Story 1.7**. **Ne PAS** modifier `open_solicitation()` ni le timing de `clear_solicitation()` dans cette story (ce serait une régression sur les smokes 1.4 et anticiperait la 1.7). 1.5 = **uniquement** l'UI + la donnée + le signal de choix. [Source: solicitation_system.gd::open_solicitation ; agent.gd::clear_solicitation ; epics.md#Story-1.7 ; 1-4…md (frontière file/patience → 1.7)]

### Pourquoi une FIFO minimale (Task 5)

Une pop-up à la fois (sinon empilement illisible). Mais comme 1.4 **consomme** la sollicitation à l'ouverture (`open_solicitation` retire l'état actif), si on **ignorait** un 2ᵉ `solicitation_opened` reçu pendant qu'une pop-up est ouverte, la décision serait **perdue** (l'agent a déjà été nettoyé côté 1.4). D'où une **FIFO en mémoire** dans le contrôleur : on enfile, on dépile à la fermeture. C'est un **garde-fou minimal**, pas la vraie file d'attente physique (patience/moral/ordre au bureau = **Story 1.7**, qui l'intégrera). [Source: solicitation_system.gd (état actif retiré à l'ouverture) ; epics.md#Story-1.7]

### UI Godot 4.6 — points d'attention (première UI 2D)

- **Racine `CanvasLayer`** : rend par-dessus la 3D indépendamment de sa position dans l'arbre. Le `Control` enfant porte la mise en page. [Source: game-architecture.md D9]
- **`PROCESS_MODE_ALWAYS` sur la racine** → la pop-up traite l'input GUI **même quand `get_tree().paused`** (AC#3). Sans ça, les boutons ne répondent plus en pause (deadlock d'interaction). [Source: 1-3…md#Piège-n°1 ; game_manager.gd ; selection_controller.gd]
- **Fond bloquant** (`mouse_filter = STOP`, plein écran sous le `Panel`) → un clic sur la pop-up (même hors bouton) **ne traverse pas** vers un agent (sinon `SelectionController._unhandled_input` ouvrirait une autre sollicitation). Les `Button` consomment déjà leur clic (input « handled ») → `_unhandled_input` ne les voit pas. [Source: selection_controller.gd (`_unhandled_input` sur `select_click`)]
- **Boutons créés dynamiquement** : `decision.options.size()` boutons (2 ou 3), connectés via `pressed.connect(choose_option.bind(i))`. **Vider** le `VBoxContainer` avant de re-remplir (à chaque nouvelle décision). Pas d'allocation par frame (création à l'ouverture seulement). [Source: NFR1 ; gdd.md#Performance]
- **Ne PAS** appeler `get_tree().paused = true` depuis la pop-up (AC#2 : le temps continue). [Source: epics.md#Story-1.5 AC ; gdd.md (« le temps continue de tourner sauf pause »)]

### Lecture des fichiers UPDATE (état actuel à préserver)

- **`scripts/autoloads/event_bus.gd`** — **11 signaux** (4 fondateurs + `day_started`/`agent_spawned`/`agent_departed` + `game_paused`/`speed_changed` + `solicitation_raised`/`solicitation_opened`). **Ajouter** `decision_chosen(decision_id: int, option_index: int)`. **Préserver les 11.** ⚠️ `decision_resolved(decision_id, outcome)` existe déjà (fondateur) → **réservé à la Story 1.6**, ne pas l'émettre ici. [Source: lecture directe event_bus.gd]
- **`scenes/world/open_space.tscn`** — nœuds `OpenSpace/GridMap/NavigationRegion3D/Agents(%)/AgentSpawner/SolicitationSystem(%)/SelectionController/WorldEnvironment/DirectionalLight3D/CameraRig(process_mode=3)/Camera3D`. **Ajouter** l'instance `%DecisionPopup` (`scenes/ui/decision_popup.tscn`). **Préserver** la structure et `CameraRig.process_mode=3`. [Source: lecture directe open_space.tscn]
- **`scripts/main/main.gd`** — harnais `--measure-fps`/`--sim-smoke`/`--time-smoke`/`--solicitation-smoke` + helper `_real_wait` + compteurs membres `_sol_*`. **Ajouter** `--decision-smoke` (+ compteur membre `_decisions_chosen`). **Préserver les 4 harnais existants** et `_real_wait`. [Source: lecture directe main.gd]
- **`scripts/decisions/solicitation_system.gd`** — `open_solicitation()` émet `solicitation_opened` puis `agent.clear_solicitation()`. **NE PAS MODIFIER** (la pop-up s'abonne au signal ; ne pas changer le timing — cf. « Tension 1.4 ↔ 1.7 »). [Source: lecture directe solicitation_system.gd]
- **`scripts/decisions/solicitation.gd`** — `enum Channel { DESK = 0, MAIL = 1 }` (**source unique** du canal). **Réutiliser** cet enum dans `DecisionCatalog.pick(channel, …)` ; **ne PAS** redéclarer. [Source: lecture directe solicitation.gd]
- **`scripts/world/selection_controller.gd`** — `_unhandled_input` sur `select_click` → `open_solicitation`. **NE PAS MODIFIER** ; vérifier seulement le non-conflit (le clic bouton ne doit pas atteindre ce handler). [Source: lecture directe selection_controller.gd]

> **Important** : une story doit laisser le système **fonctionnel de bout en bout**. Au-delà des AC, caméra (1.1), simulation (1.2), contrôle du temps (1.3) et sollicitations (1.4) doivent rester pleinement opérationnels.

### Tester en headless (clic GUI peu fiable → API directe)

Comme l'input clavier (1.3) et le clic 3D (1.4), **on teste la mécanique, pas l'input GUI**. `DecisionPopup.choose_option(index)` est le **point d'entrée commun** : le `pressed` du bouton l'appelle, et `--decision-smoke` l'appelle **directement**. On valide ainsi l'affichage (2-3 boutons), la continuité du temps, l'émission de `decision_chosen`, la fermeture, et l'interactivité en pause — sans dépendre d'un vrai clic GUI. [Source: 1-4…md#Tester-le-clic-en-headless ; main.gd::_run_solicitation_smoke_and_quit]

### Direction artistique / UI

**Pas d'art final ni de juice ici.** Control natif Godot, lisible : `Panel` centré, `Label` de contexte, boutons d'options empilés. Le thème/skin *Severance*, les animations d'apparition/fermeture et les **SFX** (clic, ouverture) sont l'**Épic 6** (polish/feedback) ; le HUD persistant (compteur d'attention) est la **Story 1.8**. [Source: gdd.md §Direction-artistique ; epics.md#Story-6.5 (polish feedback) ; epics.md#Story-1.8]

### Performance (NFR1)

- 60 FPS open space peuplé, pop-up ouverte. Boutons créés **à l'ouverture** (événementiel), jamais par frame. Le contrôleur ne fait rien en `_process` (pas de `_process` requis). [Source: NFR1 ; gdd.md#Performance ; 1-4…md (145 FPS peuplé)]
- La sélection de décision (`pick`) tombe **à l'ouverture** (clic joueur), coût négligeable. [Source: sim_clock.gd ~3 Hz ; NFR2]

### Project Structure Notes

- Nouveaux fichiers conformes à la structure hybride : `scripts/decisions/decision.gd`, `decision_option.gd`, `decision_math.gd`, `decision_catalog.gd`, `decision_popup.gd` ; `scenes/ui/decision_popup.tscn` (**nouveau dossier `scenes/ui/`**) ; `data/decisions/*.tres` (**nouveau dossier `data/decisions/`**) ; `tests/unit/test_decision.gd`.
- Aucune nouvelle dépendance, aucun addon. Pas de `class_name` sur les autoloads. Logique pure isolée pour la testabilité `--script`. Première UI 2D → établit le pattern CanvasLayer+Control réutilisé par 1.8 (HUD), 1.9 (fiche), 1.10 (bilan).

### Project Context Rules

- _Aucun `project-context.md` présent dans le dépôt._ Les règles applicables proviennent de l'architecture et des stories 1.1-1.4, listées ci-dessus : `EventBus`-only (snake_case passé), pas de chemins absolus, `.tres` pour contenu/équilibrage (zéro magic number / zéro texte en dur), GDScript typé (import 0/0), autoload `Log` (pas `Logger`), pas de `class_name` autoload, enum canal = source unique (`Solicitation.Channel`), logique pure isolée (`--script`) vs intégration (`--*-smoke`), **UI = CanvasLayer + Control (D9)**, nœud interactif en pause = `PROCESS_MODE_ALWAYS`, erreurs non fatales (catalogue vide → WARN + dégradation).
- **Outillage MCP** (Gopeak Godot MCP + Context7) prévu par l'archi — **non bloquant** ici. [Source: game-architecture.md#AI-Development-Tooling]

### References

- [Source: epics.md#Story-1.5] — AC : pop-up contexte + 2-3 options ; le temps continue (sauf pause) ; choix au clic gauche → ferme + l'agent repart.
- [Source: epics.md#Story-1.4] — `solicitation_opened(agent_id, channel)` **émis ici** ; consommé par 1.5 (point d'entrée de la pop-up).
- [Source: epics.md#Story-1.6] — Résolution immédiate (~60 %) vs différée (~40 %) : **consomme `decision_chosen`** ; **hors périmètre ici** (aucun effet appliqué).
- [Source: epics.md#Story-1.7] — File/patience/Moral + « agent attend au bureau » : **hors périmètre** (l'agent repart dès l'ouverture, timing 1.4 conservé).
- [Source: epics.md#Story-1.8] — HUD/compteur d'attention : s'abonnera à `solicitation_*`/`decision_chosen` ; **hors périmètre**.
- [Source: gdd.md §Boucle-cœur (étape 2 : pop-up 2-3 options, exemple « client menace de partir ») ; §Piliers #1 (attention) & #2 (décider sans filet) ; §Direction-artistique (UI/pop-ups) ; §Performance].
- [Source: game-architecture.md#Decision-Summary D9] — UI/HUD = Control nodes + `CanvasLayer`.
- [Source: game-architecture.md#System-Location-Mapping ; #Project-Structure] — décisions/pop-ups : `scripts/decisions/` + `scenes/ui/`.
- [Source: game-architecture.md#Event-System ; #Architectural-Boundaries] — `EventBus` signals typés snake_case passé ; pas de chemins absolus.
- [Source: game-architecture.md#Configuration ; #Consistency-Rules ; D6] — contenu/équilibrage en `.tres`, zéro magic number / texte en dur.
- [Source: game-architecture.md#Error-Handling ; NFR11] — erreur non fatale, jamais de pause forcée (catalogue vide → WARN).
- [Source: 1-3…md#Piège-n°1 ; 1-4…md#Task-7 ; game_manager.gd ; selection_controller.gd] — interactif en pause = `PROCESS_MODE_ALWAYS`.
- [Source: 1-4…md] — autoload `Log`, pas de `class_name` autoload, pas de GUT (runner headless), pas de VCS, logique pure testable `--script`, harnais `--*-smoke`, point d'entrée commun clic/test, piège des lambdas (compteurs membres).
- [Source: lecture directe] — `event_bus.gd`, `solicitation_system.gd`, `solicitation.gd`, `selection_controller.gd`, `agent.gd`, `game_manager.gd`, `main.gd`, `open_space.tscn`, `main.tscn`, `agent.tscn`.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.8 (claude-opus-4-8)

### Debug Log References

- Import headless propre (**0 erreur / 0 warning**) : `godot --headless --path open_space --import` (Godot 4.6.3-stable).
- Tests unitaires décisions : `--script res://tests/unit/test_decision.gd` → `TEST_RESULT=PASS`, **17/17** (`is_valid_option_count` 0/1/2/3/4 ; `pick_index` bornes + défensif ; `DecisionCatalog.pick` bon canal / fallback / catalogue vide → null ; invariant « chaque décision livrée a 2-3 options » en chargeant le `.tres` réel).
- Intégration pop-up : `godot --headless --path open_space -- --decision-smoke` → `DECISION_SMOKE shown=true options=3 advanced=0.00500 chosen=3 closed=true fifo=true pause_ok=true`, `DECISION_SMOKE_RESULT=PASS`. Couvre AC#1 (pop-up affichée avec 3 boutons), AC#2 (la phase de journée avance de 0.005 pop-up ouverte, jeu non en pause), AC#4 (`choose_option` émet `decision_chosen` + referme), AC#5 (catalogue `.tres`), + FIFO Task 5 (`fifo=true` : 2e sollicitation enfilée puis dépilée à la fermeture) + interactivité en pause (`pause_ok=true`, `process_mode == PROCESS_MODE_ALWAYS`).
- Non-régression : `test_solicitation_math` / `test_agent_sim` / `test_camera_math` / `test_time_control` → **PASS** ; `--sim-smoke` / `--time-smoke` / `--solicitation-smoke` → **PASS** (`TOTAL_FAILURES=0`).
- Perf (NFR1) : `--measure-fps` → `FPS_MEASUREMENT=145`, exit 0 → bien au-delà de 60 (pop-up active sans allocation per-frame).
- **Décision d'implémentation (sérialisation `.tres`)** : le `data/decisions/decision_catalog.tres` a été généré par un script-outil ponctuel (`ResourceSaver.save`) **puis l'outil supprimé**, pour garantir une sérialisation correcte des tableaux typés de Resources (`Array[ExtResource(...)]([SubResource(...)])`) plutôt qu'un hand-authoring risqué. Le `.tres` est l'artefact livré.
- Note : les 2 warnings runtime de navigation (« parse RenderingServer meshes… » / « agent_radius… ») proviennent de `open_space.gd::_build_navigation` (code Story 1.2 **non modifié**) — pré-existants, hors périmètre 1.5, sans impact (déjà documentés en 1.3/1.4). L'import reste 0/0.

### Completion Notes List

- **Première UI 2D du projet** (CanvasLayer + Control, D9), conforme à l'archi : logique dans `scripts/decisions/`, scène dans `scenes/ui/` (nouveau dossier), contenu dans `data/decisions/` (nouveau dossier). Établit le pattern réutilisé par le HUD (1.8), la fiche (1.9), le bilan (1.10).
- **Modèle de données pur & data-driven** : `Decision` (contexte + `Array[DecisionOption]`) et `DecisionOption` (libellé) sont des `Resource` `.tres` ; `DecisionMath` (pur) porte l'invariant **2-3 options** et le choix d'index borné ; `DecisionCatalog` (`Resource`) sélectionne un template **par canal** (`Solicitation.Channel`, source unique réutilisée — aucun enum redéclaré) avec **fallback** si une liste est vide. Tout testé en `--script` (sans autoload).
- **Catalogue livré** : 2 décisions DESK (dont l'exemple canonique GDD « Le client menace de partir » → [Rassurer]/[Baisser le prix -500 €]/[Ignorer], 3 options ; + « augmentation » 2 options) et 2 décisions MAIL (« jour de congé » 3 options ; « process de validation » 2 options). Montants = **texte d'habillage** ; l'effet réel est la Story 1.6.
- **Contrôleur `DecisionPopup`** : s'abonne à `EventBus.solicitation_opened` (émis par 1.4), `pick()` un template, remplit le `Label` de contexte et **crée un `Button` par option** (2-3) ; `choose_option(index)` = **point d'entrée commun** clic/test → émet `decision_chosen(decision_id, index)` + referme. `decision_id` runtime incrémental (distinct du `.tres`). `PROCESS_MODE_ALWAYS` → cliquable en pause ; **ne met jamais le jeu en pause** lui-même.
- **FIFO minimale anti-perte (Task 5)** : une seule pop-up à la fois ; une sollicitation reçue pendant l'affichage est **enfilée** (la 1.4 a déjà consommé la sollicitation à l'ouverture → l'ignorer la perdrait) et **dépilée** à la fermeture. Garde-fou volontairement minimal ; la vraie file physique (patience/moral/ordre) est la Story 1.7.
- **Signal `EventBus.decision_chosen(decision_id, option_index)`** ajouté (snake_case passé) ; les 11 signaux existants préservés. `decision_resolved` (fondateur) **laissé intact** pour la Story 1.6 (résolution/effet).
- **Frontières respectées (hors périmètre)** : aucun effet de jeu / immédiat-vs-différé (1.6) ; timing de retour de l'agent **inchangé** (1.4 : `open_solicitation`→`clear_solicitation`) — `solicitation_system.gd`/`agent.gd`/`selection_controller.gd` **non modifiés** ; pas de HUD/compteur (1.8) ; pas de fiche agent (1.9) ; pas d'art/SFX/juice final (Épic 6).
- **Non-conflit clic** : un fond `ColorRect` plein écran (`mouse_filter = STOP`) bloque le clic-à-travers ; les `Button` consomment le clic GUI → `SelectionController._unhandled_input` n'ouvre pas une sollicitation derrière.
- **Non-régression** : caméra (1.1), simulation (1.2), contrôle du temps (1.3) et sollicitations (1.4) restent pleinement opérationnels (5 suites unitaires + 4 smokes PASS, 145 FPS, import 0/0).

### File List

**Nouveaux fichiers (sous `open_space/`) :**
- `scripts/decisions/decision_option.gd` (`class_name DecisionOption extends Resource` — libellé d'option)
- `scripts/decisions/decision.gd` (`class_name Decision extends Resource` — contexte + options)
- `scripts/decisions/decision_math.gd` (`class_name DecisionMath` — `is_valid_option_count`/`pick_index` purs)
- `scripts/decisions/decision_catalog.gd` (`class_name DecisionCatalog extends Resource` — `pick(channel, roll)` + fallback)
- `scripts/decisions/decision_popup.gd` (contrôleur CanvasLayer : affichage, boutons, `choose_option`, FIFO)
- `scenes/ui/decision_popup.tscn` (CanvasLayer + Blocker/Panel/VBox/`%ContextLabel`/`%OptionsBox`)
- `data/decisions/decision_catalog.tres` (catalogue data-driven : 2 décisions DESK + 2 MAIL)
- `tests/unit/test_decision.gd` (runner headless, 17 tests)

**Fichiers modifiés :**
- `scripts/autoloads/event_bus.gd` (signal `decision_chosen` ajouté ; 11 existants préservés)
- `scenes/world/open_space.tscn` (instance `%DecisionPopup` ajoutée ; structure préservée)
- `scripts/main/main.gd` (harnais `--decision-smoke` + compteur membre `_decisions_chosen` + helpers `_force_desk_solicitation`/`_open_first_active` ; 4 harnais existants préservés)

## Change Log

| Date | Version | Description |
|---|---|---|
| 2026-06-22 | 0.5.0 | Implémentation Story 1.5 : pop-up de décision 2-3 options (**première UI 2D**, CanvasLayer + Control, D9). Contenu data-driven `.tres` (`DecisionCatalog` → `Decision`/`DecisionOption`, sélection par canal + fallback) ; `DecisionMath` pur (invariant 2-3 options). `DecisionPopup` s'abonne à `solicitation_opened` (1.4), affiche contexte + boutons d'options, `choose_option` émet `decision_chosen` (Story 1.6) et referme ; `PROCESS_MODE_ALWAYS` (cliquable en pause) sans jamais mettre le jeu en pause ; FIFO minimale anti-perte de décision. Signal `decision_chosen` ajouté (`decision_resolved` laissé pour 1.6). Tests : 17/17 unitaires `test_decision` + `--decision-smoke` PASS (affichage, temps continue, choix+ferme, FIFO, pause) ; non-régression 5 suites unitaires + 3 smokes PASS ; 145 FPS (NFR1) ; import 0/0. Timing agent 1.4 et `solicitation_system.gd` non modifiés. Statut → review. |
