extends SceneTree

func _init() -> void:
	var rules = load("res://scripts/finishers/finisher_rules.gd")
	var state = load("res://scripts/finishers/match_state.gd")
	if rules == null or state == null:
		quit(1)
		return
	var context := {"implemented": true, "match_point": true, "health_ratio": 0.15, "meter": 100.0, "state": state.Value.FIGHTING, "grounded": true, "actionable": true, "distance": 1.75, "facing_correct": true, "paused": false}
	var definition := {"implemented": true, "trigger_health_ratio": 0.15, "meter_cost": 100.0, "activation_range": 1.75}
	assert(rules.is_eligible(context, definition))
	for key in ["match_point", "grounded", "actionable", "facing_correct"]:
		var invalid := context.duplicate()
		invalid[key] = false
		assert(not rules.is_eligible(invalid, definition), key)
	for pair in [["health_ratio", 0.151], ["meter", 99.9], ["distance", 1.751], ["paused", true], ["state", state.Value.RESULT]]:
		var invalid := context.duplicate()
		invalid[pair[0]] = pair[1]
		assert(not rules.is_eligible(invalid, definition))
	definition.implemented = false
	assert(not rules.is_eligible(context, definition))
	assert(rules.match_point_for(0, 1, 0))
	assert(rules.match_point_for(1, 0, 1))
	assert(not rules.match_point_for(0, 0, 1))
	assert(state.can_transition(state.Value.FIGHTING, state.Value.FINISHER_PROMPT))
	assert(not state.can_transition(state.Value.ROUND_INTRO, state.Value.CELEBRATION))
	print("PASS: finisher eligibility boundaries and transitions")
	quit(0)
