## Pure 60Hz combat simulation foundation. Godot nodes render this state but
## must not be stored in snapshots, so the same input log can replay exactly.
class_name CombatWorld
extends RefCounted

const TICKS_PER_SECOND := 60
const DT := 1.0 / float(TICKS_PER_SECOND)
const ARENA_HALF_WIDTH := 3.2
const MOVE_DATA := {
	"jab": {"duration": 16, "active_start": 6, "active_end": 8, "reach": 1.45, "damage": 8.0, "hit_stop": 3, "lunge": 0.18},
	"cross": {"duration": 22, "active_start": 9, "active_end": 11, "reach": 1.72, "damage": 13.0, "hit_stop": 4, "lunge": 0.24},
}

var seed: int
var tick := -1
var fighters := {
	0: _fighter_state(-1.0, 1.0),
	1: _fighter_state(1.0, -1.0)
}


func _init(initial_seed: int = 1) -> void:
	seed = initial_seed


func step(next_tick: int, inputs: Dictionary) -> Array[Dictionary]:
	assert(next_tick == tick + 1, "CombatWorld ticks must be consecutive")
	tick = next_tick
	var events: Array[Dictionary] = []
	for fighter_id in fighters:
		var fighter: Dictionary = fighters[fighter_id]
		var input: Dictionary = inputs.get(fighter_id, {})
		var requested_attack := str(input.get("attack", ""))
		if not requested_attack.is_empty():
			fighter.buffered_attack = requested_attack
		if int(fighter.hit_stop) > 0:
			fighter.hit_stop = int(fighter.hit_stop) - 1
			fighters[fighter_id] = fighter
			continue
		var rival_id := 1 - int(fighter_id)
		var rival: Dictionary = fighters[rival_id]
		var horizontal_delta := float(rival.x) - float(fighter.x)
		if str(fighter.attack).is_empty() and absf(horizontal_delta) > 0.02:
			fighter.facing = signf(horizontal_delta)
		if not str(fighter.attack).is_empty():
			fighter.attack_frame = int(fighter.attack_frame) + 1
			var move: Dictionary = MOVE_DATA[fighter.attack]
			if not bool(fighter.attack_landed) and int(fighter.attack_frame) >= int(move.active_start) and int(fighter.attack_frame) <= int(move.active_end):
				if absf(horizontal_delta) <= float(move.reach) and horizontal_delta * float(fighter.facing) > 0.0:
					fighter.attack_landed = true
					rival.health = maxf(0.0, float(rival.health) - float(move.damage))
					fighter.hit_stop = int(move.hit_stop)
					rival.hit_stop = int(move.hit_stop)
					fighters[rival_id] = rival
					events.append({"type": "hit", "attacker": fighter_id, "defender": rival_id, "move": fighter.attack, "damage": move.damage, "remaining_health": rival.health})
			fighter.x = clampf(float(fighter.x) + float(fighter.facing) * float(move.lunge) * DT, -ARENA_HALF_WIDTH, ARENA_HALF_WIDTH)
			if int(fighter.attack_frame) >= int(move.duration):
				fighter.attack = ""
				fighter.attack_frame = 0
				fighter.attack_landed = false
		elif MOVE_DATA.has(fighter.buffered_attack):
			fighter.attack = fighter.buffered_attack
			fighter.attack_frame = 0
			fighter.attack_landed = false
			fighter.buffered_attack = ""
		fighter.axis = clampf(float(input.get("axis", 0.0)), -1.0, 1.0)
		if str(fighter.attack).is_empty():
			fighter.x = clampf(float(fighter.x) + fighter.axis * 3.0 * DT, -ARENA_HALF_WIDTH, ARENA_HALF_WIDTH)
		fighters[fighter_id] = fighter
	return events


static func _fighter_state(x_value: float, facing_value: float) -> Dictionary:
	return {"x": x_value, "facing": facing_value, "axis": 0.0, "health": 100.0, "hit_stop": 0, "buffered_attack": "", "attack": "", "attack_frame": 0, "attack_landed": false}


func set_hit_stop(fighter_id: int, frames: int) -> void:
	var fighter: Dictionary = fighters[fighter_id]
	fighter.hit_stop = maxi(0, frames)
	fighters[fighter_id] = fighter


func buffered_action(fighter_id: int) -> String:
	return str(fighters[fighter_id].buffered_attack)


func snapshot() -> Dictionary:
	return {
		"seed": seed,
		"tick": tick,
		"fighters": fighters.duplicate(true)
	}


func restore(state: Dictionary) -> void:
	seed = int(state.seed)
	tick = int(state.tick)
	fighters = Dictionary(state.fighters).duplicate(true)
