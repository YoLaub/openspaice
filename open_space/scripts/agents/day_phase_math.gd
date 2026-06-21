class_name DayPhaseMath
extends RefCounted
## Math pure du cycle de journée (phase normalisée 0.0 → 1.0 = matin → soir).
## AUCUNE dépendance scène/autoload → testable en isolation (modèle CameraMath).
## Empreinte volontairement minimale : la Story 1.3 reprend et formalise l'horloge
## pausable, les vitesses x1/x2/x3, le compteur de jours et la durée définitive.
## [Source: epics.md Story 1.2 (cycle de journée) ; Story 1.3 (horloge) ; ADR-3]

## Avance la phase d'un pas de temps et reboucle dans [0,1). duration en secondes.
static func advance(phase: float, dt: float, duration_seconds: float) -> float:
	if duration_seconds <= 0.0:
		return 0.0
	return fposmod(phase + dt / duration_seconds, 1.0)

## Vrai si l'avance a rebouclé (nouveau matin) — détecté par le retour en arrière.
static func has_wrapped(old_phase: float, new_phase: float) -> bool:
	return new_phase < old_phase

## Phase de départ personnelle d'un agent : seuil du soir + décalage d'archétype
## (certains partent plus tard). Borné < 1.0 pour rester dans la journée.
static func departure_phase(evening_threshold: float, archetype_offset: float) -> float:
	return clampf(evening_threshold + archetype_offset, 0.0, 0.999)

## Vrai si la phase courante a atteint le seuil de départ de l'agent.
static func is_evening(phase: float, departure: float) -> bool:
	return phase >= departure
