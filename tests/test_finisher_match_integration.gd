extends SceneTree

class TestCatalog extends RefCounted:
	var definition := {"implemented": true, "meter_cost": 100, "trigger_health_ratio": 0.15, "activation_range": 1.75, "duration": 1.0, "celebration_id": "test", "events": [{"at": 0.0, "type": "portrait_lightbox"}, {"at": 0.5, "type": "hit", "id": "finish", "damage": 999, "final": true, "reaction": "finish_fall"}, {"at": 1.0, "type": "celebration_start"}]}
	func definition_for(_id: String) -> Dictionary:
		return definition.duplicate(true)
	func celebration_for(_id: String) -> Dictionary:
		return {"duration": 2.0, "events": [{"at": 2.0, "type": "result_marker"}]}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	if not main.has_method("_try_begin_finisher"):
		push_error("match finisher integration missing")
		main.free()
		quit(1)
		return
	main._finisher_catalog = TestCatalog.new()
	main._setup_bout("bennet", "avigdor", 1, "FINISHER QA")
	main.enemy.is_cpu = false
	for frame in range(95): await physics_frame
	main.player.position.x = -3.0
	main.enemy.position.x = 3.0
	main.player.meter = 100.0
	main.enemy.health = main.enemy.max_health()
	main.player_rounds = 0
	main.match_state = main.MatchState.Value.FIGHTING
	main.round_ready = true
	var far_health: float = main.enemy.health
	main.buttons.special.emit_signal("button_down")
	main.buttons.special.emit_signal("button_up")
	assert(main._finisher_director.active, "100% FINISH did not activate on one press in round one")
	main._process(0.6)
	assert(main.enemy.health == far_health, "out-of-range finisher damaged the defender")
	assert(not main._finisher_director.active and main.match_state == main.MatchState.Value.FIGHTING, "missed finisher did not resume combat")
	assert(is_equal_approx(main.player.position.x, -3.0) and is_equal_approx(main.enemy.position.x, 3.0), "missed finisher moved distant fighters together")
	main.player.position.x = -0.6
	main.enemy.position.x = 0.6
	main.player.meter = 100.0
	main.enemy.health = main.enemy.max_health()
	main._input_down["special"] = true
	main._physics_process(0.016)
	assert(main.match_state == main.MatchState.Value.FINISHER_CINEMATIC)
	assert(main._finisher_director.active, "keyboard Special did not activate the finisher on one press")
	var clock: float = main.round_clock
	main._process(0.2)
	assert(main.round_clock == clock)
	main._toggle_pause()
	var elapsed: float = main._finisher_director.timeline.elapsed()
	main._process(1.0)
	assert(main._finisher_director.timeline.elapsed() == elapsed)
	main._toggle_pause()
	main._process(0.8)
	assert(main.enemy.health == 0.0)
	assert(main.player_rounds == 1)
	assert(main.match_state == main.MatchState.Value.CELEBRATION)
	assert(not main.result_root.visible)
	main._process(2.99)
	assert(not main.result_root.visible, "finisher result bypassed the clear celebration interval")
	main._process(2.01)
	assert(main.result_root.visible and main.match_state == main.MatchState.Value.RESULT)
	assert(main._finisher_director.temporary_actor_count() == 0)
	main.free()
	print("PASS: real match finisher locks, timer/pause, KO, celebration and result")
	quit(0)
