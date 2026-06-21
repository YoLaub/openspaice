extends SceneTree
## Runner de tests unitaires headless (sans dépendance d'éditeur).
##   Lancer : godot --headless --script res://tests/unit/test_camera_math.gd
## Quitte avec le code 0 si tous les tests passent, 1 sinon.
##
## Cible : les fonctions pures de CameraController (clamp du zoom / du pan),
## cœur logique de l'AC #2 (zoom borné, pan borné). Quand l'addon GUT sera
## installé, ces cas pourront être portés en suite GUT sous tests/unit/.

const CM := preload("res://scripts/world/camera_math.gd")

var _failures: int = 0
var _checks: int = 0

func _initialize() -> void:
	_test_zoom_clamps_within_bounds()
	_test_zoom_respects_min()
	_test_zoom_respects_max()
	_test_pan_clamps_each_axis()
	_test_pan_passthrough_inside_bounds()

	print("Tests exécutés : %d, échecs : %d" % [_checks, _failures])
	if _failures == 0:
		print("TEST_RESULT=PASS")
		quit(0)
	else:
		print("TEST_RESULT=FAIL")
		quit(1)

func _check(name: String, condition: bool) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("  [FAIL] %s" % name)
	else:
		print("  [ok]   %s" % name)

func _test_zoom_clamps_within_bounds() -> void:
	var r: float = CM.clamp_zoom(16.0, 1.5, 4.0, 30.0)
	_check("zoom +1.5 depuis 16 → 17.5", is_equal_approx(r, 17.5))

func _test_zoom_respects_min() -> void:
	var r: float = CM.clamp_zoom(4.5, -10.0, 4.0, 30.0)
	_check("zoom borné au mini (4.0)", is_equal_approx(r, 4.0))

func _test_zoom_respects_max() -> void:
	var r: float = CM.clamp_zoom(29.0, 10.0, 4.0, 30.0)
	_check("zoom borné au maxi (30.0)", is_equal_approx(r, 30.0))

func _test_pan_clamps_each_axis() -> void:
	var lo: Vector3 = Vector3(-20.0, 0.0, -20.0)
	var hi: Vector3 = Vector3(20.0, 0.0, 20.0)
	var r: Vector3 = CM.clamp_pan(Vector3(999.0, 5.0, -999.0), lo, hi)
	_check("pan x borné au maxi", is_equal_approx(r.x, 20.0))
	_check("pan y borné (plan sol)", is_equal_approx(r.y, 0.0))
	_check("pan z borné au mini", is_equal_approx(r.z, -20.0))

func _test_pan_passthrough_inside_bounds() -> void:
	var lo: Vector3 = Vector3(-20.0, 0.0, -20.0)
	var hi: Vector3 = Vector3(20.0, 0.0, 20.0)
	var p: Vector3 = Vector3(5.0, 0.0, -7.0)
	var r: Vector3 = CM.clamp_pan(p, lo, hi)
	_check("pan inchangé dans les bornes", r.is_equal_approx(p))
