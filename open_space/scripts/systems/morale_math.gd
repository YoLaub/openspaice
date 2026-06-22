class_name MoraleMath
extends RefCounted
## Logique PURE de la jauge Moral (Story 1.7) — transformations sans état ni
## dépendance scène/autoload → testables en isolation (`--script`), modèle
## DecisionResolutionMath / SolicitationMath. La VALEUR du moral vit sur l'Agent
## (get_morale/adjust_morale) ; l'ACCUMULATION et l'émission vivent dans DeskQueue.
## [Source: game-architecture.md#Data-Patterns ; epics.md Story 1.7 (FR12)]

const MIN_MORALE: float = 0.0
const MAX_MORALE: float = 100.0

## Borne une valeur de moral dans [0, 100].
static func clamp_morale(value: float) -> float:
	return clampf(value, MIN_MORALE, MAX_MORALE)

## Vrai si l'attente a STRICTEMENT dépassé la patience (à l'égalité, pas encore).
static func patience_exceeded(wait_seconds: float, patience_seconds: float) -> bool:
	return wait_seconds > patience_seconds

## Nombre de paliers entiers de `interval` contenus dans l'accumulateur (pour
## appliquer la décroissance « -1 tous les N s », robuste à plusieurs paliers
## franchis en un seul tick à haute vitesse). Défensif : interval <= 0 → 0.
static func decay_steps(accumulator: float, interval: float) -> int:
	if interval <= 0.0:
		return 0
	return int(floor(accumulator / interval))
