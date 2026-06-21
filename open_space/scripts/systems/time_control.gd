class_name TimeControl
extends RefCounted
## Math pure du contrôle du temps (mapping niveau de vitesse → échelle de temps).
## AUCUNE dépendance scène/autoload → testable en isolation (modèle CameraMath /
## DayPhaseMath). L'application effective (get_tree().paused, Engine.time_scale)
## vit dans le contrôleur (GameManager), qui appelle ces fonctions pures.
## [Source: epics.md Story 1.3 ; game-architecture.md#Configuration ; 1-2…md#Découplage-temporel]

## Bornes des niveaux de vitesse de simulation (x1 / x2 / x3).
const MIN_SPEED_LEVEL: int = 1
const MAX_SPEED_LEVEL: int = 3

## Borne un niveau de vitesse demandé dans [MIN_SPEED_LEVEL, MAX_SPEED_LEVEL].
static func clamp_speed_level(level: int) -> int:
	return clampi(level, MIN_SPEED_LEVEL, MAX_SPEED_LEVEL)

## Convertit un niveau de vitesse en facteur Engine.time_scale (1→1.0, 2→2.0, 3→3.0).
## Le niveau est borné avant conversion → toujours un facteur valide (≥ 1.0).
static func scale_for_speed(level: int) -> float:
	return float(clamp_speed_level(level))
