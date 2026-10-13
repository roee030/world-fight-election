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
