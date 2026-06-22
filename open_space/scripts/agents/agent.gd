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

## Couleurs des indicateurs de sollicitation placeholder (Story 1.4 ; art final = Épic 6).
const _DESK_MARKER_COLOR: Color = Color(0.95, 0.25, 0.20)  # rouge → décision importante (bureau)
const _MAIL_MARKER_COLOR: Color = Color(0.20, 0.55, 0.95)  # bleu → mail asynchrone
const _MARKER_HEIGHT: float = 2.2                          # hauteur au-dessus du sol (au-dessus de la capsule)
const _MARKER_SIZE: float = 0.4
const _BLINK_HZ: float = 2.0                               # cadence de clignotement

var agent_id: int = -1

## Jauge Moral (0-100), Story 1.7. Valeur portée par l'agent (lue par la fiche 1.9 /
## HUD 1.8) ; bornage via MoraleMath ; baisse pilotée par DeskQueue (impatience en file).
var _morale: float = 100.0

var _archetype: AgentArchetype = null
var _move_speed: float = 3.0
var _post_position: Vector3 = Vector3.ZERO
var _exit_position: Vector3 = Vector3.ZERO
var _desk_position: Vector3 = Vector3.ZERO
var _departure_phase: float = 1.0

var _arrived_at_post: bool = false
var _leaving: bool = false
var _current_target: Vector3 = Vector3.ZERO

# --- Sollicitations (Story 1.4) ---
## Sollicitation présentielle (bureau) en cours → le cerveau dirige l'agent au bureau.
var _has_desk_solicitation: bool = false
## En route vers le bureau (distinct de _leaving / _arrived_at_post).
var _heading_to_desk: bool = false
## Arrivé au bureau, en attente du traitement joueur.
var _at_desk: bool = false
## Indicateur visuel courant (créé/retiré dynamiquement) + son temps de clignotement.
var _marker: MeshInstance3D = null
var _marker_material: StandardMaterial3D = null
var _blink_time: float = 0.0

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _nav: NavigationAgent3D = $NavigationAgent3D
@onready var _brain: BrainComponent = $BrainComponent
@onready var _sm: AgentStateMachine = $StateMachine
@onready var _idle_state: AgentIdleState = $StateMachine/IdleState
@onready var _work_state: AgentWorkState = $StateMachine/WorkState
@onready var _move_state: AgentMoveState = $StateMachine/MoveState

## Configure l'agent depuis son archétype. Appelé par l'AgentFactory AVANT add_child
## (les nœuds existent mais _ready n'a pas encore tourné → on ne stocke que des valeurs).
func setup(id: int, archetype: AgentArchetype, post: Vector3, exit: Vector3, desk: Vector3, evening_phase: float, initial_morale: float = 100.0) -> void:
	agent_id = id
	_archetype = archetype
	_post_position = post
	_exit_position = exit
	_desk_position = desk
	_departure_phase = DayPhaseMathC.departure_phase(evening_phase, archetype.departure_offset)
	_morale = MoraleMath.clamp_morale(initial_morale)

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

## Clignotement de l'indicateur de sollicitation. _process (pas _physics_process) :
## pausable (gèle en pause, cohérent Story 1.3) et scalé par Engine.time_scale.
## Pas d'allocation per-frame : on ne modifie que l'alpha d'un matériau existant.
func _process(delta: float) -> void:
	if _marker_material == null:
		return
	_blink_time += delta
	var alpha: float = 0.35 + 0.65 * (0.5 + 0.5 * sin(_blink_time * TAU * _BLINK_HZ))
	var c: Color = _marker_material.albedo_color
	c.a = alpha
	_marker_material.albedo_color = c

func _on_simulation_tick(_tick_delta: float) -> void:
	_decide()

func _decide() -> void:
	var ctx := AgentContext.new(_arrived_at_post, _is_evening(), _has_desk_solicitation)
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
		ActionRegistry.GO_TO_DESK:
			# Sollicitation présentielle : marche jusqu'au bureau du joueur (si pas
			# déjà en route/arrivé). _heading_to_desk distingue cette cible du poste/sortie.
			if not _heading_to_desk and not _at_desk:
				_heading_to_desk = true
				_current_target = _desk_position
				_nav.target_position = _desk_position
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
	elif _heading_to_desk:
		# Arrivé au bureau du joueur : attend immobile que le joueur le traite
		# (la pop-up de décision est la Story 1.5 ; ici on patiente).
		_heading_to_desk = false
		_at_desk = true
		_sm.change_to(_idle_state)
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

