extends SceneTree

## Punch clips must never show the kick pose. In the 12-frame contract frame 6
## is the signature kick; the heavy "hook" clip once played cross -> kick, so
## one K press looked like a punch and a kick.

const FighterVisualScript = preload("res://scripts/fighter_visual.gd")
const CROUCH_FRAME := 3
const KICK_FRAME := 6
const PUNCH_CLIPS := ["jab", "cross", "hook"]
const ATTACK_CLIPS := ["jab", "cross", "hook", "kick"]


func _init() -> void:
	for id in FighterVisualScript.TWELVE_FRAME_IDS:
		var clips: Dictionary = FighterVisualScript._clip_map(id)
		for clip in PUNCH_CLIPS:
			if KICK_FRAME in clips[clip]:
				push_error("%s %s clip contains the kick frame: %s" % [id, clip, clips[clip]])
				quit(1)
				return
		if not KICK_FRAME in clips.kick:
			push_error("%s kick clip lost its kick frame" % id)
			quit(1)
			return
		if CROUCH_FRAME in clips.kick:
			push_error("%s kick clip contains the crouch pose: %s" % [id, clips.kick])
			quit(1)
			return
		# A strike needs anticipation and recovery poses around its contact pose.
		# Repeating idle/impact alone reads like a slideshow even when played at
		# 60 Hz, because the silhouette only changes once in each direction.
		for clip in ATTACK_CLIPS:
			var sequence: Array = clips[clip]
			var unique_frames: Dictionary = {}
			for frame in sequence: unique_frames[frame] = true
			if sequence.size() < 10 or unique_frames.size() < 4:
				push_error("%s %s needs at least 10 presentation frames and 4 distinct poses: %s" % [id, clip, sequence])
				quit(1)
				return
	# Every move maps to the intended clip family.
	var moves: Dictionary = load("res://scripts/fighter.gd").MOVES
	if str(moves.light.clip) != "jab" or str(moves.heavy.clip) not in PUNCH_CLIPS or str(moves.kick.clip) != "kick":
		push_error("move-to-clip mapping drifted: %s" % moves)
		quit(1)
		return
	print("PASS: punch clips never show the kick pose")
	quit(0)
