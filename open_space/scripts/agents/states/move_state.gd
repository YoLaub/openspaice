class_name AgentMoveState
extends AgentState
## État déplacement : suit le chemin calculé par NavigationAgent3D vers la cible
## courante de l'agent (poste ou sortie), par frame physique → fluide à 60 FPS.
## [Source: game-architecture.md (pathfinding) ; ADR-3 ; epics.md Story 1.2 AC#2]

func physics_update(delta: float) -> void:
	if agent != null:
		agent.follow_path(delta)
