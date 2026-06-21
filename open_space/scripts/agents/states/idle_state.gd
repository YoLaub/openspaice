class_name AgentIdleState
extends AgentState
## État inactif : l'agent ne bouge pas (en attente d'une décision du cerveau).
## [Source: game-architecture.md#State-Patterns ; epics.md Story 1.2 AC#2]

func enter() -> void:
	if agent != null:
		agent.halt()
