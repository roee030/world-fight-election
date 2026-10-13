extends SceneTree

const DT := 1.0 / 60.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(4):
		await process_frame
	main._setup_bout("bennet", "avigdor", 1, "COMBAT DATA RUNTIME QA")
	for _frame in range(5):
		await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.player.set_physics_process(false)
	main.enemy.set_physics_process(false)
	if not _has_property(main.player, "combat_data"):
		main.free()
		return _fail("fighter has no injectable combat_data snapshot")

	var fixture: Dictionary = load("res://scripts/combat/combat_data.gd").current()
	fixture.input_buffer_seconds = 0.1
	fixture.motion.default_speed = 1.0
	fixture.moves.light.damage = 20.0
	fixture.economy.damage_scale = 0.5
	main.player.combat_data = fixture.duplicate(true)
	main.enemy.combat_data = fixture.duplicate(true)
	main.player.is_cpu = false
	main.enemy.is_cpu = false
	main.player.reset_round(-0.55, 100.0, true)
	main.enemy.reset_round(0.55, 100.0, true)

	main.player.busy = 1.0
	main.player.set_controls(0.0, false, false, false, "light")
	main.player._physics_process(DT)
	if main.player.buffer_time > 0.09:
		main.free()
		return _fail("fighter ignored fixture input buffer duration: %.3f" % main.player.buffer_time)
	main.player.busy = 0.0
	main.player.buffered_attack = ""
	main.player.buffer_time = 0.0

	main.player.position = Vector3(-3.0, 0.0, 0.0)
	main.enemy.position = Vector3(3.0, 0.0, 0.0)
	main.player.set_controls(1.0, false, false, false, "")
	for _frame in range(20):
		main.player._physics_process(DT)
	if not is_equal_approx(main.player.velocity.x, 1.0):
		main.free()
		return _fail("fighter ignored fixture movement speed: %.3f" % main.player.velocity.x)

	main.player.round_over = true
	main.player.velocity.x = 10.0
	main.player._physics_process(0.1)
	if not is_equal_approx(main.player.velocity.x, 8.8):
		var stopped_speed: float = main.player.velocity.x
		main.free()
		return _fail("round-over deceleration must preserve the 12.0 baseline: %.3f" % stopped_speed)
	main.player.round_over = false

	main.player.reset_round(-0.55, 100.0, true)
	main.enemy.reset_round(0.55, 100.0, true)
	main.player.set_controls(0.0, false, false, false, "light")
	for _frame in range(45):
		main.player._physics_process(DT)
		main.enemy._physics_process(DT)
	var damage: float = 100.0 - float(main.enemy.health)
	main.free()
	if not is_equal_approx(damage, 10.0):
		return _fail("fighter ignored fixture move damage/scale: %.3f" % damage)
	print("PASS: fighter runtime consumes injected combat data")
	quit(0)


func _has_property(object: Object, property_name: String) -> bool:
	for entry in object.get_property_list():
		if entry.name == property_name:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
