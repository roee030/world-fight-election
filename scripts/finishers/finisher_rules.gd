extends RefCounted

const MatchState = preload("res://scripts/finishers/match_state.gd")

static func match_point_for(attacker: int, player_rounds: int, enemy_rounds: int) -> bool:
	return (player_rounds if attacker == 0 else enemy_rounds) == 1

static func is_eligible(context: Dictionary, definition: Dictionary) -> bool:
	if not definition.get("implemented", false) or context.get("paused", false):
		return false
	if context.get("state", -1) != MatchState.Value.FIGHTING:
		return false
	for key in ["match_point", "grounded", "actionable", "facing_correct"]:
		if not context.get(key, false):
			return false
	return float(context.get("health_ratio", 1.0)) <= float(definition.get("trigger_health_ratio", 0.15)) \
		and float(context.get("meter", 0.0)) >= float(definition.get("meter_cost", 100.0)) \
		and float(context.get("distance", INF)) <= float(definition.get("activation_range", 1.75))
