class_name DecisionMath
extends RefCounted
## Transformations PURES autour des décisions (Story 1.5). Aucune dépendance scène/
## autoload → testable en --script (modèle solicitation_math.gd / day_phase_math.gd).
## Le RNG et la sélection concrète d'un template vivent dans DecisionCatalog/le
## contrôleur ; ici, uniquement des décisions déterministes à partir de tirages déjà faits.
## [Source: epics.md Story 1.5 AC#1 ; 1-4…md#Tests (logique pure isolée)]

## Borne d'options valides pour une pop-up : toujours entre 2 et 3 inclus (AC#1).
const MIN_OPTIONS: int = 2
const MAX_OPTIONS: int = 3

## Vrai si le nombre d'options est dans [MIN_OPTIONS, MAX_OPTIONS] (jamais 0/1/4+).
static func is_valid_option_count(n: int) -> bool:
	return n >= MIN_OPTIONS and n <= MAX_OPTIONS

## Choisit un index dans [0, count-1] à partir d'un tirage `roll` (∈ [0,1)).
## Borné défensivement : un roll == 1.0 ou un count <= 0 ne sort jamais des bornes
## (count <= 0 → 0, l'appelant doit vérifier la non-vacuité avant d'indexer).
static func pick_index(roll: float, count: int) -> int:
	if count <= 0:
		return 0
	return clampi(int(floor(roll * float(count))), 0, count - 1)
