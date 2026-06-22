extends SceneTree
## Runner de tests unitaires headless (sans dépendance d'éditeur ni autoload).
##   Lancer : godot --headless --path open_space --script res://tests/unit/test_solicitation_math.gd
## Quitte avec le code 0 si tous les tests passent, 1 sinon.
##
## Cible : les fonctions pures de SolicitationMath (déclenchement should_raise et
## choix de canal channel_for_roll) + l'enum Solicitation.Channel — cœur logique de
## la cadence des sollicitations (Story 1.4, AC#1/#2/#4).

const SM := preload("res://scripts/decisions/solicitation_math.gd")
const SOL := preload("res://scripts/decisions/solicitation.gd")

var _failures: int = 0
var _checks: int = 0

func _initialize() -> void:
	_test_should_raise()
	_test_should_raise_clamps_rate()
	_test_channel_for_roll()
	_test_channel_bounds()
	_test_channel_enum_values()

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

func _test_should_raise() -> void:
	# roll strictement sous le taux → déclenche ; au-dessus ou égal → non.
	_check("roll 0.05 < taux 0.1 → déclenche", SM.should_raise(0.05, 0.1))
	_check("roll 0.20 >= taux 0.1 → ne déclenche pas", not SM.should_raise(0.20, 0.1))
	_check("roll 0.10 == taux 0.1 → ne déclenche pas (strict)", not SM.should_raise(0.10, 0.1))

func _test_should_raise_clamps_rate() -> void:
	# Taux hors [0,1] ne casse pas la logique.
	_check("taux 0.0 → jamais", not SM.should_raise(0.0, 0.0))
	_check("taux 2.0 borné à 1.0 → tout roll<1 déclenche", SM.should_raise(0.999, 2.0))
	_check("taux -1.0 borné à 0.0 → jamais", not SM.should_raise(0.0, -1.0))

func _test_channel_for_roll() -> void:
	_check("roll 0.1 < p 0.4 → DESK", SM.channel_for_roll(0.1, 0.4) == SOL.Channel.DESK)
	_check("roll 0.5 >= p 0.4 → MAIL", SM.channel_for_roll(0.5, 0.4) == SOL.Channel.MAIL)

func _test_channel_bounds() -> void:
	# p=0.0 → toujours MAIL ; p=1.0 → toujours DESK.
	_check("p 0.0 → MAIL", SM.channel_for_roll(0.0, 0.0) == SOL.Channel.MAIL)
	_check("p 1.0 → DESK", SM.channel_for_roll(0.999, 1.0) == SOL.Channel.DESK)

func _test_channel_enum_values() -> void:
	_check("Channel.DESK == 0", SOL.Channel.DESK == 0)
	_check("Channel.MAIL == 1", SOL.Channel.MAIL == 1)
