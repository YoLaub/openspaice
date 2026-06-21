class_name AgentWorkState
extends AgentState
## État travail : l'agent est à son poste, immobile. Le rendu/anim "travail" réel
## (et la productivité) viennent plus tard (Épic 6 / systèmes de jauges).
## [Source: game-architecture.md#State-Patterns ; epics.md Story 1.2 AC#2]

func enter() -> void:
	if agent != null:
		agent.halt()