# =========================================================================
# API SOLLICITATIONS (Story 1.4) — appelée par SolicitationSystem.
# =========================================================================

## Lève une sollicitation PRÉSENTIELLE : l'agent ira au bureau (GO_TO_DESK au
## prochain tick) et affiche l'indicateur bureau. _arrived_at_post repasse à false
## pour qu'après résolution le cerveau réémette GO_TO_POST (retour au poste).
func raise_desk_solicitation() -> void:
	_has_desk_solicitation = true
	_arrived_at_post = false
	_show_marker(_DESK_MARKER_COLOR)

## Lève une sollicitation MAIL : indicateur clignotant, SANS déplacer l'agent
## (il continue de travailler à son poste — AC#2).
func raise_mail_solicitation() -> void:
	_show_marker(_MAIL_MARKER_COLOR)

## Résout/ferme la sollicitation : retire l'indicateur et réinitialise l'état
## d'approche bureau → l'agent retourne travailler (GO_TO_POST → WORK).
func clear_solicitation() -> void:
	_has_desk_solicitation = false
	_heading_to_desk = false
	_at_desk = false
	_hide_marker()

## Vrai si un indicateur de sollicitation est affiché (bureau OU mail).
func has_open_solicitation() -> bool:
	return _marker != null

## Vrai si l'agent peut lever une NOUVELLE sollicitation : à son poste, en train de
## travailler (pas en route/au bureau, pas en train de partir, pas le soir) et sans
## sollicitation déjà en cours. Lu par SolicitationSystem.
func is_eligible_for_solicitation() -> bool:
	return _arrived_at_post and not _leaving and not _at_desk \
		and not _heading_to_desk and not _is_evening() and not has_open_solicitation()

# =========================================================================
# API MORAL & FILE D'ATTENTE (Story 1.7) — appelée par DeskQueue.
# =========================================================================

## Valeur entière courante du moral (0-100), pour la fiche agent (1.9) / HUD (1.8) / test.
func get_morale() -> int:
	return roundi(_morale)

## Ajuste le moral d'un delta, borné dans [0, 100]. N'émet agent_morale_changed que si
## la valeur change réellement (évite le spam à chaque tick).
func adjust_morale(delta: float) -> void:
	var old: float = _morale
	_morale = MoraleMath.clamp_morale(_morale + delta)
	if _morale != old:
		EventBus.agent_morale_changed.emit(agent_id, roundi(_morale))

## Assigne (ou ré-assigne) le créneau physique de l'agent dans la file d'attente du
## bureau. Met à jour la cible bureau ; si l'agent attend déjà au bureau et qu'il
## AVANCE dans la file, relance le mouvement (le cerveau ne réémet pas GO_TO_DESK une
## fois _at_desk). Garde : un agent qui repart le soir ou sans sollicitation bureau ne
## doit jamais être ramené au bureau par un reflow.
func assign_queue_slot(slot_position: Vector3) -> void:
	if _leaving or not _has_desk_solicitation:
		return
	_desk_position = slot_position
	if _at_desk:
		_at_desk = false
		_heading_to_desk = true
	if _heading_to_desk:
		_current_target = slot_position
		_nav.target_position = slot_position
		_sm.change_to(_move_state)

func _show_marker(color: Color) -> void:
	_hide_marker()
	_marker_material = StandardMaterial3D.new()
	_marker_material.albedo_color = color
	# Transparence activée pour le clignotement par alpha ; non éclairé pour rester lisible.
	_marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(_MARKER_SIZE, _MARKER_SIZE)
	quad.material = _marker_material
	_marker = MeshInstance3D.new()
	_marker.mesh = quad
	_marker.position = Vector3(0.0, _MARKER_HEIGHT, 0.0)
	_blink_time = 0.0
	add_child(_marker)

func _hide_marker() -> void:
	if _marker != null:
		_marker.queue_free()
		_marker = null
	_marker_material = null
