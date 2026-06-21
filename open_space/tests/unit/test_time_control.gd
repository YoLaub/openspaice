extends SceneTree
## Runner de tests unitaires headless (sans dépendance d'éditeur ni autoload).
##   Lancer : godot --headless --path open_space --script res://tests/unit/test_time_control.gd
## Quitte avec le code 0 si tous les tests passent, 1 sinon.
##
## Cible : les fonctions pures de TimeControl (mapping niveau de vitesse → échelle,
## bornage des niveaux), cœur logique de l'AC #2 (vitesses x1/x2/x3). Quand l'addon
## GUT sera installé, ces cas pourront être portés en suite GUT sous tests/unit/.

const TC := preload("res://scripts/systems/time_control.gd")

var _failures: int = 0
var _checks: int = 0

func _initialize() -> void:
	_test_scale_for_each_speed()
	_test_scale_clamps_below_min()
	_test_scale_clamps_above_max()
	_test_clamp_speed_level_bounds()

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

func _test_scale_for_each_speed() -> void:
	_check("vitesse 1 → time_scale 1.0", is_equal_approx(TC.scale_for_speed(1), 1.0))
	_check("vitesse 2 → time_scale 2.0", is_equal_approx(TC.scale_for_speed(2), 2.0))
	_check("vitesse 3 → time_scale 3.0", is_equal_approx(TC.scale_for_speed(3), 3.0))

func _test_scale_clamps_below_min() -> void:
	# Un niveau invalide (0 ou négatif) ne doit jamais produire un facteur < x1.
	_check("vitesse 0 bornée à 1.0", is_equal_approx(TC.scale_for_speed(0), 1.0))
	_check("vitesse -5 bornée à 1.0", is_equal_approx(TC.scale_for_speed(-5), 1.0))

func _test_scale_clamps_above_max() -> void:
	_check("vitesse 9 bornée à 3.0", is_equal_approx(TC.scale_for_speed(9), 3.0))

func _test_clamp_speed_level_bounds() -> void:
	_check("clamp 2 = 2", TC.clamp_speed_level(2) == 2)
	_check("clamp 0 = 1 (mini)", TC.clamp_speed_level(0) == 1)
	_check("clamp 99 = 3 (maxi)", TC.clamp_speed_level(99) == 3)
