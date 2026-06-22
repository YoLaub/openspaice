extends Node
## SolicitationSystem — orchestrateur des sollicitations (Story 1.4). Possède la
## CADENCE (RNG seedé + valeurs .tres) et le SUIVI des sollicitations actives. Le
## SimClock et les agents restent agnostiques : le système réagit au tick et pilote
## les agents via leur API publique.
##   - DESK : l'agent va au bureau du joueur (raise_desk_solicitation).
##   - MAIL : indicateur clignotant, sans déplacement (raise_mail_solicitation).
## L'ouverture (clic ou test) passe par open_solicitation() → émet solicitation_opened,
## retire l'indicateur, et l'agent retourne travailler. La pop-up de décision (contenu
## 2-3 options) est la Story 1.5 ; la file/patience/moral la Story 1.7.
## [Source: epics.md Story 1.4 ; game-architecture.md#System-Location-Mapping ; #Event-System]

const SolicitationC := preload("res://scripts/decisions/solicitation.gd")
const SolicitationMathC := preload("res://scripts/decisions/solicitation_math.gd")
const _BALANCE: SimBalance = preload("res://data/balance/sim_balance.tres")

@onready var _agents_container: Node3D = %Agents

## Sollicitations actives, clé = agent_id → Solicitation (une seule par agent).
var _active: Dictionary = {}
var _next_id: int = 0
var _rng := RandomNumberGenerator.new()

## Overrides de test (< 0 = utiliser la valeur d'équilibrage .tres). Permettent au
## harnais d'intégration --solicitation-smoke de forcer la cadence et le canal de
## façon déterministe, sans toucher au .tres partagé. Inutilisés en jeu réel.
var rate_override: float = -1.0
var desk_prob_override: float = -1.0

func _ready() -> void:
	_rng.randomize()
	SimClock.simulation_tick.connect(_on_simulation_tick)
	# Nettoyage : un agent qui quitte l'open space ne doit pas laisser de sollicitation
	# fantôme (fin de journée / départ).
	EventBus.agent_departed.connect(_on_agent_departed)

func _on_simulation_tick(_tick_delta: float) -> void:
	var rate: float = rate_override if rate_override >= 0.0 else _BALANCE.solicitation_rate_per_tick
	var desk_prob: float = desk_prob_override if desk_prob_override >= 0.0 else _BALANCE.desk_channel_probability
	for node: Node in _agents_container.get_children():
		if not (node is Agent):
			continue
		var agent: Agent = node
		if _active.has(agent.agent_id):
			continue
		if not agent.is_eligible_for_solicitation():
			continue
		if not SolicitationMathC.should_raise(_rng.randf(), rate):
			continue
		var channel: int = SolicitationMathC.channel_for_roll(_rng.randf(), desk_prob)
		_raise(agent, channel)

func _raise(agent: Agent, channel: int) -> void:
	var sol: Solicitation = SolicitationC.new(_next_id, agent.agent_id, channel)
	_next_id += 1
	_active[agent.agent_id] = sol
	if channel == SolicitationC.Channel.DESK:
		agent.raise_desk_solicitation()
	else:
		agent.raise_mail_solicitation()
	EventBus.solicitation_raised.emit(agent.agent_id, channel)
	Log.info("Sollicitation #%d agent %d (%s)" % [
		sol.id, agent.agent_id, "BUREAU" if channel == SolicitationC.Channel.DESK else "MAIL"])

## Ouvre la sollicitation de l'agent donné : émet solicitation_opened, retire
## l'indicateur, l'agent retourne travailler. Vrai si une sollicitation existait.
## POINT D'ENTRÉE COMMUN du clic (Task 7) ET du test d'intégration (--solicitation-smoke).
func open_solicitation(agent_id: int) -> bool:
	if not _active.has(agent_id):
		return false
	var sol: Solicitation = _active[agent_id]
	_active.erase(agent_id)
	EventBus.solicitation_opened.emit(agent_id, sol.channel)
	var agent: Agent = _find_agent(agent_id)
	if agent != null:
		agent.clear_solicitation()
	Log.info("Sollicitation ouverte — agent %d" % agent_id)
	return true

## Vrai si l'agent a une sollicitation active suivie par le système (utile au clic/test).
func has_active_solicitation(agent_id: int) -> bool:
	return _active.has(agent_id)

func _on_agent_departed(agent_id: int) -> void:
	_active.erase(agent_id)

func _find_agent(agent_id: int) -> Agent:
	for node: Node in _agents_container.get_children():
		if node is Agent and (node as Agent).agent_id == agent_id:
			return node
	return null
