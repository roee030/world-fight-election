extends SceneTree

const FighterVisualScript = preload("res://scripts/fighter_visual.gd")


func _init() -> void:
	for fighter_id in FighterVisualScript.TWELVE_FRAME_IDS:
		assert(FighterVisualScript._has_transition_set(fighter_id), "%s complete transition batch was not detected" % fighter_id)
		var canonical: Dictionary = FighterVisualScript._clip_map(fighter_id)
		for clip in ["jab", "cross", "kick"]:
			var sequence: Array = FighterVisualScript._presentation_sequence(fighter_id, clip, canonical[clip])
			assert(sequence.size() >= 12, "%s %s did not gain presentation frames" % [fighter_id, clip])
			assert(sequence.any(func(frame): return frame is String), "%s %s does not use supplemental drawings" % [fighter_id, clip])
		var visual := FighterVisualScript.build(fighter_id)
		for clip in ["jab", "cross", "kick"]:
			var frames: SpriteFrames = visual.sprite.sprite_frames
			assert(frames.get_frame_count(clip) >= 12)
			var supplemental := false
			for index in range(frames.get_frame_count(clip)):
				var texture := frames.get_frame_texture(clip, index)
				if texture != null and texture.resource_path.contains("/transitions/"):
					supplemental = true
			assert(supplemental, "%s %s did not load supplemental textures" % [fighter_id, clip])
		visual.root.free()

	var fallback: Array = [0, 1, 4, 0]
	assert(FighterVisualScript._presentation_sequence("missing_fighter", "jab", fallback) == fallback, "missing transition art must keep canonical animation")
	print("PASS: optional transition art extends animation and preserves fallback")
	quit(0)
