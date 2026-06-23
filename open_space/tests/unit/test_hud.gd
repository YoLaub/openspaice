extends SceneTree
## Runner de tests unitaires headless (sans dépendance d'éditeur ni autoload).
##   Lancer : godot --headless --path open_space --script res://tests/unit/test_hud.gd
## Quitte avec le code 0 si tous les tests passent, 1 sinon.
##
## Cible : la logique PURE d'agrégation/seuils du HUD (Story 1.8) —
##   - HudMath.average_morale     (moyenne entière, sentinelle -1 si vide)
##   - HudMath.morale_severity    (seuils alerte/critique, défensif sur vide)
##   - HudMath.attention_severity (seuil de charge file+mails)

const HM := preload("res://scripts/ui/hud_math.gd")

var _failures: int = 0
var _checks: int = 0

func _initialize() -> void:
	_test_average_morale()
	_test_morale_severity()
	_test_attention_severity()

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

func _test_average_morale() -> void:
	# Vide → sentinelle -1 (« aucun agent » → le HUD affiche « — »).
	_check("[] → -1 (sentinelle vide)", HM.average_morale([]) == -1)
	_check("[100] → 100", HM.average_morale([100]) == 100)
	_check("[100, 50] → 75", HM.average_morale([100, 50]) == 75)
	# Arrondi entier : (100+99+98)/3 = 99.0
	_check("[100, 99, 98] → 99 (arrondi)", HM.average_morale([100, 99, 98]) == 99)
	# Arrondi : (100+99)/2 = 99.5 → 100
	_check("[100, 99] → 100 (arrondi 99.5)", HM.average_morale([100, 99]) == 100)
	_check("[0, 0] → 0", HM.average_morale([0, 0]) == 0)

func _test_morale_severity() -> void:
	# Seuils : alerte sous 50, critique sous 25.
	var warn: int = 50
	var crit: int = 25
	_check("80 → NORMAL", HM.morale_severity(80, warn, crit) == HM.Severity.NORMAL)
	_check("50 → NORMAL (borne exclusive)", HM.morale_severity(50, warn, crit) == HM.Severity.NORMAL)
	_check("49 → WARNING", HM.morale_severity(49, warn, crit) == HM.Severity.WARNING)
	_check("25 → WARNING (borne exclusive critique)", HM.morale_severity(25, warn, crit) == HM.Severity.WARNING)
	_check("24 → CRITICAL", HM.morale_severity(24, warn, crit) == HM.Severity.CRITICAL)
	_check("0 → CRITICAL", HM.morale_severity(0, warn, crit) == HM.Severity.CRITICAL)
	# Défensif : sentinelle vide (-1) → pas d'alerte sans agent.
	_check("-1 (vide) → NORMAL (défensif)", HM.morale_severity(-1, warn, crit) == HM.Severity.NORMAL)

func _test_attention_severity() -> void:
	# Charge d'attention = file + mails ; alerte au-delà du seuil (>=).
	var warn_at: int = 3
	_check("0 → NORMAL", HM.attention_severity(0, warn_at) == HM.Severity.NORMAL)
	_check("2 → NORMAL", HM.attention_severity(2, warn_at) == HM.Severity.NORMAL)
	_check("3 → WARNING (seuil inclus)", HM.attention_severity(3, warn_at) == HM.Severity.WARNING)
	_check("5 → WARNING", HM.attention_severity(5, warn_at) == HM.Severity.WARNING)
	# Défensif : seuil 0 → jamais d'alerte (évite une alerte permanente).
	_check("seuil 0 → NORMAL (défensif)", HM.attention_severity(1, 0) == HM.Severity.NORMAL)
