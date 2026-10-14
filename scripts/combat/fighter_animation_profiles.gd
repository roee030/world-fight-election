extends RefCounted
class_name FighterAnimationProfiles

const DEFAULT_PATH := "res://data/fighter_animation_profiles.json"
const IDS := ["bennet", "avigdor", "bibi", "yair_golan", "aryeh_deri", "yair_lapid", "mansour_abbas", "benny_gantz", "itamar_ben_gvir", "bezalel_smotrich", "gadi_eisenkot", "trump", "joint_list"]
const MOVES := ["light", "heavy", "kick", "special"]
const FIELDS := ["drive", "lift", "tilt_deg", "squash", "recoil"]
static var _cached: Dictionary = {}


static func load_data(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


static func current() -> Dictionary:
	if _cached.is_empty():
		var loaded := load_data()
		var errors := validate(loaded)
		if not errors.is_empty():
			push_error("Invalid fighter animation profiles: %s" % errors)
			return {}
		_cached = loaded.duplicate(true)
	return _cached.duplicate(true)


static func profile_for(fighter_id: String) -> Dictionary:
	var data := current()
	return data.get("profiles", {}).get(fighter_id, {}).duplicate(true)


static func validate(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data.has("presentation_fps") or not (data.presentation_fps is int or data.presentation_fps is float) or not is_finite(float(data.presentation_fps)) or int(data.presentation_fps) < 60 or not is_equal_approx(float(data.presentation_fps), float(int(data.presentation_fps))):
		errors.append("presentation_fps must be an integer-valued number of at least 60")
	if not data.has("profiles") or not data.profiles is Dictionary:
		errors.append("profiles must be a dictionary")
		return errors
	for fighter_id in IDS:
		if not data.profiles.has(fighter_id) or not data.profiles[fighter_id] is Dictionary:
			errors.append("profiles.%s must be a dictionary" % fighter_id)
			continue
		var profile: Dictionary = data.profiles[fighter_id]
		if str(profile.get("style", "")).is_empty(): errors.append("profiles.%s.style is required" % fighter_id)
		if not profile.has("moves") or not profile.moves is Dictionary:
			errors.append("profiles.%s.moves must be a dictionary" % fighter_id)
			continue
		for move_id in MOVES:
			if not profile.moves.has(move_id) or not profile.moves[move_id] is Dictionary:
				errors.append("profiles.%s.moves.%s must be a dictionary" % [fighter_id, move_id])
				continue
			var move: Dictionary = profile.moves[move_id]
			for field in FIELDS:
				if not move.has(field) or not (move[field] is int or move[field] is float) or not is_finite(float(move[field])):
					errors.append("profiles.%s.moves.%s.%s must be finite" % [fighter_id, move_id, field])
				elif field != "tilt_deg" and float(move[field]) < 0.0:
					errors.append("profiles.%s.moves.%s.%s must be non-negative" % [fighter_id, move_id, field])
	return errors
