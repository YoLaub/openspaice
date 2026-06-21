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
