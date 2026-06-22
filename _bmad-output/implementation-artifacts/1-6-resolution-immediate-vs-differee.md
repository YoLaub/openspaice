---
baseline_commit: NO_VCS
---

# Story 1.6: Résolution immédiate vs différée

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a joueur,
I want que certaines décisions aient un effet immédiat et d'autres différé,
so that je décide sans filet (pilier #2 « décider sans filet »).

## Acceptance Criteria

1. **Given** je tranche une décision (la pop-up de la Story 1.5 émet `EventBus.decision_chosen(decision_id, option_index)` au clic d'une option) **When** la résolution la classe comme **immédiate** (~60 %, tunable) **Then** son **effet se résout tout de suite** : `EventBus.decision_resolved(decision_id, outcome)` est émis **dans le même tour** que le choix, où `outcome` est l'effet porté par l'**option choisie** (data-driven `.tres`). [Source: epics.md#Story-1.6 AC1 ; gdd.md §Boucle-cœur (étape 4 : ~60 % immédiat) ; FR6]
2. **Given** je tranche une décision classée **différée** (~40 %, tunable) **When** **1 à 2 jours de jeu** s'écoulent (échéance ordonnancée sur le cycle de journée de `SimClock`/`GameManager`) **Then** son effet **se résout à l'échéance** : `EventBus.decision_resolved(decision_id, outcome)` est émis **au début du jour d'échéance**, et **pas avant**. [Source: epics.md#Story-1.6 AC2 ; gdd.md ligne 76 (« ~40 % à résultat différé (1-2 jours) ») ; game-architecture.md#ADR-3 (résultats différés ordonnancés sur SimClock)]
3. **Given** une décision différée est **en attente** **When** je consulte l'état du jeu (logs, événements, tout signal observable) **Then** **rien ne révèle prématurément son issue** : aucun `decision_resolved` émis avant l'échéance, **aucun log de l'`outcome`** d'une décision différée tant qu'elle n'est pas résolue (anti save-scum, **NFR9**). [Source: epics.md#Story-1.6 AC3 ; gdd.md ligne 167/208 (anti-« save-scum » : résultats différés + RNG) ; NFR9]

> **Frontière de cette story (lire absolument — périmètre volontairement borné) :**
> - **1.6 FAIT** : ajouter l'**effet** (`outcome`) aux options de décision (`.tres`, data-driven) ; **classer chaque choix** immédiat (~60 %) vs différé (~40 %) par **RNG seedé** ; **résoudre** les immédiats tout de suite ; **ordonnancer** les différés à **+1-2 jours de jeu** et les résoudre **à l'échéance** ; **émettre le signal fondateur `decision_resolved(decision_id, outcome)`** (jusqu'ici jamais émis) ; garantir l'**anti save-scum** (aucune fuite anticipée de l'issue, NFR9). Les valeurs (% immédiat, fenêtre de jours) vivent en `.tres` (`data/balance/`).
> - **1.6 NE FAIT PAS** (ne pas déborder) :
>   - **Appliquer des deltas de jauges concrètes** (Moral, Trésorerie, Fatigue…). **Ces jauges n'existent pas encore** : Moral = **Story 1.7** (FR12), Trésorerie = **Épic 3** (FR10), Fatigue = **Épic 2** (FR13). Ici l'`outcome` est un **code d'effet abstrait** transporté par `decision_resolved` ; les systèmes de jauges futurs s'y abonneront pour appliquer l'effet réel. **Ne PAS** créer de système de jauge dans cette story (ce serait empiéter sur 1.7/Épic 2/Épic 3).
>   - **Afficher la résolution dans un HUD / une notification joueur** → **Story 1.8** (HUD) + Épic 6 (feedback). Ici : émission de signal + logs dev uniquement.
>   - **La file d'attente, la patience, le « l'agent attend au bureau »** → **Story 1.7**. Le timing 1.4/1.5 (l'agent repart dès l'ouverture) est **conservé tel quel** — ne PAS le toucher.
>   - **Le RNG des « dérapages » LLM** (l'autre pilier anti save-scum) → **Épic 5**. Ici, seul le RNG immédiat/différé est posé.
>   - **La persistance des décisions différées en attente** (sauvegarde/chargement) → **Épic 7** (FR41). Voir Dev Notes « Anti save-scum & sauvegarde future » pour la note de conception à respecter, sans l'implémenter.
>   - **L'art / SFX / juice** de la résolution → **Épic 6**.

## Tasks / Subtasks

- [x] **Task 1 — Logique PURE de résolution : `DecisionResolutionMath` (testable `--script`)** (AC: #1, #2)
  - [x] Créer `scripts/decisions/decision_resolution_math.gd` (`class_name DecisionResolutionMath extends RefCounted`) — transformations **pures**, **zéro** dépendance scène/autoload (modèle `decision_math.gd` / `solicitation_math.gd` / `day_phase_math.gd`, tous testés en `--script`).
  - [x] `static func is_immediate(roll: float, immediate_prob: float) -> bool` → `roll < immediate_prob` (avec `roll ∈ [0,1)`). Convention : `immediate_prob = 0.6` → ~60 % immédiat, ~40 % différé (AC#1/#2).
  - [x] `static func delay_days(roll: float, min_days: int, max_days: int) -> int` → renvoie un nombre de jours **borné dans `[min_days, max_days]`** (pour `min=1, max=2` → 1 ou 2). Implémenter via le même schéma borné que `DecisionMath.pick_index` : `min_days + DecisionMath.pick_index(roll, max_days - min_days + 1)`. **Défensif** : si `max_days < min_days`, renvoyer `min_days`.
  - [x] `static func is_due(due_day: int, current_day: int) -> bool` → `current_day >= due_day` (l'échéance est atteinte). Pur, trivial, mais testé pour verrouiller la sémantique « résout à l'échéance, pas avant » (AC#2/#3).
  - [x] **Ne PAS** mettre de RNG, de `Time`, d'`EventBus` ni de jauge ici. Le RNG concret et l'ordonnancement vivent dans `DecisionResolver` (Task 5).

- [x] **Task 2 — Effet data-driven : champ `outcome` sur `DecisionOption` + valeurs d'équilibrage** (AC: #1, #2)
  - [x] **UPDATE** `scripts/decisions/decision_option.gd` : ajouter `@export var outcome: int = 0`. **Tout typer** (`untyped_declaration=1` → sinon warning import). Commenter que `outcome` est le **code d'effet abstrait** émis dans `decision_resolved` ; les **deltas de jauges concrètes** (Moral 1.7, Trésorerie Épic 3) seront mappés par les systèmes futurs — **laissé extensible, non anticipé ici** (même esprit que la 1.5 qui avait laissé `DecisionOption` extensible pour la 1.6). **Préserver** le champ `label` existant.
  - [x] **UPDATE** `data/decisions/decision_catalog.tres` : ajouter une ligne `outcome = N` à **chaque** sous-ressource d'option. Codes distincts non nuls : `Rassurer=1`, `Baisser le prix -500 €=2`, `Ignorer=3`, `Accorder=4`, `Refuser(augmentation)=5`, `Accepter(congé)=6`, `Décaler=7`, `Refuser(congé)=8`, `Répondre=9`, `Déléguer=10`. Hand-edit de scalaires `int` (sûr) ; tableaux `desk_decisions`/`mail_decisions` non touchés. Import 0/0 confirmé.
  - [x] **UPDATE** `scripts/systems/sim_balance.gd` : ajouter `decision_immediate_probability: float = 0.6`, `decision_deferred_min_days: int = 1`, `decision_deferred_max_days: int = 2`. `data/balance/sim_balance.tres` non modifié (prend les défauts). Champs existants préservés.

- [x] **Task 3 — `DecisionPopup` : transmettre l'effet de l'option choisie au résolveur** (AC: #1)
  - [x] **UPDATE** `scripts/decisions/decision_popup.gd`. Ajout de `var _current_decision: Decision = null`, affecté dans `_present()` et remis à `null` dans `_close()`.
  - [x] Dans `choose_option(index)` : après `decision_chosen`, lecture de l'`outcome` de l'option choisie + émission de `EventBus.decision_committed(_current_decision_id, outcome)`. **Garde défensive** : `_current_decision != null` et `0 <= index < options.size()` sinon log WARN sans émettre (NFR11).
  - [x] **Aucun** tirage/effet/`decision_resolved` dans la pop-up : UI pure (frontière 1.5). FIFO, `PROCESS_MODE_ALWAYS`, « ne jamais mettre en pause », fond bloquant **préservés**.

- [x] **Task 4 — `EventBus` : signal `decision_committed` ; `decision_resolved` enfin émis** (AC: #1, #2, #3)
  - [x] **UPDATE** `scripts/autoloads/event_bus.gd` : ajout de `signal decision_committed(decision_id: int, outcome: int)` (commenté : émis par la pop-up, consommé par `DecisionResolver`, distinct de `decision_chosen`).
  - [x] **12 signaux existants préservés** ; signature de `decision_chosen` inchangée.
  - [x] Le signal fondateur `decision_resolved(decision_id, outcome)` (jamais émis jusqu'ici) est **désormais émis** par `DecisionResolver` ; signature inchangée.

- [x] **Task 5 — `DecisionResolver` : tirage immédiat/différé, ordonnancement par jours, émission `decision_resolved`** (AC: #1, #2, #3)
  - [x] Créer `scripts/decisions/decision_resolver.gd` (`extends Node`, sans `class_name` — cohérent `solicitation_system.gd`). Doc d'en-tête + sources.
  - [x] `const _BALANCE` (preload `.tres`) + `var _rng := RandomNumberGenerator.new()`.
  - [x] Override de test `var immediate_prob_override: float = -1.0` (modèle `rate_override`).
  - [x] `_ready()` : `_rng.randomize()` + abonnements `decision_committed`/`day_started`. **Pas de `_process`** (événementiel, zéro coût/frame, NFR1) ; pas de `PROCESS_MODE_ALWAYS` (callbacks de signal exécutés même en pause).
  - [x] `_pending: Array` d'entrées `{ decision_id, outcome, due_day }`.
  - [x] `_on_decision_committed` : `prob` (override ou `.tres`) → `is_immediate` ? émet `decision_resolved` tout de suite (+ log avec outcome) : sinon `due = GameManager.day_count + delay_days(1-2)`, empile, log **sans** outcome (anti save-scum).
  - [x] `_on_day_started` : reconstruit `_pending` (itération sûre), émet `decision_resolved` pour chaque entrée échue (`is_due`) puis la retire (log avec outcome — issue révélée).
  - [x] `due = day_count + delay` (delay ≥ 1) ⇒ échéance toujours future, jamais le jour même (AC#2). Getter `pending_count()` (ne révèle pas l'issue).

- [x] **Task 6 — Instancier `%DecisionResolver` dans l'open space** (AC: #2, #3)
  - [x] **UPDATE** `scenes/world/open_space.tscn` : nœud `DecisionResolver` (type `Node`, script id `7`) + `unique_name_in_owner = true`. Structure existante (dont `%DecisionPopup`, `CameraRig.process_mode=3`) **préservée**.
  - [x] Import **0 erreur / 0 warning** confirmé ; `%DecisionResolver` présent et abonné (logs `_ready`).

- [x] **Task 7 — Tests (unitaires purs + intégration `--resolution-smoke` + non-régression)** (AC: #1, #2, #3)
  - [x] Runner headless autonome (pas de GUT), logique **pure** uniquement en `--script`.
  - [x] Créer `tests/unit/test_decision_resolution.gd` : `is_immediate` (bornes + prob 0/1), `delay_days` (1-2, rafale dans bornes, dégénéré `max<min`), `is_due`, + invariant « chaque option du catalogue livré porte un `outcome` int, au moins un non nul ». **18/18 PASS**.
  - [x] **Intégration** `--resolution-smoke` dans `scripts/main/main.gd` (compteurs MEMBRES) : (a) immédiat (override 1.0 → résolu dans le même tour, `outcome` fidèle à `decision_committed`) ; (b) différé (override 0.0 → rien d'émis tout de suite + 1 en attente = anti save-scum ; après journée accélérée franchissant l'échéance → `decision_resolved` émis avec le bon `outcome`, file vidée). **PASS** (`immediate_ok=true deferred_held=true deferred_resolved=true drained=true`). 5 harnais existants + `_real_wait` préservés.
  - [x] **Non-régression** : 6/6 suites unitaires PASS ; `--sim-smoke`/`--time-smoke`/`--solicitation-smoke`/`--decision-smoke`/`--measure-fps` PASS.

- [x] **Task 8 — Non-régression, anti save-scum, perf & état par défaut** (AC: tous ; NFR1, NFR9)
  - [x] **AC#3 / NFR9** : différé en attente → aucun `decision_resolved` anticipé (`deferred_held=true`) et **aucun log de l'`outcome`** d'un différé (revue de `_on_decision_committed` : seul « différée → échéance jour N » est loggé). Confirmé code + smoke.
  - [x] **Frontières respectées** : aucune jauge concrète créée/modifiée ; `solicitation_system.gd`/`agent.gd`/`selection_controller.gd`/`game_manager.gd`/`sim_clock.gd` **non modifiés** ; pas de HUD/art/persistance.
  - [x] Import headless **0 erreur / 0 warning** ; **`FPS_MEASUREMENT=145`** (≥ 60, NFR1) — résolveur événementiel, zéro coût/frame.
  - [x] Système **fonctionnel de bout en bout** : caméra (1.1), agents (1.2), temps (1.3), sollicitations (1.4), pop-up (1.5) opérationnels ; la boucle cœur s'enchaîne désormais jusqu'à la **résolution**.

## Dev Notes

### Contexte & objectif

Cette story **ferme la boucle de décision** posée par les Stories 1.4 (sollicitation) → 1.5 (pop-up + choix). Après que le joueur a **choisi** une option (`decision_chosen`), la 1.6 **résout** la décision : ~60 % d'effet **immédiat**, ~40 % **différé** à 1-2 jours, en émettant enfin le signal fondateur **`decision_resolved(decision_id, outcome)`** (présent depuis la 1.1, jamais émis jusqu'ici). C'est le mécanisme qui sert le **pilier #2 « décider sans filet »** et le **garde-fou anti save-scum (NFR9)**.
[Source: epics.md#Story-1.6 ; gdd.md ligne 76 (« ~60 % immédiat ; ~40 % différé 1-2 jours ») ; gdd.md §Boucle-cœur étape 4 ; FR6 ; NFR9]

### ⚠️ Le point dur de cette story : il n'y a PAS encore de jauges à modifier

À ce stade du MVP, **aucune jauge concrète n'existe** :
- **Moral** = Story **1.7** (FR12, « impact patience »),
- **Trésorerie (€)** = **Épic 3** (FR10),
- **Fatigue** = **Épic 2** (FR13).

Donc « **l'effet s'applique** » (AC#1) **ne peut pas** signifier « décrémenter le cash » ici (le cash n'existe pas). La 1.6 livre le **mécanisme de résolution** : elle **classe** (immédiat/différé), **ordonnance** (les différés), et **émet `decision_resolved(decision_id, outcome)`** où `outcome` est un **code d'effet abstrait** porté par l'option choisie (data-driven `.tres`). Les **systèmes de jauges futurs** (1.7 Moral, Épic 3 Trésorerie…) **s'abonneront** à `decision_resolved` pour traduire `outcome` en deltas réels. **Tenter d'appliquer des deltas de jauges maintenant = empiéter sur 1.7/Épic 2/Épic 3 et inventer des systèmes hors périmètre.** C'est exactement le même esprit de bornage que la 1.5 (qui n'appliquait aucun effet et laissait `DecisionOption` extensible **pour cette story**).

> `decision_resolved` n'est **pas** un « signal mort » : c'est le **signal fondateur** dont l'émission **est** le livrable de la 1.6 (l'épic l'exige). Ses consommateurs (jauges, HUD 1.8, bilan 1.10) arrivent ensuite — c'est le contrat que la 1.6 établit. [Source: event_bus.gd lignes 8-11 (fondateurs) ; epics.md#Story-1.6]

### Le flux exact : du choix à la résolution (qui fait quoi)

```
[Story 1.5]  joueur clique une option → DecisionPopup.choose_option(index)
             → émet EventBus.decision_chosen(decision_id, index)        [→ HUD/compteur, Story 1.8]
             → (1.6) émet EventBus.decision_committed(decision_id, outcome)  [outcome = option choisie]
             → ferme la pop-up + dépile la FIFO (inchangé 1.5)
[Story 1.6]  DecisionResolver._on_decision_committed(decision_id, outcome)
             → roll immédiat (~60 %) vs différé (~40 %)  [DecisionResolutionMath.is_immediate, RNG seedé]
             ├─ IMMÉDIAT : émet EventBus.decision_resolved(decision_id, outcome)   [tout de suite]
             └─ DIFFÉRÉ  : due_day = GameManager.day_count + delay(1-2) ; range dans _pending
                          → (anti save-scum) RIEN ne sort avant l'échéance
             DecisionResolver._on_day_started(day)
             → pour chaque pending échu (is_due) : émet decision_resolved(decision_id, outcome) ; retire
[Futur]      (1.7 Moral / Épic 3 Trésorerie / 1.8 HUD / 1.10 Bilan) s'abonnent à decision_resolved
```

### Décision de conception : pourquoi un NOUVEAU signal `decision_committed` (et pas réutiliser `decision_chosen`)

`decision_chosen(decision_id, option_index)` a été **figé par la 1.5** comme l'événement « le joueur a choisi l'option i », destiné au **compteur d'attention du HUD (1.8)** — qui n'a **pas besoin** de l'effet. Surtout, il porte un `option_index` (int) mais **pas** l'`outcome` ; et la pop-up **détruit** le `Decision` à la fermeture → un résolveur abonné à `decision_chosen` **ne pourrait pas** retrouver l'effet choisi.

Trois options ont été pesées :
1. **Étendre** `decision_chosen` en `(decision_id, option_index, outcome)` — casse le contrat documenté 1.5 et fait fuiter une préoccupation de **résolution** dans un signal d'**UI/attention**.
2. **Registre** `decision_id → Decision` interrogé par le résolveur — couplage direct, viole l'« EventBus-only / pas d'appel dur ».
3. ✅ **Nouveau signal dédié** `decision_committed(decision_id, outcome)` émis par la pop-up au choix — **séparation nette** : `decision_chosen` = « clic UI » (HUD), `decision_committed` = « voici l'effet à résoudre » (résolveur). Chaque consommateur reçoit **exactement** ce dont il a besoin ; la pop-up reste le seul détenteur du `Decision`.

→ **On retient l'option 3.** La pop-up mémorise `_current_decision` (mini-UPDATE) et émet `decision_committed` avec l'`outcome` de l'option choisie. [Source: decision_popup.gd (le `Decision` est local à `_present`, perdu à la fermeture) ; event_bus.gd ; game-architecture.md#Architectural-Boundaries (EventBus-only, pas d'appel dur)]

### Immédiat vs différé = RNG seedé (pas un type figé par option)

FR6 et le GDD énoncent une **répartition probabiliste** (« ~60 % immédiate, ~40 % différée »), pas un type figé par décision. On **tire** donc le classement au moment de la résolution (`DecisionResolutionMath.is_immediate(_rng.randf(), immediate_prob)`), `immediate_prob` venant de `data/balance/sim_balance.tres`. Ceci sert directement l'**anti save-scum** (l'aléa rend le rechargement peu fiable) et reste **tunable** sans toucher au code. Un éventuel « type imposé par certaines décisions » serait un raffinement futur (non requis). [Source: FR6 ; gdd.md ligne 76/167/208 ; game-architecture.md#Configuration (équilibrage `.tres`)]

### Ordonnancement des différés sur le cycle de journée

`GameManager` est le **propriétaire unique du temps** : il incrémente `day_count` et émet `EventBus.day_started(day)` / `day_ended(day)` au franchissement de la phase de journée (sur tick `SimClock`, ~3 Hz). Le résolveur **compte les jours** : `due_day = day_count + delay(1-2)`, et résout sur `day_started` quand `is_due(due_day, day)`. **Avantages** : en **pause**, `SimClock` est gelé → pas de `day_started` → les différés **attendent** naturellement (cohérent, AC#2) ; à x2/x3, ils arrivent plus vite, comme tout le reste. [Source: game_manager.gd lignes 89-108 (`_on_simulation_tick` → `day_ended`/`day_started`, `day_count`) ; sim_clock.gd ; game-architecture.md#ADR-3]

> ⚠️ **Itération sûre de `_pending`** : `decision_resolved` est émis **pendant** `_on_day_started` ; si un futur consommateur réagissait en re-déclenchant le résolveur, muter `_pending` en cours d'itération planterait. Collecter les entrées échues **puis** émettre/retirer (ou reconstruire la liste des non-échues). Défensif, peu coûteux.

### Anti save-scum (NFR9) — exigence dure de l'AC#3

« Rien ne révèle prématurément l'issue » :
- **Aucun** `decision_resolved` émis avant l'échéance.
- **Aucun log de l'`outcome`** d'un différé tant qu'il n'est pas résolu (un log « différée → échéance jour N » **sans** l'issue est autorisé).
- À ce stade il n'y a **pas** d'UI d'inspection (le HUD est 1.8) → la seule fuite possible serait un signal/log : on les évite.

**Note de conception pour la sauvegarde future (Épic 7, FR41 — NE PAS implémenter ici)** : quand la persistance arrivera, l'état `_pending` (decision_id, outcome, due_day) devra être **sérialisé tel quel** (sans le ré-tirer au chargement, sinon le save-scum redevient possible) ; l'`outcome` stocké ne doit pas être exposé à l'UI avant échéance. Le mentionner pour que l'Épic 7 en hérite ; ici on **n'écrit aucun code de save**. [Source: gdd.md ligne 167/208 ; NFR9 ; epics.md#Story-7.1 (sauvegarde état complet)]

### Stack technique imposée (NE PAS dévier)

- **Godot 4.6.3-stable**, **GDScript typé statiquement** (`untyped_declaration=1` → **tout typer**, sinon warning à l'import). [Source: game-architecture.md#Decision-Summary D10 ; project.godot ligne 27]
- **Décisions** : logique dans **`scripts/decisions/`** ; **équilibrage** dans **`data/balance/`** (`.tres`). [Source: game-architecture.md#System-Location-Mapping ; #Project-Structure]
- **Communication via `EventBus`** (signals typés, snake_case au passé) ; jamais d'appel direct en dur entre systèmes. [Source: game-architecture.md#Event-System ; #Architectural-Boundaries]
- **Jamais de chemins de nœuds absolus** — `@onready`/`%UniqueName`/signals/référence parent→enfant connue uniquement. [Source: game-architecture.md#Architectural-Boundaries]
- **Contenu/équilibrage en `.tres`** ; **zéro magic number / zéro texte codé en dur** dans la logique. [Source: game-architecture.md#Configuration ; #Consistency-Rules ; D6]
- **Une erreur n'est jamais fatale et ne met jamais le jeu en pause** (option hors bornes / `_current_decision` null → log WARN + dégradation propre). [Source: game-architecture.md#Error-Handling ; NFR11]

### ⚠️ Apprentissages critiques des Stories 1.1 → 1.5 (à respecter absolument)

- **L'autoload du logger s'appelle `Log`, PAS `Logger`** (`Logger` = classe native Godot 4.6 → collision). `Log.info/warn/error/debug`. (Les extraits d'archi montrant `Logger.info(...)` sont **illustratifs**.) [Source: 1-1…md ; 1-5…md#Apprentissages]
- **Les autoloads n'ont PAS de `class_name`** — accès par nom de singleton (`EventBus`, `SimClock`, `GameManager`, `ConfigService`, `Log`). Un **système instancié en scène** (comme `SolicitationSystem`) n'a **pas** de `class_name` non plus → faire pareil pour `DecisionResolver`. [Source: 1-2…md ; 1-5…md ; solicitation_system.gd]
- **GUT non installé** → runner headless autonome (`tests/unit/*.gd extends SceneTree`, `quit(0/1)`). [Source: 1-1…1-5…md ; `tests/unit/test_*.gd`]
- **En mode `--script`, les autoloads ne sont PAS chargés** → la logique testée unitairement doit être **pure** (sans `Log`/`EventBus`/`SimClock`/`GameManager`). D'où `DecisionResolutionMath` (pur, `--script`) vs `DecisionResolver` (autoloads/scène, testé via `--resolution-smoke`). [Source: 1-5…md#Tests]
- **Pas de VCS** (`baseline_commit=NO_VCS`) → valider par **import + exécution headless réels**, jamais « au jugé ». [Source: 1-5…md#Debug-Log-References]
- **Piège des lambdas GDScript (capture par valeur)** : dans un harnais smoke, compter via **variables membres** de `main.gd` (cf. `_decisions_chosen`, `_sol_*`), **jamais** des locaux (capturés par valeur → jamais incrémentés). [Source: 1-4…md / 1-5…md#main.gd]
- **Pattern override de test** (forcer un comportement déterministe sans toucher au `.tres` partagé) : champ membre `*_override` à `-1.0` par défaut, voir `solicitation_system.gd::rate_override`/`desk_prob_override`. → `immediate_prob_override` pour le résolveur. [Source: solicitation_system.gd lignes 27-39 ; main.gd::_run_solicitation_smoke_and_quit]
- **`.tres` — éditer prudemment** : ajouter un **scalaire** à une sous-ressource est sûr ; **réécrire un `Array[ExtResource]` à la main est risqué** → la 1.5 a régénéré via `ResourceSaver.save` (outil ponctuel supprimé après). Ici on n'ajoute que `outcome = N` (scalaire) → hand-edit OK. [Source: 1-5…md#Debug-Log-References (sérialisation `.tres`)]
- **Callbacks de signal vs pause** : `process_mode` gèle `_process`/`_input`, **pas** les callbacks de signal. La pop-up étant `PROCESS_MODE_ALWAYS`, un choix peut survenir en **pause** → `decision_committed` est émis et `DecisionResolver._on_decision_committed` s'exécute même en pause (sans `_process`, donc OK sans `ALWAYS`). [Source: game_manager.gd (pause = `get_tree().paused`) ; decision_popup.gd lignes 35-37]

### Lecture des fichiers UPDATE (état actuel à préserver)

- **`scripts/autoloads/event_bus.gd`** — **12 signaux** (4 fondateurs dont `decision_resolved(decision_id, outcome)` **jamais émis** + cycle/agents + temps + sollicitations + `decision_chosen` 1.5). **Ajouter** `decision_committed(decision_id, outcome)`. **Préserver les 12** et **ne pas** toucher la signature de `decision_chosen` ni de `decision_resolved`. [Source: lecture directe event_bus.gd]
- **`scripts/decisions/decision_popup.gd`** — contrôleur 1.5 ; `_present()` détient `decision` localement (perdu à la fermeture) ; `choose_option(index)` émet `decision_chosen` puis ferme + dépile la FIFO. **Ajouter** `_current_decision` + l'émission de `decision_committed`. **Préserver** FIFO, `PROCESS_MODE_ALWAYS`, fond bloquant, « ne jamais mettre en pause », `is_showing`/`option_button_count`. [Source: lecture directe decision_popup.gd]
- **`scripts/decisions/decision_option.gd`** — n'a que `label`. **Ajouter** `outcome: int = 0` (extensible, déjà annoncé par la 1.5). [Source: lecture directe decision_option.gd lignes 4-11]
- **`scripts/systems/sim_balance.gd`** — `day_duration_seconds`/`evening_phase`/`agent_count` + `solicitation_rate_per_tick`/`desk_channel_probability`. **Ajouter** `decision_immediate_probability`/`decision_deferred_min_days`/`decision_deferred_max_days`. **Préserver** l'existant. [Source: lecture directe sim_balance.gd]
- **`data/decisions/decision_catalog.tres`** — 4 décisions (2 DESK : « client menace de partir » 3 opts, « augmentation » 2 opts ; 2 MAIL : « jour de congé » 3 opts, « process » 2 opts), 10 options. **Ajouter** `outcome = N` à chaque sous-ressource d'option. **Ne PAS** réécrire les `Array[ExtResource]`. [Source: lecture directe decision_catalog.tres]
- **`scenes/world/open_space.tscn`** — `OpenSpace/GridMap/NavigationRegion3D/Agents(%)/AgentSpawner/SolicitationSystem(%)/SelectionController/DecisionPopup(%)/WorldEnvironment/DirectionalLight3D/CameraRig(process_mode=3)/Camera3D`. **Ajouter** `%DecisionResolver` (Node + script). **Préserver** tout, dont `CameraRig.process_mode=3` et l'instance `%DecisionPopup`. [Source: lecture directe open_space.tscn]
- **`scripts/main/main.gd`** — 5 harnais (`--measure-fps`/`--sim-smoke`/`--time-smoke`/`--solicitation-smoke`/`--decision-smoke`) + `_real_wait` + helpers `_force_desk_solicitation`/`_open_first_active`/`_min_agent_distance_to` + compteurs membres. **Ajouter** `--resolution-smoke` + compteurs membres (`_resolved_count`, `_last_resolved_outcome`). **Préserver les 5 harnais** et helpers. [Source: lecture directe main.gd]
- **NE PAS MODIFIER** : `solicitation_system.gd`, `agent.gd`, `selection_controller.gd`, `game_manager.gd`, `sim_clock.gd` (le résolveur **s'abonne** à `day_started`/`decision_committed`, il ne change pas le producteur). [Source: game-architecture.md#Architectural-Boundaries]

> **Important** : une story doit laisser le système **fonctionnel de bout en bout**. Au-delà des AC, caméra (1.1), simulation (1.2), temps (1.3), sollicitations (1.4) et pop-up (1.5) doivent rester pleinement opérationnels.

### Tester en headless (API directe, pas l'input GUI)

`DecisionPopup.choose_option(index)` reste le **point d'entrée commun** clic/test (1.5). Le smoke 1.6 force le classement via `DecisionResolver.immediate_prob_override` (1.0 = immédiat, 0.0 = différé), déclenche une sollicitation (`_force_desk_solicitation` + `_open_first_active`, helpers 1.5), appelle `choose_option(0)`, et vérifie l'émission (ou la **rétention**) de `decision_resolved` via des **compteurs membres**. Pour les différés, on accélère la journée (comme `--time-smoke`) pour franchir l'échéance. [Source: 1-5…md#Tester-en-headless ; main.gd::_run_decision_smoke_and_quit / _run_time_smoke_and_quit]

### Performance (NFR1)

`DecisionResolver` est **purement événementiel** (abonné à `decision_committed`/`day_started`) : **aucun `_process`**, donc **zéro coût par frame**. `_pending` reste minuscule (décisions rares — cadence de sollicitation ~0.01/tick/agent). 60 FPS open space peuplé inchangé. [Source: NFR1 ; sim_balance.gd ligne 21 ; 1-5…md (145 FPS)]

### Direction artistique / UI

**Aucune UI ni SFX ici.** La résolution est **silencieuse** (signal + logs dev). L'affichage de l'issue (notification, mise à jour HUD) est la **Story 1.8** ; le juice/feedback est l'**Épic 6**. [Source: epics.md#Story-1.8 ; epics.md#Épic-6]

### Project Structure Notes

- Nouveaux fichiers conformes à la structure hybride : `scripts/decisions/decision_resolution_math.gd`, `scripts/decisions/decision_resolver.gd`, `tests/unit/test_decision_resolution.gd`.
- Fichiers modifiés : `scripts/decisions/decision_option.gd`, `scripts/decisions/decision_popup.gd`, `scripts/autoloads/event_bus.gd`, `scripts/systems/sim_balance.gd`, `data/decisions/decision_catalog.tres`, `scenes/world/open_space.tscn`, `scripts/main/main.gd`.
- Aucune nouvelle dépendance, aucun addon. Pas de `class_name` sur le nœud de scène `DecisionResolver` (cohérent `SolicitationSystem`). Logique pure isolée (`DecisionResolutionMath`) pour la testabilité `--script`.

### Project Context Rules

- _Aucun `project-context.md` présent dans le dépôt._ Les règles applicables proviennent de l'architecture et des stories 1.1-1.5, résumées ci-dessus : `EventBus`-only (snake_case passé, pas d'appel dur), pas de chemins absolus, `.tres` pour contenu/équilibrage (zéro magic number / texte en dur), GDScript typé (import 0/0), autoload `Log` (pas `Logger`), pas de `class_name` sur autoloads ni systèmes de scène, logique pure isolée (`--script`) vs intégration (`--*-smoke`), erreurs non fatales (NFR11), anti save-scum (NFR9), 60 FPS (NFR1).
- **Outillage MCP** (Gopeak Godot MCP + Context7) prévu par l'archi — **non bloquant** ici. [Source: game-architecture.md#AI-Development-Tooling]

### References

- [Source: epics.md#Story-1.6] — AC : effet immédiat (~60 %) tout de suite ; différé (~40 %) résolu à +1-2 jours via `SimClock` ; rien ne révèle l'issue d'un différé en attente (NFR9).
- [Source: epics.md#Story-1.5] — `decision_chosen(decision_id, option_index)` **émis ici** au choix ; consommé par la résolution 1.6.
- [Source: epics.md#Story-1.7] — File/patience/Moral + « agent attend au bureau » : **hors périmètre** (timing 1.4/1.5 conservé). FR12 Moral = consommateur futur de `decision_resolved`.
- [Source: epics.md#Story-1.8] — HUD/feedback : affichage de la résolution **hors périmètre**.
- [Source: gdd.md ligne 76] — « ~60 % effet immédiat ; ~40 % à résultat différé (1-2 jours) — pilier décider sans filet ».
- [Source: gdd.md lignes 167, 208] — anti-« save-scum » : résultats différés + dérapage aléatoire rendent le rechargement peu fiable (NFR9).
- [Source: game-architecture.md#ADR-3] — résultats différés + RNG ordonnancés sur `SimClock` (~3 Hz, découplé du rendu).
- [Source: game-architecture.md#Decision-Summary D3/D4/D6/D10] — `SimClock` ; `GameManager`/`EventBus` ; `.tres` data-driven ; GDScript typé.
- [Source: game-architecture.md#Event-System ; #Architectural-Boundaries ; #Configuration ; #Consistency-Rules ; #Error-Handling] — EventBus typé, pas de chemins absolus, `.tres` équilibrage, erreur non fatale.
- [Source: lecture directe] — `event_bus.gd`, `decision_popup.gd`, `decision_option.gd`, `decision.gd`, `decision_catalog.gd`, `decision_math.gd`, `sim_balance.gd`, `sim_clock.gd`, `game_manager.gd`, `solicitation_system.gd`, `main.gd`, `open_space.tscn`, `decision_catalog.tres`, `sim_balance.tres`, `test_decision.gd`, `project.godot`.
- [Source: 1-5…md] — autoload `Log`, pas de `class_name`, pas de GUT (runner headless), pas de VCS, logique pure `--script` vs smoke d'intégration, point d'entrée commun clic/test, piège des lambdas (compteurs membres), pattern override de test, prudence sérialisation `.tres`.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.8 (claude-opus-4-8)

### Debug Log References

- Import headless propre (**0 erreur / 0 warning**) : `godot --headless --path open_space --import` (Godot 4.6.3-stable).
- Tests unitaires résolution : `--script res://tests/unit/test_decision_resolution.gd` → `TEST_RESULT=PASS`, **18/18** (`is_immediate` bornes + prob 0/1 ; `delay_days` 1-2 + rafale bornée + dégénéré `max<min` ; `is_due` ; invariant « chaque option du catalogue livré porte un `outcome` int, ≥ 1 non nul » en chargeant le `.tres` réel).
- Intégration résolution : `godot --headless --path open_space -- --resolution-smoke` → `RESOLUTION_SMOKE immediate_ok=true deferred_held=true deferred_resolved=true drained=true outcome=4`, `RESOLUTION_SMOKE_RESULT=PASS`. Couvre AC#1 (immédiat résolu dans le même tour, `outcome` fidèle à `decision_committed`), AC#2 (différé résolu à l'échéance après journées accélérées), AC#3 / NFR9 (`deferred_held` : rien d'émis avant l'échéance + 1 décision en attente).
- Non-régression : `test_decision` / `test_decision_resolution` / `test_solicitation_math` / `test_agent_sim` / `test_camera_math` / `test_time_control` → **6/6 PASS** ; `--sim-smoke` / `--time-smoke` / `--solicitation-smoke` / `--decision-smoke` / `--resolution-smoke` → **PASS**.
- Perf (NFR1) : `--measure-fps` → `FPS_MEASUREMENT=145`, exit 0 → bien au-delà de 60 (résolveur événementiel, aucun `_process`, zéro allocation par frame).
- Note : les 2 warnings runtime de navigation (`open_space.gd::_build_navigation`, code Story 1.2 non modifié) restent pré-existants, hors périmètre, sans impact ; l'import reste 0/0.

### Completion Notes List

- **Boucle de décision fermée** : 1.4 (sollicitation) → 1.5 (pop-up + choix) → **1.6 (résolution)**. Le signal **fondateur `decision_resolved(decision_id, outcome)`** (posé en 1.1, jamais émis) est **désormais émis** — c'est le livrable central. Les consommateurs (jauges Moral 1.7, Trésorerie Épic 3, HUD 1.8, bilan 1.10) s'y abonneront ensuite.
- **Pas de jauges à ce stade** : aucune jauge concrète n'existe encore → l'`outcome` est un **code d'effet abstrait** porté par l'option choisie (data-driven `.tres`) et transporté tel quel. **Aucun** système de jauge créé (resterait dans le périmètre de 1.7/Épic 2/Épic 3).
- **Décision de conception — nouveau signal `decision_committed(decision_id, outcome)`** : `decision_chosen` (figé en 1.5, destiné au compteur HUD) ne porte que l'`option_index` et la pop-up détruit le `Decision` à la fermeture → un résolveur ne pourrait pas retrouver l'effet. Plutôt que de casser le contrat 1.5 ou d'introduire un couplage direct, la pop-up mémorise `_current_decision` et émet `decision_committed` (l'effet à résoudre). Séparation nette : `decision_chosen` = clic UI, `decision_committed` = effet à résoudre.
- **Immédiat vs différé = RNG seedé** (`DecisionResolutionMath.is_immediate`, `immediate_prob` depuis `.tres` = 0.6 → ~60 %/~40 %), conforme à FR6 et à l'anti save-scum (NFR9). Différés ordonnancés en **jours de jeu** (`due = day_count + delay(1-2)`), résolus sur `day_started` à l'échéance.
- **Anti save-scum (NFR9)** strictement respecté : aucun `decision_resolved` anticipé, **aucun log de l'`outcome`** d'un différé avant sa résolution (seul « différée → échéance jour N » est loggé). En pause, `SimClock` gelé → pas de `day_started` → les différés attendent naturellement. Note de conception pour la sauvegarde Épic 7 documentée (sérialiser `_pending` sans re-tirer), **non implémentée**.
- **Performance** : `DecisionResolver` purement événementiel (aucun `_process`) → zéro coût par frame ; 145 FPS inchangé.
- **Frontières respectées** : `solicitation_system.gd`/`agent.gd`/`selection_controller.gd`/`game_manager.gd`/`sim_clock.gd` **non modifiés** ; timing agent 1.4/1.5 conservé ; pas de HUD (1.8), pas d'art/SFX (Épic 6), pas de persistance (Épic 7).
- **Non-régression** : caméra (1.1), simulation (1.2), temps (1.3), sollicitations (1.4), pop-up (1.5) pleinement opérationnels (6 suites unitaires + 5 smokes PASS, 145 FPS, import 0/0).

### File List

**Nouveaux fichiers (sous `open_space/`) :**
- `scripts/decisions/decision_resolution_math.gd` (`class_name DecisionResolutionMath` — `is_immediate`/`delay_days`/`is_due` purs)
- `scripts/decisions/decision_resolver.gd` (résolveur : roll immédiat/différé, ordonnancement par jours, émission `decision_resolved`, anti save-scum)
- `tests/unit/test_decision_resolution.gd` (runner headless, 18 tests)

**Fichiers modifiés :**
- `scripts/decisions/decision_option.gd` (champ `outcome: int` ajouté ; `label` préservé)
- `scripts/systems/sim_balance.gd` (`decision_immediate_probability`/`decision_deferred_min_days`/`decision_deferred_max_days` ajoutés ; existant préservé)
- `data/decisions/decision_catalog.tres` (`outcome = N` sur les 10 options ; tableaux de décisions préservés)
- `scripts/decisions/decision_popup.gd` (`_current_decision` mémorisé ; émission de `decision_committed` au choix ; FIFO/pause/UI préservés)
- `scripts/autoloads/event_bus.gd` (signal `decision_committed` ajouté ; 12 signaux existants préservés)
- `scenes/world/open_space.tscn` (instance `%DecisionResolver` ajoutée ; structure préservée)
- `scripts/main/main.gd` (harnais `--resolution-smoke` + compteurs membres `_resolved_count`/`_last_resolved_outcome`/`_committed_outcome` ; 5 harnais existants préservés)

## Change Log

| Date | Version | Description |
|---|---|---|
| 2026-06-22 | 0.6.0 | Implémentation Story 1.6 : résolution immédiate (~60 %) vs différée (~40 %, 1-2 jours). `DecisionResolutionMath` pur (`is_immediate`/`delay_days`/`is_due`, testé `--script`). Champ `outcome` data-driven sur `DecisionOption` + valeurs d'équilibrage (`decision_immediate_probability`/`decision_deferred_min/max_days`). `DecisionPopup` mémorise la décision courante et émet le nouveau signal `decision_committed(decision_id, outcome)` au choix (UI pure, aucun effet). `DecisionResolver` (nœud `%DecisionResolver`) classe par RNG seedé : immédiat → émet le signal fondateur `decision_resolved` tout de suite ; différé → ordonnance à `day_count + delay(1-2)` et résout sur `day_started` à l'échéance, **sans jamais révéler l'issue avant** (anti save-scum, NFR9). Tests : 18/18 unitaires `test_decision_resolution` + `--resolution-smoke` PASS (immédiat, différé tenu, résolu à l'échéance, file vidée) ; non-régression 6 suites unitaires + 4 smokes PASS ; 145 FPS (NFR1) ; import 0/0. `solicitation_system.gd`/`agent.gd`/`game_manager.gd`/`sim_clock.gd` non modifiés. Statut → review. |
