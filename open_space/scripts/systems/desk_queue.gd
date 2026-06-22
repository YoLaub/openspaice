extends Node
## DeskQueue — file d'attente physique au bureau du joueur + patience → moral (Story 1.7).
## S'ABONNE aux signaux de SolicitationSystem (1.4) sans le modifier :
##   - solicitation_raised (canal DESK) → l'agent rejoint la file, on lui assigne un créneau.
##   - solicitation_opened (canal DESK) → l'agent traité quitte la file, les suivants avancent.
##   - agent_departed                   → nettoyage (un départ ne laisse pas de trou).
## Sur chaque simulation_tick (~3 Hz, gelé en pause), chaque agent en file voit son attente
## croître ; au-delà de sa patience, son moral chute (-1 / 5 s de jeu, via MoraleMath).
## Pilier #1 : l'attention du joueur est une ressource rare.
## Conventions : EventBus-only, pas de chemin absolu, équilibrage .tres, pas de class_name
## (cohérent SolicitationSystem / DecisionResolver). Événementiel + tick : aucun _process (NFR1).
## [Source: epics.md Story 1.7 ; game-architecture.md#System-Location-Mapping ; #ADR-3 ; #Event-System]

const _BALANCE: SimBalance = preload("res://data/balance/sim_balance.tres")

@onready var _agents_container: Node3D = %Agents
## Le parent porte open_space.gd → desk_queue_slot_world() (mirroir d'AgentSpawner).
@onready var _open_space: Node3D = get_parent()

## File ordonnée (FIFO d'arrivée) des agent_id présentiels au bureau.
var _queue: Array[int] = []
## Attente cumulée (s de jeu) par agent en file.
var _wait: Dictionary = {}
## Accumulateur de décroissance (s de jeu au-delà de la patience) par agent en file.
var _decay_acc: Dictionary = {}

## Override de test (< 0 = utiliser la valeur d'équilibrage .tres). Permet au harnais
## --queue-smoke de forcer une patience nulle (décroissance immédiate). Inutilisé en jeu.
var patience_override: float = -1.0

func _ready() -> void:
	EventBus.solicitation_raised.connect(_on_solicitation_raised)
	EventBus.solicitation_opened.connect(_on_solicitation_opened)
	EventBus.agent_departed.connect(_on_agent_departed)
	SimClock.simulation_tick.connect(_on_simulation_tick)

func _on_solicitation_raised(agent_id: int, channel: int) -> void:
	if channel != Solicitation.Channel.DESK:
		return
	if _queue.has(agent_id):
		return
	_queue.append(agent_id)
	_wait[agent_id] = 0.0
	_decay_acc[agent_id] = 0.0
	_assign_slot(agent_id, _queue.size() - 1)
	Log.info("File bureau : agent %d rejoint (position %d)" % [agent_id, _queue.size() - 1])

func _on_solicitation_opened(agent_id: int, channel: int) -> void:
	if channel != Solicitation.Channel.DESK:
		return
	if not _queue.has(agent_id):
		return
	_remove(agent_id)
	_reflow()  # les agents restants avancent d'un créneau ; leur attente CONTINUE de courir.
	Log.info("File bureau : agent %d traité, %d en attente" % [agent_id, _queue.size()])

func _on_agent_departed(agent_id: int) -> void:
	if not _queue.has(agent_id):
		return
	_remove(agent_id)
	_reflow()

## Patience/moral : sur chaque tick de simulation (gelé en pause, accéléré à x2/x3).
func _on_simulation_tick(tick_delta: float) -> void:
	if _queue.is_empty():
		return
	var patience: float = patience_override if patience_override >= 0.0 else _BALANCE.queue_patience_seconds
	var interval: float = _BALANCE.morale_decay_interval_seconds
	for agent_id: int in _queue:
		_wait[agent_id] = float(_wait[agent_id]) + tick_delta
		if not MoraleMath.patience_exceeded(float(_wait[agent_id]), patience):
			continue
		_decay_acc[agent_id] = float(_decay_acc[agent_id]) + tick_delta
		var steps: int = MoraleMath.decay_steps(float(_decay_acc[agent_id]), interval)
		if steps <= 0:
			continue
		var agent: Agent = _find_agent(agent_id)
		if agent != null:
			agent.adjust_morale(-float(steps) * _BALANCE.morale_decay_per_interval)
		_decay_acc[agent_id] = float(_decay_acc[agent_id]) - float(steps) * interval

# --- Getters (clic réel ET test) ---
func queue_size() -> int:
	return _queue.size()

func front_agent_id() -> int:
	return _queue[0] if not _queue.is_empty() else -1

func is_queued(agent_id: int) -> bool:
	return _queue.has(agent_id)

# --- Interne ---
func _remove(agent_id: int) -> void:
	_queue.erase(agent_id)
	_wait.erase(agent_id)
	_decay_acc.erase(agent_id)

## Réassigne les créneaux à tous les agents restants (lecture seule de _queue : sûr).
func _reflow() -> void:
	for i: int in _queue.size():
		_assign_slot(_queue[i], i)

func _assign_slot(agent_id: int, index: int) -> void:
	var agent: Agent = _find_agent(agent_id)
	if agent != null:
		agent.assign_queue_slot(_open_space.desk_queue_slot_world(index))

func _find_agent(agent_id: int) -> Agent:
	for node: Node in _agents_container.get_children():
		if node is Agent and (node as Agent).agent_id == agent_id:
			return node
	return null
