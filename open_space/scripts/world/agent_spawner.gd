extends Node
## AgentSpawner — orchestre l'arrivée du matin et le nettoyage de fin de journée.
## Écoute EventBus.day_started (émis par GameManager) et peuple l'open space via
## l'AgentFactory (data-driven). Découplé : ne connaît ni SimClock ni la phase de
## journée — il réagit aux signals. Les départs échelonnés du soir sont gérés par
## chaque agent (phase de départ personnelle issue de son archétype).
## [Source: game-architecture.md#Entity-Patterns ; #Event-System ; epics.md Story 1.2 AC#1/#3]

const AgentFactoryC := preload("res://scripts/agents/agent_factory.gd")

const _ARCHETYPES: Array[AgentArchetype] = [
	preload("res://data/agents/archetype_steady.tres"),
	preload("res://data/agents/archetype_overtimer.tres"),
]
const _BALANCE: SimBalance = preload("res://data/balance/sim_balance.tres")

@onready var _open_space: Node3D = get_parent()
@onready var _agents_container: Node3D = %Agents

var _next_id: int = 0

func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)

func _on_day_started(day: int) -> void:
	_clear_agents()
	var posts: Array[Vector3] = _open_space.post_world_positions()
	var entrance: Vector3 = _open_space.entrance_world()
	var desk: Vector3 = _open_space.desk_world()
	var count: int = mini(_BALANCE.agent_count, posts.size())
	for i: int in count:
		var archetype: AgentArchetype = _ARCHETYPES[i % _ARCHETYPES.size()]
		# Créneau de porte propre à chaque agent (étalé) : évite que tous visent le
		# même point d'entrée/sortie et s'empilent (collisions → blocage à la porte).
		var door_slot: Vector3 = entrance + Vector3(0.0, 0.0, float(i) * 0.9)
		var agent: Agent = AgentFactoryC.create(
			_next_id, archetype, posts[i], door_slot, desk, _BALANCE.evening_phase,
			_BALANCE.agent_initial_morale)
		_next_id += 1
		# position locale avant add_child (le conteneur Agents est à l'origine →
		# local == global) : l'agent est bien placé avant que son _ready ne tourne.
		agent.position = door_slot
		_agents_container.add_child(agent)
	Log.info("Jour %d : %d agents arrivés le matin" % [day, count])

func _clear_agents() -> void:
	for child: Node in _agents_container.get_children():
		child.queue_free()
