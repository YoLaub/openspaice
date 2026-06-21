class_name CameraMath
extends RefCounted
## Fonctions pures de caméra (clamp du zoom / du pan). AUCUNE dépendance de
## scène ni d'autoload → testables en isolation totale (headless ou GUT).
## [Source: story 1.1 — Dev Notes → Tests]

## Applique un delta de zoom puis borne entre min/max (AC #2 : zoom borné).
static func clamp_zoom(size: float, delta_size: float, min_zoom: float, max_zoom: float) -> float:
	return clampf(size + delta_size, min_zoom, max_zoom)

## Borne une position de pan dans la zone autorisée du plateau (AC #2 : pan borné).
static func clamp_pan(pos: Vector3, min_bound: Vector3, max_bound: Vector3) -> Vector3:
	return Vector3(
		clampf(pos.x, min_bound.x, max_bound.x),
		clampf(pos.y, min_bound.y, max_bound.y),
		clampf(pos.z, min_bound.z, max_bound.z)
	)
