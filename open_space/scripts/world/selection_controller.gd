extends Node
## SelectionController — traduit le clic gauche en ouverture de sollicitation
## (Story 1.4). Raycast caméra → si l'agent cliqué a une sollicitation active,
## on l'ouvre via SolicitationSystem.open_solicitation(). Cliquer dans le vide ou
## un agent sans sollicitation = no-op (la fiche agent au clic est la Story 1.9,
## qui étendra ce handler).
##
## ⚠️ PROCESS_MODE_ALWAYS : on doit pouvoir ouvrir une sollicitation même en PAUSE
## (le joueur met en pause pour réfléchir — même piège que l'input « Espace » en 1.3).
## Conventions : input via Input Map (jamais de bouton en dur), pas de chemin absolu.
## [Source: epics.md Story 1.4 AC#3 ; 1-3…md#Piège-n°1 ; game-architecture.md#Architectural-Boundaries]

const _RAY_LEN: float = 1000.0

@onready var _solicitations: Node = %SolicitationSystem

func _ready() -> void:
	# Actif en pause pour permettre l'ouverture pendant que le temps est gelé.
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("select_click"):
		return
	var agent: Agent = _agent_under_mouse()
	if agent != null:
		_solicitations.open_solicitation(agent.agent_id)

## Raycast depuis la caméra active vers la position souris ; renvoie l'Agent touché
## (ou null). Fonctionne en projection orthographique (origine variable par pixel).
func _agent_under_mouse() -> Agent:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return null
	var mpos: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mpos)
	var to: Vector3 = from + cam.project_ray_normal(mpos) * _RAY_LEN
	var space: PhysicsDirectSpaceState3D = cam.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return null
	var collider: Object = hit.get("collider")
	return _as_agent(collider)

## Remonte du collider à l'Agent (le collider EST l'agent CharacterBody3D, ou un enfant).
func _as_agent(node: Object) -> Agent:
	var n: Node = node as Node
	while n != null:
		if n is Agent:
			return n
		n = n.get_parent()
	return null
