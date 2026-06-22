class_name SolicitationMath
extends RefCounted
## Transformations PURES de la cadence de sollicitation (Story 1.4). Aucune
## dépendance scène/autoload → testable en --script (modèle time_control.gd /
## day_phase_math.gd). Le RNG et le choix des agents vivent dans SolicitationSystem ;
## ici, uniquement la décision déterministe à partir d'un tirage déjà fait.
## [Source: 1-3…md#Tests (logique pure isolée) ; game-architecture.md#Configuration]

## Vrai si le tirage `roll` (∈ [0,1)) déclenche une sollicitation pour le taux donné.
## Le taux est clampé dans [0,1] (un taux hors borne ne casse pas la logique).
static func should_raise(roll: float, rate_per_tick: float) -> bool:
	return roll < clampf(rate_per_tick, 0.0, 1.0)

## Choisit le canal à partir d'un tirage `roll` (∈ [0,1)) et de la probabilité
## d'un canal présentiel (DESK). roll < desk_probability → DESK, sinon MAIL.
## desk_probability est clampée dans [0,1].
static func channel_for_roll(roll: float, desk_probability: float) -> int:
	if roll < clampf(desk_probability, 0.0, 1.0):
		return Solicitation.Channel.DESK
	return Solicitation.Channel.MAIL
