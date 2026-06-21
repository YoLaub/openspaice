extends Node3D
## Open space : construit la grille de sol via GridMap + une MeshLibrary générée
## au runtime (une tuile de sol), matérialisant le plateau de départ "petit local".
## Story 1.2 : ajoute la navigation (NavigationRegion3D + NavMesh runtime couvrant
## le plateau) et expose la géométrie (cellule→monde, entrée, postes) pour le spawn
## d'agents. Le mobilier et l'agrandissement par paliers arrivent en Épic 3 — le
## mobilier deviendra alors obstacle (re-bake du NavMesh / NavigationObstacle3D).
## [Source: game-architecture.md#Decision-Summary D8 ; (pathfinding) ; epics.md Story 1.2/3.5]

const GRID_COLS: int = 12      # plateau de départ (petit local)
const GRID_ROWS: int = 12
const CELL: float = 2.0        # taille de cellule GridMap (m)
const _FLOOR_ITEM: int = 0
const _FLOOR_THICKNESS: float = 0.1
const _FLOOR_COLOR: Color = Color(0.86, 0.88, 0.87)  # blanc/teal aseptisé (DA Severance, minimal)

const AGENT_Y: float = 0.1     # plan de circulation des agents (au-dessus du sol)
const _NAV_MARGIN: float = 0.5 # marge du NavMesh au-delà du plateau

## Cellules de postes de travail (placeholders ; les vrais bureaux = Épic 3).
const _POST_CELLS: Array[Vector2i] = [
	Vector2i(3, 3), Vector2i(8, 3), Vector2i(5, 6),
	Vector2i(3, 8), Vector2i(8, 8), Vector2i(6, 9),
]
const _ENTRANCE_CELL: Vector2i = Vector2i(0, 6)  # porte d'entrée/sortie (bord du plateau)

@onready var _grid: GridMap = $GridMap
@onready var _light: DirectionalLight3D = $DirectionalLight3D
@onready var _nav_region: NavigationRegion3D = $NavigationRegion3D

func _ready() -> void:
	_configure_light()
	_build_floor()
	_build_navigation()
	Log.info("Open space initialisé (%d x %d cellules)" % [GRID_COLS, GRID_ROWS])

func _configure_light() -> void:
	if _light != null:
		_light.rotation_degrees = Vector3(-50.0, -40.0, 0.0)

func _build_floor() -> void:
	_grid.cell_size = Vector3(CELL, CELL, CELL)
	_grid.mesh_library = _make_floor_library()
	for x: int in GRID_COLS:
		for z: int in GRID_ROWS:
			_grid.set_cell_item(Vector3i(x, 0, z), _FLOOR_ITEM)

func _make_floor_library() -> MeshLibrary:
	var lib: MeshLibrary = MeshLibrary.new()
	var tile: BoxMesh = BoxMesh.new()
	tile.size = Vector3(CELL, _FLOOR_THICKNESS, CELL)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = _FLOOR_COLOR
	tile.material = mat
	lib.create_item(_FLOOR_ITEM)
	lib.set_item_name(_FLOOR_ITEM, "floor")
	lib.set_item_mesh(_FLOOR_ITEM, tile)
	return lib

## Construit un NavMesh plat couvrant tout le plateau (génération runtime, sans bake
## d'éditeur → robuste et vérifiable headless). Le mobilier (Épic 3) viendra carver
## des obstacles : il suffira de re-générer ce NavMesh ou d'ajouter des NavigationObstacle3D.
func _build_navigation() -> void:
	var c00: Vector3 = _grid.to_global(_grid.map_to_local(Vector3i(0, 0, 0)))
	var c11: Vector3 = _grid.to_global(_grid.map_to_local(Vector3i(GRID_COLS - 1, 0, GRID_ROWS - 1)))
	var min_x: float = minf(c00.x, c11.x) - CELL * 0.5 - _NAV_MARGIN
	var max_x: float = maxf(c00.x, c11.x) + CELL * 0.5 + _NAV_MARGIN
	var min_z: float = minf(c00.z, c11.z) - CELL * 0.5 - _NAV_MARGIN
	var max_z: float = maxf(c00.z, c11.z) + CELL * 0.5 + _NAV_MARGIN

	# On bake le NavMesh depuis une géométrie source plate (PlaneMesh orientée vers
	# le haut) : le bake gère l'orientation/les marges et reste déterministe/headless.
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(max_x - min_x, max_z - min_z)
	var center: Vector3 = Vector3((min_x + max_x) * 0.5, AGENT_Y, (min_z + max_z) * 0.5)

	var source: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	source.add_mesh(plane, Transform3D(Basis(), center))

	var nav_mesh: NavigationMesh = NavigationMesh.new()
	nav_mesh.agent_radius = 0.4
	nav_mesh.cell_size = 0.25
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source)
	_nav_region.navigation_mesh = nav_mesh

## Centre-monde d'une cellule de grille, au plan de circulation des agents.
func cell_to_world(cell: Vector2i) -> Vector3:
	var local: Vector3 = _grid.map_to_local(Vector3i(cell.x, 0, cell.y))
	var world: Vector3 = _grid.to_global(local)
	world.y = AGENT_Y
	return world

## Position d'entrée/sortie des agents (bord du plateau).
func entrance_world() -> Vector3:
	return cell_to_world(_ENTRANCE_CELL)

## Positions de postes de travail (placeholders), dans l'ordre d'assignation.
func post_world_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for cell: Vector2i in _POST_CELLS:
		out.append(cell_to_world(cell))
	return out
