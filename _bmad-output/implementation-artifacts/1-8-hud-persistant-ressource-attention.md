---
baseline_commit: 17a1bf743b7bbe370a86cc508b0222aa2bb0b047
---

# Story 1.8: HUD persistant & ressource Attention

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a joueur,
I want un HUD persistant qui me montre d'un coup d'œil l'état global de la boîte (jour, moral moyen) et ma charge d'attention (file au bureau + mails en attente),
so that je priorise sous pression sans avoir à fouiller chaque agent — l'attention reste ma ressource rare (pilier #1).

## Acceptance Criteria

1. **Given** une partie est en cours **When** je joue **Then** un **HUD persistant** (toujours affiché, ne masque pas l'open space) montre les **jauges globales** : **jour en cours** (lu sur `GameManager.day_count`, mis à jour sur `EventBus.day_started`), **moral moyen** des agents présents (moyenne entière des `Moral` 0-100, alimentée par `EventBus.agent_morale_changed` posé en 1.7), et un **emplacement Trésorerie réservé** (placeholder « € — », **données Épic 3**, cf. bornage). [Source: epics.md#Story-1.8 AC1 ; FR14 ; gdd.md §Boucle/Bilan (trésorerie, moral moyen, jour) ; game-architecture.md#Decision-Summary D9 (UI = Control + CanvasLayer)]
2. **Given** des sollicitations sont en attente (la 1.4 émet `solicitation_raised(agent_id, channel)` / `solicitation_opened(agent_id, channel)` ; canal `Solicitation.Channel` 0=DESK, 1=MAIL) **When** la **file au bureau** et/ou des **mails** s'accumulent **Then** la **pression d'attention est matérialisée** par deux compteurs lisibles : **compteur de file** (nombre de sollicitations DESK en attente) et **compteur de mails** (nombre de sollicitations MAIL en attente), tous deux mis à jour en temps réel (montée à `raised`, baisse à `opened` **et** au départ d'un agent `agent_departed` — anti-fantôme). [Source: epics.md#Story-1.8 AC2 ; FR9 (l'Attention = file + mails) ; 1-4…md ; 1-7…md#DeskQueue]
3. **Given** une jauge globale **live** franchit un **seuil notable** (moral moyen sous un seuil d'alerte/critique, ou charge d'attention file+mails au-delà d'un seuil) **When** ça se produit **Then** le HUD le **signale visuellement** (changement de couleur/emphase du compteur concerné — lisibilité NFR7), seuils **data-driven** en `.tres` (zéro magic number). [Source: epics.md#Story-1.8 AC3 ; NFR7 (lisibilité) ; game-architecture.md#Configuration (.tres) ; gdd.md §DA (signaux forts lisibles d'un coup d'œil)]

> **Frontière de cette story (lire absolument — périmètre volontairement borné) :**
> - **1.8 FAIT** : (a) la **première UI HUD persistante** du projet — un `CanvasLayer` (`%Hud`) en surcouche, **Control + Label** natifs (D9), instancié dans `open_space.tscn`, qui **n'interagit pas** avec la souris (laisse passer clics caméra/sélection → `mouse_filter = IGNORE` sur les conteneurs) ; (b) **branche le HUD sur l'`EventBus`** (consommateur **pur** : il **lit**/agrège l'état déjà émis, il n'**émet rien**, ne **modifie aucun système**) : jour (`day_started`), moral moyen (`agent_spawned`/`agent_morale_changed`/`agent_departed`), file/mails (`solicitation_raised`/`solicitation_opened`/`agent_departed`) ; (c) la **logique pure** d'agrégation/seuils dans `HudMath` (`class_name`, testable `--script`) ; (d) le **signal visuel de seuil** (couleur) sur moral moyen et charge d'attention, seuils en `.tres` (`sim_balance.gd`). État temporel **pause/vitesse** (`game_paused`/`speed_changed`) : indicateur facultatif (cf. Task 2, marqué optionnel) — la barre de temps complète relève d'Épic 6 (polish) / déjà piloté clavier en 1.3.
> - **1.8 NE FAIT PAS** (ne pas déborder) :
>   - **La vraie Trésorerie / le Budget IA / la Deadline de mission.** FR14 les liste au HUD, mais **aucun de ces systèmes n'existe** : Trésorerie = **Épic 3** (FR21), Budget IA = **Épic 5** (FR33), Deadline = **Épic 4** (contrats). Ici : **emplacement(s) réservé(s)** avec placeholder figé (« € — »), **exactement** comme la fiche 1.9 réserve les actions futures et le bilan 1.10 met un « placeholder mission ». **NE PAS** inventer de valeur/économie. La SEULE Trésorerie affichée est un placeholder statique. [Source: epics.md#Épic-3/#Épic-4/#Épic-5 ; 1-7…md (même esprit de bornage)]
>   - **La fiche agent au clic** (état individuel détaillé) → **Story 1.9**. Le HUD n'affiche que des **agrégats globaux** ; il ne réagit pas au clic, n'ouvre rien.
>   - **Le bilan de fin de journée** (écran récap modal) → **Story 1.10**. Le HUD est **permanent**, pas un écran de fin.
>   - **La barre de temps cliquable (boutons pause/x1/x2/x3 à la souris)** et tout **juice/animation** (clignotements, tweens, icônes) → **Épic 6** (polish/lisibilité). Ici : Labels statiques + couleur de seuil suffisent ; l'input temps reste **clavier** (1.3).
>   - **Fatigue / burnout / contagion** (autres jauges par agent) → **Épic 2**. Le seul agrégat « bien-être » ici est le **moral moyen** (le Moral est la seule jauge par-agent existante, posée en 1.7).
>   - **La persistance du HUD / des compteurs** (sauvegarde) → **Épic 7**. Les agents sont recréés chaque matin (moral repart à 100) ; le HUD **reflète l'état courant**, il ne sauvegarde rien.
>   - **Toute modification d'un système existant** (`SolicitationSystem`, `DeskQueue`, `Agent`, `GameManager`, etc.). Le HUD est un **abonné en lecture seule** : il ne touche **à aucun** producteur. La seule UPDATE de logique métier autorisée est l'ajout de **scalaires de seuil `@export`** dans `sim_balance.gd` (cohérent 1.7).

## Tasks / Subtasks

- [x] **Task 1 — Logique PURE d'agrégation & de seuils : `HudMath` (testable `--script`)** (AC: #1, #2, #3)
  - [x] Créer `scripts/ui/hud_math.gd` (`class_name HudMath extends RefCounted`) — transformations **pures**, **zéro** dépendance scène/autoload (modèle `morale_math.gd` / `decision_resolution_math.gd` / `solicitation_math.gd`, testés en `--script`).
  - [x] `static func average_morale(values: Array) -> int` : moyenne **entière arrondie** des moraux fournis ; **défensif** : si `values` est vide → renvoyer `-1` (sentinelle « aucun agent » → le HUD affichera « — »). Itérer en sommant des `float`/`int`, `roundi(sum / count)`.
  - [x] `enum Severity { NORMAL = 0, WARNING = 1, CRITICAL = 2 }`.
  - [x] `static func morale_severity(average: int, warn_below: int, critical_below: int) -> int` : `CRITICAL` si `0 <= average < critical_below` ; sinon `WARNING` si `average < warn_below` ; sinon `NORMAL`. **Défensif** : si `average < 0` (sentinelle vide) → `NORMAL` (pas d'alerte sans agent).
  - [x] `static func attention_severity(pending_count: int, warn_at: int) -> int` : `WARNING` si `pending_count >= warn_at` (et `warn_at > 0`), sinon `NORMAL`. (Charge d'attention = file + mails ; pas de niveau CRITICAL imposé par l'AC → on reste à 2 niveaux ici.)
  - [x] **Ne PAS** mettre de `Time`, `EventBus`, RNG, ni état mutable ici. L'accumulation concrète (dictionnaires d'agents/sollicitations) et l'affichage vivent dans `Hud` (Task 3). **→ 18/18 PASS (`test_hud`).** [Source: 1-7…md (séparation math pure ↔ système) ; game-architecture.md#System-Location-Mapping]

- [x] **Task 2 — Scène HUD : `scenes/ui/hud.tscn` (CanvasLayer + Control/Label)** (AC: #1, #2, #3)
  - [x] Créer `scenes/ui/hud.tscn` : racine **`Hud` (CanvasLayer)** + script `hud.gd` (Task 3). Modèle d'organisation = `scenes/ui/decision_popup.tscn` (CanvasLayer racine + sous-arbre Control), mais **sans Blocker plein écran** (le HUD ne capte pas la souris).
  - [x] Conteneur d'ancrage en **coin haut** : `TopBar` (`PanelContainer`, ancré haut pleine largeur, `self_modulate` α=0.55 pour un fond léger lisible) → `Margin` (`MarginContainer`) → `HBox` (`HBoxContainer`, séparation 28). **`mouse_filter = 2` (IGNORE)** sur **tous** les Control (TopBar/Margin/HBox/labels/Spacer) → les clics traversent vers la caméra/`SelectionController` (1.1/1.4) : le HUD **ne vole jamais un clic de sélection**.
  - [x] **Labels nommés `unique_name_in_owner = true`** (lecture par `%`) :
    - `%DayLabel` (« Jour N »),
    - `%MoraleLabel` (« Moral moyen : NN » ou « — »),
    - `%FileLabel` (« File bureau : N »),
    - `%MailLabel` (« Mails : N »),
    - `%TreasuryLabel` (placeholder figé « € — » ; **Épic 3**),
    - `%TimeLabel` (« x1 » / « PAUSE ») — indicateur temps **inclus** (poussé à droite par un `Spacer` expansé).
  - [x] Texte **lisible** (contraste sur la DA claire « Severance » : texte foncé `_COLOR_NORMAL` ; fond `PanelContainer` semi-opaque léger pour la lisibilité NFR7). **Aucune** chaîne de gameplay en dur hors libellés d'UI (les valeurs viennent du runtime ; les seuils du `.tres`).
  - [x] **Aucune** autre UI (pas de boutons, pas de barre de temps cliquable, pas d'icône) — bornage.

- [x] **Task 3 — `Hud` : abonnement EventBus, agrégation, rendu** (AC: #1, #2, #3)
  - [x] Créer `scripts/ui/hud.gd` (`extends CanvasLayer`, **sans `class_name`** — cohérent `decision_popup.gd`/`SolicitationSystem`/`DeskQueue` : un nœud de scène n'a pas de `class_name`). Doc d'en-tête + sources + rappel « première brique du HUD persistant, consommateur EventBus pur ».
  - [x] `const _BALANCE: SimBalance = preload("res://data/balance/sim_balance.tres")` (lecture des seuils + moral initial).
  - [x] `@onready var` sur chaque label via `%` (cf. Task 2). **Pas** de chemin de nœud absolu.
  - [x] État (dictionnaires utilisés comme ensembles/maps — **EventBus-only**, aucun ref de nœud agent) :
    - `var _morale_by_agent: Dictionary = {}` (agent_id → int moral courant) ;
    - `var _desk_agents: Dictionary = {}` (agent_id → true : sollicitations DESK en attente) ;
    - `var _mail_agents: Dictionary = {}` (agent_id → true : sollicitations MAIL en attente).
  - [x] `_ready()` :
    - `process_mode = Node.PROCESS_MODE_ALWAYS` (le HUD doit refléter l'état même en **pause** ; les callbacks de signal arrivent de toute façon en pause, mais on garde le nœud actif par cohérence avec `DecisionPopup`/`GameManager`).
    - Abonnements : `EventBus.day_started` ; `EventBus.agent_spawned` ; `EventBus.agent_morale_changed` ; `EventBus.agent_departed` ; `EventBus.solicitation_raised` ; `EventBus.solicitation_opened` ; `EventBus.game_paused` / `EventBus.speed_changed` (indicateur temps inclus).
    - Initialiser l'affichage depuis l'état courant : `_render_all()` (lit `GameManager.day_count`, dictionnaires vides → moral « — », compteurs 0 ; `GameManager.is_paused`/`speed_level`).
  - [x] **Pas de `_process`** (NFR1) : le HUD est **100 % événementiel**, il ne se redessine qu'à la réception d'un signal.
  - [x] Handlers (chacun met à jour l'état puis appelle le `_render_*` concerné) :
    - `_on_day_started(day)` : `_render_day(day)` (ou lire `GameManager.day_count`).
    - `_on_agent_spawned(agent_id)` : `_morale_by_agent[agent_id] = roundi(_BALANCE.agent_initial_morale)` (le spawner seed exactement cette valeur → cohérent ; le 1er `agent_morale_changed` n'arrive qu'**au changement**) ; `_render_morale()`.
    - `_on_agent_morale_changed(agent_id, morale)` : `_morale_by_agent[agent_id] = morale` ; `_render_morale()`.
    - `_on_agent_departed(agent_id)` : `_morale_by_agent.erase(agent_id)` ; `_desk_agents.erase(agent_id)` ; `_mail_agents.erase(agent_id)` ; `_render_morale()` + `_render_attention()` (anti-fantôme : un départ purge les compteurs **et** le moral).
    - `_on_solicitation_raised(agent_id, channel)` : si `channel == Solicitation.Channel.DESK` → `_desk_agents[agent_id] = true` sinon `_mail_agents[agent_id] = true` ; `_render_attention()`.
    - `_on_solicitation_opened(agent_id, channel)` : retirer l'agent du set correspondant (par sécurité, `erase` des **deux** sets) ; `_render_attention()`.
    - `_on_game_paused(is_paused)` / `_on_speed_changed(level)` : `_render_time()`.
  - [x] Rendu :
    - `_render_day(day)` : `%DayLabel.text = "Jour %d" % day`.
    - `_render_morale()` : `var avg := HudMath.average_morale(_morale_by_agent.values())` ; texte « Moral moyen : NN » ou « — » si `avg < 0` ; **couleur de seuil** via `HudMath.morale_severity(avg, _BALANCE.hud_morale_warn_below, _BALANCE.hud_morale_critical_below)` → `_apply_severity(%MoraleLabel, severity)`.
    - `_render_attention()` : `%FileLabel.text = "File bureau : %d" % _desk_agents.size()` ; `%MailLabel.text = "Mails : %d" % _mail_agents.size()` ; **couleur de seuil** sur la charge totale via `HudMath.attention_severity(_desk_agents.size() + _mail_agents.size(), _BALANCE.hud_attention_warn_at)` appliquée au(x) compteur(s).
    - `_render_all()` : appelle `_render_day(GameManager.day_count)` + `_render_morale()` + `_render_attention()` (+ `_render_time()` optionnel) + fixe `%TreasuryLabel.text = "€ —"` (placeholder Épic 3).
    - `_apply_severity(label, severity)` : `NORMAL` → couleur normale ; `WARNING` → ambre ; `CRITICAL` → rouge, via `label.add_theme_color_override("font_color", ...)` (couleurs constantes du script — c'est de la présentation, pas de l'équilibrage ; **les seuils** restent en `.tres`).
  - [x] **Garde-fous NFR11** : un signal pour un `agent_id` inconnu ne doit jamais crasher (`erase` sur clé absente est sans effet ; `average_morale([])` renvoie -1). Le HUD n'appelle **aucune** méthode d'un autre système (lecture seule de `GameManager`/`_BALANCE`).
  - [x] **Getters pour le test d'intégration** (modèle `DecisionPopup.is_showing()`/`option_button_count()`) : `func displayed_day() -> int` ; `func displayed_file_count() -> int` (= `_desk_agents.size()`) ; `func displayed_mail_count() -> int` ; `func displayed_average_morale() -> int` (= `HudMath.average_morale(...)`) ; `func displayed_morale_severity() -> int`.

- [x] **Task 4 — Seuils data-driven (`SimBalance`)** (AC: #3)
  - [x] **UPDATE** `scripts/systems/sim_balance.gd` : ajouter, **tous typés** (sinon warning `untyped_declaration` à l'import — cf. 1.7) et commentés :
    - `@export var hud_morale_warn_below: int = 50` (moral moyen sous 50 → alerte ambre) ;
    - `@export var hud_morale_critical_below: int = 25` (sous 25 → critique rouge) ;
    - `@export var hud_attention_warn_at: int = 3` (file+mails ≥ 3 → la charge d'attention passe en alerte).
  - [x] **Préserver intégralement** tous les champs existants (1.2 → 1.7). `data/balance/sim_balance.tres` reste **vide** (prend les défauts du script) — **ne PAS** réécrire le `.tres` à la main (cohérent 1.7 ; aucun `Array[ExtResource]` ici). [Source: 1-7…md (prudence `.tres`, typage `@export`)]

- [x] **Task 5 — Instancier `%Hud` dans l'open space** (AC: #1, #2, #3)
  - [x] **UPDATE** `scenes/world/open_space.tscn` : ajouter une instance de `scenes/ui/hud.tscn` (nœud `Hud`) **enfant de `OpenSpace`**, avec `unique_name_in_owner = true` (`%Hud`), modèle = l'instance `DecisionPopup` (`[node name="DecisionPopup" parent="." instance=ExtResource("6")]`).
  - [x] Déclarer la `PackedScene` du HUD via un **nouvel `id` `ext_resource` distinct** (`id="9"`, ids 1-8 déjà pris). **Préserver toute la structure existante** (`GridMap`/`NavigationRegion3D`/`%Agents`/`AgentSpawner`/`%SolicitationSystem`/`SelectionController`/`%DecisionPopup`/`%DecisionResolver`/`%DeskQueue`/`WorldEnvironment`/`DirectionalLight3D`/`CameraRig (process_mode=3)/Camera3D`).
  - [x] Import **0 erreur / 0 warning** confirmé ; `%Hud` présent, abonné (log `_ready` « HUD prêt »), et **`mouse_filter = IGNORE`** garantit que les clics de sélection (1.4) traversent (aucun élément cliquable dans le HUD).

- [x] **Task 6 — Tests (unitaires purs + intégration `--hud-smoke` + non-régression)** (AC: #1, #2, #3)
  - [x] Créer `tests/unit/test_hud.gd` (runner headless autonome `extends SceneTree`, `quit(0/1)`, **pas de GUT** — cf. 1.1→1.7) testant **uniquement** `HudMath` (pur) :
    - `average_morale` : `[]`→-1 ; `[100]`→100 ; `[100, 50]`→75 ; `[100, 99, 98]`→99 (arrondi) ; `[100, 99]`→100 (arrondi 99.5) ; `[0, 0]`→0.
    - `morale_severity` (warn 50, crit 25) : 80→NORMAL ; 50→NORMAL (borne exclusive) ; 49→WARNING ; 25→WARNING ; 24→CRITICAL ; 0→CRITICAL ; -1 (vide)→NORMAL.
    - `attention_severity` (warn 3) : 0→NORMAL ; 2→NORMAL ; 3→WARNING ; 5→WARNING ; (warn_at 0 → NORMAL défensif). **→ 18/18 PASS.**
  - [x] **Intégration** `--hud-smoke` dans `scripts/main/main.gd` (lecture directe des getters du HUD → pas de compteur lambda nécessaire) :
    - Récupérer `var hud: CanvasLayer = open_space.get_node("Hud")`.
    - **AC1 (jour + moral)** : après l'amorçage d'une journée, `hud.displayed_day() == GameManager.day_count` (≥ 1) ; tous agents au moral initial → `hud.displayed_average_morale() == 100`.
    - **AC2 (mails puis file)** : forcer MAIL (`desk_prob_override = 0.0 ; rate_override = 1.0` brève fenêtre puis `0.0`) **d'abord** (agents encore tous éligibles) → `hud.displayed_mail_count() >= 1` ; purger (ouvrir toutes les sollicitations actives) → `displayed_mail_count() == 0` ; puis forcer DESK (`_force_desk_solicitation`) → `hud.displayed_file_count() >= 1` ; ouvrir le front (`_open_first_active`) → `displayed_file_count()` **décrémente d'exactement 1**.
    - **AC3 (seuil moral)** : franchissement via le **VRAI signal `agent_morale_changed`** émis par `Agent.adjust_morale` (chemin réel partagé avec `DeskQueue`), **injecté de façon déterministe** plutôt que via la décroissance lente de patience (qui demanderait ~80 s réelles à x3 pour atteindre le seuil critique). Sévérité initiale `NORMAL` (avg 100) ; après `adjust_morale(-55)` sur chaque agent (avg ~45) → `WARNING` ; après `adjust_morale(-25)` de plus (avg ~20) → `CRITICAL`. Couvre exactement le contrat de l'AC3 : *signal réel → agrégation HUD → re-classification de sévérité*. *(Le chemin patience→moral en file est déjà couvert de bout en bout par `--queue-smoke`, Story 1.7.)*
    - Restaurer les overrides (`rate_override = -1.0`, `desk_prob_override = -1.0`) + état temporel neutre (`set_speed(1)`, `Engine.time_scale = 1.0`). `print("HUD_SMOKE ...")` + `HUD_SMOKE_RESULT=PASS/FAIL` + `get_tree().quit(0/1)`. **Réutilise** `_force_desk_solicitation`/`_open_first_active`/`_real_wait`.
  - [x] Brancher `--hud-smoke` dans `_ready()` (chaîne `elif args.has(...)`) **sans toucher aux 7 branches existantes** (`--measure-fps`/`--sim-smoke`/`--time-smoke`/`--solicitation-smoke`/`--decision-smoke`/`--resolution-smoke`/`--queue-smoke`).
  - [x] **Non-régression** : suites unitaires (`test_camera_math`, `test_agent_sim`, `test_time_control`, `test_solicitation_math`, `test_decision`, `test_decision_resolution`, `test_morale`, **+ `test_hud`**) → **8/8 PASS** ; et `--sim-smoke`/`--time-smoke`/`--solicitation-smoke`/`--decision-smoke`/`--resolution-smoke`/`--queue-smoke`/`--hud-smoke` → **7/7 PASS** (système fonctionnel de bout en bout) ; `--measure-fps` → **145** (≥ 60, NFR1). Sélection non interceptée : garantie déclarative par `mouse_filter = IGNORE` (aucun élément cliquable dans le HUD).

## Dev Notes

### Contexte & objectif

Les Stories 1.1→1.7 ont posé tout le **modèle** (caméra, agents, temps, sollicitations DESK/MAIL, pop-up, résolution, file/patience/**Moral 0-100**) **mais quasi aucune UI 2D persistante** : aujourd'hui la seule UI est la pop-up de décision (1.5). Le joueur ne voit **aucun agrégat global**. La 1.8 ajoute la **première brique du HUD persistant** : un `CanvasLayer` en surcouche qui **agrège et affiche** l'état déjà émis sur l'`EventBus` — **jour**, **moral moyen**, et surtout les **deux compteurs d'attention** (file bureau + mails) qui **matérialisent la ressource rare** du pilier #1 (« l'attention du patron est LA ressource rare », FR9). C'est un **consommateur pur** : aucun nouveau système métier, aucune modification d'un producteur existant.
[Source: epics.md#Story-1.8 ; FR9/FR14 ; gdd.md §Piliers (#1) ; game-architecture.md#Decision-Summary D9]

### ⚠️ Décision de conception clé : un HUD **lecteur d'EventBus**, qui ne couple rien

Le HUD **n'invente pas** d'état : il **reconstruit des agrégats** à partir des signaux que les stories précédentes émettent **déjà** (et qui annoncent explicitement « le HUD Story 1.8 s'y abonnera » dans `event_bus.gd`). Il ne tient **aucune** référence vers les nœuds agents / systèmes : il maintient trois petits dictionnaires (moral par agent, sets DESK/MAIL) alimentés **uniquement** par signaux. Conséquences :

- **Zéro régression** : on ne touche ni à `SolicitationSystem`, ni à `DeskQueue`, ni à `Agent`, ni à `GameManager`. Les 7 harnais de fumée existants restent verts. La seule UPDATE de logique est l'ajout de **3 scalaires de seuil `@export`** dans `sim_balance.gd` (même nature d'ajout qu'en 1.7).
- **Découplage maison respecté** : `CanvasLayer` + Control/Label (D9), `EventBus`-only (snake_case au passé), pas de chemin de nœud absolu (`%UniqueName`/signals), seuils en `.tres`. [Source: game-architecture.md#Event-System ; #Architectural-Boundaries ; #Configuration]
- **Math pur isolé** : l'agrégation (moyenne) et la classification de seuils vivent dans `HudMath` (`class_name`, pur, testé `--script`), comme `MoraleMath`/`SolicitationMath` ; le `Hud` (nœud de scène) ne fait que **collecter + afficher**. [Source: 1-7…md ; game-architecture.md#System-Location-Mapping]

> **Pourquoi reconstruire les compteurs par signaux plutôt que lire `DeskQueue.queue_size()` / `SolicitationSystem`** : (1) garder le HUD **strictement EventBus** (aucune dépendance de nœud, donc robuste si l'ordre d'instanciation change) ; (2) **symétrie** file ↔ mails (rien ne « compte » les mails côté systèmes) ; (3) **anti-fantôme** : un agent qui **part le soir** (`agent_departed`) voit sa sollicitation effacée côté `SolicitationSystem` **sans** émettre `solicitation_opened` — un compteur purement `raised`/`opened` **fuirait**. D'où l'abonnement **obligatoire** à `agent_departed` qui purge les deux sets (et le moral). [Source: lecture directe solicitation_system.gd L84-85 ; 1-7…md#DeskQueue (même raison) ]

### Le moral moyen : d'où viennent les valeurs, et le piège du seed initial

Le **Moral (0-100)** vit **sur l'`Agent`** (posé en 1.7) et n'émet `agent_morale_changed` **que sur variation réelle** (jamais à la valeur initiale). Donc un HUD qui n'écouterait **que** `agent_morale_changed` **ignorerait** les agents fraîchement spawnés (encore à 100) → moyenne fausse. Solution **data-driven et cohérente** : sur `agent_spawned`, **seeder** `_morale_by_agent[agent_id] = roundi(SimBalance.agent_initial_morale)` — c'est **exactement** la valeur que le spawner passe à `setup()` (cf. `agent_spawner.gd` → `_BALANCE.agent_initial_morale` → `Agent.setup(..., initial_morale)`), donc **pas** de double source de vérité divergente. Les variations ultérieures sont reçues par `agent_morale_changed`, les départs purgés par `agent_departed`. La moyenne (`HudMath.average_morale`) renvoie **-1** quand aucun agent n'est présent (avant le 1er matin / la nuit) → le HUD affiche « — » sans alerte.
[Source: 1-7…md (signal sur variation only ; moral repart à 100 chaque matin) ; lecture directe agent.gd L61-81 ; agent_spawner.gd]

### La Trésorerie : placeholder assumé (Épic 3), pas une invention

L'AC1 (et FR14) listent la **Trésorerie** au HUD, mais **aucun système financier n'existe** (Trésorerie = **Épic 3 / FR21** ; Budget IA = **Épic 5** ; Deadline = **Épic 4**). Inventer une économie ici = exactement le **hors-périmètre** que les stories 1.6/1.7 ont refusé. On applique le **même patron** que la fiche 1.9 (« réserve l'emplacement des actions futures — désactivées à ce stade ») et le bilan 1.10 (« placeholder mission ») : un **emplacement `%TreasuryLabel` figé** (« € — »), prêt à être branché en Épic 3, **sans** logique. **La seule valeur Trésorerie de cette story est ce placeholder statique.**
[Source: epics.md#Épic-3/#Story-1.9/#Story-1.10 ; gdd.md §Économie (Trésorerie €) ]

### Pause / vitesse au HUD : optionnel et borné

`GameManager` émet déjà `game_paused(is_paused)` et `speed_changed(level)` (et `event_bus.gd` annonce « le HUD s'y abonnera »). Un petit indicateur texte (« PAUSE » / « x2 ») est un **bonus de lisibilité** peu coûteux ; il est **marqué optionnel** dans les tasks. La **barre de temps cliquable** (boutons souris) et tout juice relèvent d'**Épic 6** : ne PAS les faire ici. L'input temps reste **clavier** (Espace/1/2/3, posé en 1.3). [Source: event_bus.gd L21-25 ; epics.md#Épic-6 ; 1-3…]

### Le HUD ne doit JAMAIS voler un clic (anti-régression sélection)

La sélection d'agent (clic gauche, `SelectionController` 1.4, étendue en fiche 1.9) et la caméra utilisent la souris sur le viewport 3D. Un `CanvasLayer` avec des `Control` **capte par défaut** la souris sur sa surface (`mouse_filter = STOP`). Il faut donc mettre **`mouse_filter = MOUSE_FILTER_IGNORE`** sur les conteneurs et labels du HUD pour que les clics **traversent** vers le 3D. (Le HUD est purement informatif en 1.8 : il n'a **aucun** élément cliquable.) C'est l'inverse de la pop-up 1.5 qui, elle, **bloque** volontairement (Blocker plein écran) parce qu'elle est modale. [Source: lecture directe decision_popup.tscn (Blocker modal) ; selection_controller.gd ; game-architecture.md#Decision-Summary D9]

### Le flux exact : du signal au label (qui fait quoi)

```
[1.2] Agent._ready → EventBus.agent_spawned(agent_id)
[1.8] Hud._on_agent_spawned → _morale_by_agent[id] = agent_initial_morale ; _render_morale()
[1.7] Agent.adjust_morale → (si change) EventBus.agent_morale_changed(id, morale)
[1.8] Hud._on_agent_morale_changed → _morale_by_agent[id] = morale ; _render_morale()
                                   → avg = HudMath.average_morale(...) ; severity = HudMath.morale_severity(...) ; couleur
[1.4] SolicitationSystem._raise → EventBus.solicitation_raised(id, channel)
[1.8] Hud._on_solicitation_raised → _desk_agents/_mail_agents[id]=true ; _render_attention()
[1.4] open_solicitation(id) → EventBus.solicitation_opened(id, channel)
[1.8] Hud._on_solicitation_opened → erase id des sets ; _render_attention()
[1.2] Agent._depart → EventBus.agent_departed(id)
[1.8] Hud._on_agent_departed → erase id (moral + sets) ; _render_morale() + _render_attention()  (anti-fantôme)
[1.3] GameManager._on_simulation_tick → EventBus.day_started(day)
[1.8] Hud._on_day_started → %DayLabel = "Jour N"
```

### Anti-pièges (apprentissages 1.1 → 1.7 — à respecter absolument)

- **L'autoload logger s'appelle `Log`, PAS `Logger`** (`Logger` = classe native Godot 4.6 → collision). `Log.info/warn/error`. [Source: 1-1…/1-7…md]
- **Pas de `class_name` sur un nœud de scène** (`Hud` comme `DecisionPopup`/`SolicitationSystem`/`DeskQueue`) ; **`class_name` pour le module math pur** (`HudMath` comme `MoraleMath`/`SolicitationMath`). [Source: 1-2…/1-7…md]
- **En mode `--script`, les autoloads ne sont PAS chargés** → la logique testée unitairement doit être **pure** (sans `Log`/`EventBus`/`GameManager`/`SimBalance`). D'où `HudMath` (pur, `--script`) vs `Hud` (autoloads/scène, testé via `--hud-smoke`). [Source: 1-5…/1-6…/1-7…md#Tests]
- **GUT non installé** → runner headless autonome (`tests/unit/*.gd extends SceneTree`, `quit(0/1)`). [Source: 1-1…1-7…md]
- **VCS désormais présent** (`baseline_commit` renseigné, cf. frontmatter) mais **toujours valider par import + exécution headless réels** (jamais « au jugé ») : `godot --headless --path open_space --import` doit rester **0 erreur / 0 warning**. [Source: 1-7…md#Debug-Log-References]
- **Piège des lambdas GDScript (capture par valeur)** : dans `--hud-smoke`, tout compteur/mémo via **variables membres** de `main.gd`, **jamais** un local capturé dans un signal. (Ici, on lit surtout les getters du `Hud`, donc peu de captures — mais respecter la règle si besoin.) [Source: 1-4…/1-6…/1-7…md]
- **Pattern override de test** : on **réutilise** ceux des stories amont (`SolicitationSystem.rate_override`/`desk_prob_override`, `DeskQueue.patience_override`) ; **aucun nouvel override** n'est requis pour le HUD (il observe). [Source: solicitation_system.gd L27-39 ; 1-7…md]
- **Callbacks de signal vs pause** : `process_mode` gèle `_process`, **pas** les callbacks de signal. Le `Hud` n'a pas de `_process` ; on le met quand même `PROCESS_MODE_ALWAYS` (cohérence `DecisionPopup`/`GameManager`, et il reflète l'état en pause). [Source: 1-6…/1-7…md#Callbacks]
- **`.tres` — éditer prudemment** : on n'**ajoute que des scalaires `@export` typés** au **script** `sim_balance.gd` ; `sim_balance.tres` reste **vide** (prend les défauts). **Aucun** `Array[ExtResource]` à réécrire. [Source: 1-7…md ; lecture directe sim_balance.tres (vide)]
- **`mouse_filter = IGNORE`** sur les Control du HUD (anti-vol de clic) — point déjà détaillé ci-dessus.

### Lecture des fichiers UPDATE (état actuel à préserver)

- **`scripts/systems/sim_balance.gd`** — `SimBalance extends Resource` (`class_name`). Champs existants : `day_duration_seconds`/`evening_phase`/`agent_count` + `solicitation_rate_per_tick`/`desk_channel_probability` + `decision_immediate_probability`/`decision_deferred_min_days`/`decision_deferred_max_days` + (1.7) `agent_initial_morale`/`queue_patience_seconds`/`morale_decay_per_interval`/`morale_decay_interval_seconds`. **Ajouter** `hud_morale_warn_below`/`hud_morale_critical_below`/`hud_attention_warn_at` (typés). **Préserver** tout l'existant. [Source: lecture directe sim_balance.gd]
- **`scenes/world/open_space.tscn`** — `OpenSpace`(open_space.gd) avec enfants `GridMap`/`NavigationRegion3D`/`%Agents`/`AgentSpawner`/`%SolicitationSystem`/`SelectionController`/`%DecisionPopup`(instance)/`%DecisionResolver`/`%DeskQueue`/`WorldEnvironment`/`DirectionalLight3D`/`CameraRig(process_mode=3)/Camera3D`. **Ajouter** une instance `%Hud` (enfant d'`OpenSpace`, nouvel `ext_resource` id). **Préserver** tout. [Source: lecture directe open_space.tscn]
- **`scripts/main/main.gd`** — 7 harnais (`--measure-fps`/`--sim-smoke`/`--time-smoke`/`--solicitation-smoke`/`--decision-smoke`/`--resolution-smoke`/`--queue-smoke`) + helpers `_force_desk_solicitation`/`_open_first_active`/`_find_agent_by_id`/`_min_agent_distance_to`/`_real_wait` + compteurs membres. **Ajouter** `--hud-smoke` (+ branche dans `_ready`) en **réutilisant** les helpers. **Préserver les 7 harnais** et helpers. [Source: lecture directe main.gd]
- **`scripts/autoloads/event_bus.gd`** — **14 signaux** ; le HUD **consomme** `day_started`/`agent_spawned`/`agent_morale_changed`/`agent_departed`/`solicitation_raised`/`solicitation_opened` (+ optionnel `game_paused`/`speed_changed`). **NE PAS MODIFIER** (aucun nouveau signal requis : le HUD lit). [Source: lecture directe event_bus.gd]
- **`scripts/autoloads/game_manager.gd`** — expose `day_count`/`day_phase`/`is_paused`/`speed_level` (lecture seule par le HUD) ; émet `day_started`/`day_ended`/`game_paused`/`speed_changed`. **NE PAS MODIFIER**. [Source: lecture directe game_manager.gd]
- **`scripts/decisions/solicitation.gd`** — enum `Channel { DESK = 0, MAIL = 1 }` = **source unique** du canal ; le `Hud` la réutilise (`Solicitation.Channel.DESK`). **NE PAS MODIFIER**. [Source: lecture directe solicitation.gd ; 1-7…md]
- **`scripts/world/agent_spawner.gd`** / **`scripts/agents/agent.gd`** — seed du moral = `_BALANCE.agent_initial_morale` ; `agent_spawned` émis dans `Agent._ready()` après `setup()` (donc moral déjà fixé). **NE PAS MODIFIER** (le HUD seed côté lui à la même valeur). [Source: lecture directe agent_spawner.gd / agent.gd L61-81]
- **`scripts/world/selection_controller.gd`** / **`scenes/ui/decision_popup.tscn`** — modèles : la pop-up **bloque** la souris (modal) ; le HUD doit **la laisser passer** (`mouse_filter = IGNORE`). **NE PAS MODIFIER** `selection_controller.gd`. [Source: lecture directe]
- **NE PAS MODIFIER** : `solicitation_system.gd`, `desk_queue.gd`, `decision_popup.gd`, `decision_resolver.gd`, `sim_clock.gd`, `native_brain.gd`, `agent_context.gd`, `action_registry.gd`, `morale_math.gd`. Le HUD n'ajoute **aucune** action et ne pilote **aucun** agent. [Source: game-architecture.md#Architectural-Boundaries]

> **Important** : une story doit laisser le système **fonctionnel de bout en bout**. Au-delà des AC, caméra (1.1), agents (1.2), temps (1.3), sollicitations (1.4), pop-up (1.5), résolution (1.6) et file/moral (1.7) doivent rester pleinement opérationnels — **et la sélection au clic ne doit pas être interceptée par le HUD**.

### Performance (NFR1)

`Hud` est **100 % événementiel** (aucun `_process`), ne se redessine qu'à la réception d'un signal, et n'itère que sur des dictionnaires ≤ `agent_count` (5). Coût par frame **nul**. 60 FPS open space inchangés (1.7 mesurait 144 FPS). [Source: NFR1 ; 1-7…md (144 FPS) ]

### Direction artistique / UI

UI **fonctionnelle et lisible**, pas finalisée : Labels natifs sur la DA claire « Severance » (texte foncé/contrasté, fond léger optionnel pour la lisibilité NFR7), signal de seuil par **couleur** (ambre/rouge). Le **juice** (clignotements, icônes, tweens, barre de temps cliquable) et l'esthétique finale relèvent d'**Épic 6**. [Source: gdd.md §DA (signaux forts lisibles) ; epics.md#Épic-6 ; NFR7]

### Project Structure Notes

- Nouveaux fichiers conformes à la structure hybride (UI = `scripts/ui/` + `scenes/ui/`, cf. game-architecture.md#Project-Structure « ui/ : hud, pop-ups décision, fiche agent ») : `scripts/ui/hud_math.gd`, `scripts/ui/hud.gd`, `scenes/ui/hud.tscn`, `tests/unit/test_hud.gd`.
- Fichiers modifiés : `scripts/systems/sim_balance.gd` (3 seuils `@export`), `scenes/world/open_space.tscn` (instance `%Hud`), `scripts/main/main.gd` (harnais `--hud-smoke`).
- Aucune nouvelle dépendance, aucun addon. `HudMath` = `class_name` + pur (`--script`) ; `Hud` = nœud de scène (`CanvasLayer`) **sans** `class_name` (cohérent `DecisionPopup`/`SolicitationSystem`/`DeskQueue`).
- **Note d'emplacement** : la pop-up 1.5 a son script dans `scripts/decisions/` (groupé par domaine) mais sa scène dans `scenes/ui/`. Le HUD étant de l'UI pure (pas de domaine métier), son script va dans `scripts/ui/` (création du dossier) — l'emplacement canonique d'après l'architecture pour « hud ». [Source: game-architecture.md#Project-Structure (ligne ui/) ; #System-Location-Mapping]

### Project Context Rules

- _Aucun `project-context.md` présent dans le dépôt._ Règles applicables (archi + stories 1.1-1.7) : **`EventBus`-only** (snake_case au passé, pas d'appel dur entre systèmes — le HUD est **lecteur seul**) ; **pas de chemins de nœuds absolus** (`@onready`/`%UniqueName`/signals) ; **`.tres` pour l'équilibrage/seuils** (zéro magic number) ; **GDScript typé** (import 0/0) ; autoload **`Log`** (pas `Logger`) ; **pas de `class_name`** sur nœud de scène, **`class_name`** sur module math pur ; **logique pure isolée** (`--script`) vs intégration (`--*-smoke`) ; **erreurs non fatales** (NFR11) ; **60 FPS** (NFR1) ; UI = **Control + CanvasLayer** natifs (D9).
- **Outillage MCP** (Gopeak Godot MCP + Context7) prévu par l'archi — **non bloquant** ici. [Source: game-architecture.md#AI-Development-Tooling]

### References

- [Source: epics.md#Story-1.8] — HUD persistant : jauges globales (trésorerie, moral moyen, jour) ; matérialisation de l'attention (compteur de file + mails) ; signal visuel au franchissement d'un seuil (NFR7).
- [Source: epics.md#Story-1.7] — `agent_morale_changed` (signal fondateur consommé ici) ; Moral 0-100 par agent ; `DeskQueue`/file ; moral repart à 100 chaque matin (agents recréés).
- [Source: epics.md#Story-1.4] — `solicitation_raised`/`solicitation_opened` (canaux DESK/MAIL) ; `open_solicitation` ; l'Attention = file + mails (FR9).
- [Source: epics.md#Story-1.9] — fiche agent (état individuel) : **hors périmètre** ; précédent du « réserver un emplacement futur désactivé ».
- [Source: epics.md#Story-1.10] — bilan de fin de journée (écran modal récap) : **hors périmètre** ; précédent du « placeholder mission ».
- [Source: epics.md#Épic-3 (Trésorerie) / #Épic-4 (Deadline) / #Épic-5 (Budget IA)] — systèmes financiers/mission : **hors périmètre** → placeholders réservés au HUD.
- [Source: epics.md#Épic-6] — barre de temps cliquable, juice, polish de feedback : **hors périmètre**.
- [Source: gdd.md §Piliers #1 / §Boucle / §DA] — l'attention est la ressource rare ; bilan jour (trésorerie/moral/avancement) ; signaux visuels lisibles d'un coup d'œil.
- [Source: game-architecture.md#Decision-Summary D9] — UI/HUD = Control nodes + `CanvasLayer`, natif Godot.
- [Source: game-architecture.md#Project-Structure ; #System-Location-Mapping] — `ui/` (scripts + `scenes/ui/`) pour hud/pop-ups/fiche ; agrégation = logique pure de présentation.
- [Source: game-architecture.md#Event-System ; #Architectural-Boundaries ; #Configuration ; #Error-Handling] — EventBus typé, pas de chemins absolus, `.tres` équilibrage, erreur non fatale (NFR11).
- [Source: lecture directe] — `event_bus.gd` (14 signaux), `game_manager.gd` (day_count/is_paused/speed_level), `sim_balance.gd`, `solicitation_system.gd` (départ ≠ opened → anti-fantôme), `solicitation.gd` (enum Channel), `agent.gd` (morale/agent_spawned), `agent_spawner.gd` (seed initial_morale), `decision_popup.gd`/`decision_popup.tscn` (modèle CanvasLayer/UI + Blocker modal), `open_space.tscn`, `main.gd` (harnais + helpers).
- [Source: 1-7…md] — autoload `Log` ; pas de `class_name` sur systèmes/nœuds de scène ; modules math purs avec `class_name` ; pas de GUT (runner headless) ; pure `--script` vs smoke d'intégration ; piège des lambdas (compteurs membres) ; pattern override de test ; prudence `.tres` (scalaires `@export` typés) ; signal fondateur ; moral seedé par `agent_initial_morale`.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.8 (claude-opus-4-8)

### Debug Log References

- Moteur : Godot 4.6.3-stable (`Godot_v4.6.3-stable_win64_console.exe`), exécution **headless réelle** (validation par import + run, jamais « au jugé »).
- **Baseline avant dev** (état de départ vert) : import 0/0 ; 7 suites unitaires PASS ; smokes PASS (commit `17a1bf7`).
- Import après implémentation : `godot --headless --path open_space --import` → **0 erreur / 0 warning** (grep `SCRIPT ERROR|^ERROR:|WARNING:|Parse Error` = 0). `HudMath`/`SimBalance` enregistrés.
- Unitaire HUD : `--script res://tests/unit/test_hud.gd` → `TEST_RESULT=PASS`, **18/18** (`average_morale` vide/arrondi/0 ; `morale_severity` bornes exclusives 50/25 + sentinelle -1 ; `attention_severity` seuil 3 + défensif seuil 0).
- Intégration HUD : `godot --headless --path open_space -- --hud-smoke` → `HUD_SMOKE day=1 morale0=100 mail_ok=true file_before=4 file_after=3 warn_ok=true crit_ok=true`, `HUD_SMOKE_RESULT=PASS`. Couvre AC1 (jour=1, moral moyen=100), AC2 (mails ≥ 1 puis purge à 0 ; file 4→3 au traitement du front), AC3 (sévérité NORMAL→WARNING→CRITICAL via le vrai `agent_morale_changed`).
- **Non-régression** : 8 suites unitaires PASS (7 existantes + `test_hud`) ; 7 smokes PASS (`--sim-smoke`/`--time-smoke`/`--solicitation-smoke`/`--decision-smoke`/`--resolution-smoke`/`--queue-smoke`/`--hud-smoke`).
- Perf (NFR1) : `--measure-fps` → `FPS_MEASUREMENT=145` (≥ 60 ; `Hud` événementiel, aucun `_process`).
- Note : les 2 warnings runtime de navigation (`open_space.gd::_build_navigation`, code Story 1.2 non modifié) restent pré-existants, hors périmètre ; l'**import** reste 0/0.

### Completion Notes List

- **HUD persistant livré comme consommateur EventBus pur** : nouveau `%Hud` (`CanvasLayer`, `scripts/ui/hud.gd`, sans `class_name`) instancié dans `open_space.tscn`. Il **s'abonne** à `day_started`/`agent_spawned`/`agent_morale_changed`/`agent_departed`/`solicitation_raised`/`solicitation_opened`/`game_paused`/`speed_changed` et **n'émet rien, ne modifie aucun système** → zéro régression (8 suites + 7 smokes verts). Seule UPDATE de logique : 3 scalaires de seuil `@export` dans `sim_balance.gd` (typés, existant préservé, `.tres` non réécrit).
- **AC1** : `%DayLabel` (« Jour N », lu sur `GameManager.day_count` / `day_started`) ; `%MoraleLabel` (moral moyen entier ou « — » si aucun agent) ; `%TreasuryLabel` **placeholder figé « € — »** (Trésorerie = Épic 3, non inventée). Indicateur temps `%TimeLabel` (« x1 »/« PAUSE ») inclus en bonus de lisibilité.
- **AC2 (matérialisation de l'attention)** : compteurs `%FileLabel` (DESK) et `%MailLabel` (MAIL) reconstruits par signaux dans deux sets ; **anti-fantôme** via abonnement à `agent_departed` (un départ purge les deux sets + le moral, car `SolicitationSystem` n'émet pas `solicitation_opened` au départ). Décrément vérifié : file 4→3 au traitement du front.
- **AC3 (signal visuel de seuil, NFR7)** : couleur du label (normal/ambre/rouge) pilotée par `HudMath.morale_severity` (moral moyen) et `HudMath.attention_severity` (charge file+mails), **seuils data-driven** (`hud_morale_warn_below=50`/`hud_morale_critical_below=25`/`hud_attention_warn_at=3`). Logique pure isolée et testée `--script` (18/18).
- **Moral moyen — piège du seed** : `agent_morale_changed` n'émet qu'au changement ; le HUD seed `_morale_by_agent` sur `agent_spawned` à `SimBalance.agent_initial_morale` (exactement la valeur que le spawner passe à `Agent.setup`) → moyenne correcte dès le spawn, sans double source de vérité.
- **Anti-vol de clic** : `mouse_filter = IGNORE` sur tous les Control du HUD → les clics traversent vers la caméra/`SelectionController` (la sélection 1.4 et la future fiche 1.9 ne sont pas interceptées). Inverse volontaire de la pop-up modale 1.5.
- **Bornes respectées** : aucune vraie Trésorerie/Budget IA/Deadline (placeholder uniquement) ; pas de fiche agent (1.9) ; pas de bilan modal (1.10) ; pas de barre de temps cliquable ni juice (Épic 6) ; pas de Fatigue/burnout (Épic 2) ; pas de persistance (Épic 7). `solicitation_system.gd`/`desk_queue.gd`/`agent.gd`/`game_manager.gd`/`event_bus.gd`/`decision_popup.gd`/`selection_controller.gd` **non modifiés**.
- **Système fonctionnel de bout en bout** : caméra (1.1), agents (1.2), temps (1.3), sollicitations (1.4), pop-up (1.5), résolution (1.6), file/moral (1.7) restent opérationnels (8 suites + 7 smokes PASS, 145 FPS, import 0/0).

### File List

**Nouveaux fichiers (sous `open_space/`) :**
- `scripts/ui/hud_math.gd` (`class_name HudMath` — `average_morale`/`morale_severity`/`attention_severity` purs + enum `Severity`)
- `scripts/ui/hud_math.gd.uid`
- `scripts/ui/hud.gd` (HUD persistant : abonnements EventBus, agrégation moral/attention, rendu + signal de seuil ; getters d'affichage pour le test)
- `scripts/ui/hud.gd.uid`
- `scenes/ui/hud.tscn` (CanvasLayer + PanelContainer/Margin/HBox + labels `%`, `mouse_filter = IGNORE`)
- `tests/unit/test_hud.gd` (runner headless, 18 tests purs)
- `tests/unit/test_hud.gd.uid`

**Fichiers modifiés :**
- `scripts/systems/sim_balance.gd` (3 seuils HUD `@export` typés ajoutés ; existant préservé)
- `scenes/world/open_space.tscn` (instance `%Hud` ajoutée, `ext_resource id="9"` ; structure préservée)
- `scripts/main/main.gd` (harnais `--hud-smoke` + branche dans `_ready` ; 7 harnais + helpers existants préservés)

## Change Log

| Date | Version | Description |
|---|---|---|
| 2026-06-22 | 0.8.0 | Implémentation Story 1.8 : HUD persistant & ressource Attention. Première UI HUD du projet (`%Hud`, `CanvasLayer`) instanciée dans `open_space.tscn`, **consommateur EventBus pur** (jour, moral moyen, compteurs file/mails, indicateur temps), sans modifier aucun système. `HudMath` pur (`average_morale`/`morale_severity`/`attention_severity`, testé `--script` 18/18). Compteurs d'attention reconstruits par signaux avec **anti-fantôme** (`agent_departed` purge sets + moral) ; moral moyen seedé sur `agent_spawned` à `SimBalance.agent_initial_morale` ; signal visuel de seuil (couleur) data-driven (`hud_morale_warn_below`/`hud_morale_critical_below`/`hud_attention_warn_at`). `mouse_filter = IGNORE` → la sélection au clic n'est pas interceptée. Trésorerie/Budget IA/Deadline = placeholder réservé (Épics 3/4/5). Tests : 18/18 `test_hud` + `--hud-smoke` PASS (jour=1, moral=100, mails≥1 puis 0, file 4→3, sévérité N→W→C) ; non-régression 8 suites unitaires + 7 smokes PASS ; 145 FPS (NFR1) ; import 0/0. `solicitation_system.gd`/`desk_queue.gd`/`agent.gd`/`game_manager.gd`/`event_bus.gd` non modifiés. Statut → review. |
