extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var script = load("res://scripts/combat/combat_data.gd")
	if script == null:
		return _fail("CombatData loader is missing")
	var data: Dictionary = script.load_data()
	var errors: PackedStringArray = script.validate(data)
	if not errors.is_empty():
		return _fail("shipped combat data is invalid: %s" % errors)
	if not is_equal_approx(float(data.moves.light.startup), 0.12):
		return _fail("JAB startup must preserve the 0.12 second baseline")
	if not is_equal_approx(float(data.motion.jump_velocity), 7.1):
		return _fail("jump velocity must preserve the 7.1 baseline")

	var malformed: Dictionary = data.duplicate(true)
	malformed.moves.light.active = 0.5
	malformed.moves.light.duration = 0.4
	var malformed_errors: PackedStringArray = script.validate(malformed)
	if not _contains_error(malformed_errors, "active window"):
		return _fail("validator accepted an active window beyond move duration")
	if not script.validated_data(malformed).is_empty():
		return _fail("validated loader accepted malformed numeric combat data")
	if not script.load_validated("res://tests/fixtures/does-not-exist.json").is_empty():
		return _fail("validated loader accepted a missing combat data file")

	var missing: Dictionary = data.duplicate(true)
	missing.erase("economy")
	var missing_errors: PackedStringArray = script.validate(missing)
	if not _contains_error(missing_errors, "economy"):
		return _fail("validator accepted missing economy data")

	var first: Dictionary = script.current()
	first.moves.light.damage = 999.0
	var second: Dictionary = script.current()
	if not is_equal_approx(float(second.moves.light.damage), 7.0):
		return _fail("mutating returned data changed the cached combat contract")

	var validator = script.new()
	if not validator.has_method("validate_combo_routes"):
		return _fail("combat data validator does not validate combo routes")
	var combos_file := FileAccess.open("res://data/combos.json", FileAccess.READ)
	var combos: Dictionary = JSON.parse_string(combos_file.get_as_text())
	var broken_combos: Dictionary = combos.duplicate(true)
	broken_combos.routes.light.append("unknown_attack")
	var route_errors: PackedStringArray = script.validate_combo_routes(data, broken_combos)
	if not _contains_error(route_errors, "unknown_attack"):
		return _fail("validator accepted a combo route with an unknown move")
	var extra_move: Dictionary = data.duplicate(true)
	extra_move.moves.unknown_attack = {}
	var extra_move_combos: Dictionary = combos.duplicate(true)
	extra_move_combos.routes.light.append("unknown_attack")
	var extra_move_errors: PackedStringArray = script.validate(extra_move, extra_move_combos)
	if not _contains_error(extra_move_errors, "moves.unknown_attack"):
		return _fail("validator accepted a malformed additional move used by a combo route")

	var unknown_fighter: Dictionary = data.duplicate(true)
	unknown_fighter.fighter_speed_overrides.ghost_fighter = 3.0
	var fighter_errors: PackedStringArray = script.validate(unknown_fighter)
	if not _contains_error(fighter_errors, "ghost_fighter"):
		return _fail("validator accepted an unknown fighter speed override")
	print("PASS: combat data values, validation and copy isolation")
	quit(0)


func _contains_error(errors: PackedStringArray, fragment: String) -> bool:
	for message in errors:
		if fragment.to_lower() in message.to_lower():
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
