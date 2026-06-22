extends SceneTree
## Runner de tests unitaires headless (sans dépendance d'éditeur ni autoload).
##   Lancer : godot --headless --path open_space --script res://tests/unit/test_decision.gd
## Quitte avec le code 0 si tous les tests passent, 1 sinon.
##
## Cible : la logique PURE des décisions (Story 1.5) —
##   - DecisionMath.is_valid_option_count (invariant 2-3 options, AC#1)
##   - DecisionMath.pick_index (bornes, déterminisme)
##   - DecisionCatalog.pick (bon canal, fallback, catalogue vide)
## + l'invariant "chaque décision du catalogue livré a 2-3 options".

const DM := preload("res://scripts/decisions/decision_math.gd")
const DEC := preload("res://scripts/decisions/decision.gd")
const OPT := preload("res://scripts/decisions/decision_option.gd")
const CAT := preload("res://scripts/decisions/decision_catalog.gd")
const SOL := preload("res://scripts/decisions/solicitation.gd")

const CATALOG_PATH := "res://data/decisions/decision_catalog.tres"

var _failures: int = 0
var _checks: int = 0

func _initialize() -> void:
	_test_is_valid_option_count()
	_test_pick_index_bounds()
	_test_catalog_pick_channel()
	_test_catalog_pick_fallback()
	_test_catalog_empty()
	_test_shipped_catalog_invariants()

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

func _test_is_valid_option_count() -> void:
	_check("0 options → invalide", not DM.is_valid_option_count(0))
	_check("1 option → invalide", not DM.is_valid_option_count(1))
	_check("2 options → valide", DM.is_valid_option_count(2))
	_check("3 options → valide", DM.is_valid_option_count(3))
	_check("4 options → invalide", not DM.is_valid_option_count(4))

func _test_pick_index_bounds() -> void:
	# roll ∈ [0,1) sur 3 éléments → 0 / 1 / 2 selon le tiers.
	_check("roll 0.0, count 3 → 0", DM.pick_index(0.0, 3) == 0)
	_check("roll 0.5, count 3 → 1", DM.pick_index(0.5, 3) == 1)
	_check("roll 0.99, count 3 → 2", DM.pick_index(0.99, 3) == 2)
	# Bornes défensives : roll 1.0 ne sort pas du tableau ; count<=0 → 0.
	_check("roll 1.0, count 3 → 2 (borné)", DM.pick_index(1.0, 3) == 2)
	_check("count 0 → 0 (défensif)", DM.pick_index(0.5, 0) == 0)

func _test_catalog_pick_channel() -> void:
	var cat: Resource = CAT.new()
	cat.desk_decisions.assign([_make_decision("desk", ["A", "B"])])
	cat.mail_decisions.assign([_make_decision("mail", ["C", "D"])])
	var desk: Decision = cat.pick(SOL.Channel.DESK, 0.0)
	var mail: Decision = cat.pick(SOL.Channel.MAIL, 0.0)
	_check("pick DESK → décision DESK", desk != null and desk.context_text == "desk")
	_check("pick MAIL → décision MAIL", mail != null and mail.context_text == "mail")

func _test_catalog_pick_fallback() -> void:
	# Canal demandé vide → bascule sur l'autre liste (jamais null si l'autre est peuplée).
	var cat: Resource = CAT.new()
	cat.mail_decisions.assign([_make_decision("mail-only", ["A", "B"])])
	var desk: Decision = cat.pick(SOL.Channel.DESK, 0.0)
	_check("DESK vide → fallback MAIL", desk != null and desk.context_text == "mail-only")

func _test_catalog_empty() -> void:
	var cat: Resource = CAT.new()
	_check("catalogue vide → null", cat.pick(SOL.Channel.DESK, 0.0) == null)

func _test_shipped_catalog_invariants() -> void:
	var cat: Resource = load(CATALOG_PATH)
	_check("catalogue livré chargé", cat != null)
	if cat == null:
		return
	var all: Array = []
	all.append_array(cat.desk_decisions)
	all.append_array(cat.mail_decisions)
	_check("catalogue livré non vide", all.size() >= 2)
	var all_valid: bool = true
	for dec: Decision in all:
		if not DM.is_valid_option_count(dec.options.size()):
			all_valid = false
			printerr("    décision '%s' a %d options" % [dec.context_text, dec.options.size()])
	_check("chaque décision livrée a 2-3 options", all_valid)

func _make_decision(context: String, labels: Array) -> Decision:
	var dec: Decision = DEC.new()
	dec.context_text = context
	var opts: Array[DecisionOption] = []
	for label: String in labels:
		var opt: DecisionOption = OPT.new()
		opt.label = label
		opts.append(opt)
	dec.options.assign(opts)
	return dec
