extends SceneTree
## Runner de tests unitaires headless (sans dépendance d'éditeur ni autoload).
##   Lancer : godot --headless --path open_space --script res://tests/unit/test_fatigue.gd
## Quitte avec le code 0 si tous les tests passent, 1 sinon.
##
## Cible : la logique PURE de la fatigue (Story 2.1) —
##   - FatigueMath.clamp_fatigue        (bornage 0-100)
##   - FatigueMath.accrual_per_tick     (accumulation proportionnelle à la phase de journée)
##   - FatigueMath.overnight_recovery   (repos -25/nuit, +15 heures sup', borné)

const FM := preload("res://scripts/systems/fatigue_math.gd")

var _failures: int = 0
var _checks: int = 0

func _initialize() -> void:
	_test_clamp_fatigue()
	_test_accrual_per_tick()
	_test_overnight_recovery()

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

func _test_clamp_fatigue() -> void:
	_check("−10 → 0 (borne basse)", FM.clamp_fatigue(-10.0) == 0.0)
	_check("150 → 100 (borne haute)", FM.clamp_fatigue(150.0) == 100.0)
	_check("50 → 50 (intérieur)", FM.clamp_fatigue(50.0) == 50.0)
	_check("0 → 0 (borne incluse)", FM.clamp_fatigue(0.0) == 0.0)
	_check("100 → 100 (borne incluse)", FM.clamp_fatigue(100.0) == 100.0)

func _test_accrual_per_tick() -> void:
	# Fraction de journée écoulée ce tick × taux/jour. 1 s sur 10 s = 1/10 de 25 = 2.5.
	_check("25/j, dt=1, D=10 → 2.5", is_equal_approx(FM.accrual_per_tick(25.0, 1.0, 10.0), 2.5))
	# Sur une journée complète (somme des accruals) ≈ taux/jour : (D/dt) × accrual = 25.
	_check("somme sur 1 journée ≈ 25", is_equal_approx(
		FM.accrual_per_tick(25.0, 0.333, 10.0) * (10.0 / 0.333), 25.0))
	# Défensif : durée nulle/négative → 0 (pas de division par zéro).
	_check("durée 0 → 0 (défensif)", FM.accrual_per_tick(25.0, 1.0, 0.0) == 0.0)
	_check("durée négative → 0 (défensif)", FM.accrual_per_tick(25.0, 1.0, -5.0) == 0.0)

func _test_overnight_recovery() -> void:
	# Sans heures sup' : seulement le repos -25.
	_check("40, repos25, sans HS → 15", FM.overnight_recovery(40.0, 25.0, 15.0, false) == 15.0)
	# Avec heures sup' : +15 puis -25 → net -10.
	_check("40, repos25, +15 HS → 30", FM.overnight_recovery(40.0, 25.0, 15.0, true) == 30.0)
	# Bornage bas : 10 - 25 = -15 → 0.
	_check("10, repos25, sans HS → 0 (borné bas)", FM.overnight_recovery(10.0, 25.0, 15.0, false) == 0.0)
	# Bornage haut : 95 + 15 - 25 = 85 (sous 100, pas de clamp haut ici).
	_check("95, repos25, +15 HS → 85", FM.overnight_recovery(95.0, 25.0, 15.0, true) == 85.0)
	# Bornage haut effectif : 100 + 15 - 5 = 110 → 100.
	_check("100, repos5, +15 HS → 100 (borné haut)", FM.overnight_recovery(100.0, 5.0, 15.0, true) == 100.0)
