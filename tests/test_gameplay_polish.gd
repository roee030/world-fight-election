extends SceneTree

const GameFighter = preload("res://scripts/fighter.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := Node3D.new()
	get_root().add_child(arena)
	var attacker := GameFighter.new()
	var victim := GameFighter.new()
	attacker.setup("bennet", 0, false)
	victim.setup("avigdor", 1, false)
	arena.add_child(attacker)
	arena.add_child(victim)
	attacker.rival = victim
	victim.rival = attacker
	attacker.position = Vector3(-0.55, 0.0, 0.0)
	victim.position = Vector3(0.55, 0.0, 0.0)
	attacker.facing = 1.0
	attacker._start_attack("light")
	var health_before := victim.health
	attacker._try_hit()
	if victim.health >= health_before:
		return _fail("a real attack window did not reduce rival health")
	if victim._visual.sprite.animation != "hit":
		return _fail("a landed attack did not show the rival hit reaction")
	if attacker.meter <= 0.0:
		return _fail("a landed attack did not charge the special meter")

	attacker.position.y = 1.25
	attacker._animate()
	if absf(attacker._visual.shadow.global_position.y - 0.018) > 0.03:
		return _fail("fighter shadow rises away from the floor during a jump")

	var scene := load("res://scenes/main.tscn") as PackedScene
	var main = scene.instantiate()
	get_root().add_child(main)
	await process_frame
	var chamber: Dictionary = main._stage_data("knesset_chamber")
	if float(chamber.get("backdrop_y", 0.0)) <= 0.0:
		return _fail("Knesset chamber has no floor-line alignment correction")
	main.fight_live = true
	main._toggle_pause()
	if not main.paused or not paused or not main.pause_root.visible:
		return _fail("pause menu does not pause the scene tree")
	main._toggle_pause()
	if paused:
		return _fail("resume did not unpause the scene tree")

	main.free()
	arena.free()
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	paused = false
	quit(1)
