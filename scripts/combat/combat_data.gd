extends RefCounted
class_name CombatData

const DEFAULT_PATH := "res://data/combat.json"
const REQUIRED_MOVES := ["light", "heavy", "kick", "special"]
const MOVE_NUMBER_FIELDS := ["duration", "startup", "active", "cancel_from", "cancel_to", "damage", "reach", "lunge"]
const MOTION_FIELDS := ["default_speed", "acceleration", "deceleration", "depth_speed", "depth_acceleration", "depth_deceleration", "crouch_speed_scale", "jump_velocity", "gravity", "guard_deceleration"]
const ECONOMY_FIELDS := ["special_cost", "damage_scale", "meter_hit_base", "meter_hit_damage_scale", "meter_blocked_attacker", "meter_defender_damage_scale"]
const KNOWN_CLIPS := ["jab", "hook", "kick"]
const PLAYABLE_IDS := ["bennet", "avigdor", "bibi", "yair_golan", "aryeh_deri", "yair_lapid", "mansour_abbas", "benny_gantz", "itamar_ben_gvir", "bezalel_smotrich", "gadi_eisenkot", "trump", "joint_list"]
const COMBO_PATH := "res://data/combos.json"

static var _cached: Dictionary = {}


static func load_data(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {}
	return (parsed as Dictionary).duplicate(true)


static func current() -> Dictionary:
	if _cached.is_empty():
		var loaded := load_data()
		var errors := validate(loaded)
		assert(errors.is_empty(), "Invalid combat data: %s" % errors)
		_cached = loaded.duplicate(true)
	return _cached.duplicate(true)


static func validate(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not _number_at_least(data, "input_buffer_seconds", 0.0):
		errors.append("input_buffer_seconds must be a finite non-negative number")
	_validate_number_section(data, "motion", MOTION_FIELDS, errors)
	_validate_number_section(data, "economy", ECONOMY_FIELDS, errors)
	if not data.has("fighter_speed_overrides") or not data.fighter_speed_overrides is Dictionary:
		errors.append("fighter_speed_overrides must be a dictionary")
	else:
		for fighter_id in data.fighter_speed_overrides:
			if str(fighter_id) not in PLAYABLE_IDS:
				errors.append("fighter_speed_overrides.%s is not a playable fighter" % fighter_id)
			elif not _is_non_negative_number(data.fighter_speed_overrides[fighter_id]):
				errors.append("fighter_speed_overrides.%s must be a finite non-negative number" % fighter_id)
	if not data.has("moves") or not data.moves is Dictionary:
		errors.append("moves must be a dictionary")
		return errors
	for move_id in REQUIRED_MOVES:
		if not data.moves.has(move_id) or not data.moves[move_id] is Dictionary:
			errors.append("moves.%s must be a dictionary" % move_id)
			continue
		_validate_move(move_id, data.moves[move_id], errors)
	var combo_file := FileAccess.open(COMBO_PATH, FileAccess.READ)
	var combo_parsed = JSON.parse_string(combo_file.get_as_text()) if combo_file != null else null
	if combo_parsed is Dictionary:
		errors.append_array(validate_combo_routes(data, combo_parsed))
	else:
		errors.append("could not load combo routes from %s" % COMBO_PATH)
	return errors


static func validate_combo_routes(data: Dictionary, combos: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data.has("moves") or not data.moves is Dictionary:
		return errors
	if not combos.has("routes") or not combos.routes is Dictionary:
		errors.append("combos.routes must be a dictionary")
		return errors
	for source_move in combos.routes:
		if str(source_move) not in data.moves:
			errors.append("combo route source uses unknown move %s" % source_move)
		var targets = combos.routes[source_move]
		if not targets is Array:
			errors.append("combo route %s must be an array" % source_move)
			continue
		for target_move in targets:
			if str(target_move) not in data.moves:
				errors.append("combo route %s uses unknown move %s" % [source_move, target_move])
	return errors


static func _validate_number_section(data: Dictionary, section: String, fields: Array, errors: PackedStringArray) -> void:
	if not data.has(section) or not data[section] is Dictionary:
		errors.append("%s must be a dictionary" % section)
		return
	var values: Dictionary = data[section]
	for field in fields:
		if not _number_at_least(values, field, 0.0):
			errors.append("%s.%s must be a finite non-negative number" % [section, field])


static func _validate_move(move_id: String, move: Dictionary, errors: PackedStringArray) -> void:
	for field in MOVE_NUMBER_FIELDS:
		if not _number_at_least(move, field, 0.0):
			errors.append("moves.%s.%s must be a finite non-negative number" % [move_id, field])
	if not move.has("clip") or str(move.clip) not in KNOWN_CLIPS:
		errors.append("moves.%s.clip must be one of %s" % [move_id, KNOWN_CLIPS])
	if not _has_valid_numbers(move, ["duration", "startup", "active", "cancel_from", "cancel_to"]):
		return
	var duration := float(move.duration)
	if float(move.startup) + float(move.active) > duration:
		errors.append("moves.%s active window exceeds duration" % move_id)
	if float(move.cancel_from) > float(move.cancel_to) or float(move.cancel_to) > duration:
		errors.append("moves.%s cancel window is outside duration" % move_id)


static func _number_at_least(data: Dictionary, key: String, minimum: float) -> bool:
	return data.has(key) and _is_non_negative_number(data[key]) and float(data[key]) >= minimum


static func _is_non_negative_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0


static func _has_valid_numbers(data: Dictionary, fields: Array) -> bool:
	for field in fields:
		if not data.has(field) or not _is_non_negative_number(data[field]):
			return false
	return true
