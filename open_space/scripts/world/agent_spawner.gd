extends Node
## AgentSpawner — orchestre l'arrivée du matin et le nettoyage de fin de journée.
## Écoute EventBus.day_started (émis par GameManager) et peuple l'open space via
## l'AgentFactory (data-driven). Découplé : ne connaît ni SimClock ni la phase de
## journée — il réagit aux signals. Les départs échelonnés du soir sont gérés par
## chaque agent (phase de départ personnelle issue de son archétype).
##
## Story 2.1 : ROSTER PERSISTANT. Au lieu de recréer une cohorte NEUVE (ids neufs) chaque
## matin, on maintient un roster stable {id, archetype, fatigue} : les MÊMES agents
## reviennent chaque jour en CONSERVANT leur fatigue (repos -25/nuit, +15 si heures sup').
## La fatigue est suivie en direct via agent_fatigue_changed (l'agent part le soir avant
## day_ended → on mémorise sa dernière valeur connue, modèle instantané robuste du bilan 1.10).
## Le Moral, lui, repart à sa valeur initiale chaque matin (comportement Épic 1 inchangé ;
## le report/dynamique inter-jour du moral = Stories 2.2/2.5). Recrutement = Épic 3.
## [Source: game-architecture.md#Entity-Patterns ; #Event-System ; epics.md Story 1.2/2.1 ; 1-10…md]

const AgentFactoryC := preload("res://scripts/agents/agent_factory.gd")

const _ARCHETYPES: Array[AgentArchetype] = [
	preload("res://data/agents/archetype_steady.tres"),
	preload("res://data/agents/archetype_overtimer.tres"),
]
const _BALANCE: SimBalance = preload("res://data/balance/sim_balance.tres")

@onready var _open_space: Node3D = get_parent()
@onready var _agents_container: Node3D = %Agents

var _next_id: int = 0

## Roster persistant : une entrée par poste de travail occupé (Story 2.1).
## Chaque entrée = { "id": int, "archetype": AgentArchetype, "fatigue": float }.
var _roster: Array = []
## Dernière fatigue connue de chaque agent présent (id → float), suivie en direct via
## agent_fatigue_changed → survit au queue_free du soir (report inter-jour fiable).
var _fatigue_by_id: Dictionary = {}
## Le roster n'est construit qu'une fois (au tout premier matin) ; ensuite réutilisé.
var _roster_built: bool = false

func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.agent_fatigue_changed.connect(_on_agent_fatigue_changed)

func _on_agent_fatigue_changed(agent_id: int, fatigue: int) -> void:
	# Mémorise la fatigue courante (la dernière reçue avant le départ du soir fait foi).
	_fatigue_by_id[agent_id] = float(fatigue)

func _on_day_started(day: int) -> void:
	_clear_agents()
	var posts: Array[Vector3] = _open_space.post_world_positions()
	var entrance: Vector3 = _open_space.entrance_world()
	var desk: Vector3 = _open_space.desk_world()
	var count: int = mini(_BALANCE.agent_count, posts.size())

	if not _roster_built:
		# Premier matin : construire le roster (ids stables attribués une seule fois).
		for i: int in count:
			_roster.append({
				"id": _next_id,
				"archetype": _ARCHETYPES[i % _ARCHETYPES.size()],
				"fatigue": _BALANCE.agent_initial_fatigue,
			})
			_next_id += 1
		_roster_built = true
	else:
		# Jours suivants : report inter-jour de la fatigue (repos -25/nuit, +15 si heures sup').
		for rec: Dictionary in _roster:
			var end_fatigue: float = _fatigue_by_id.get(rec["id"], rec["fatigue"])
			rec["fatigue"] = FatigueMath.overnight_recovery(
				end_fatigue, _BALANCE.fatigue_rest_per_day, _BALANCE.fatigue_overtime_bonus,
				rec["archetype"].does_overtime)

	# (Ré)instancier les MÊMES agents (mêmes ids/archétypes), fatigue reportée.
	for i: int in mini(count, _roster.size()):
		var rec: Dictionary = _roster[i]
		# Créneau de porte propre à chaque agent (étalé) : évite l'empilement à la porte.
		var door_slot: Vector3 = entrance + Vector3(0.0, 0.0, float(i) * 0.9)
		var agent: Agent = AgentFactoryC.create(
			rec["id"], rec["archetype"], posts[i], door_slot, desk, _BALANCE.evening_phase,
			_BALANCE.agent_initial_morale, rec["fatigue"])
		# position locale avant add_child (le conteneur Agents est à l'origine →
		# local == global) : l'agent est bien placé avant que son _ready ne tourne.
		agent.position = door_slot
		_agents_container.add_child(agent)
		# Reseed du suivi de fatigue pour le nouveau jour (= fatigue de départ du matin).
		_fatigue_by_id[rec["id"]] = rec["fatigue"]
	Log.info("Jour %d : %d agents (roster persistant) arrivés le matin" % [day, mini(count, _roster.size())])

func _clear_agents() -> void:
	for child: Node in _agents_container.get_children():
		child.queue_free()
