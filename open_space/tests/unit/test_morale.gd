extends SceneTree
## Runner de tests unitaires headless (sans dépendance d'éditeur ni autoload).
##   Lancer : godot --headless --path open_space --script res://tests/unit/test_morale.gd
## Quitte avec le code 0 si tous les tests passent, 1 sinon.
##
## Cible : la logique PURE du moral (Story 1.7) —
##   - MoraleMath.clamp_morale       (bornage 0-100)
##   - MoraleMath.patience_exceeded  (attente au-delà strict de la patience)
##   - MoraleMath.decay_steps        (paliers entiers de décroissance dans l'accumulateur)

const MM := preload("res://scripts/systems/morale_math.gd")

var _failures: int = 0
var _checks: int = 0

func _initialize() -> void:
	_test_clamp_morale()
	_test_patience_exceeded()
	_test_decay_steps()

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

func _test_clamp_morale() -> void:
	_check("−10 → 0 (borne basse)", MM.clamp_morale(-10.0) == 0.0)
	_check("150 → 100 (borne haute)", MM.clamp_morale(150.0) == 100.0)
	_check("50 → 50 (intérieur)", MM.clamp_morale(50.0) == 50.0)
	_check("0 → 0 (borne incluse)", MM.clamp_morale(0.0) == 0.0)
	_check("100 → 100 (borne incluse)", MM.clamp_morale(100.0) == 100.0)

func _test_patience_exceeded() -> void:
	# Au-delà STRICT de la patience (>). À l'égalité exacte, pas encore dépassée.
	_check("44 < 45 → non dépassée", not MM.patience_exceeded(44.0, 45.0))
	_check("45 = 45 → non dépassée (borne exclusive)", not MM.patience_exceeded(45.0, 45.0))
	_check("46 > 45 → dépassée", MM.patience_exceeded(46.0, 45.0))
	_check("0 attente → non dépassée", not MM.patience_exceeded(0.0, 45.0))

func _test_decay_steps() -> void:
	# Nombre de paliers entiers de `interval` contenus dans l'accumulateur.
	_check("0 / 5 → 0", MM.decay_steps(0.0, 5.0) == 0)
	_check("4.9 / 5 → 0", MM.decay_steps(4.9, 5.0) == 0)
	_check("5 / 5 → 1", MM.decay_steps(5.0, 5.0) == 1)
	_check("9 / 5 → 1", MM.decay_steps(9.0, 5.0) == 1)
	_check("12 / 5 → 2", MM.decay_steps(12.0, 5.0) == 2)
	# Défensif : intervalle nul/négatif → 0 (pas de division ni boucle infinie).
	_check("intervalle 0 → 0 (défensif)", MM.decay_steps(10.0, 0.0) == 0)
	_check("intervalle négatif → 0 (défensif)", MM.decay_steps(10.0, -5.0) == 0)
