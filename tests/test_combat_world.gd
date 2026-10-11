extends SceneTree

const WORLD_PATH := "res://scripts/combat/combat_world.gd"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(ResourceLoader.exists(WORLD_PATH), "CombatWorld script is missing")
	var script: Script = load(WORLD_PATH)
	var first = script.new(37)
	var second = script.new(37)
	for tick in range(120):
		var inputs := {0: {"axis": 1.0 if tick < 30 else 0.0}, 1: {"axis": -1.0 if tick < 30 else 0.0}}
		first.step(tick, inputs)
		second.step(tick, inputs)
	assert(first.snapshot() == second.snapshot(), "same seed and inputs must replay identically")
	var checkpoint: Dictionary = first.snapshot()
	for tick in range(120, 240):
		first.step(tick, {})
	var expected: Dictionary = first.snapshot()
	second.restore(checkpoint)
	for tick in range(120, 240):
		second.step(tick, {})
	assert(second.snapshot() == expected, "restore must reproduce subsequent ticks")
	assert(not first.snapshot().has("node"), "snapshot must not contain Godot nodes")
	assert(first.has_method("set_hit_stop") and first.has_method("buffered_action"), "CombatWorld input-buffer API is missing")
	if not first.has_method("set_hit_stop") or not first.has_method("buffered_action"):
		quit(1)
		return
	first.set_hit_stop(0, 3)
	first.step(240, {0: {"attack": "light"}})
	first.step(241, {})
	first.step(242, {})
	assert(first.buffered_action(0) == "light", "hit-stop must preserve a pressed buffered attack")
	print("PASS: deterministic CombatWorld snapshot and replay")
	quit(0)
