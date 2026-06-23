---
baseline_commit: 17a1bf743b7bbe370a86cc508b0222aa2bb0b047
---

# Story 1.9: Fiche agent & sélection

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a joueur,
I want cliquer gauche sur un agent pour ouvrir sa **fiche** (identité + jauge Moral), avec un **emplacement réservé** pour les actions futures (brancher/débrancher, jour off — désactivées à ce stade), et la **refermer** proprement,
so that je comprends l'**état individuel** de chaque agent (et pas seulement les agrégats du HUD 1.8) — première brique d'inspection qui prépare la gestion humaine des Épics 2/5.

## Acceptance Criteria

1. **Given** des agents sont présents dans l'open space **When** je **clique gauche** sur l'un d'eux (et qu'il **n'a pas** de sollicitation active — cf. bornage / décision de conception) **Then** sa **fiche** s'ouvre : **identité** (nom d'archétype + `agent_id`) et **jauge Moral** (valeur entière 0-100 lue sur l'agent, posée en 1.7), avec un **signal de seuil** sur le moral (couleur ambre/rouge sous les seuils `.tres`, lisibilité NFR7). [Source: epics.md#Story-1.9 AC1 ; FR43 (clic agent → fiche : jauges, identité) ; FR12 (Moral 0-100 par agent) ; gdd.md §Controls (« Clic sur un agent : ouvrir sa fiche ») ; game-architecture.md#Decision-Summary D9 (UI = Control + CanvasLayer)]
2. **Given** la fiche est ouverte **When** je la consulte **Then** elle **réserve l'emplacement des actions futures** — **brancher/débrancher** (FR32, Épic 5) et **jour off** (FR17, Épic 2) — sous forme de **boutons désactivés** (`disabled = true`, **sans aucune connexion ni logique**), exactement comme le HUD 1.8 réserve la Trésorerie (placeholder figé). [Source: epics.md#Story-1.9 AC2 ; FR32/FR17 ; epics.md#Épic-5/#Épic-2 ; 1-8…md (patron du placeholder réservé) ]
3. **Given** une fiche est ouverte **When** je **clique ailleurs** (le vide / un autre agent) **ou** j'actionne le **bouton Fermer** **Then** elle se **referme proprement** (clic sur un **autre** agent sans sollicitation → la fiche **bascule** sur cet agent ; clic dans le **vide** → fermeture ; le clic **sur** la fiche ne la ferme pas et n'est **jamais** capté comme clic de sélection 3D). De plus, si l'agent affiché **quitte** l'open space (`agent_departed` — soir / `queue_free`), la fiche se **referme automatiquement** (anti-fiche-fantôme). [Source: epics.md#Story-1.9 AC3 ; 1-8…md#anti-fantôme (départ purge l'état) ; selection_controller.gd (handler de clic à étendre) ]

> **Frontière de cette story (lire absolument — périmètre volontairement borné) :**
> - **1.9 FAIT** : (a) une **fiche agent** = nouvelle UI `CanvasLayer` (`%AgentCard`) avec un **Panel ancré** (côté écran), instanciée dans `open_space.tscn`, affichant **identité + Moral** d'**un** agent ; (b) **étend le `SelectionController`** (1.4) pour **router** le clic gauche : agent **avec** sollicitation active → comportement **1.4 inchangé** (`open_solicitation`) ; agent **sans** sollicitation → **ouvre/bascule** la fiche ; clic **dans le vide** → **ferme** la fiche ; (c) un **point d'entrée commun** testable sur le `SelectionController` (`handle_agent_click(agent)` / `handle_empty_click()`), appelé par `_unhandled_input` **et** par le smoke `--card-smoke` (modèle `DecisionPopup.choose_option` / `SolicitationSystem.open_solicitation`) ; (d) **un getter additif** `Agent.get_display_name()` (lecture seule de l'archétype, **aucun** changement de comportement) ; (e) la fiche est un **consommateur EventBus** pour le **live** (`agent_morale_changed` → met à jour le moral affiché ; `agent_departed` → auto-fermeture), et **réutilise `HudMath.morale_severity`** (1.8) pour la couleur de seuil — **zéro** nouveau module/seuil.
> - **1.9 NE FAIT PAS** (ne pas déborder) :
>   - **Aucune action réelle** : brancher/débrancher (FR32 = **Épic 5**), jour off / heures sup' (FR17 = **Épic 2**), jours de repos, etc. → **boutons désactivés** réservés, **sans** logique. **NE PAS** câbler le LLM ni le temps de travail.
>   - **Aucune autre jauge** que le **Moral** : Fatigue / burnout / instabilité = **Épic 2** ; Trésorerie individuelle / salaire = **Épic 3**. Le seul état par-agent existant est le **Moral (0-100)** (posé en 1.7). **NE PAS** inventer de jauge.
>   - **Pas de surbrillance/outline 3D de l'agent sélectionné, pas d'indicateur « branché » au-dessus de la tête** (FR32/FR44 visuel, indicateurs sur têtes = **Épic 6**), pas de juice/animation d'ouverture (tween, fade) = **Épic 6**. Ici : Panel statique + Labels + couleur de seuil suffisent.
>   - **Pas de modification de la jauge Moral** ni d'aucun système (`SolicitationSystem`, `DeskQueue`, `Agent` **au-delà** du getter additif, `GameManager`, `EventBus`, `DecisionPopup`, `Hud`). La fiche est un **lecteur** ; le `SelectionController` ne fait que **router** un clic déjà existant.
>   - **Pas de pop-up de décision modifiée** : la fiche est **non-modale** (elle ne bloque ni la souris hors de son Panel, ni le temps — inverse de la pop-up 1.5). Le temps continue de tourner fiche ouverte.
>   - **Pas de persistance** (sauvegarde de la sélection) = **Épic 7**. La fiche reflète l'état courant ; un agent recréé chaque matin n'a pas de fiche mémorisée.
>   - **Pas de bilan de fin de journée** (écran modal récap) = **Story 1.10**.

## Tasks / Subtasks

- [x] **Task 1 — Scène fiche : `scenes/ui/agent_card.tscn` (CanvasLayer + Panel ancré, non-modal)** (AC: #1, #2, #3)
  - [x] Créer `scenes/ui/agent_card.tscn` : racine **`AgentCard` (CanvasLayer)** + script `agent_card.gd` (Task 2). Modèle = `scenes/ui/hud.tscn` (CanvasLayer + Control) pour les conventions, mais avec un **Panel** ancré (pas une TopBar pleine largeur).
  - [x] **Panel ancré sur un côté** (ex. coin bas-droite ou droite) : `Panel` (`%Card`, ancré, taille fixe ex. 280×220) → `Margin` (`MarginContainer`) → `VBox` (`VBoxContainer`, séparation 8). **`mouse_filter = STOP` (0) sur le `Panel`** uniquement → il **capte** les clics **dans son rect** (le bouton Fermer fonctionne ; cliquer la fiche ne déclenche **pas** `_unhandled_input` → ne déselectionne pas). **AUCUN** catcher plein écran (sinon il volerait tous les clics 3D) : hors du Panel, les clics atteignent `SelectionController._unhandled_input` (→ « clic ailleurs ferme »). C'est l'**inverse** de la pop-up modale 1.5 (Blocker plein écran) et symétrique au HUD (qui, lui, est IGNORE partout).
  - [x] **Labels nommés `unique_name_in_owner = true`** (lecture par `%`) :
    - `%NameLabel` (« {nom archétype} #{id} »),
    - `%MoraleLabel` (« Moral : NN » ; couleur de seuil),
    - `%ActionsHint` (libellé « Actions (à venir) » — facultatif, simple intitulé de section).
  - [x] **Boutons d'actions futures DÉSACTIVÉS** (réservation AC2) : `%LinkButton` (« Brancher l'IA — Épic 5 », `disabled = true`), `%DayOffButton` (« Jour off — Épic 2 », `disabled = true`). **Aucune** connexion `pressed`, **aucune** logique. Pur placeholder (patron Trésorerie 1.8).
  - [x] **Bouton Fermer** : `%CloseButton` (« ✕ » / « Fermer ») — **seul** bouton actif ; il appellera `hide_card()` (Task 2). Étant **dans** le Panel (STOP), son clic est consommé par la GUI (ne traverse pas vers le 3D).
  - [x] Texte **lisible** sur la DA claire « Severance » (texte foncé contrasté, Panel semi-opaque léger pour NFR7). `visible = false` au départ (la fiche s'ouvre à la sélection).

- [x] **Task 2 — `AgentCard` : affichage d'un agent + live EventBus + fermeture** (AC: #1, #2, #3)
  - [x] Créer `scripts/ui/agent_card.gd` (`extends CanvasLayer`, **sans `class_name`** — cohérent `Hud`/`DecisionPopup`/`SolicitationSystem` : un nœud de scène n'a pas de `class_name`). Doc d'en-tête + sources + rappel « fiche = lecteur d'état d'UN agent ; non-modale ; réutilise HudMath pour la couleur ».
  - [x] `const _BALANCE: SimBalance = preload("res://data/balance/sim_balance.tres")` (réutilise les **seuils HUD** existants `hud_morale_warn_below` / `hud_morale_critical_below` — **aucun nouveau champ `.tres`**).
  - [x] Couleurs de seuil **en dur** (présentation, pas équilibrage) — réutiliser exactement la convention du HUD : `_COLOR_NORMAL` foncé, `_COLOR_WARNING` ambre, `_COLOR_CRITICAL` rouge.
  - [x] `@onready var` sur chaque label/bouton via `%` (cf. Task 1). **Pas** de chemin de nœud absolu.
  - [x] État minimal : `var _agent_id: int = -1` (id de l'agent **actuellement affiché**, `-1` = aucune fiche). **Pas** de référence de nœud conservée au-delà de l'instant de `show_for` (on lit l'identité une fois, puis on suit le moral par **signal** filtré sur `_agent_id` → robuste si l'agent est libéré).
  - [x] `_ready()` :
    - `process_mode = Node.PROCESS_MODE_ALWAYS` (cohérent UI : interactive/à jour même en pause — la fiche ne **met pas** le jeu en pause, mais reste vivante s'il l'est).
    - `visible = false`.
    - Abonnements **persistants** : `EventBus.agent_morale_changed.connect(_on_agent_morale_changed)` ; `EventBus.agent_departed.connect(_on_agent_departed)`. (Pas besoin de connect/disconnect par ouverture : on **filtre** sur `_agent_id`.)
    - `%CloseButton.pressed.connect(hide_card)`.
  - [x] **Pas de `_process`** (NFR1) : 100 % événementiel (signal moral + clics).
  - [x] **`func show_for(agent: Agent) -> void`** (appelée par le `SelectionController`) : garde `if agent == null: return` ; `_agent_id = agent.agent_id` ; `%NameLabel.text = "%s #%d" % [agent.get_display_name(), agent.agent_id]` ; rendre le moral via `_render_morale(agent.get_morale())` ; `visible = true`. (Lecture **ponctuelle** de l'identité + moral courant ; les variations ultérieures arrivent par signal.)
  - [x] **`func hide_card() -> void`** : `visible = false` ; `_agent_id = -1`. (Fermeture propre — bouton Fermer, clic vide, ou départ.)
  - [x] Handlers :
    - `_on_agent_morale_changed(agent_id, morale)` : **si** `agent_id == _agent_id` **et** `is_showing()` → `_render_morale(morale)` (live).
    - `_on_agent_departed(agent_id)` : **si** `agent_id == _agent_id` → `hide_card()` (anti-fiche-fantôme : l'agent affiché a quitté l'open space).
  - [x] `_render_morale(morale: int)` : `%MoraleLabel.text = "Moral : %d" % morale` ; **couleur de seuil** via `HudMath.morale_severity(morale, _BALANCE.hud_morale_warn_below, _BALANCE.hud_morale_critical_below)` → `_apply_severity(%MoraleLabel, severity)` (réutilise la logique pure **déjà testée** en 1.8). `_apply_severity` identique au HUD (`add_theme_color_override("font_color", …)`).
  - [x] **Garde-fous NFR11** : un signal pour un `agent_id` ≠ `_agent_id` est ignoré sans effet ; aucun appel vers un autre système ; lecture seule de `_BALANCE`. Un `show_for(null)` est sans effet.
  - [x] **Getters pour le test** (modèle `DecisionPopup.is_showing()` / `Hud.displayed_*`) : `func is_showing() -> bool` (= `visible`) ; `func displayed_agent_id() -> int` (= `_agent_id`) ; `func displayed_morale() -> int` (parse de `%MoraleLabel` **ou** mémoriser le dernier moral rendu dans une var `_shown_morale` — **préférer une var membre** `_shown_morale` mise à jour dans `_render_morale`, plus robuste que parser le texte).

- [x] **Task 3 — Étendre `SelectionController` : router le clic (sollicitation ↔ fiche ↔ fermeture)** (AC: #1, #3)
  - [x] **UPDATE** `scripts/world/selection_controller.gd`. **Préserver** le raycast existant (`_agent_under_mouse` / `_as_agent` / `_RAY_LEN`) **inchangé**. Ajouter `@onready var _agent_card: CanvasLayer = %AgentCard` (la fiche, via nom unique — précédent : le controller référence déjà `%SolicitationSystem`).
  - [x] Remanier `_unhandled_input` pour **router** vers des **points d'entrée communs** (testables) :
    ```
    func _unhandled_input(event):
        if not event.is_action_pressed("select_click"): return
        var agent := _agent_under_mouse()
        if agent != null: handle_agent_click(agent)
        else:             handle_empty_click()
    ```
  - [x] **`func handle_agent_click(agent: Agent) -> void`** — **POINT D'ENTRÉE COMMUN** (clic réel + `--card-smoke`) :
    - **Si** `_solicitations.has_active_solicitation(agent.agent_id)` → `_solicitations.open_solicitation(agent.agent_id)` (**comportement 1.4 STRICTEMENT préservé** : l'agent qui réclame l'attention est traité d'abord — c'est la boucle cœur). **Ne PAS** ouvrir la fiche dans ce cas.
    - **Sinon** → `_agent_card.show_for(agent)` (fiche de l'agent inspecté ; un nouveau clic sur un autre agent **bascule** la fiche — `show_for` réécrit `_agent_id`).
  - [x] **`func handle_empty_click() -> void`** : `_agent_card.hide_card()` (« clic ailleurs ferme »). *(Le clic **sur** le Panel de la fiche est consommé par la GUI → `_unhandled_input` ne le voit pas → la fiche ne se ferme pas en se cliquant elle-même.)*
  - [x] **Préserver** `process_mode = PROCESS_MODE_ALWAYS` (ouverture/sélection possible en pause, 1.4). Conventions : Input Map (`select_click`, déjà défini en 1.4), pas de chemin absolu.
  - [x] **Mettre à jour la doc d'en-tête** du controller (elle annonce déjà « la fiche agent au clic est la Story 1.9, qui étendra ce handler ») : décrire le routage sollicitation-prioritaire ↔ fiche ↔ fermeture.

- [x] **Task 4 — Getter d'identité additif sur `Agent`** (AC: #1)
  - [x] **UPDATE** `scripts/agents/agent.gd` : ajouter **un seul** getter **lecture seule**, **purement additif** (modèle `get_morale()` ajouté en 1.7) :
    ```
    ## Nom lisible de l'agent (archétype) — pour la fiche agent (1.9) / debug. Lecture seule.
    func get_display_name() -> String:
        return _archetype.display_name if _archetype != null else "Agent"
    ```
  - [x] **NE RIEN d'autre modifier** dans `agent.gd` : aucune logique de mouvement, sollicitation, moral, état. `_archetype` existe déjà (posé en 1.2) et porte `display_name` (cf. `agent_archetype.gd`). [Source: lecture directe agent.gd L28/L61-68 ; agent_archetype.gd L10]

- [x] **Task 5 — Instancier `%AgentCard` dans l'open space** (AC: #1, #2, #3)
  - [x] **UPDATE** `scenes/world/open_space.tscn` : ajouter une instance de `scenes/ui/agent_card.tscn` (nœud `AgentCard`) **enfant de `OpenSpace`**, avec `unique_name_in_owner = true` (`%AgentCard`). Modèle = l'instance `Hud` (`[node name="Hud" parent="." instance=ExtResource("9")]`).
  - [x] Déclarer la `PackedScene` de la fiche via un **nouvel `id` `ext_resource` distinct** (`id="10"` — ids 1-9 déjà pris). **Préserver toute la structure existante** (`GridMap`/`NavigationRegion3D`/`%Agents`/`AgentSpawner`/`%SolicitationSystem`/`SelectionController`/`%DecisionPopup`/`%DecisionResolver`/`%DeskQueue`/`%Hud`/`WorldEnvironment`/`DirectionalLight3D`/`CameraRig (process_mode=3)/Camera3D`).
  - [x] L'ordre d'instanciation doit garantir que `%AgentCard` existe quand `SelectionController._ready()` résout `%AgentCard` (`@onready` → résolu après que tous les enfants frères sont entrés dans l'arbre du parent ; ajouter l'instance **avant** ou **après** `SelectionController` est sans effet sur `@onready`, qui s'exécute en fin de `_ready`). Import **0 erreur / 0 warning**.

- [x] **Task 6 — Tests (intégration `--card-smoke` + non-régression)** (AC: #1, #2, #3)
  - [x] **Intégration** `--card-smoke` dans `scripts/main/main.gd` (modèle `_run_hud_smoke_and_quit` ; réutiliser `_real_wait`, `_force_desk_solicitation`, `_find_agent_by_id`, `_open_first_active`). Récupérer `var card: CanvasLayer = open_space.get_node("AgentCard")` et `var selection: Node = open_space.get_node("SelectionController")`.
    - **Pré** : `solicitations.rate_override = 0.0`, `set_speed(3)`, `await _real_wait(4.0)` (agents arrivés, **aucune** sollicitation).
    - **AC1 (ouverture + identité + moral)** : prendre un agent (`agents_root.get_children()` premier `Agent`) ; `selection.handle_agent_click(agent)` → `card.is_showing() == true` ; `card.displayed_agent_id() == agent.agent_id` ; `card.displayed_morale() == 100` (moral initial).
    - **AC1 (live moral via vrai signal)** : `agent.adjust_morale(-60)` (émet `agent_morale_changed`) → `card.displayed_morale() == 40` (fiche mise à jour en direct). *(Optionnel : vérifier la sévérité WARNING via `HudMath.morale_severity`.)*
    - **AC3 (bascule sur un autre agent)** : `selection.handle_agent_click(autre_agent)` → `card.displayed_agent_id() == autre_agent.agent_id` (la fiche **change** d'agent, reste ouverte).
    - **AC3 (clic ailleurs ferme)** : `selection.handle_empty_click()` → `card.is_showing() == false`.
    - **AC3 (auto-fermeture au départ)** : rouvrir (`handle_agent_click(agent)`), puis émettre le départ via le vrai chemin (`EventBus.agent_departed.emit(agent.agent_id)` **ou** forcer le soir) → `card.is_showing() == false`.
    - **Non-régression 1.4 (sollicitation prioritaire)** : `await _force_desk_solicitation(solicitations)` ; prendre un agent **avec** sollicitation active (`solicitations.has_active_solicitation(id)`) ; `card.hide_card()` (état propre) puis `selection.handle_agent_click(cet_agent)` → la **sollicitation s'ouvre** (`has_active_solicitation(id) == false` après) **et** `card.is_showing() == false` (la fiche **ne** s'ouvre **pas** pour un agent sollicité).
    - Restaurer overrides (`rate_override = -1.0`, `desk_prob_override = -1.0`), `set_speed(1)`, `Engine.time_scale = 1.0`. `print("CARD_SMOKE ...")` + `CARD_SMOKE_RESULT=PASS/FAIL` + `get_tree().quit(0/1)`.
  - [x] Brancher `--card-smoke` dans `_ready()` (nouvelle branche `elif args.has("--card-smoke")`) **sans toucher aux 8 branches existantes** (`--measure-fps`/`--sim-smoke`/`--time-smoke`/`--solicitation-smoke`/`--decision-smoke`/`--resolution-smoke`/`--queue-smoke`/`--hud-smoke`).
  - [x] **Piège lambda GDScript (capture par valeur)** : si un compteur/mémo est requis dans le smoke, utiliser des **variables membres** de `main.gd`, jamais un local capturé dans un signal (cf. apprentissages 1.4/1.6/1.7). Ici on lit surtout les getters → peu de captures.
  - [x] **Non-régression** : suites unitaires existantes (`test_camera_math`, `test_agent_sim`, `test_time_control`, `test_solicitation_math`, `test_decision`, `test_decision_resolution`, `test_morale`, `test_hud`) → **8/8 PASS** (la fiche n'ajoute **pas** de module pur testable séparément ; elle réutilise `HudMath`, déjà couvert) ; et **9 smokes** (`--sim`/`--time`/`--solicitation`/`--decision`/`--resolution`/`--queue`/`--hud`/`--card`) → **PASS** ; `--measure-fps` → **≥ 60** (NFR1). Sélection 3D non volée par la fiche : garantie déclarative par **`mouse_filter = STOP` borné au Panel** (aucun catcher plein écran).

## Dev Notes

### Contexte & objectif

Les Stories 1.1→1.8 ont posé le modèle complet (caméra, agents, temps, sollicitations DESK/MAIL, pop-up, résolution, file/patience/**Moral 0-100**) et la **première UI persistante** (HUD 1.8, agrégats **globaux**). Ce qui manque : voir l'**état d'UN agent**. La 1.9 ajoute la **fiche agent** — une UI `CanvasLayer` non-modale qui, au **clic gauche** sur un agent, affiche son **identité** (archétype + id) et sa **jauge Moral** (la seule jauge par-agent existante, 1.7), avec le **même signal de seuil couleur** que le HUD. C'est la **brique d'inspection** qui prépare la gestion humaine (brancher/débrancher = Épic 5, jour off/fatigue = Épic 2) — d'où les **emplacements d'actions réservés mais désactivés** (AC2). [Source: epics.md#Story-1.9 ; FR43/FR12 ; gdd.md §Controls/§Piliers ; game-architecture.md#Decision-Summary D9]

### ⚠️ Décision de conception clé n°1 : le **routage du clic** (sollicitation-prioritaire ↔ fiche)

Le `SelectionController` (1.4) traduit **déjà** le clic gauche sur un agent en `open_solicitation()`. La fiche 1.9 doit cohabiter **sans casser la boucle cœur**. **Décision retenue (à confirmer, cf. Questions) :** un clic gauche sur un agent **avec sollicitation active** ouvre/traite la **sollicitation** (1.4 **inchangé** — l'agent qui réclame l'attention passe en priorité, c'est le pilier #1) ; un clic sur un agent **sans** sollicitation ouvre sa **fiche**. Rationale :
- **Zéro régression de la boucle 1.4→1.5** : le geste « cliquer l'agent au bureau pour trancher » reste identique ; le smoke `--solicitation-smoke`/`--decision-smoke` reste vert (ils passent par `open_solicitation` directement, et le clic réel garde la même priorité).
- **FR43 satisfait pour le cas normal** : la grande majorité des agents (au poste, sans sollicitation) ouvrent leur fiche au clic — exactement « Clic sur un agent : ouvrir sa fiche » (GDD).
- **Symétrie de point d'entrée** : `handle_agent_click(agent)` est le **POINT D'ENTRÉE COMMUN** (clic réel + smoke), exactement comme `DecisionPopup.choose_option` / `SolicitationSystem.open_solicitation` exposent un seuil testable. [Source: decision_popup.gd L78-81 ; solicitation_system.gd L65-78 ; gdd.md §Controls ; FR43]

> **Pourquoi ne PAS ouvrir la fiche ET la sollicitation en même temps** : deux UIs simultanées (fiche non-modale + pop-up modale) nuiraient à la lisibilité (NFR7) et compliqueraient l'input. La priorité « sollicitation d'abord » garde une seule intention par clic. Une interaction plus riche (fiche → bouton « traiter », ou fiche d'un agent sollicité) relève du polish (Épic 6) ou d'un correct-course explicite.

### ⚠️ Décision de conception clé n°2 : fiche **non-modale**, fermeture par clic extérieur **sans catcher plein écran**

La pop-up 1.5 est **modale** (Blocker `ColorRect` plein écran → capte tout). La fiche 1.9 est **l'inverse** : elle ne doit **ni** geler le temps **ni** voler les clics 3D (sélection caméra/agents). Donc **pas** de catcher plein écran. Mécanique de fermeture « clic ailleurs » :
- Seul le **Panel** a `mouse_filter = STOP` → il consomme les clics **dans son rect** (le bouton Fermer marche, et cliquer la fiche ne déclenche pas `_unhandled_input` → ne déselectionne pas).
- **Hors** du Panel, les clics ne sont consommés par aucun Control → ils atteignent `SelectionController._unhandled_input` → `handle_empty_click()` (vide) **ou** `handle_agent_click(autre)` (bascule). C'est le `SelectionController` qui **pilote** l'ouverture/fermeture/bascule ; la fiche expose juste `show_for()` / `hide_card()`. [Source: decision_popup.tscn (Blocker modal) vs hud.tscn (IGNORE partout) ; hud.gd#mouse_filter ; selection_controller.gd]

> **Subtilité Godot** : un `Control` `mouse_filter = STOP` ne consomme que les events **survolant son rect**. Un clic hors du Panel arrive donc bien à `_unhandled_input`. (Le HUD met IGNORE **partout** car il ne doit **jamais** capter ; la fiche met STOP **uniquement** sur le Panel pour que ses propres boutons marchent **et** que le reste de l'écran reste « sélectionnable ».)

### La fiche, lecteur d'état d'UN agent : identité ponctuelle + moral par signal

La fiche lit l'**identité** une seule fois à l'ouverture (`agent.get_display_name()` + `agent.agent_id`, via la référence passée par le `SelectionController` au clic — le controller tient déjà cette ref depuis son raycast). Elle **ne conserve pas** de référence de nœud : elle mémorise seulement `_agent_id` et suit les **variations de moral par signal** `agent_morale_changed` **filtré** sur `_agent_id` (comme le HUD suit le moral moyen). Conséquences :
- **Robuste à la libération** : si l'agent est `queue_free()` (départ du soir), `agent_departed` ferme la fiche (anti-fiche-fantôme) — on ne déréférence jamais un nœud mort.
- **Live** : baisser le moral (impatience en file, 1.7) met à jour la fiche ouverte en temps réel.
- **Pas de double source de vérité** : la valeur initiale vient de `agent.get_morale()` (= état réel de l'agent), pas d'un seed dupliqué. [Source: agent.gd L229-239 (get_morale/adjust_morale + signal) ; 1-8…md (HUD suit le moral par signal) ]

### Réutilisation de `HudMath` (zéro nouveau module pur, zéro nouveau seuil)

Le HUD 1.8 a déjà un module **pur testé** `HudMath` (`morale_severity`, testé `--script` 18/18) et trois **seuils `.tres`** (`hud_morale_warn_below=50` / `hud_morale_critical_below=25`). La fiche **réutilise** `HudMath.morale_severity` pour colorer le moral **individuel** et **réutilise** les **mêmes seuils** (`_BALANCE.hud_morale_warn_below/critical_below`). → **Aucun** nouveau module math, **aucun** champ `.tres` ajouté, **aucune** réécriture de `sim_balance.tres` (il reste vide / défauts du script). C'est pourquoi 1.9 **n'ajoute pas** de suite unitaire `--script` (la logique pure est déjà couverte) et se valide par **intégration** `--card-smoke`. [Source: hud_math.gd (morale_severity) ; sim_balance.gd (seuils hud_*) ; 1-8…md ]

### Anti-pièges (apprentissages 1.1 → 1.8 — à respecter absolument)

- **L'autoload logger s'appelle `Log`, PAS `Logger`** (collision avec la classe native Godot 4.6). `Log.info/warn/error`. [Source: 1-1…/1-8…md]
- **Pas de `class_name` sur un nœud de scène** (`AgentCard` comme `Hud`/`DecisionPopup`/`SolicitationSystem`). Ici **aucun** nouveau module pur (réutilisation `HudMath`), donc pas de `class_name` à créer. [Source: 1-2…/1-8…md]
- **En mode `--script`, les autoloads ne sont PAS chargés** : non pertinent ici (pas de nouveau test `--script`), mais le `--card-smoke` tourne en **scène complète** (autoloads présents) comme les autres smokes. [Source: 1-8…md#Tests]
- **GUT non installé** → harnais headless via `main.gd --card-smoke` (`get_tree().quit(0/1)`), pas de GUT. [Source: 1-1…1-8…md]
- **VCS présent** (`baseline_commit` renseigné) mais **toujours valider par import + exécution headless réels** : `godot --headless --path open_space --import` doit rester **0 erreur / 0 warning** ; lancer **tous** les smokes + unitaires. [Source: 1-8…md#Debug-Log-References]
- **Piège des lambdas GDScript (capture par valeur)** : tout compteur/mémo via **variables membres** de `main.gd`. [Source: 1-4…/1-6…/1-7…md]
- **Pattern override de test** : **réutiliser** ceux des stories amont (`SolicitationSystem.rate_override`/`desk_prob_override`) ; **aucun nouvel override** requis (la fiche observe ; on pilote via `handle_agent_click`/`handle_empty_click` + `adjust_morale` + `agent_departed`). [Source: solicitation_system.gd ; 1-8…md]
- **Callbacks de signal vs pause** : `process_mode` gèle `_process`, pas les callbacks de signal. La fiche n'a pas de `_process` ; on la met `PROCESS_MODE_ALWAYS` (cohérence `DecisionPopup`/`Hud`). [Source: 1-6…/1-8…md]
- **`.tres` — ne PAS éditer** : la fiche réutilise les seuils HUD ; **aucun** champ ajouté, `sim_balance.tres` **non touché**. [Source: 1-8…md ; sim_balance.gd]
- **`mouse_filter = STOP` borné au Panel** (pas de catcher plein écran) — détaillé en décision n°2.

### Lecture des fichiers UPDATE (état actuel à préserver)

- **`scripts/world/selection_controller.gd`** — `extends Node`, `process_mode = PROCESS_MODE_ALWAYS`, `@onready var _solicitations := %SolicitationSystem`, `_unhandled_input` → `_agent_under_mouse()` → `open_solicitation()`. La doc d'en-tête **annonce déjà** l'extension 1.9. **Ajouter** `@onready var _agent_card := %AgentCard` + `handle_agent_click` / `handle_empty_click` ; **préserver** `_agent_under_mouse`/`_as_agent`/`_RAY_LEN`/`process_mode`. [Source: lecture directe selection_controller.gd]
- **`scripts/agents/agent.gd`** — `class_name Agent extends CharacterBody3D` ; `_archetype: AgentArchetype` (privé, porte `display_name`) ; expose déjà `get_morale()` (1.7) / `agent_id`. **Ajouter** uniquement `get_display_name()` (lecture seule). **Ne RIEN d'autre** modifier (mouvement, sollicitation, moral, états). [Source: lecture directe agent.gd L1-2/L28/L61-68/L229-239 ; agent_archetype.gd L10]
- **`scenes/world/open_space.tscn`** — `OpenSpace` avec enfants existants (…/`%Hud` instance `ExtResource("9")`). **Ajouter** une instance `%AgentCard` (nouvel `ext_resource id="10"`). **Préserver** tout (ids 1-9, `CameraRig process_mode=3`, etc.). [Source: lecture directe open_space.tscn]
- **`scripts/main/main.gd`** — 8 harnais (`--measure-fps`/`--sim-smoke`/`--time-smoke`/`--solicitation-smoke`/`--decision-smoke`/`--resolution-smoke`/`--queue-smoke`/`--hud-smoke`) + helpers `_force_desk_solicitation`/`_open_first_active`/`_find_agent_by_id`/`_min_agent_distance_to`/`_real_wait` + compteurs membres. **Ajouter** `--card-smoke` (+ branche dans `_ready`) en **réutilisant** les helpers. **Préserver les 8 harnais** et helpers. [Source: lecture directe main.gd L41-60/L460-568]
- **NE PAS MODIFIER** : `event_bus.gd` (aucun nouveau signal — la fiche consomme `agent_morale_changed`/`agent_departed` existants), `game_manager.gd`, `solicitation_system.gd`, `desk_queue.gd`, `decision_popup.gd`/`.tscn`, `decision_resolver.gd`, `hud.gd`/`hud_math.gd`/`hud.tscn`, `sim_balance.gd`/`.tres`, `agent_spawner.gd`, `agent_archetype.gd`, `morale_math.gd`, `solicitation.gd`. [Source: game-architecture.md#Architectural-Boundaries]

> **Important** : une story doit laisser le système **fonctionnel de bout en bout**. Au-delà des AC, caméra (1.1), agents (1.2), temps (1.3), sollicitations (1.4), pop-up (1.5), résolution (1.6), file/moral (1.7) et HUD (1.8) doivent rester pleinement opérationnels — **et la boucle clic→sollicitation 1.4 ne doit pas être interceptée par la fiche** (sollicitation-prioritaire).

### Performance (NFR1)

`AgentCard` est **100 % événementiel** (aucun `_process`) : il ne se redessine qu'à `show_for`/`hide_card` ou à la réception d'un `agent_morale_changed` filtré. Coût/frame **nul**. 60 FPS inchangés (1.8 mesurait 145 FPS). [Source: NFR1 ; 1-8…md]

### Direction artistique / UI

UI **fonctionnelle et lisible**, pas finalisée : Panel + Labels natifs sur la DA claire « Severance » (texte foncé contrasté, fond léger), signal de seuil moral par **couleur** (ambre/rouge), boutons d'actions futures **grisés** (désactivés). Le **juice** (tween d'ouverture, outline 3D de l'agent sélectionné, indicateur « branché » au-dessus de la tête, icônes) relève d'**Épic 6**. [Source: gdd.md §Art/§Controls ; epics.md#Épic-6 ; NFR7]

### Project Structure Notes

- Nouveaux fichiers conformes à la structure hybride (UI = `scripts/ui/` + `scenes/ui/`, cf. game-architecture.md#Project-Structure « ui/ : …, fiche agent ») : `scripts/ui/agent_card.gd`, `scenes/ui/agent_card.tscn`.
- Fichiers modifiés : `scripts/world/selection_controller.gd` (routage clic), `scripts/agents/agent.gd` (getter `get_display_name`), `scenes/world/open_space.tscn` (instance `%AgentCard`, `ext_resource id="10"`), `scripts/main/main.gd` (harnais `--card-smoke`).
- Aucune nouvelle dépendance, aucun addon, **aucun nouveau module pur** (réutilise `HudMath`), **aucun champ `.tres`** ajouté. `AgentCard` = nœud de scène (`CanvasLayer`) **sans** `class_name` (cohérent `Hud`/`DecisionPopup`).
- **Note d'emplacement** : la fiche est de l'UI pure (pas de domaine métier) → son script va dans `scripts/ui/` (comme le HUD), sa scène dans `scenes/ui/`. [Source: game-architecture.md#Project-Structure (ligne ui/) ; #System-Location-Mapping]

### Project Context Rules

- _Aucun `project-context.md` présent dans le dépôt._ Règles applicables (archi + stories 1.1-1.8) : **`EventBus`-only** (snake_case au passé ; la fiche **consomme** `agent_morale_changed`/`agent_departed`, le controller **route** un clic) ; **pas de chemins de nœuds absolus** (`@onready`/`%UniqueName`) ; **`.tres` pour les seuils** (zéro magic number — ici **réutilisés** du HUD) ; **GDScript typé** (import 0/0) ; autoload **`Log`** (pas `Logger`) ; **pas de `class_name`** sur nœud de scène ; **erreurs non fatales** (NFR11) ; **60 FPS** (NFR1) ; UI = **Control + CanvasLayer** natifs (D9) ; UI non-modale ≠ pop-up modale.
- **Outillage MCP** (GoPeak Godot MCP + Context7) prévu par l'archi — **non bloquant** ici. [Source: game-architecture.md#AI-Development-Tooling]

### References

- [Source: epics.md#Story-1.9] — fiche agent au clic gauche (jauges : moral ; identité) ; réservation des actions futures désactivées (brancher/débrancher, jour off) ; fermeture propre au clic ailleurs.
- [Source: epics.md#Story-1.8] — HUD persistant ; `HudMath`/seuils `.tres` **réutilisés** ; patron du placeholder réservé (Trésorerie) ; anti-fantôme par `agent_departed`.
- [Source: epics.md#Story-1.7] — `agent_morale_changed` (signal consommé ici) ; Moral 0-100 par agent ; `get_morale()`/`adjust_morale()`.
- [Source: epics.md#Story-1.4] — `SelectionController` (clic → `open_solicitation`) : **handler étendu** ici ; `has_active_solicitation` ; boucle cœur préservée.
- [Source: epics.md#FR43] — cliquer un agent ouvre sa fiche (jauges, brancher/débrancher, jour off) ; clic gauche sélectionne / valide.
- [Source: epics.md#FR12] — jauge Moral 0-100 par agent (la seule jauge par-agent à ce stade).
- [Source: epics.md#FR32 (Épic 5) / #FR17 (Épic 2)] — brancher/débrancher & jour off : **hors périmètre** → boutons réservés désactivés.
- [Source: epics.md#Épic-6] — outline de sélection, indicateurs au-dessus des têtes, juice : **hors périmètre**.
- [Source: gdd.md §Controls and Input] — « Clic gauche : sélectionner un agent / valider une option ; Clic sur un agent : ouvrir sa fiche (jauges, brancher/débrancher, jour off) ».
- [Source: game-architecture.md#Decision-Summary D9] — UI/HUD/fiche = Control nodes + `CanvasLayer`, natif Godot.
- [Source: game-architecture.md#Project-Structure ; #System-Location-Mapping] — `ui/` (scripts + `scenes/ui/`) pour hud/pop-ups/fiche.
- [Source: game-architecture.md#Event-System ; #Architectural-Boundaries ; #Configuration ; #Error-Handling] — EventBus typé, pas de chemins absolus, `.tres` seuils, erreur non fatale (NFR11).
- [Source: lecture directe] — `selection_controller.gd` (handler à étendre), `agent.gd` (`get_morale`/`agent_id`/`_archetype`), `agent_archetype.gd` (`display_name`), `hud.gd`/`hud_math.gd` (`morale_severity`, `_apply_severity`, getters de test), `decision_popup.gd`/`.tscn` (modèle CanvasLayer + point d'entrée commun + modal vs non-modal), `open_space.tscn` (instanciation `%Hud` → modèle `%AgentCard`), `main.gd` (harnais + helpers), `solicitation_system.gd` (`has_active_solicitation`/`open_solicitation`).
- [Source: 1-8…md] — autoload `Log` ; pas de `class_name` sur nœud de scène ; pas de GUT (harnais headless) ; pure `--script` (réutilisé) vs smoke d'intégration ; piège des lambdas ; pattern override de test ; prudence `.tres` ; le HUD suit le moral par signal (modèle direct pour la fiche).

## Dev Agent Record

### Agent Model Used

Claude Opus 4.8 (claude-opus-4-8)

### Debug Log References

- Moteur : Godot 4.6.3-stable (`Godot_v4.6.3-stable_win64_console.exe`), exécution **headless réelle** (validation par import + run, jamais « au jugé »).
- **Baseline avant dev** (état de départ vert) : import 0/0 (commit `17a1bf7`).
- Import après implémentation : `godot --headless --path open_space --import` → **0 erreur / 0 warning** (grep `SCRIPT ERROR|^ERROR:|WARNING:|Parse Error` = 0). `agent_card.gd` enregistré (`.uid` généré).
- Intégration fiche : `godot --headless --path open_space -- --card-smoke` → `CARD_SMOKE open=true morale0=true live40=true switch=true empty_close=true sol_priority=true depart_close=true`, `CARD_SMOKE_RESULT=PASS`. Couvre AC1 (ouverture : identité + moral=100 ; live : `agent_morale_changed` réel −60 → 40), AC3 (bascule sur un autre agent ; clic ailleurs ferme ; auto-fermeture sur `agent_departed`), et **non-régression 1.4** (agent avec sollicitation active → le clic ouvre la **sollicitation**, pas la fiche).
- **Non-régression** : 8 suites unitaires PASS (`test_camera_math`/`test_agent_sim`/`test_time_control`/`test_solicitation_math`/`test_decision`/`test_decision_resolution`/`test_morale`/`test_hud`) ; 8 smokes amont PASS (`--sim`/`--time`/`--solicitation`/`--decision`/`--resolution`/`--queue`/`--hud`) + `--card-smoke` PASS → **9 smokes PASS**.
- Perf (NFR1) : `--measure-fps` → `FPS_MEASUREMENT=145` (≥ 60 ; `AgentCard` événementiel, aucun `_process`).

### Completion Notes List

- **Fiche agent livrée comme lecteur d'état d'UN agent** : nouvelle `%AgentCard` (`CanvasLayer`, `scripts/ui/agent_card.gd`, sans `class_name`) instanciée dans `open_space.tscn` (`ext_resource id="10"`). Non-modale : elle ne gèle pas le temps et ne pose **pas** de catcher plein écran ; seul son `PanelContainer` (`mouse_filter = STOP`) capte les clics dans son rect.
- **AC1** : `%NameLabel` (« {archétype} #{id} », identité lue une fois à l'ouverture via `Agent.get_display_name()` + `agent_id`) ; `%MoraleLabel` (« Moral : NN », lu sur `Agent.get_morale()`) avec **signal de seuil couleur** réutilisant `HudMath.morale_severity` + les seuils HUD du `.tres` (`hud_morale_warn_below`/`hud_morale_critical_below`) — **zéro nouveau module pur, zéro nouveau champ `.tres`**. Mise à jour **live** du moral via `agent_morale_changed` filtré sur l'agent affiché.
- **AC2** : actions futures **réservées et désactivées** — `%LinkButton` (« Brancher l'IA — Épic 5 ») et `%DayOffButton` (« Jour off — Épic 2 »), `disabled = true`, **aucune** connexion/logique (patron Trésorerie 1.8). Seul `%CloseButton` est actif (→ `hide_card`).
- **AC3** : fermeture propre par (a) bouton Fermer, (b) clic dans le vide (`SelectionController.handle_empty_click` → `hide_card`), (c) bascule sur un autre agent sans sollicitation (`show_for` réécrit l'agent affiché), (d) **auto-fermeture** si l'agent affiché émet `agent_departed` (anti-fiche-fantôme — aucun déréférencement de nœud mort, on ne garde que `_agent_id`).
- **Routage du clic (décision n°1, sollicitation-prioritaire)** : `SelectionController` étendu avec deux **points d'entrée communs** testables — `handle_agent_click(agent)` (agent **avec** sollicitation active → `open_solicitation` **1.4 inchangé** ; sinon → `AgentCard.show_for`) et `handle_empty_click()` (→ `hide_card`). Le raycast (`_agent_under_mouse`/`_as_agent`) est **préservé** tel quel.
- **Anti-vol de clic (décision n°2)** : `mouse_filter = STOP` borné au `PanelContainer` → cliquer la fiche ne déclenche pas `_unhandled_input` (pas de désélection) ; hors du Panel, les clics atteignent le `SelectionController`. Inverse volontaire de la pop-up modale 1.5 (Blocker plein écran).
- **Seul changement de logique métier** : `Agent.get_display_name()` — getter **lecture seule purement additif** (modèle `get_morale()` de 1.7), aucun changement de comportement. Aucun nouveau signal `EventBus` (la fiche consomme `agent_morale_changed`/`agent_departed` existants).
- **Bornes respectées** : aucune action réelle (brancher/débrancher = Épic 5, jour off = Épic 2 → boutons grisés) ; aucune autre jauge que le Moral ; pas d'outline 3D / indicateur sur tête / juice (Épic 6) ; pas de persistance (Épic 7) ; pas de bilan modal (1.10). `solicitation_system.gd`/`desk_queue.gd`/`game_manager.gd`/`event_bus.gd`/`decision_popup.gd`/`hud.gd`/`sim_balance.gd`(`.tres`) **non modifiés**.
- **Système fonctionnel de bout en bout** : caméra (1.1), agents (1.2), temps (1.3), sollicitations (1.4), pop-up (1.5), résolution (1.6), file/moral (1.7) et HUD (1.8) restent opérationnels (8 suites + 9 smokes PASS, 145 FPS, import 0/0). La boucle clic→sollicitation 1.4 n'est **pas** interceptée par la fiche (priorité sollicitation, vérifiée par `--card-smoke`).

### File List

**Nouveaux fichiers (sous `open_space/`) :**
- `scripts/ui/agent_card.gd` (fiche agent : `show_for`/`hide_card`, live moral via EventBus filtré, auto-fermeture au départ, couleur de seuil réutilisant `HudMath` ; getters de test)
- `scripts/ui/agent_card.gd.uid`
- `scenes/ui/agent_card.tscn` (CanvasLayer + PanelContainer ancré bas-droite `mouse_filter = STOP` + labels `%` + boutons actions désactivés + bouton Fermer)

**Fichiers modifiés :**
- `scripts/agents/agent.gd` (getter additif `get_display_name()` ; reste inchangé)
- `scripts/world/selection_controller.gd` (routage du clic : `handle_agent_click`/`handle_empty_click` ; raycast préservé)
- `scenes/world/open_space.tscn` (instance `%AgentCard` ajoutée, `ext_resource id="10"` ; structure 1-9 préservée)
- `scripts/main/main.gd` (harnais `--card-smoke` + branche dans `_ready` ; 8 harnais + helpers existants préservés)

## Change Log

| Date | Version | Description |
|---|---|---|
| 2026-06-22 | 0.9.0 | Implémentation Story 1.9 : Fiche agent & sélection. Nouvelle UI `%AgentCard` (`CanvasLayer`, non-modale) instanciée dans `open_space.tscn`, ouverte au clic gauche via le `SelectionController` étendu (routage sollicitation-prioritaire : agent sollicité → `open_solicitation` **1.4 inchangé** ; sinon → fiche). Affiche identité (`Agent.get_display_name()` + `agent_id`) et Moral (`get_morale()`) avec signal de seuil couleur **réutilisant `HudMath.morale_severity` + les seuils HUD du `.tres`** (zéro nouveau module/seuil). Live du moral via `agent_morale_changed` filtré ; auto-fermeture sur `agent_departed` (anti-fiche-fantôme) ; fermeture au clic ailleurs / bouton Fermer ; bascule sur un autre agent. Actions futures (brancher/débrancher = Épic 5, jour off = Épic 2) = boutons réservés **désactivés**. `mouse_filter = STOP` borné au Panel → la sélection 3D n'est pas interceptée. Seul changement métier : getter additif `Agent.get_display_name()` ; aucun nouveau signal EventBus. Tests : `--card-smoke` PASS (ouverture/identité/moral=100, live −60→40, bascule, clic-ailleurs-ferme, priorité-sollicitation, auto-fermeture-départ) ; non-régression 8 suites unitaires + 9 smokes PASS ; 145 FPS (NFR1) ; import 0/0. `solicitation_system.gd`/`desk_queue.gd`/`game_manager.gd`/`event_bus.gd`/`hud.gd`/`sim_balance.gd` non modifiés. Statut → review. |
