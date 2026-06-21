class_name AgentFactory
extends RefCounted
## Fabrique d'agents data-driven : lit un AgentArchetype (.tres) et configure
## l'agent instancié (id, archétype, BrainComponent + NativeBrain via la scène).
## Pas d'object pooling en v1 (effectifs modestes) — instanciation directe.
## [Source: game-architecture.md#Entity-Patterns ; epics.md Story 1.2 AC#1]

const _AGENT_SCENE: PackedScene = preload("res://scenes/agents/agent.tscn")

## Crée un agent prêt à être ajouté à l'arbre. setup() est appelé AVANT add_child
## (l'appelant ajoute ensuite l'agent au conteneur Agents de l'open space).
static func create(
		id: int,
		archetype: AgentArchetype,
		post_position: Vector3,
		exit_position: Vector3,
		evening_phase: float) -> Agent:
	var agent: Agent = _AGENT_SCENE.instantiate()
	agent.setup(id, archetype, post_position, exit_position, evening_phase)
	return agent
