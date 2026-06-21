class_name AgentStateMachine
extends Node
## State Machine d'agent — orchestre les transitions entre nœuds AgentState enfants.
## Le mouvement (suivi du chemin de nav) tourne par frame physique via l'état courant,
## DÉCOUPLÉ des décisions du cerveau (qui, elles, tombent sur le tick SimClock ~3 Hz).
## [Source: game-architecture.md#State-Patterns ; ADR-3 (découplage)]

var _current: AgentState = null

## Bascule vers un nouvel état (no-op si déjà courant).
func change_to(next: AgentState) -> void:
	if next == _current:
		return
	if _current != null:
		_current.exit()
	_current = next
	if _current != null:
		_current.enter()

func physics_update(delta: float) -> void:
	if _current != null:
		_current.physics_update(delta)

## Nom lisible de l'état courant (debug / logs).
func current_state_name() -> StringName:
	return _current.name if _current != null else &"<none>"
