extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	for _frame in range(4):
		await process_frame
	main._setup_bout("bennet", "avigdor", 1, "LIVE INPUT DAMAGE QA")
	for _frame in range(4):
		await process_frame
	main.round_ready = true
	main.player.round_over = false
	main.enemy.round_over = false
	main.enemy.is_cpu = false
	main.enemy.input_block = true
	main.player.position = Vector3(-0.86, 0.0, 0.0)
	main.enemy.position = Vector3(0.86, 0.0, 0.0)
	var starting_health: float = main.enemy.health
	main._input_down["light"] = true
	for _frame in range(36):
		await physics_frame
	if main.enemy.health >= starting_health:
		return _fail("a live player attack against guard caused no chip damage")
	if not is_equal_approx(main.enemy_health_bar.value, main.enemy.health):
		return _fail("enemy HUD health did not follow live combat damage")
	main.enemy.input_block = false
	main.enemy.health = 1.0
	main.enemy.receive_hit(7.0, 1.0, "light")
	if main.enemy._visual.sprite.animation != "knockdown" or main.enemy._visual.sprite.is_playing():
		return _fail("the final blow did not leave the defeated fighter fallen on the floor")
	main.free()
	print("PASS: live combat damage")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
