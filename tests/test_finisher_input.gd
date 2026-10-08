extends SceneTree

class InputHost extends "res://scripts/main.gd":
	var test_eligible := true
	func _finisher_eligible() -> bool:
		return test_eligible

func _init() -> void:
	var script = load("res://scripts/finishers/special_hold.gd")
	if script == null:
		quit(1)
		return
	var hold = script.new()
	assert(hold.update(0.0, true, false, false) == "special")
	assert(hold.update(0.0, true, false, true) == "none")
	assert(hold.update(0.549, false, true, true) == "special")
	assert(hold.update(0.0, true, false, true) == "none")
	assert(hold.update(0.55, false, false, true) == "finisher")
	assert(hold.update(0.0, false, true, true) == "none")
	assert(hold.update(0.0, true, false, true) == "none")
	assert(hold.update(0.54, false, false, false) == "none")
	assert(hold.update(0.1, false, true, true) == "none")
	assert(not hold.active)
	hold.update(0.0, true, false, true)
	hold.cancel()
	assert(hold.update(0.6, false, true, true) == "none")
	var host := InputHost.new()
	host.match_state = host.MatchState.Value.FIGHTING
	assert(host._update_special_hold(0.0, true, false) == "none")
	assert(host.match_state == host.MatchState.Value.FINISHER_PROMPT)
	assert(host._update_special_hold(0.55, false, false) == "finisher")
	assert(host.match_state == host.MatchState.Value.FIGHTING)
	assert(host._update_special_hold(0.0, false, true) == "none")
	host.test_eligible = false
	assert(host._update_special_hold(0.0, true, false) == "special")
	host.test_eligible = true
	assert(host._finisher_hint_text(false, false, false) == "MAX: WIN 1 ROUND FIRST")
	assert(host._finisher_hint_text(true, false, false) == "MAX: RIVAL HP ≤ 15%")
	assert(host._finisher_hint_text(true, true, false) == "FINISH: MOVE CLOSE + HOLD L/MAX")
	assert(host._finisher_hint_text(true, true, true) == "FINISH READY: HOLD L/MAX")
	host._on_touch_action_down("special")
	host._on_touch_action_up("special")
	assert(host._sample_special_input(0.01) == "special", "touch tap between physics ticks")
	assert(host._sample_special_input(0.6) == "none", "tap must not leave a held finisher")
	hold.update(0.6, true, false, true)
	assert(hold.active and hold.elapsed == 0.0, "do not credit time before press")
	host.free()
	print("PASS: Special tap/hold boundary, cancellation, one action")
	quit(0)
