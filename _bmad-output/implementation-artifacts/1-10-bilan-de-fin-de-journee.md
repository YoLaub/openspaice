---
baseline_commit: 17a1bf743b7bbe370a86cc508b0222aa2bb0b047
---

# Story 1.10: Bilan de fin de journée

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a joueur,
I want un **récapitulatif en fin de journée** (écran modal) qui s'affiche quand le soir arrive et **met la journée suivante en attente** tant que je ne l'ai pas validé,
so that je **mesure ma performance** (moral moyen de l'équipe, trésorerie/avancement réservés) et **décide consciemment** de passer au lendemain — bouclant ainsi la **boucle native complète (1.1→1.10)**, prête à être jugée « fun » avant toute intégration LLM (NFR10, gate de sortie de l'Épic 1).

## Acceptance Criteria

1. **Given** une journée ouvrée se termine **When** le soir arrive (la phase de journée **reboucle** — `day_ended` émis par `GameManager`) **Then** un **écran de bilan MODAL** s'affiche et **récapitule** : (a) le **jour qui vient de se terminer** (« Jour N terminé ») ; (b) la **Trésorerie** sous forme de **placeholder réservé** (« € — », Épic 3, exactement comme le HUD 1.8) ; (c) le **Moral moyen** de l'équipe de la journée (valeur entière 0-100 calculée via `HudMath.average_morale`, avec **signal de seuil couleur** réutilisant `HudMath.morale_severity` + les seuils HUD du `.tres` ; « — » si aucun agent n'a été présent) ; (d) l'**Avancement mission** en **placeholder réservé** (« — », Épic 4). [Source: epics.md#Story-1.10 AC1 ; FR15 (bilan : trésorerie, moral moyen, avancement) ; gdd.md ; game-architecture.md#Decision-Summary D9 (UI = Control + CanvasLayer) ; 1-8…md (patron placeholder Trésorerie + agrégation moral + couleur de seuil)]

2. **Given** le bilan est affiché **When** je le **valide** (bouton « Lancer la journée suivante ») **Then** l'écran se **referme** et la **journée suivante démarre** (`GameManager.start_next_day()` → `day_started(N+1)` → le matin se relance : nettoyage + spawn des agents par `AgentSpawner`, HUD passe à « Jour N+1 »). **Tant que** le bilan n'est **pas** validé, **aucune** nouvelle journée ne démarre (le temps de simulation est **gelé** : plus de tick `SimClock` → la phase de journée n'avance pas, aucun spawn). [Source: epics.md#Story-1.10 AC2 ; game_manager.gd#_on_simulation_tick (wrap → `day_ended`+`day_started` à découpler) ; agent_spawner.gd (spawn/clear sur `day_started`)]

3. **Given** la **boucle native complète** tourne (1.1→1.10 : caméra, agents, temps pausable, sollicitations DESK/MAIL, pop-up de décision, résolution immédiate/différée, file/patience/Moral, HUD persistant, fiche agent, **et désormais le bilan + l'enchaînement des journées**) **When** elle est exécutée de bout en bout (import 0/0, tous les tests et smokes verts) **Then** elle est **fonctionnelle et jouable sans rien casser** des Stories 1.1→1.9 — et **prête pour le playtest « fun »** (NFR10, gate de sortie de l'Épic 1, **jugement manuel** hors périmètre code). [Source: epics.md#Story-1.10 AC3 ; NFR10 ; epics.md#Épic-1 (gate avant Épic 5)]

> **Frontière de cette story (lire absolument — périmètre volontairement borné) :**
> - **1.10 FAIT** :
>   - **(a)** un **écran de bilan MODAL** = nouvelle UI `CanvasLayer` (`%DayReport`) avec un **`ColorRect` Blocker plein écran** (capte tout — **modèle exact `decision_popup.tscn`**, pas la fiche non-modale 1.9), un **Panel centré**, des **Labels** (jour terminé, Trésorerie placeholder, **Moral moyen** + couleur de seuil, Avancement mission placeholder) et **un bouton de validation actif** (« Lancer la journée suivante ») ;
>   - **(b)** le **découplage du cycle de journée** dans `GameManager` : au rebouclage, on **émet `day_ended`** puis on **GÈLE** la sim (`SimClock.stop()`) **sans** enchaîner `day_started` ; une nouvelle méthode **`start_next_day()`** (appelée par le bouton du bilan **et** par le smoke) **relance** la sim (`SimClock.start()`) et émet `day_started(N+1)` ;
>   - **(c)** un **point d'entrée commun** testable sur le bilan : **`func confirm() -> void`** (appelé par le bouton `pressed` **et** par `--report-smoke`), modèle `DecisionPopup.choose_option` / `SelectionController.handle_agent_click` ;
>   - **(d)** le bilan est un **consommateur EventBus pur** : il **agrège le Moral** par les signaux existants (`agent_spawned` / `agent_morale_changed` / `agent_departed`, **exactement** comme le HUD 1.8) pour disposer d'une **moyenne de la journée** au moment de `day_ended` (cf. Décision n°2 — instantané robuste aux départs du soir), et **réutilise `HudMath.average_morale` + `HudMath.morale_severity` + les seuils HUD du `.tres`** — **zéro** nouveau module pur, **zéro** nouveau seuil `.tres` ;
>   - **(e)** la **mise à jour du harnais `--time-smoke`** (et l'ajout de `--report-smoke`) pour valider le **nouveau flux gaté** (la journée suivante ne démarre **plus** automatiquement : elle démarre via `start_next_day()`).
> - **1.10 NE FAIT PAS** (ne pas déborder) :
>   - **Aucune trésorerie / aucun chiffre d'avancement réels** : Trésorerie = **Épic 3**, Missions/avancement = **Épic 4** → **placeholders figés** (« € — » / « — »), **sans** logique ni source de données (patron Trésorerie du HUD 1.8). **NE PAS** inventer d'économie ni de mission.
>   - **Aucune nouvelle jauge / aucun nouveau calcul d'agrégat** : le **Moral moyen** réutilise **strictement** `HudMath.average_morale` (déjà testé en 1.8). **NE PAS** créer de module `DayReportMath` ni de nouveau seuil.
>   - **Aucune persistance / sauvegarde** : le bilan ne sauvegarde **rien** (sauvegarde de l'état complet = `SaveManager`, **Épic 7**, D7). Pas de cumul inter-parties, pas d'historique des jours.
>   - **Aucun score / classement / fin de partie** : conditions de victoire/défaite, IPO, mode infini & score = **Épics 4/7**. Le bilan **récapitule** un jour, il ne **juge** pas la partie.
>   - **Pas de juice** (tween d'apparition, fondu, son de fin de journée, graphes/courbes) = **Épic 6**. Ici : Blocker + Panel + Labels + 1 bouton suffisent.
>   - **Aucune modification de comportement** des systèmes amont **au-delà du strict découplage du cycle de journée dans `GameManager`** : `Agent`, `SolicitationSystem`, `DeskQueue`, `DecisionResolver`, `DecisionPopup`, `Hud`, `AgentCard`, `SelectionController`, `EventBus` (signaux), `AgentSpawner`, `SimClock`, `SimBalance`(`.tres`) **restent inchangés** (le bilan est un **lecteur** ; `GameManager` ne fait que **scinder** l'émission `day_ended` / `day_started` déjà présente et **geler/relancer** `SimClock`). `day_ended` **existe déjà** (signal fondateur 1.1, déjà émis au wrap depuis 1.3) — **NE PAS** créer de nouveau signal.

## Tasks / Subtasks

- [x] **Task 1 — Scène bilan : `scenes/ui/day_report.tscn` (CanvasLayer + Blocker MODAL + Panel)** (AC: #1, #2)
  - [x] Créer `scenes/ui/day_report.tscn` : racine **`DayReport` (CanvasLayer)** + script `day_report.gd` (Task 2). **Modèle EXACT = `scenes/ui/decision_popup.tscn`** (UI modale du projet), **PAS** `agent_card.tscn` (qui est non-modale).
  - [x] **`Blocker` (`ColorRect`)** plein écran (`anchor_right=1.0`, `anchor_bottom=1.0`, `color = Color(0,0,0,0.35)` comme la pop-up) → il **capte tous les clics** (modal : le joueur ne peut rien faire d'autre tant qu'il n'a pas validé). C'est **l'inverse** de la fiche 1.9 (Panel STOP borné) et **identique** à la pop-up 1.5.
  - [x] **`Panel` centré** (ancré au centre, 480×320 → offsets -240/-160 → 240/160) → `VBox` (`VBoxContainer`, séparation 16) avec **Labels nommés `unique_name_in_owner = true`** (lecture par `%`) :
    - `%TitleLabel` (« Jour N terminé »),
    - `%TreasuryLabel` (« Trésorerie : € — » — **placeholder figé** Épic 3),
    - `%MoraleLabel` (« Moral moyen de l'équipe : NN » ou « — » ; **couleur de seuil**),
    - `%MissionLabel` (« Avancement mission : — » — **placeholder figé** Épic 4).
  - [x] **`%ConfirmButton`** (« Lancer la journée suivante ») — **seul** bouton actif ; il appellera `confirm()` (Task 2). Étant dans le Blocker modal, son clic est consommé par la GUI (ne traverse pas vers le 3D).
  - [x] Texte **lisible** sur la DA claire « Severance » (texte foncé contrasté, Panel semi-opaque léger pour NFR7). `visible = false` au départ (le bilan ne s'ouvre qu'à `day_ended`).

- [x] **Task 2 — `DayReport` : agrégation du moral, affichage à `day_ended`, validation** (AC: #1, #2)
  - [x] Créer `scripts/ui/day_report.gd` (`extends CanvasLayer`, **sans `class_name`** — cohérent `Hud`/`DecisionPopup`/`AgentCard`/`SolicitationSystem` : un nœud de scène n'a pas de `class_name`). Doc d'en-tête + sources + rappel « bilan = lecteur d'agrégats + porte de passage au jour suivant ; modal ; réutilise `HudMath` ».
  - [x] `const _BALANCE: SimBalance = preload("res://data/balance/sim_balance.tres")` (réutilise les **seuils HUD** `hud_morale_warn_below` / `hud_morale_critical_below` — **aucun nouveau champ `.tres`**).
  - [x] Couleurs de seuil **en dur** (présentation, pas équilibrage) — réutiliser **exactement** la convention HUD/fiche : `_COLOR_NORMAL` foncé, `_COLOR_WARNING` ambre, `_COLOR_CRITICAL` rouge.
  - [x] `@onready var` sur chaque label/bouton via `%` (cf. Task 1). **Pas** de chemin de nœud absolu.
  - [x] **Agrégation du moral (modèle HUD 1.8) — instantané robuste aux départs du soir (Décision n°2)** :
    - `var _morale_by_agent: Dictionary = {}` (agent_id → int), reconstruit **par signaux** (aucune référence de nœud).
    - `var _day_avg_morale: int = -1` : **instantané** de la moyenne de la journée. **Mis à jour sur `agent_spawned` et `agent_morale_changed`** (cohorte présente) ; **PAS** sur `agent_departed` (un départ du soir ne doit **pas** écraser l'instantané — sinon la moyenne finit par ne refléter que le dernier agent restant). Cf. Décision n°2.
  - [x] `_ready()` :
    - `process_mode = Node.PROCESS_MODE_ALWAYS` (cohérent UI : interactif/à jour même si le jeu est gelé).
    - `visible = false`.
    - Abonnements **persistants** : `EventBus.day_ended.connect(_on_day_ended)` ; `EventBus.agent_spawned.connect(_on_agent_spawned)` ; `EventBus.agent_morale_changed.connect(_on_agent_morale_changed)` ; `EventBus.agent_departed.connect(_on_agent_departed)` ; `EventBus.day_started.connect(_on_day_started)`.
    - `%ConfirmButton.pressed.connect(confirm)`.
  - [x] **Pas de `_process`** (NFR1) : 100 % événementiel.
  - [x] Handlers d'agrégation (modèle HUD `_on_agent_*`) :
    - `_on_agent_spawned(agent_id)` : `_morale_by_agent[agent_id] = roundi(_BALANCE.agent_initial_morale)` ; `_recompute_snapshot()`.
    - `_on_agent_morale_changed(agent_id, morale)` : `_morale_by_agent[agent_id] = morale` ; `_recompute_snapshot()`.
    - `_on_agent_departed(agent_id)` : `_morale_by_agent.erase(agent_id)` **uniquement** (NE PAS recomputer l'instantané — il fige la moyenne d'avant les départs).
    - `_on_day_started(_day)` : **réinitialise** le cycle d'agrégation pour le nouveau jour → `_morale_by_agent.clear()` ; `_day_avg_morale = -1`. (Le bilan est déjà fermé à ce stade ; ce reset prépare le jour suivant.)
    - `_recompute_snapshot()` : `if not _morale_by_agent.is_empty(): _day_avg_morale = HudMath.average_morale(_morale_by_agent.values())`.
  - [x] **`func _on_day_ended(day: int) -> void`** : remplit les labels et **affiche** le bilan (modal). C'est le déclencheur unique de l'écran.
    - `%TitleLabel.text = "Jour %d terminé" % day`.
    - `%TreasuryLabel.text = "Trésorerie : € —"` (**placeholder figé** — Épic 3).
    - `%MissionLabel.text = "Avancement mission : —"` (**placeholder figé** — Épic 4).
    - **Moral** via `_render_morale(_day_avg_morale)`.
    - `visible = true`.
  - [x] `_render_morale(avg: int)` : `%MoraleLabel.text = "Moral moyen de l'équipe : —" if avg < 0 else "Moral moyen de l'équipe : %d" % avg` ; **couleur de seuil** via `HudMath.morale_severity(avg, _BALANCE.hud_morale_warn_below, _BALANCE.hud_morale_critical_below)` → `_apply_severity(%MoraleLabel, severity)` (réutilise la logique pure **déjà testée** en 1.8 ; `_apply_severity` identique au HUD : `add_theme_color_override("font_color", …)`). Mémoriser `_day_avg_morale` rendu (pour les getters de test).
  - [x] **`func confirm() -> void`** — **POINT D'ENTRÉE COMMUN** (bouton + `--report-smoke`) :
    - garde `if not is_showing(): return` ;
    - `visible = false` (referme le bilan **avant** de relancer, pour éviter tout réaffichage parasite) ;
    - `GameManager.start_next_day()` (relance la sim + émet `day_started(N+1)` → spawn du matin via `AgentSpawner`). **Le bilan ne touche RIEN d'autre** : il ne spawn pas, ne nettoie pas, ne modifie aucun système.
    - `Log.info("Bilan validé — passage au jour suivant")`.
  - [x] **Getters pour le test** (modèle `Hud.displayed_*` / `DecisionPopup.is_showing()`) : `func is_showing() -> bool` (= `visible`) ; `func displayed_day_avg_morale() -> int` (= `_day_avg_morale`) ; `func displayed_morale_severity() -> int` (= `HudMath.morale_severity(_day_avg_morale, _BALANCE.hud_morale_warn_below, _BALANCE.hud_morale_critical_below)`).
  - [x] **Garde-fous NFR11** : `confirm()` hors affichage est sans effet ; aucun appel vers un système autre que `GameManager.start_next_day()` ; lecture seule de `_BALANCE`.

- [x] **Task 3 — Découpler le cycle de journée dans `GameManager` (gel du jour suivant)** (AC: #2)
  - [x] **UPDATE** `scripts/autoloads/game_manager.gd`. **Préserver intégralement** : pause (`set_paused`/`toggle_pause`/`game_paused`), vitesses (`set_speed`/`speed_changed`/`Engine.time_scale`), l'**amorce du tout premier jour** dans `_on_simulation_tick` (la branche `if not _day_active:` qui émet `day_started(day_count+1)` au 1er tick — **inchangée**, ce n'est pas un wrap), `_on_day_started` (qui fixe `day_count`), `process_mode = ALWAYS`, l'input clavier.
  - [x] Ajouter un drapeau d'attente : `var _awaiting_day_review: bool = false`.
  - [x] **Modifier UNIQUEMENT la branche de rebouclage** de `_on_simulation_tick` (`if DayPhaseMathC.has_wrapped(...)`) : émettre **`day_ended(day_count)`** (comme aujourd'hui), puis **NE PLUS** émettre `day_started` ici ; à la place : `_awaiting_day_review = true` ; `SimClock.stop()` (gèle l'horloge → plus de tick → `day_phase` figée, aucun nouveau wrap, aucun spawn) ; `Log.info("Fin de journée %d — bilan en attente" % day_count)`.
    ```
    if DayPhaseMathC.has_wrapped(previous, day_phase):
        EventBus.day_ended.emit(day_count)
        _awaiting_day_review = true
        SimClock.stop()   # gèle la sim jusqu'à validation du bilan (start_next_day)
    ```
  - [x] **`func start_next_day() -> void`** (appelée par `DayReport.confirm()` et par les smokes) :
    ```
    func start_next_day() -> void:
        if not _awaiting_day_review:
            return
        _awaiting_day_review = false
        SimClock.start()
        EventBus.day_started.emit(day_count + 1)   # _on_day_started fixe day_count, AgentSpawner respawn
    ```
  - [x] **Garde sur l'input pendant l'attente** (anti-incohérence) : dans `_unhandled_input`, **ignorer** pause/vitesses tant que `_awaiting_day_review` est vrai (le temps est géré par le bilan, pas par le joueur, à ce moment). *(SimClock étant arrêté, presser une vitesse ne relancerait pas les ticks ; cette garde évite surtout que le HUD affiche un état temporel trompeur pendant le bilan.)*
  - [x] **Exposer l'attente pour le test** : `func is_awaiting_day_review() -> bool: return _awaiting_day_review`.
  - [x] **Mettre à jour la doc d'en-tête** du `GameManager` : décrire que la fin de journée **n'enchaîne plus automatiquement** le matin suivant — elle émet `day_ended`, gèle `SimClock`, et **attend `start_next_day()`** (validé via le bilan 1.10).

- [x] **Task 4 — Instancier `%DayReport` dans l'open space** (AC: #1, #2)
  - [x] **UPDATE** `scenes/world/open_space.tscn` : ajouter une instance de `scenes/ui/day_report.tscn` (nœud `DayReport`) **enfant de `OpenSpace`**, avec `unique_name_in_owner = true` (`%DayReport`). Modèle = les instances `%Hud`/`%DecisionPopup`/`%AgentCard`.
  - [x] Déclarer la `PackedScene` du bilan via un **nouvel `id` `ext_resource` distinct** (`id="11"` — ids 1-10 déjà pris). **Préserver toute la structure existante** (`GridMap`/`NavigationRegion3D`/`%Agents`/`AgentSpawner`/`%SolicitationSystem`/`SelectionController`/`%DecisionPopup`/`%DecisionResolver`/`%DeskQueue`/`%Hud`/`%AgentCard`/`WorldEnvironment`/`DirectionalLight3D`/`CameraRig (process_mode=3)/Camera3D`). Import **0 erreur / 0 warning**.

- [x] **Task 5 — Tests (intégration `--report-smoke` + MAJ `--time-smoke` + non-régression)** (AC: #1, #2, #3)
  - [x] **MAJ OBLIGATOIRE de `--time-smoke`** dans `scripts/main/main.gd` (régression directe du découplage) : aujourd'hui `cycle_ok` exige `GameManager.day_count > day_before` **automatiquement** après un wrap. Avec le gel, le jour suivant **ne démarre plus seul**. Remplacer la vérification du bloc « (c) AC#3 » par le **nouveau flux gaté** :
    - après le `_real_wait(2.0)` qui provoque le wrap : vérifier `GameManager.is_awaiting_day_review() == true` **et** `GameManager.day_count == day_before` (le jour n'a **pas** avancé tout seul) **et** `ended_days.size() == 1` (un **seul** wrap : `SimClock` est arrêté) ;
    - puis appeler `GameManager.start_next_day()` et vérifier `GameManager.day_count == day_before + 1` (le matin suivant démarre **sur validation**).
    - Adapter `cycle_ok` en conséquence ; **conserver** les vérifications (a) pause et (b) vitesses x1/x3 **inchangées**.
  - [x] **Intégration `--report-smoke`** dans `scripts/main/main.gd` (modèle `_run_hud_smoke_and_quit` / `_run_card_smoke_and_quit` ; réutiliser `_real_wait`). Récupérer `var report: CanvasLayer = open_space.get_node("DayReport")`, `var hud: CanvasLayer = open_space.get_node("Hud")`, `var agents_root := open_space.get_node("Agents")`, `var solicitations := open_space.get_node("SolicitationSystem")`.
    - **Pré** : `solicitations.rate_override = 0.0` (pas de sollicitation parasite), `set_speed(3)`, `await _real_wait(4.0)` (agents arrivés, moral à 100). Mémoriser `var day_before: int = GameManager.day_count`.
    - **(AC1 — instantané moral robuste)** : baisser le moral d'un/plusieurs agents via le **vrai** chemin (`(node as Agent).adjust_morale(-40.0)` sur ≥1 agent) → l'instantané `_day_avg_morale` du bilan doit refléter la baisse (cohorte présente). *(Vérifier `report.displayed_day_avg_morale() < 100` après la baisse.)*
    - **(AC1 — affichage à `day_ended`)** : provoquer le wrap (`GameManager.day_duration_seconds = 1.0`, `set_speed(3)`, `await _real_wait(2.0)`) → `report.is_showing() == true` ; le moral affiché = l'instantané d'avant les départs (`displayed_day_avg_morale()` cohérent avec la baisse, **pas** « — »), **même si tous les agents sont partis le soir** (robustesse Décision n°2) ; `report.displayed_morale_severity()` cohérent avec le seuil.
    - **(AC2 — gate)** : juste après le wrap, `GameManager.is_awaiting_day_review() == true` **et** `GameManager.day_count == day_before` (le jour suivant **n'a pas** démarré). Attendre encore (`await _real_wait(1.0)`) et reconfirmer que `day_count` n'a **pas** bougé (sim gelée).
    - **(AC2 — validation)** : `report.confirm()` → `report.is_showing() == false` ; `GameManager.day_count == day_before + 1` ; `GameManager.is_awaiting_day_review() == false` ; après `await _real_wait(2.0)`, des agents sont de nouveau présents (`agents_root.get_children()` contient des `Agent`) et `hud.displayed_day() == day_before + 1` (le HUD a suivi). *(Optionnel : `report` a réinitialisé son agrégation sur `day_started`.)*
    - Restaurer overrides (`rate_override = -1.0`, `desk_prob_override = -1.0`), `set_speed(1)`, `Engine.time_scale = 1.0`. `print("REPORT_SMOKE ...")` + `REPORT_SMOKE_RESULT=PASS/FAIL` + `get_tree().quit(0/1)`.
  - [x] Brancher `--report-smoke` dans `_ready()` (nouvelle branche `elif args.has("--report-smoke")`) **sans toucher aux 9 branches existantes** (`--measure-fps`/`--sim-smoke`/`--time-smoke`/`--solicitation-smoke`/`--decision-smoke`/`--resolution-smoke`/`--queue-smoke`/`--hud-smoke`/`--card-smoke`).
  - [x] **Piège lambda GDScript (capture par valeur)** : tout compteur/mémo requis dans le smoke via **variables membres** de `main.gd`, jamais un local capturé dans un signal (apprentissages 1.4/1.6/1.7). Ici on lit surtout des getters → peu de captures.
  - [x] **Non-régression** : suites unitaires existantes (`test_camera_math`, `test_agent_sim`, `test_time_control`, `test_solicitation_math`, `test_decision`, `test_decision_resolution`, `test_morale`, `test_hud`) → **8/8 PASS** (le bilan n'ajoute **pas** de module pur — il réutilise `HudMath`, déjà couvert) ; **10 smokes** (`--sim`/`--time` *(mis à jour)*/`--solicitation`/`--decision`/`--resolution`/`--queue`/`--hud`/`--card`/`--report`) → **PASS** ; `--measure-fps` → **≥ 60** (NFR1). **Vérifier explicitement** que le découplage du cycle de journée **ne casse aucun** smoke amont qui force un wrap (notamment `--resolution-smoke`, qui passe `day_duration_seconds = 1.0` et attend la résolution **différée** sur ≥1 bouclage de journée — cf. Décision n°3 / Anti-pièges).

## Dev Notes

### Contexte & objectif

Les Stories 1.1→1.9 ont posé la **boucle cœur complète** : caméra iso (1.1), agents natifs + cycle de journée (1.2), horloge pausable x1/x2/x3 (1.3), sollicitations DESK/MAIL (1.4), pop-up de décision (1.5), résolution immédiate/différée (1.6), file/patience/**Moral 0-100** (1.7), **HUD persistant** (1.8) et **fiche agent** (1.9). Il manque la **clôture du jour** : un **bilan de fin de journée** qui récapitule la performance et **rythme** le jeu (un jour → un bilan → le jour suivant). La 1.10 ajoute cet **écran modal** et — point clé — **découple l'enchaînement des journées** pour que le lendemain ne démarre que sur **validation du joueur**. C'est la **dernière brique de l'Épic 1** : une fois livrée, la **boucle native (1.1→1.10) est complète et jouable de bout en bout**, prête pour le **playtest « fun »** (NFR10) qui conditionne le démarrage de l'Épic 5 (intégration LLM). [Source: epics.md#Story-1.10 ; #Épic-1 ; FR15 ; NFR10 ; gdd.md]

### ⚠️ Décision de conception clé n°1 : **découpler `day_ended` de `day_started`** (geler le matin suivant)

Aujourd'hui, `GameManager._on_simulation_tick` émet, **dans le même tick**, `day_ended(day_count)` **puis** `day_started(day_count+1)` au rebouclage — le matin suivant s'enchaîne **automatiquement** (commentaire existant : « signaler le jour qui se termine (consommé par le bilan, Story 1.10) AVANT d'ouvrir le jour suivant »). L'AC2 impose l'**inverse** : le jour suivant **ne doit pas** démarrer tant que le bilan n'est pas validé. **Décision retenue** :
- Au wrap : émettre `day_ended`, poser `_awaiting_day_review = true`, **`SimClock.stop()`** (gèle l'horloge → plus de tick → `day_phase` figée, **aucun** nouveau wrap, **aucun** spawn). **Ne pas** émettre `day_started` ici.
- Le bouton du bilan (ou le smoke) appelle **`GameManager.start_next_day()`** → `SimClock.start()` + `day_started(N+1)` → `AgentSpawner` nettoie/respawn, le HUD passe à « Jour N+1 ». 

**Pourquoi `SimClock.stop()` plutôt que `get_tree().paused = true`** : la pause joueur (1.3) utilise déjà `get_tree().paused` + `is_paused` + signal `game_paused` (lu par le HUD). Réutiliser ce mécanisme pour le **gel de fin de journée** mélangerait deux états distincts (« le joueur a mis en pause » vs « le jeu attend la validation du bilan ») et ferait clignoter l'indicateur « PAUSE » du HUD à chaque soir. **Arrêter `SimClock`** gèle proprement la **simulation** (c'est `SimClock` qui pilote l'avance de `day_phase` et les ticks agents) **sans** toucher l'état de pause joueur, sans toucher `Engine.time_scale`, et sans émettre `game_paused`. Le bilan, étant **modal** (Blocker plein écran), empêche de toute façon le joueur d'agir sur le monde pendant l'attente. [Source: game_manager.gd#_on_simulation_tick L92-108 ; sim_clock.gd (start/stop/running) ; 1-3…/1-8…md (pause = get_tree().paused + game_paused)]

> **Subtilité** : l'**amorce du tout premier jour** (branche `if not _day_active:` dans `_on_simulation_tick`) émet `day_started` au 1er tick et **n'est pas** un wrap → elle reste **inchangée** (le jeu démarre toujours directement sur le Jour 1, sans bilan). Le gel ne concerne **que** la **fin** d'une journée.

### ⚠️ Décision de conception clé n°2 : **instantané du Moral moyen robuste aux départs du soir**

Le HUD 1.8 agrège le moral des agents **présents** (`_morale_by_agent`, alimenté par `agent_spawned`/`agent_morale_changed`/`agent_departed`). Or les agents **partent échelonnés le soir** (`departure_phase` ≈ `evening_phase` 0.6 → ~1.0) **avant** le rebouclage (`day_ended` au wrap, phase 1.0→0.0). Donc **au moment de `day_ended`, le HUD a, en général, un set d'agents VIDE** → `average_morale([])` = `-1` → « — ». Lire la moyenne **live** du HUD au moment du bilan donnerait donc presque toujours « — » : **inutilisable**.

**Décision retenue** : le bilan maintient sa **propre** agrégation `_morale_by_agent` (modèle HUD) **mais** mémorise un **instantané** `_day_avg_morale` qui n'est **mis à jour que sur `agent_spawned` et `agent_morale_changed`** — **jamais** sur `agent_departed`. Ainsi :
- pendant la journée (avant le soir), `_day_avg_morale` suit la moyenne de la **cohorte complète** (les variations de moral viennent de l'impatience en file, 1.7, qui se produit **en journée**, pas le soir) ;
- quand les agents partent le soir, les `erase` **réduisent** le dictionnaire mais **n'écrasent pas** l'instantané → au `day_ended`, `_day_avg_morale` reflète bien la moyenne **d'avant les départs** (représentative de la journée), pas « le moral du dernier agent restant ».
- `day_started` (jour suivant) **réinitialise** l'agrégation (`clear()` + `_day_avg_morale = -1`) pour repartir propre.

Cas limite : journée sans aucun agent (théorique) → `_day_avg_morale` reste `-1` → le bilan affiche « — » (défensif, comme le HUD). [Source: hud.gd#_morale_by_agent / _on_agent_* ; hud_math.gd#average_morale (sentinelle -1) ; agent.gd (départ → queue_free → agent_departed) ; day_phase_math.gd#departure_phase ; sim_balance.gd#evening_phase]

### ⚠️ Décision de conception clé n°3 : non-régression des smokes qui forcent un wrap

Le découplage **change le comportement au wrap** → vérifier les smokes amont qui **bouclent une journée** :
- **`--time-smoke`** : **doit être mis à jour** (Task 5) — il vérifiait l'auto-avance du jour ; il doit désormais valider le **gel + `start_next_day()`**.
- **`--resolution-smoke`** : passe `day_duration_seconds = 1.0` + x3 et attend la **résolution différée** sur « plusieurs bouclages de journée » (`_real_wait(3.0)`). **Risque** : avec le gel, **un seul** wrap se produit puis `SimClock` s'arrête → les jours **n'avancent plus** seuls → la résolution différée (échéance en **jours**) pourrait **ne jamais** être atteinte → smoke **rouge**. **Le dev DOIT vérifier ce point** et, si nécessaire, adapter `--resolution-smoke` pour **enchaîner les jours via `GameManager.start_next_day()`** (après chaque `day_ended`, ou en bouclant `start_next_day()` jusqu'à franchir l'échéance) — **sans** changer la logique testée (immédiat vs différé). C'est une **régression attendue** du découplage : la traiter explicitement, ne pas la masquer.

> **Comment vérifier `DecisionResolver` vis-à-vis du jour** : lire `scripts/decisions/decision_resolver.gd` pour savoir **comment** il mesure l'échéance (compte-t-il les `day_started`/`day_ended`, ou la `day_phase` ?). Si l'échéance est comptée en **`day_started`**, alors tant qu'on ne valide pas les bilans, l'échéance ne tombe pas → adapter le smoke. **Ne pas** modifier `decision_resolver.gd` lui-même (hors périmètre) : adapter **le smoke** pour enchaîner les jours.

### La pop-up modale vs le bilan modal vs la fiche non-modale

Trois UIs `CanvasLayer` coexistent désormais ; bien distinguer leurs modes (NFR7) :
- **`DecisionPopup` (1.5)** : **modale** (Blocker `ColorRect` plein écran), ne gèle **pas** le temps, point d'entrée commun `choose_option`.
- **`AgentCard` (1.9)** : **non-modale** (Panel `mouse_filter = STOP` borné, **pas** de catcher plein écran), ne gèle pas le temps, points d'entrée `show_for`/`hide_card`.
- **`DayReport` (1.10, NOUVEAU)** : **modale** (Blocker plein écran, **modèle `decision_popup.tscn`**) ; pendant son affichage, la **simulation est gelée** par `GameManager` (`SimClock.stop()`), pas par le bilan lui-même. Point d'entrée commun `confirm()`. C'est la **seule** UI qui **pilote** la reprise du temps (via `GameManager.start_next_day()`). [Source: decision_popup.tscn (Blocker modal) ; agent_card.tscn (Panel STOP) ; hud.tscn (IGNORE) ; 1-5…/1-9…md]

### Anti-pièges (apprentissages 1.1 → 1.9 — à respecter absolument)

- **L'autoload logger s'appelle `Log`, PAS `Logger`** (collision avec la classe native Godot 4.6). `Log.info/warn/error`. [Source: 1-1…/1-8…/1-9…md]
- **Pas de `class_name` sur un nœud de scène** (`DayReport` comme `Hud`/`DecisionPopup`/`AgentCard`). Aucun nouveau module pur ici (réutilisation `HudMath`) → pas de `class_name` à créer. [Source: 1-2…/1-8…/1-9…md]
- **En mode `--script`, les autoloads ne sont PAS chargés** : non pertinent ici (pas de nouveau test `--script`) ; `--report-smoke` tourne en **scène complète** (autoloads présents) comme les autres smokes. [Source: 1-8…md#Tests]
- **GUT non installé** → harnais headless via `main.gd --report-smoke` (`get_tree().quit(0/1)`), pas de GUT. [Source: 1-1…→1-9…md]
- **Toujours valider par import + exécution headless réels** : `godot --headless --path open_space --import` doit rester **0 erreur / 0 warning** ; lancer **tous** les smokes (dont `--time` **mis à jour** et `--resolution`) + unitaires. [Source: 1-8…/1-9…md#Debug-Log-References]
- **Piège des lambdas GDScript (capture par valeur)** : tout compteur/mémo via **variables membres** de `main.gd`. [Source: 1-4…/1-6…/1-7…md]
- **Callbacks de signal vs gel** : `SimClock.stop()` arrête l'émission de `simulation_tick` (donc l'avance de la sim) ; il n'empêche **pas** les callbacks de signal déjà connectés ni l'UI (`DayReport` est `PROCESS_MODE_ALWAYS`, son bouton reste cliquable). [Source: sim_clock.gd ; 1-6…/1-8…md]
- **`.tres` — ne PAS éditer** : le bilan réutilise les seuils HUD ; **aucun** champ ajouté, `sim_balance.tres` **non touché**. [Source: 1-8…md ; sim_balance.gd]
- **Modal** : `Blocker` `ColorRect` plein écran (modèle pop-up 1.5) — **pas** de Panel borné (ce serait la fiche 1.9).

### Lecture des fichiers UPDATE (état actuel à préserver)

- **`scripts/autoloads/game_manager.gd`** — autoload `PROCESS_MODE_ALWAYS` ; possède `day_phase`/`day_count`/`evening_phase`/`day_duration_seconds`, l'état temporel (`is_paused`/`speed_level`), `toggle_pause`/`set_paused`/`set_speed`, `_on_day_started` (fixe `day_count`), et `_on_simulation_tick` (amorce 1er jour **+** avance/wrap → `day_ended`+`day_started`). **Modifier UNIQUEMENT** : la branche `has_wrapped` (ne plus enchaîner `day_started`, poser `_awaiting_day_review`, `SimClock.stop()`) ; **ajouter** `start_next_day()`, `is_awaiting_day_review()`, la garde d'input pendant l'attente. **Préserver** tout le reste (pause/vitesses/amorce 1er jour). [Source: lecture directe game_manager.gd L18-108]
- **`scenes/world/open_space.tscn`** — `OpenSpace` avec enfants existants (…/`%Hud` `ExtResource("9")`, `%AgentCard` `ExtResource("10")`). **Ajouter** une instance `%DayReport` (nouvel `ext_resource id="11"`). **Préserver** tout (ids 1-10, `CameraRig process_mode=3`, etc.). [Source: lecture directe open_space.tscn]
- **`scripts/main/main.gd`** — 9 harnais (`--measure-fps`/`--sim`/`--time`/`--solicitation`/`--decision`/`--resolution`/`--queue`/`--hud`/`--card`-smoke) + helpers (`_force_desk_solicitation`/`_open_first_active`/`_find_agent_by_id`/`_min_agent_distance_to`/`_real_wait`) + compteurs membres. **MàJ `--time-smoke`** (flux gaté), **ajouter** `--report-smoke` (+ branche dans `_ready`), **vérifier/adapter `--resolution-smoke`** (Décision n°3). **Préserver les autres harnais** et helpers. [Source: lecture directe main.gd L41-167 (time-smoke), L310-384 (resolution-smoke), L453-530 (hud-smoke), L537-618 (card-smoke)]
- **À LIRE (sans modifier) avant d'écrire le smoke** : `scripts/decisions/decision_resolver.gd` (mesure de l'échéance différée vs jours — cf. Décision n°3).
- **NE PAS MODIFIER** : `event_bus.gd` (aucun nouveau signal — `day_ended`/`day_started`/`agent_*` existent déjà), `sim_clock.gd` (on utilise `start`/`stop` existants), `agent.gd`, `agent_spawner.gd` (il respawn **déjà** sur `day_started` — c'est exactement ce que `start_next_day()` déclenche), `solicitation_system.gd`, `desk_queue.gd`, `decision_popup.gd`/`.tscn`, `decision_resolver.gd`, `hud.gd`/`hud_math.gd`/`hud.tscn`, `agent_card.gd`/`.tscn`, `selection_controller.gd`, `sim_balance.gd`/`.tres`, `agent_archetype.gd`, `morale_math.gd`. [Source: game-architecture.md#Architectural-Boundaries]

> **Important** : une story doit laisser le système **fonctionnel de bout en bout**. Au-delà des AC, **toute** la boucle 1.1→1.9 doit rester opérationnelle — **et le nouvel enchaînement de journées (gel → bilan → `start_next_day`) ne doit casser aucun smoke qui boucle un jour** (cf. Décision n°3 pour `--resolution-smoke`).

### Performance (NFR1)

`DayReport` est **100 % événementiel** (aucun `_process`) : il n'agrège qu'à la réception de signaux (`agent_spawned`/`agent_morale_changed`/`agent_departed`/`day_started`/`day_ended`) et ne s'affiche qu'au soir. Coût/frame **nul**. `SimClock.stop()` **réduit** la charge pendant l'attente (aucun tick). 60 FPS inchangés (1.9 mesurait 145 FPS). [Source: NFR1 ; 1-8…/1-9…md]

### Direction artistique / UI

UI **fonctionnelle et lisible**, pas finalisée : Blocker semi-opaque + Panel + Labels natifs sur la DA claire « Severance » (texte foncé contrasté), signal de seuil moral par **couleur** (ambre/rouge), un seul bouton d'action (« Lancer la journée suivante »). Le **juice** (tween/fondu d'apparition, son de fin de journée, graphes/courbes de tendance, icônes) relève d'**Épic 6**. [Source: gdd.md §Art ; epics.md#Épic-6 ; NFR7]

### Project Structure Notes

- Nouveaux fichiers conformes à la structure hybride (UI = `scripts/ui/` + `scenes/ui/`, cf. game-architecture.md#Project-Structure « ui/ : hud, pop-ups décision, fiche agent, **écrans méta**, écran IPO ») : `scripts/ui/day_report.gd`, `scenes/ui/day_report.tscn`. Le bilan est un **écran méta** de fin de journée → emplacement `ui/`.
- Fichiers modifiés : `scripts/autoloads/game_manager.gd` (découplage du cycle de journée + `start_next_day`), `scenes/world/open_space.tscn` (instance `%DayReport`, `ext_resource id="11"`), `scripts/main/main.gd` (harnais `--report-smoke`, MàJ `--time-smoke`, vérif/adaptation `--resolution-smoke`).
- Aucune nouvelle dépendance, aucun addon, **aucun nouveau module pur** (réutilise `HudMath`), **aucun champ `.tres`** ajouté, **aucun nouveau signal `EventBus`**. `DayReport` = nœud de scène (`CanvasLayer`) **sans** `class_name`. [Source: game-architecture.md#Project-Structure ; #System-Location-Mapping]

### Project Context Rules

- _Aucun `project-context.md` présent dans le dépôt._ Règles applicables (archi + stories 1.1-1.9) : **`EventBus`-only** (snake_case au passé ; le bilan **consomme** `day_ended`/`agent_*`, `GameManager` **émet** `day_ended`/`day_started`) ; **pas de chemins de nœuds absolus** (`@onready`/`%UniqueName`) ; **`.tres` pour les seuils** (zéro magic number — ici **réutilisés** du HUD) ; **GDScript typé** (import 0/0) ; autoload **`Log`** (pas `Logger`) ; **pas de `class_name`** sur nœud de scène ; **erreurs non fatales** (NFR11) ; **60 FPS** (NFR1) ; UI = **Control + CanvasLayer** natifs (D9) ; **modal** (Blocker plein écran) ≠ fiche non-modale ; **sauvegarde = `SaveManager`/Épic 7** (hors périmètre, D7).
- **Outillage MCP** (GoPeak Godot MCP + Context7) prévu par l'archi — **non bloquant** ici. [Source: game-architecture.md#AI-Development-Tooling]

### References

- [Source: epics.md#Story-1.10] — bilan de fin de journée (trésorerie, moral moyen, avancement placeholder) ; validation → journée suivante ; boucle 1.1→1.10 jugée « fun » avant LLM (NFR10, gate Épic 1).
- [Source: epics.md#FR15] — « Un bilan de fin de journée récapitule trésorerie, moral moyen et avancement mission. » ; FR15 rattaché à l'Épic 1.
- [Source: epics.md#Épic-1] — NFR10 = gate de sortie de l'Épic (boucle native fun avant intégration LLM).
- [Source: epics.md#Story-1.8] — HUD persistant ; `HudMath.average_morale`/`morale_severity` + seuils `.tres` **réutilisés** ; patron du placeholder réservé (Trésorerie « € — ») ; agrégation moral par signaux.
- [Source: epics.md#Story-1.3] — horloge pausable, `GameManager` propriétaire du temps ; cycle de journée (`day_started`/`day_ended`).
- [Source: epics.md#Story-1.2] — cycle de journée matin→soir, spawn/départ des agents (`AgentSpawner` sur `day_started`).
- [Source: epics.md#Épic-3 (Trésorerie) / #Épic-4 (Missions) / #Épic-7 (Sauvegarde)] — trésorerie, avancement mission, persistance : **hors périmètre** → placeholders / non traités.
- [Source: gdd.md] — bilan de fin de journée comme rythme du jeu (un jour → un récap → le lendemain).
- [Source: game-architecture.md#Decision-Summary D9] — UI/HUD/écrans = Control nodes + `CanvasLayer`, natif Godot ; [#D7] Sauvegarde = `SaveManager` (Épic 7).
- [Source: game-architecture.md#Project-Structure ; #System-Location-Mapping] — `ui/` (scripts + `scenes/ui/`) pour hud/pop-ups/écrans méta.
- [Source: game-architecture.md#Event-System ; #Architectural-Boundaries ; #Configuration ; #Error-Handling] — EventBus typé, pas de chemins absolus, `.tres` seuils, erreur non fatale (NFR11).
- [Source: lecture directe] — `game_manager.gd` (`_on_simulation_tick` wrap → `day_ended`+`day_started` à découpler ; `_on_day_started`), `sim_clock.gd` (`start`/`stop`/`running`), `event_bus.gd` (`day_ended`/`day_started`/`agent_*` — déjà présents), `agent_spawner.gd` (respawn sur `day_started`), `hud.gd`/`hud_math.gd` (`_morale_by_agent`, `average_morale`, `morale_severity`, `_apply_severity`, getters), `decision_popup.gd`/`.tscn` (modèle modal + point d'entrée commun), `agent_card.gd` (modèle consommateur EventBus + getters de test), `main.gd` (harnais + `--time-smoke` à mettre à jour, `--resolution-smoke` à vérifier), `decision_resolver.gd` (à lire : mesure de l'échéance différée vs jours), `open_space.tscn` (instanciation `%Hud`/`%AgentCard` → modèle `%DayReport`).
- [Source: 1-8…md] — autoload `Log` ; pas de `class_name` sur nœud de scène ; pas de GUT (harnais headless) ; pure `--script` (réutilisé) vs smoke d'intégration ; piège des lambdas ; pattern override de test ; prudence `.tres` ; agrégation du moral par signaux + couleur de seuil.
- [Source: 1-9…md] — point d'entrée commun testable (`confirm()` ≈ `handle_agent_click`/`choose_option`) ; consommateur EventBus filtré ; getters de test ; modal vs non-modal ; instance UI dans `open_space.tscn` (nouvel `ext_resource id`).

## Dev Agent Record

### Agent Model Used

Claude Opus 4.8 (claude-opus-4-8)

### Debug Log References

- Moteur : Godot 4.6.3-stable (`Godot_v4.6.3-stable_win64_console.exe`), exécution **headless réelle** (validation par import + run, jamais « au jugé »).
- **Baseline avant dev** (état de départ vert) : import 0/0 (commit `17a1bf7`).
- Import après implémentation : `godot --headless --path open_space --import` → **0 erreur / 0 warning** (filtre `ERROR|WARNING|Parse|SCRIPT` = 0). `day_report.gd`/`day_report.tscn` enregistrés.
- Intégration bilan : `godot --headless --path open_space -- --report-smoke` → `REPORT_SMOKE snapshot=60 shown=true morale_display=60 awaiting=true gated=true closed=true next_day=true`, `REPORT_SMOKE_RESULT=PASS`. Couvre AC1 (instantané du moral robuste : baisse réelle −40 sur la cohorte → 60, **affiché tel quel au `day_ended` malgré le départ des agents le soir** — pas « — »), AC2 (GATE : après le wrap, `is_awaiting_day_review()==true` et `day_count` figé même après attente ; `confirm()` referme + relance le jour suivant : `day_count+1`, agents respawnés, HUD à « Jour N+1 »).
- **Régression du découplage (Décision n°1)** : `--time-smoke` **mis à jour** → `TIME_SMOKE ... day_ended=1 gated=true advanced=true day_count=2`, `TIME_SMOKE_RESULT=PASS` (le jour ne s'enchaîne plus seul : un seul wrap + gel, puis `start_next_day()` avance le compteur).
- **Régression de l'échéance différée (Décision n°3)** : `--resolution-smoke` **adapté** pour enchaîner les jours via `start_next_day()` (le résolveur compte l'échéance en `day_count`, résout sur `day_started` — gelé sans validation) → `RESOLUTION_SMOKE immediate_ok=true deferred_held=true deferred_resolved=true drained=true`, PASS.
- **Faux positif `resources still in use at exit`** rencontré sur `--time`/`--resolution` (agents respawnés au dernier instant via `start_next_day()` juste avant `quit()` → nœuds non encore initialisés au shutdown headless ; identifié via `--verbose` : `state.gd`/ObjectDB). **Corrigé** par un `await _real_wait(0.5)` de respiration avant de quitter (et restauration de l'état temporel **avant** l'attente côté `--time-smoke`, sinon un 2e wrap survenait). Plus aucun `ERROR:` au shutdown.
- **Non-régression** : 8 suites unitaires PASS (`test_camera_math`/`test_agent_sim`/`test_time_control`/`test_solicitation_math`/`test_decision`/`test_decision_resolution`/`test_morale`/`test_hud`) ; **9 smokes** PASS (`--sim`/`--time`✎/`--solicitation`/`--decision`/`--resolution`✎/`--queue`/`--hud`/`--card`/`--report`★).
- Perf (NFR1) : `--measure-fps` → `FPS_MEASUREMENT=144` (≥ 60 ; `DayReport` 100 % événementiel, aucun `_process`).

### Completion Notes List

- **Bilan de fin de journée livré comme écran modal + porte de passage au jour suivant** : nouvelle `%DayReport` (`CanvasLayer`, `scripts/ui/day_report.gd`, sans `class_name`) instanciée dans `open_space.tscn` (`ext_resource id="11"`). Modal : `ColorRect` Blocker plein écran (modèle `decision_popup.tscn`), Panel centré, Labels + 1 bouton actif.
- **AC1** : sur `day_ended`, le bilan affiche « Jour N terminé », Trésorerie « € — » (placeholder Épic 3), **Moral moyen** de l'équipe (instantané `_day_avg_morale`) avec **couleur de seuil** réutilisant `HudMath.morale_severity` + les seuils HUD du `.tres`, et « Avancement mission : — » (placeholder Épic 4). **Zéro nouveau module pur, zéro nouveau champ `.tres`, zéro nouveau signal EventBus.**
- **Décision n°2 (instantané robuste)** : le bilan agrège le moral par signaux (modèle HUD) mais ne met à jour `_day_avg_morale` que sur `agent_spawned`/`agent_morale_changed` (cohorte présente), **jamais** sur `agent_departed` → la moyenne reflète la journée d'avant les départs du soir, et reste valable au `day_ended` même quand l'open space s'est vidé (vérifié : `morale_display=60` post-départs). Reset sur `day_started`.
- **AC2 / Décision n°1 (découplage du cycle de journée)** : `GameManager` au rebouclage émet `day_ended` puis **gèle** la sim (`_awaiting_day_review = true` + `SimClock.stop()`) **sans** enchaîner `day_started`. Le bouton du bilan (`confirm()`) appelle **`GameManager.start_next_day()`** → `SimClock.start()` + `day_started(N+1)` (spawn via `AgentSpawner`, HUD à jour). Garde d'input ajoutée : pause/vitesses ignorées tant que le bilan est en attente.
- **Choix `SimClock.stop()` plutôt que `get_tree().paused`** : ne pollue pas l'état de pause joueur (`is_paused`/`game_paused`/HUD) ; gèle proprement la **simulation** seule. Le bilan modal empêche de toute façon d'agir sur le monde.
- **Régressions traitées explicitement** : `--time-smoke` réécrit pour le flux gaté ; `--resolution-smoke` adapté pour enchaîner les jours via `start_next_day()` (sinon l'échéance différée — comptée en `day_count`, résolue sur `day_started` — ne tombait jamais). `decision_resolver.gd` **non modifié** (seul le smoke est adapté).
- **Bornes respectées** : aucune trésorerie/mission réelle (placeholders) ; aucune nouvelle jauge/agrégat (réutilise `HudMath`) ; aucune persistance (Épic 7) ; aucun score/fin de partie ; pas de juice (Épic 6). `Agent`/`SolicitationSystem`/`DeskQueue`/`DecisionResolver`/`DecisionPopup`/`Hud`/`AgentCard`/`SelectionController`/`EventBus`/`AgentSpawner`/`SimClock`/`SimBalance`(`.tres`) **non modifiés** (seul `GameManager` change, pour scinder `day_ended`/`day_started` + geler/relancer `SimClock`).
- **Boucle native complète (1.1→1.10) fonctionnelle de bout en bout** : 8 suites + 9 smokes PASS, 144 FPS, import 0/0. **AC3 (jugement « fun », NFR10)** = gate de **playtest manuel** (hors périmètre code) ; la boucle est désormais prête pour ce playtest avant l'intégration LLM (Épic 5).

### File List

**Nouveaux fichiers (sous `open_space/`) :**
- `scripts/ui/day_report.gd` (bilan : agrégation moral par signaux + instantané robuste, affichage à `day_ended`, `confirm` → `start_next_day`, couleur de seuil réutilisant `HudMath` ; getters de test)
- `scripts/ui/day_report.gd.uid`
- `scenes/ui/day_report.tscn` (CanvasLayer + Blocker `ColorRect` modal plein écran + Panel centré + labels `%` + bouton de validation `%ConfirmButton`)

**Fichiers modifiés :**
- `scripts/autoloads/game_manager.gd` (découplage du cycle de journée : au wrap → `day_ended` + `_awaiting_day_review` + `SimClock.stop()` ; ajout `start_next_day()` + `is_awaiting_day_review()` ; garde d'input pendant l'attente ; doc d'en-tête)
- `scenes/world/open_space.tscn` (instance `%DayReport` ajoutée, `ext_resource id="11"` ; structure 1-10 préservée)
- `scripts/main/main.gd` (MàJ `--time-smoke` pour le flux gaté ; adaptation `--resolution-smoke` pour enchaîner les jours ; ajout harnais `--report-smoke` + branche dans `_ready` ; respirations anti-faux-positif au shutdown ; 9 harnais + helpers existants préservés)

## Change Log

| Date | Version | Description |
|---|---|---|
| 2026-06-22 | 0.10.0 | Implémentation Story 1.10 : Bilan de fin de journée. Nouvel écran modal `%DayReport` (`CanvasLayer`, Blocker plein écran modèle `decision_popup.tscn`) instancié dans `open_space.tscn` (`ext_resource id="11"`), affiché sur `EventBus.day_ended` : récapitule le jour terminé, Trésorerie (« € — », Épic 3) et Avancement mission (« — », Épic 4) en placeholders, et le **Moral moyen** de l'équipe (instantané `_day_avg_morale` robuste aux départs du soir) avec couleur de seuil **réutilisant `HudMath.morale_severity` + les seuils HUD du `.tres`** (zéro nouveau module/seuil/signal). **Découplage du cycle de journée** dans `GameManager` : au rebouclage, `day_ended` + gel (`_awaiting_day_review` + `SimClock.stop()`) **sans** enchaîner `day_started` ; le bouton du bilan (`confirm()`) appelle `GameManager.start_next_day()` (→ `SimClock.start()` + `day_started(N+1)`, spawn via `AgentSpawner`, HUD à jour) ; garde d'input pendant l'attente. Tests : `--report-smoke` PASS (instantané moral, gate, validation/relance) ; `--time-smoke` mis à jour (flux gaté) et `--resolution-smoke` adapté (enchaînement des jours via `start_next_day`) — PASS ; non-régression 8 suites unitaires + 9 smokes PASS ; 144 FPS (NFR1) ; import 0/0. `decision_resolver.gd`/`agent_spawner.gd`/`sim_clock.gd`/`hud.gd`/`event_bus.gd`/`sim_balance.gd`(`.tres`) non modifiés (seul `GameManager` change). Boucle native 1.1→1.10 complète et jouable de bout en bout (AC3/NFR10 = gate de playtest manuel). Statut → review. |
