class_name SimBalance
extends Resource
## Valeurs d'équilibrage de la simulation (data-driven, tunables sans toucher au code).
## Story 1.2 : durée de journée, seuil du soir, nombre d'agents. Zéro magic number
## dans la logique. Story 1.3 : durée de journée portée à la cible ~5 min (les
## vitesses x1/x2/x3 sont gérées par GameManager via Engine.time_scale, pas ici) ;
## l'équilibrage fin global est l'Épic 7.
## [Source: game-architecture.md#Configuration (couche .tres) ; #Consistency-Rules]

## Durée d'une journée (matin→soir) en secondes réelles, à x1 (cible ~5 min).
@export var day_duration_seconds: float = 300.0
## Phase de base à partir de laquelle commence le soir (les départs s'échelonnent autour).
@export var evening_phase: float = 0.6
## Nombre d'agents instanciés chaque matin (modeste pour le petit local 12×12).
@export var agent_count: int = 5

## Story 1.4 — cadence des sollicitations (pilier #1 : l'attention est rare).
## Probabilité qu'un agent ÉLIGIBLE (à son poste, pas le soir, sans sollicitation
## en cours) lève une sollicitation PAR TICK SimClock (~3 Hz). 0.01 ≈ ~1 sollicitation
## toutes ~33 s par agent — volontairement rare avant la file d'attente (Story 1.7).
@export var solicitation_rate_per_tick: float = 0.01
## Répartition des canaux : probabilité qu'une sollicitation soit présentielle (DESK,
## décision importante) plutôt qu'un mail (MAIL). ~0.4 → 40 % bureau / 60 % mail (GDD).
@export var desk_channel_probability: float = 0.4

## Story 1.6 — résolution immédiate vs différée (FR6, pilier "décider sans filet").
## Probabilité qu'une décision tranchée se résolve IMMÉDIATEMENT (sinon différée).
## 0.6 → ~60 % immédiat / ~40 % différé (GDD). Tunable sans toucher au code.
@export var decision_immediate_probability: float = 0.6
## Fenêtre (en JOURS de jeu) avant résolution d'une décision différée — bornes incluses.
## GDD : "résultat différé (1-2 jours)". L'aléa de la fenêtre sert l'anti save-scum (NFR9).
@export var decision_deferred_min_days: int = 1
@export var decision_deferred_max_days: int = 2

## Story 1.7 — file d'attente, patience & jauge Moral (FR7/FR12, pilier "attention rare").
## Moral de départ de chaque agent à l'instanciation (0-100).
@export var agent_initial_morale: float = 100.0
## Patience (en SECONDES DE JEU à x1, gelée en pause, accélérée à x2/x3 via SimClock)
## avant qu'une attente en file ne commence à entamer le moral. GDD : ~45 s.
@export var queue_patience_seconds: float = 45.0
## Décroissance du moral appliquée à chaque palier d'intervalle dépassant la patience.
@export var morale_decay_per_interval: float = 1.0
## Durée (s de jeu) d'un palier de décroissance : "-1 tous les 5 s" → 5.0.
@export var morale_decay_interval_seconds: float = 5.0
