extends SceneTree
## Runner de tests unitaires headless (sans dépendance d'éditeur ni autoload).
##   Lancer : godot --headless --path open_space --script res://tests/unit/test_decision_resolution.gd
## Quitte avec le code 0 si tous les tests passent, 1 sinon.
##
## Cible : la logique PURE de résolution des décisions (Story 1.6) —
##   - DecisionResolutionMath.is_immediate (tirage immédiat ~60 % vs différé ~40 %)
##   - DecisionResolutionMath.delay_days  (fenêtre 1-2 jours, bornée)
##   - DecisionResolutionMath.is_due      (résout à l'échéance, pas avant)
## + l'invariant "chaque option du catalogue livré porte un champ outcome (int)".

const DRM := preload("res://scripts/decisions/decision_resolution_math.gd")

const CATALOG_PATH := "res://data/decisions/decision_catalog.tres"

var _failures: int = 0
var _checks: int = 0

func _initialize() -> void:
	_test_is_immediate()
	_test_delay_days()
	_test_is_due()
	_test_shipped_options_have_outcome()

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

func _test_is_immediate() -> void:
	# roll < prob → immédiat ; sinon différé. prob = 0.6 → ~60 % immédiat.
	_check("roll 0.0, prob 0.6 → immédiat", DRM.is_immediate(0.0, 0.6))
	_check("roll 0.59, prob 0.6 → immédiat", DRM.is_immediate(0.59, 0.6))
	_check("roll 0.6, prob 0.6 → différé (borne exclusive)", not DRM.is_immediate(0.6, 0.6))
	_check("roll 0.99, prob 0.6 → différé", not DRM.is_immediate(0.99, 0.6))
	# Bornes dégénérées : prob 0 → jamais immédiat ; prob 1 → toujours immédiat.
	_check("prob 0.0 → jamais immédiat", not DRM.is_immediate(0.0, 0.0))
	_check("prob 1.0 → toujours immédiat", DRM.is_immediate(0.999, 1.0))

func _test_delay_days() -> void:
	# Fenêtre [1,2] : roll bas → 1, roll haut → 2, toujours dans les bornes.
	_check("roll 0.0, [1,2] → 1", DRM.delay_days(0.0, 1, 2) == 1)
	_check("roll 0.999, [1,2] → 2", DRM.delay_days(0.999, 1, 2) == 2)
	_check("roll 1.0, [1,2] → 2 (borné)", DRM.delay_days(1.0, 1, 2) == 2)
	# Plage à une seule valeur.
	_check("[3,3] → 3", DRM.delay_days(0.5, 3, 3) == 3)
	# Dégénéré : max < min → renvoie min (défensif).
	_check("max<min → min (défensif)", DRM.delay_days(0.5, 2, 1) == 2)
	# Toujours dans [min,max] pour une rafale de rolls.
	var in_bounds: bool = true
	for i: int in 100:
		var r: float = float(i) / 100.0
		var d: int = DRM.delay_days(r, 1, 2)
		if d < 1 or d > 2:
			in_bounds = false
	_check("delay_days toujours ∈ [1,2]", in_bounds)

func _test_is_due() -> void:
	_check("due 3, courant 2 → pas échu", not DRM.is_due(3, 2))
	_check("due 3, courant 3 → échu", DRM.is_due(3, 3))
	_check("due 3, courant 4 → échu", DRM.is_due(3, 4))

func _test_shipped_options_have_outcome() -> void:
	var cat: Resource = load(CATALOG_PATH)
	_check("catalogue livré chargé", cat != null)
	if cat == null:
		return
	var all: Array = []
	all.append_array(cat.desk_decisions)
	all.append_array(cat.mail_decisions)
	var all_have_outcome: bool = true
	var any_nonzero: bool = false
	for dec: Decision in all:
		for opt: DecisionOption in dec.options:
			# Le champ doit exister et être un int (typé via @export).
			if typeof(opt.outcome) != TYPE_INT:
				all_have_outcome = false
			if opt.outcome != 0:
				any_nonzero = true
	_check("chaque option porte un outcome int", all_have_outcome)
	_check("au moins une option a un outcome non nul", any_nonzero)
