extends Node3D
## Contrôleur de caméra iso. Attaché au pivot (CameraRig).
## - Pan : WASD (InputMap) + bord d'écran (edge-pan), borné.
## - Zoom : molette (InputMap), via Camera3D.size orthographique, borné.
## La caméra enfant est orthographique et orientée en angle isométrique.
## [Source: gdd.md#Controls-and-Input ; game-architecture.md#Decision-Summary D12]
##
## Conventions : aucune touche codée en dur dans la logique — tout passe par
## l'Input Map. Pas de chemin de nœud absolu (référence enfant via @onready).

const PAN_SPEED: float = 12.0          # unités/seconde
const EDGE_MARGIN_PX: float = 16.0     # marge de bord d'écran pour l'edge-pan
const MIN_ZOOM: float = 4.0            # Camera3D.size mini (zoom avant)
const MAX_ZOOM: float = 30.0           # Camera3D.size maxi (zoom arrière)
const ZOOM_STEP: float = 1.5           # variation de size par cran de molette
const PAN_MIN: Vector3 = Vector3(-20.0, 0.0, -20.0)
const PAN_MAX: Vector3 = Vector3(20.0, 0.0, 20.0)

# Pose de la caméra iso (offset local depuis le pivot, regardant le pivot).
const _CAM_OFFSET: Vector3 = Vector3(20.0, 20.0, 20.0)
const _START_SIZE: float = 16.0

@onready var _camera: Camera3D = $Camera3D

func _ready() -> void:
	if _camera == null:
		Log.error("CameraController : aucune Camera3D enfant trouvée")
		return
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.position = _CAM_OFFSET
	_camera.look_at(global_position, Vector3.UP)
	_camera.size = CameraMath.clamp_zoom(_START_SIZE, 0.0, MIN_ZOOM, MAX_ZOOM)

func _process(delta: float) -> void:
	var dir: Vector3 = _read_pan_input()
	if dir != Vector3.ZERO:
		global_position = CameraMath.clamp_pan(
			global_position + dir * PAN_SPEED * delta, PAN_MIN, PAN_MAX
		)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cam_zoom_in"):
		_apply_zoom(-ZOOM_STEP)
	elif event.is_action_pressed("cam_zoom_out"):
		_apply_zoom(ZOOM_STEP)

func _apply_zoom(delta_size: float) -> void:
	if _camera != null:
		_camera.size = CameraMath.clamp_zoom(_camera.size, delta_size, MIN_ZOOM, MAX_ZOOM)

## Combine clavier (WASD) et bord d'écran en une direction sur le plan sol (x,z).
func _read_pan_input() -> Vector3:
	var v: Vector2 = Vector2.ZERO
	v.x += Input.get_action_strength("cam_right") - Input.get_action_strength("cam_left")
	v.y += Input.get_action_strength("cam_down") - Input.get_action_strength("cam_up")
	v += _edge_pan_vector()
	if v == Vector2.ZERO:
		return Vector3.ZERO
	v = v.limit_length(1.0)
	return Vector3(v.x, 0.0, v.y)

## Vecteur d'edge-pan selon la position de la souris dans la fenêtre.
func _edge_pan_vector() -> Vector2:
	var vp: Viewport = get_viewport()
	if vp == null:
		return Vector2.ZERO
	var size: Vector2 = vp.get_visible_rect().size
	var mouse: Vector2 = vp.get_mouse_position()
	if mouse.x < 0.0 or mouse.y < 0.0 or mouse.x > size.x or mouse.y > size.y:
		return Vector2.ZERO  # souris hors fenêtre → pas d'edge-pan
	var e: Vector2 = Vector2.ZERO
	if mouse.x <= EDGE_MARGIN_PX:
		e.x -= 1.0
	elif mouse.x >= size.x - EDGE_MARGIN_PX:
		e.x += 1.0
	if mouse.y <= EDGE_MARGIN_PX:
		e.y -= 1.0
	elif mouse.y >= size.y - EDGE_MARGIN_PX:
		e.y += 1.0
	return e

# Les fonctions pures de clamp (zoom/pan) vivent dans CameraMath (camera_math.gd),
# isolées et testables sans dépendance de scène/autoload.
