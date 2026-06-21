extends SceneTree
## Runner de tests unitaires headless (sans dépendance d'éditeur ni autoload).
##   Lancer : godot --headless --path open_space --script res://tests/unit/test_agent_sim.gd
## Quitte avec le code 0 si tous les tests passent, 1 sinon.
##
## Cibles : logique PURE de la simulation d'agents de la Story 1.2 —
##   - NativeBrain.decide() (aller au poste / travailler / repartir)
##   - ActionRegistry.make() (parité, actions connues)
##   - DayPhaseMath (avance/rebouclage de phase, phase de départ, soir)
## En mode --script les autoloads ne sont PAS chargés : ces classes ne dépendent
## d'aucun autoload, donc elles compilent et s'exécutent ici (modèle CameraMath, S1.1).

const NativeBrainC := preload("res://scripts/agents/brain/native_brain.gd")
const AgentContextC := preload("res://scripts/agents/brain/agent_context.gd")
const ActionRegistryC := preload("res://scripts/agents/tools/action_registry.gd")
const DayPhaseMathC := preload("res://scripts/agents/day_phase_math.gd")

var _failures: int = 0
var _checks: int = 0

func _initialize() -> void:
	_test_native_brain_goes_to_post_then_works()
	_test_native_brain_leaves_in_evening()
	_test_action_registry_make_and_known()
	_test_day_phase_advance_and_wrap()
	_test_departure_phase_and_is_evening()

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

func _test_native_brain_goes_to_post_then_works() -> void:
	var brain := NativeBrainC.new()
	var not_arrived := AgentContextC.new(false, false)
	var a1: AgentAction = brain.decide(not_arrived)
	_check("pas encore au poste → go_to_post", a1.type == ActionRegistryC.GO_TO_POST)

	var arrived := AgentContextC.new(true, false)
	var a2: AgentAction = brain.decide(arrived)
	_check("au poste, journée → work", a2.type == ActionRegistryC.WORK)

func _test_native_brain_leaves_in_evening() -> void:
	var brain := NativeBrainC.new()
	# Le soir prime, qu'on soit arrivé au poste ou non.
	var evening_at_post := AgentContextC.new(true, true)
	_check("soir + au poste → leave", brain.decide(evening_at_post).type == ActionRegistryC.LEAVE)
	var evening_walking := AgentContextC.new(false, true)
	_check("soir + en route → leave", brain.decide(evening_walking).type == ActionRegistryC.LEAVE)

func _test_action_registry_make_and_known() -> void:
	var act: AgentAction = ActionRegistryC.make(ActionRegistryC.WORK)
	_check("make(WORK) renvoie une AgentAction typée WORK", act != null and act.type == ActionRegistryC.WORK)
	_check("WORK est une action connue", ActionRegistryC.is_known(ActionRegistryC.WORK))
	_check("action inconnue rejetée par is_known", not ActionRegistryC.is_known(&"defenestrate"))

func _test_day_phase_advance_and_wrap() -> void:
	# Journée de 10 s : avancer de 1 s → phase 0.1.
	var p: float = DayPhaseMathC.advance(0.0, 1.0, 10.0)
	_check("advance(0, 1s, 10s) → 0.1", is_equal_approx(p, 0.1))
	# Rebouclage : 0.95 + 1 s sur 10 s → 0.05, et has_wrapped vrai.
	var p2: float = DayPhaseMathC.advance(0.95, 1.0, 10.0)
	_check("advance rebouclage → ~0.05", is_equal_approx(p2, 0.05))
	_check("has_wrapped détecte le nouveau matin", DayPhaseMathC.has_wrapped(0.95, p2))
	_check("pas de wrap en journée normale", not DayPhaseMathC.has_wrapped(0.1, 0.2))
	# duration 0 → garde-fou, retourne 0.
	_check("duration 0 → 0 (garde-fou)", DayPhaseMathC.advance(0.4, 1.0, 0.0) == 0.0)

func _test_departure_phase_and_is_evening() -> void:
	# Deux archétypes : offset 0.0 (part tôt) vs 0.2 (part tard).
	var early: float = DayPhaseMathC.departure_phase(0.6, 0.0)
	var late: float = DayPhaseMathC.departure_phase(0.6, 0.2)
	_check("départ tôt = seuil du soir (0.6)", is_equal_approx(early, 0.6))
	_check("départ tard décalé (0.8)", is_equal_approx(late, 0.8))
	_check("départs échelonnés distincts", early < late)
	# À phase 0.7 : l'agent 'tôt' doit partir, le 'tard' non.
	_check("phase 0.7 ≥ départ tôt → soir", DayPhaseMathC.is_evening(0.7, early))
	_check("phase 0.7 < départ tard → pas encore", not DayPhaseMathC.is_evening(0.7, late))
	# Borne haute < 1.0.
	_check("phase de départ bornée < 1.0", DayPhaseMathC.departure_phase(0.95, 0.5) < 1.0)
