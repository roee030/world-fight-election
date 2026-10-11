extends SceneTree

const CombatWorld := preload("res://scripts/combat/combat_world.gd")

func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run() -> void:
	var world := CombatWorld.new(11)
	world.fighters[0].x = -0.6
	world.fighters[1].x = 0.6
	var hit_events: Array[Dictionary] = []
	var hit_stop_seen := false
	for tick in range(18):
		var events: Array[Dictionary] = world.step(tick, {0: {"attack": "jab"} if tick == 0 else {}})
		for event in events:
			if event.type == "hit":
				hit_events.append(event)
				hit_stop_seen = int(world.fighters[0].hit_stop) > 0 and int(world.fighters[1].hit_stop) > 0
	if hit_events.size() != 1:
		_fail("A close jab must produce exactly one hit event")
		return
	if float(world.fighters[1].health) >= 100.0:
		_fail("A hit event must reduce the defender's health")
		return
	if not hit_stop_seen:
		_fail("A confirmed hit must apply hit-stop to both fighters")
		return
	var distant := CombatWorld.new(11)
	distant.fighters[0].x = -3.0
	distant.fighters[1].x = 3.0
	var distant_events: Array[Dictionary] = []
	for tick in range(18):
		distant_events.append_array(distant.step(tick, {0: {"attack": "jab"} if tick == 0 else {}}))
	if distant_events.any(func(event): return event.type == "hit"):
		_fail("An out-of-range jab must not hit")
		return
	quit(0)
