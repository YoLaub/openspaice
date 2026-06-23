class_name FatigueMath
extends RefCounted
## Logique PURE de la jauge Fatigue (Story 2.1) — transformations sans état ni
## dépendance scène/autoload → testables en isolation (`--script`), modèle MoraleMath.
## La VALEUR de la fatigue vit sur l'Agent (get_fatigue/adjust_fatigue) ; l'ACCUMULATION
## (au travail, sur SimClock) vit dans Agent et le REPORT inter-jour dans AgentSpawner.
## [Source: game-architecture.md#Data-Patterns ; #Consistency-Rules (MAX_FATIGUE) ; epics.md Story 2.1 (FR13)]

const MIN_FATIGUE: float = 0.0
const MAX_FATIGUE: float = 100.0

## Borne une valeur de fatigue dans [0, 100].
static func clamp_fatigue(value: float) -> float:
	return clampf(value, MIN_FATIGUE, MAX_FATIGUE)

## Fatigue gagnée en UN tick de travail : proportionnelle à la fraction de journée
## écoulée ce tick (rate_per_day × tick_delta / day_duration) → cohérente x1/x2/x3 (le
## tick_delta est scalé par Engine.time_scale) et gelée en pause (plus de tick émis).
## Sur une journée complète de travail, la somme ≈ rate_per_day. Défensif : durée <= 0 → 0.
## [Source: day_phase_math.gd#advance ; NFR2]
static func accrual_per_tick(rate_per_day: float, tick_delta: float, day_duration_seconds: float) -> float:
	if day_duration_seconds <= 0.0:
		return 0.0
	return rate_per_day * (tick_delta / day_duration_seconds)

## Fatigue du lendemain matin à partir de la fatigue de fin de journée : on applique
## le bonus d'heures sup' (si l'agent en fait) PUIS le repos de la nuit, le tout borné.
## (« heures sup' +15/j », « repos -25/j » — FR13.)
static func overnight_recovery(end_fatigue: float, rest_per_day: float, overtime_bonus: float, did_overtime: bool) -> float:
	var bonus: float = overtime_bonus if did_overtime else 0.0
	return clamp_fatigue(end_fatigue + bonus - rest_per_day)
