extends SceneTree

const StageReactivity = preload("res://scripts/stages/stage_reactivity.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var main = scene.instantiate()
	get_root().add_child(main)
	await process_frame

	var reaction = StageReactivity.new()
	get_root().add_child(reaction)
	if reaction.process_mode != Node.PROCESS_MODE_PAUSABLE:
		return _fail("stage reaction would keep advancing while the scene tree is paused")

	for stage in main.STAGES:
		reaction.configure(stage)
		var expected := Color(str(stage.accent))
		var left := reaction.get_node_or_null("LeftPulse") as OmniLight3D
		var right := reaction.get_node_or_null("RightPulse") as OmniLight3D
		if left == null or right == null:
			return _fail("stage reaction must use exactly two reusable pulse lights")
		if left.light_color != expected or right.light_color != expected:
			return _fail("stage %s did not use its authored accent" % stage.id)
		if not is_zero_approx(left.light_energy) or not is_zero_approx(right.light_energy):
			return _fail("configuring stage %s did not reset its pulse" % stage.id)
		var expected_prop := "StudioSweep" if stage.kind == "studio" else ("StreetDust" if stage.kind == "street" else "CrowdWave")
		var prop_root := reaction.get_node_or_null(expected_prop) as Node3D
		if prop_root == null or prop_root.get_child_count() < 3:
			return _fail("stage %s did not build its interactive %s props" % [stage.id, expected_prop])
		if reaction.get_node_or_null("StudioSweep" if expected_prop != "StudioSweep" else "StreetDust") != null:
			return _fail("stage %s kept props from another stage kind" % stage.id)

	reaction.configure(main.STAGES[0])
	var crowd := reaction.get_node("CrowdWave") as Node3D
	var crowd_start := (crowd.get_child(0) as MeshInstance3D).position
	reaction.react_to_strike("light", false, 1)
	reaction.advance(0.08)
	if (crowd.get_child(0) as MeshInstance3D).position.is_equal_approx(crowd_start):
		return _fail("a strike did not move the stage-specific background prop")
	var light_energy := (reaction.get_node("LeftPulse") as OmniLight3D).light_energy
	var left_glow := reaction.get_node_or_null("LeftGlow") as MeshInstance3D
	var right_glow := reaction.get_node_or_null("RightGlow") as MeshInstance3D
	if left_glow == null or right_glow == null:
		return _fail("stage reaction has no visible presentation surface for unshaded stage art")
	if left_glow.position.z <= -7.2 or left_glow.position.y > 1.6:
		return _fail("stage glow sits behind the tilted backplate or above the fight lane")
	var glow_material := left_glow.material_override as ShaderMaterial
	if glow_material == null or float(glow_material.get_shader_parameter("strength")) <= 0.0:
		return _fail("a strike did not make the stage glow surface visible")
	reaction.configure(main.STAGES[0])
	reaction.react_to_strike("heavy", false, 1)
	var heavy_energy := (reaction.get_node("LeftPulse") as OmniLight3D).light_energy
	if heavy_energy <= light_energy:
		return _fail("heavy strike did not create a stronger stage response than a jab")

	reaction.configure(main.STAGES[0])
	reaction.react_to_strike("heavy", true, 1)
	var blocked_energy := (reaction.get_node("LeftPulse") as OmniLight3D).light_energy
	if blocked_energy >= heavy_energy or blocked_energy <= 0.0:
		return _fail("blocked strike response must be visible and quieter than a clean hit")

	reaction.configure(main.STAGES[0])
	reaction.react_to_strike("kick", false, 5)
	var capped_combo_energy := (reaction.get_node("LeftPulse") as OmniLight3D).light_energy
	reaction.configure(main.STAGES[0])
	reaction.react_to_strike("kick", false, 500)
	if not is_equal_approx((reaction.get_node("LeftPulse") as OmniLight3D).light_energy, capped_combo_energy):
		return _fail("combo contribution to stage response is not capped")

	for i in range(20):
		reaction.react_to_strike("special", false, 500)
	var peak_energy := (reaction.get_node("LeftPulse") as OmniLight3D).light_energy
	if peak_energy > 1.15 + 0.001:
		return _fail("repeated stage impulses exceeded the Web/mobile light budget")
	reaction.advance(0.25)
	var decayed_energy := (reaction.get_node("LeftPulse") as OmniLight3D).light_energy
	if decayed_energy >= peak_energy or decayed_energy < 0.0:
		return _fail("stage response did not decay deterministically")
	if not is_equal_approx(decayed_energy, (reaction.get_node("RightPulse") as OmniLight3D).light_energy):
		return _fail("stage pulse lights drifted to different energies")

	main._setup_bout("bennet", "avigdor", 1, "STAGE REACTION QA")
	await process_frame
	main.round_ready = true
	var live_reaction = main._stage_reactivity
	if live_reaction == null or live_reaction.get_parent() != main._arena:
		return _fail("selected stage did not build its reaction controller")
	var before := (live_reaction.get_node("LeftPulse") as OmniLight3D).light_energy
	main._on_strike_landed(0, 1, "heavy", false, 2)
	if (live_reaction.get_node("LeftPulse") as OmniLight3D).light_energy <= before:
		return _fail("real strike signal was not forwarded to the stage")

	reaction.free()
	main.free()
	print("PASS: six stages own bounded, deterministic, pause-safe strike lighting")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	paused = false
	quit(1)
