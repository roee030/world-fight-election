extends SceneTree

const IDS := ["bennet", "avigdor", "bibi", "yair_golan", "aryeh_deri", "yair_lapid", "mansour_abbas", "benny_gantz", "itamar_ben_gvir", "bezalel_smotrich", "gadi_eisenkot", "trump", "joint_list"]
const MOVES := ["light", "heavy", "kick", "special"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var profiles_script = load("res://scripts/combat/fighter_animation_profiles.gd")
	if profiles_script == null:
		return _fail("fighter animation profile loader is missing")
	var data: Dictionary = profiles_script.current()
	var errors: PackedStringArray = profiles_script.validate(data)
	if not errors.is_empty():
		return _fail("shipped fighter animation profiles are invalid: %s" % errors)
	if int(data.presentation_fps) < 60:
		return _fail("attack presentation must provide at least 60 motion samples per second")
	var signatures := {}
	for fighter_id in IDS:
		if not data.profiles.has(fighter_id):
			return _fail("missing attack identity for %s" % fighter_id)
		var profile: Dictionary = data.profiles[fighter_id]
		for move_id in MOVES:
			if not profile.moves.has(move_id):
				return _fail("%s has no %s presentation" % [fighter_id, move_id])
		var signature := JSON.stringify(profile.moves)
		if signatures.has(signature):
			return _fail("%s duplicates %s attack identity" % [fighter_id, signatures[signature]])
		signatures[signature] = fighter_id
		var visual := FighterVisual.build(fighter_id)
		for clip in ["jab", "cross", "hook", "kick"]:
			if visual.sprite.sprite_frames.get_frame_count(clip) < 8:
				visual.root.free()
				return _fail("%s %s has fewer than eight display frames" % [fighter_id, clip])
		visual.root.free()

	var fast := FighterVisual.build("yair_lapid")
	var heavy := FighterVisual.build("benny_gantz")
	fast.motion.start_attack("heavy", 0.66)
	heavy.motion.start_attack("heavy", 0.66)
	fast.motion._process(0.20)
	heavy.motion._process(0.20)
	if fast.sprite.position.is_equal_approx(heavy.sprite.position) and is_equal_approx(fast.sprite.rotation.z, heavy.sprite.rotation.z):
		fast.root.free(); heavy.root.free()
		return _fail("distinct profiles produced identical heavy presentation")
	fast.motion.freeze_motion(true)
	var frozen_position: Vector3 = fast.sprite.position
	fast.motion._process(0.20)
	if not fast.sprite.position.is_equal_approx(frozen_position):
		fast.root.free(); heavy.root.free()
		return _fail("attack in-between motion ignored pause/hit-stop freeze")
	fast.root.free(); heavy.root.free()
	print("PASS: all fighters have unique, smooth, pause-safe attack presentation")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
