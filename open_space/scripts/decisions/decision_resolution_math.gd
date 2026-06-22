class_name DecisionResolutionMath
extends RefCounted
## Transformations PURES de la résolution des décisions (Story 1.6). Aucune dépendance
## scène/autoload → testable en --script (modèle decision_math.gd / day_phase_math.gd).
## Le RNG concret et l'ordonnancement par jours vivent dans DecisionResolver ; ici,
## uniquement des décisions déterministes à partir de tirages/jours déjà connus.
## [Source: epics.md Story 1.6 AC1/AC2 ; gdd.md (~60 % immédiat / ~40 % différé 1-2 j) ; FR6]

## Classe un choix comme IMMÉDIAT (true) ou DIFFÉRÉ (false) à partir d'un tirage
## `roll` ∈ [0,1) et de la probabilité d'immédiateté (ex. 0.6 → ~60 % immédiat).
## Borne EXCLUSIVE : roll == immediate_prob → différé (donc prob 0.0 = jamais immédiat).
static func is_immediate(roll: float, immediate_prob: float) -> bool:
	return roll < immediate_prob

## Nombre de jours de jeu avant résolution d'un différé, borné dans [min_days, max_days]
## (ex. 1 ou 2). Réutilise le tirage borné de DecisionMath.pick_index. Défensif : si
## max_days < min_days, renvoie min_days.
static func delay_days(roll: float, min_days: int, max_days: int) -> int:
	if max_days < min_days:
		return min_days
	return min_days + DecisionMath.pick_index(roll, max_days - min_days + 1)

## Vrai quand l'échéance est atteinte (le jour courant a rejoint/dépassé le jour dû).
## Verrouille la sémantique "résout à l'échéance, jamais avant" (AC2/AC3, anti save-scum).
static func is_due(due_day: int, current_day: int) -> bool:
	return current_day >= due_day
