extends Node
## SelectionController — route le clic gauche (Story 1.4 + extension 1.9). Raycast
## caméra → agent cliqué. ROUTAGE (sollicitation-prioritaire) :
##   - agent AVEC sollicitation active → on l'ouvre via open_solicitation() (boucle
##     cœur 1.4 INCHANGÉE : l'agent qui réclame l'attention passe d'abord) ;
##   - agent SANS sollicitation → on ouvre/bascule sa FICHE (Story 1.9) ;
##   - clic dans le VIDE → on ferme la fiche.
## handle_agent_click()/handle_empty_click() sont des POINTS D'ENTRÉE COMMUNS (clic réel
## via _unhandled_input ET test d'intégration --card-smoke), modèle DecisionPopup.choose_option.
##
## ⚠️ PROCESS_MODE_ALWAYS : on doit pouvoir sélectionner/ouvrir même en PAUSE (le joueur
## met en pause pour réfléchir — même piège que l'input « Espace » en 1.3). La fiche est
## NON-MODALE : son Panel (mouse_filter = STOP) capte les clics dans son rect (donc cliquer
## la fiche ne déclenche pas _unhandled_input et ne déselectionne pas) ; hors du Panel, les
## clics arrivent ici → handle_empty_click ferme la fiche.
## Conventions : input via Input Map (jamais de bouton en dur), pas de chemin absolu.
## [Source: epics.md Story 1.4 AC#3 / Story 1.9 ; 1-9…md#Décision-n°1/n°2 ; game-architecture.md#Architectural-Boundaries]

const _RAY_LEN: float = 1000.0

@onready var _solicitations: Node = %SolicitationSystem
@onready var _agent_card: CanvasLayer = %AgentCard

func _ready() -> void:
	# Actif en pause pour permettre l'ouverture pendant que le temps est gelé.
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("select_click"):
		return
	var agent: Agent = _agent_under_mouse()
	if agent != null:
		handle_agent_click(agent)
	else:
		handle_empty_click()

## POINT D'ENTRÉE COMMUN du clic agent (clic réel + --card-smoke). Sollicitation-prioritaire :
## un agent qui réclame l'attention est traité d'abord (1.4) ; sinon on ouvre sa fiche (1.9).
func handle_agent_click(agent: Agent) -> void:
	if _solicitations.has_active_solicitation(agent.agent_id):
		_solicitations.open_solicitation(agent.agent_id)
	else:
		_agent_card.show_for(agent)

## POINT D'ENTRÉE COMMUN du clic dans le vide : ferme la fiche (« clic ailleurs ferme »).
func handle_empty_click() -> void:
	_agent_card.hide_card()

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
