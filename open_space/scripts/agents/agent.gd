class_name Agent
extends CharacterBody3D
## Agent natif de l'open space. Deux horloges DÉCOUPLÉES (clé de NFR1+NFR2) :
##   - DÉCISION : sur simulation_tick de SimClock (~3 Hz) → le BrainComponent choisit
##     l'action (aller au poste / travailler / repartir) via NativeBrain.
##   - MOUVEMENT : par frame physique (60 FPS) → l'état Move suit le chemin de
##     NavigationAgent3D (obstacle-aware ; le mobilier deviendra obstacle en Épic 3).
## La DA réelle et les animations sont l'Épic 6 (ici : capsule teintée placeholder).
## [Source: game-architecture.md#Novel-Pattern ; #State-Patterns ; ADR-3 ; epics.md Story 1.2]

const DayPhaseMathC := preload("res://scripts/agents/day_phase_math.gd")

const _ARRIVE_EPS: float = 0.6  # tolérance d'arrivée (m), garde-fou nav non prête

var agent_id: int = -1

var _archetype: AgentArchetype = null
var _move_speed: float = 3.0
var _post_position: Vector3 = Vector3.ZERO
var _exit_position: Vector3 = Vector3.ZERO
var _departure_phase: float = 1.0

var _arrived_at_post: bool = false
var _leaving: bool = false
var _current_target: Vector3 = Vector3.ZERO

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _nav: NavigationAgent3D = $NavigationAgent3D
@onready var _brain: BrainComponent = $BrainComponent
@onready var _sm: AgentStateMachine = $StateMachine
@onready var _idle_state: AgentIdleState = $StateMachine/IdleState
@onready var _work_state: AgentWorkState = $StateMachine/WorkState
@onready var _move_state: AgentMoveState = $StateMachine/MoveState

## Configure l'agent depuis son archétype. Appelé par l'AgentFactory AVANT add_child
## (les nœuds existent mais _ready n'a pas encore tourné → on ne stocke que des valeurs).
func setup(id: int, archetype: AgentArchetype, post: Vector3, exit: Vector3, evening_phase: float) -> void:
	agent_id = id
	_archetype = archetype
	_post_position = post
	_exit_position = exit
	_departure_phase = DayPhaseMathC.departure_phase(evening_phase, archetype.departure_offset)

func _ready() -> void:
	_move_speed = _archetype.move_speed
	_apply_tint(_archetype.tint)
	for state: AgentState in [_idle_state, _work_state, _move_state]:
		state.agent = self
	# Agent de navigation top-down : mouvement libre 3D (pas de gravité/sol à gérer ;
	# le suivi du chemin nous place à la hauteur du NavMesh).
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_nav.target_desired_distance = 0.5
	_sm.change_to(_idle_state)
	SimClock.simulation_tick.connect(_on_simulation_tick)
	EventBus.agent_spawned.emit(agent_id)
	# Attendre que la carte de navigation soit synchronisée et que l'agent y soit
	# enregistré avant la 1re décision (sinon la 1re requête de chemin part à vide
	# et n'est jamais relancée). Piège classique de NavigationAgent3D en Godot 4.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_decide()

func _physics_process(delta: float) -> void:
	_sm.physics_update(delta)

func _on_simulation_tick(_tick_delta: float) -> void:
	_decide()

func _decide() -> void:
	var ctx := AgentContext.new(_arrived_at_post, _is_evening())
	var action: AgentAction = _brain.tick(ctx)
	_apply_action(action)

func _is_evening() -> bool:
	return DayPhaseMathC.is_evening(GameManager.day_phase, _departure_phase)

func _apply_action(action: AgentAction) -> void:
	match action.type:
		ActionRegistry.GO_TO_POST:
			_current_target = _post_position
			_nav.target_position = _post_position
			_sm.change_to(_move_state)
		ActionRegistry.WORK:
			_sm.change_to(_work_state)
		ActionRegistry.LEAVE:
			if not _leaving:
				_leaving = true
				_current_target = _exit_position
				_nav.target_position = _exit_position
				_sm.change_to(_move_state)
		ActionRegistry.IDLE:
			_sm.change_to(_idle_state)

## Suit le chemin de navigation vers la cible courante (appelé par AgentMoveState).
## L'arrivée est jugée sur la distance HORIZONTALE à la cible (robuste au léger écart
## de hauteur entre l'agent et le plan du NavMesh) ; get_next_path_position ne sert
## qu'au pilotage du déplacement le long du chemin.
func follow_path(_delta: float) -> void:
	if _horizontal_distance(_current_target) <= _ARRIVE_EPS:
		_on_destination_reached()
		return
	var next: Vector3 = _nav.get_next_path_position()
	var dir: Vector3 = next - global_position
	if dir.length() > 0.001:
		velocity = dir.normalized() * _move_speed
	else:
		velocity = Vector3.ZERO
	move_and_slide()

func _horizontal_distance(target: Vector3) -> float:
	var flat: Vector3 = target - global_position
	flat.y = 0.0
	return flat.length()

## Stoppe le mouvement (utilisé par idle/work).
func halt() -> void:
	velocity = Vector3.ZERO

func _on_destination_reached() -> void:
	halt()
	if _leaving:
		_depart()
	elif not _arrived_at_post:
		_arrived_at_post = true
		_sm.change_to(_work_state)

func _depart() -> void:
	EventBus.agent_departed.emit(agent_id)
	Log.info("Agent %d (%s) a quitté l'open space" % [agent_id, _archetype.display_name])
	queue_free()

func _apply_tint(color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	_mesh.material_override = mat
