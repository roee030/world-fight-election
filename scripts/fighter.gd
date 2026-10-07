extends CharacterBody3D
class_name GameFighter

signal health_changed(who: int, value: float)
signal meter_changed(who: int, value: float)
signal defeated(who: int)
signal combo_changed(who: int, hits: int)
signal strike_landed(attacker: int, defender: int, move: String, blocked: bool, combo: int)

const MOVES := {
	"light": {"duration": 0.46, "startup": 0.12, "active": 0.09, "cancel_from": 0.205, "cancel_to": 0.34, "damage": 7.0, "reach": 1.32, "lunge": 2.45, "clip": "jab"},
	"heavy": {"duration": 0.66, "startup": 0.235, "active": 0.105, "cancel_from": 0.365, "cancel_to": 0.51, "damage": 14.0, "reach": 1.58, "lunge": 2.7, "clip": "hook"},
	"special": {"duration": 0.84, "startup": 0.28, "active": 0.13, "cancel_from": 0.51, "cancel_to": 0.65, "damage": 23.0, "reach": 2.18, "lunge": 2.6, "clip": "kick"}
}
const INPUT_BUFFER_SECONDS := 0.34
const MAX_COMBO_HITS := 3

var who := 0
var character_id := "bennet"
var is_cpu := false
var cpu_level := 1
var ai_mode := "approach"
var input_axis := 0.0
var input_depth := 0.0
var input_jump := false
var input_block := false
var input_crouch := false
var attack_request := ""
var buffered_attack := ""
var buffer_time := 0.0
var health := 100.0
var meter := 0.0
var facing := 1.0
var attack_facing := 1.0
var busy := 0.0
var stun := 0.0
var invulnerable := 0.0
var hit_stop := 0.0
var _paused_velocity := Vector3.ZERO
var attack_time := 0.0
var attack_duration := 0.0
var attack_kind := ""
var attack_clip := ""
var attack_hit := false
var attack_confirmed := false
var combo_count := 0
var combo_timer := 0.0
var attack_lunge := 0.0
var lunge_speed := 0.0
var round_over := false
var knockdown_time := 0.0
var recovery_time := 0.0
var getup_pending := false
var knockdown_rotation := 0.0
var jump_crossing := false
var jump_lane_target_z := 0.0
var jump_phase := ""
var jump_phase_time := 0.0
var rival: GameFighter
var arena_bounds := 5.8
var arena_depth_bounds := 0.82
var ai_clock := 0.0
var ai_block_time := 0.0
var ai_attack_cooldown := 0.0
var _visual: Dictionary
var _body_mesh: Node3D
var _animation_paused := false
var _collider: CollisionShape3D
var _standing_capsule: CapsuleShape3D


func setup(id: String, player_index: int, cpu: bool, level: int = 1) -> void:
	character_id = id
	who = player_index
	is_cpu = cpu
	cpu_level = level


func _ready() -> void:
	floor_snap_length = 0.28
	_body_mesh = Node3D.new()
	_body_mesh.name = "AnimatedBody"
	add_child(_body_mesh)
	_visual = FighterVisual.build(character_id)
	_body_mesh.add_child(_visual.root)
	facing = 1.0 if who == 0 else -1.0
	_visual.sprite.flip_h = facing < 0.0
	_standing_capsule = CapsuleShape3D.new()
	_standing_capsule.radius = 0.32 * float(_visual.height_m) / 1.82
	_standing_capsule.height = float(_visual.height_m)
	_collider = CollisionShape3D.new()
	_collider.shape = _standing_capsule
	_collider.position.y = float(_visual.height_m) * 0.5
	add_child(_collider)
	# Fighter collision is resolved deliberately in the pair-separation step.
	# This lets a real jump pass over the rival while both still collide with the floor.
	collision_layer = 2
	collision_mask = 1
	health = max_health()
	if is_cpu:
		ai_mode = "approach"


func max_health() -> float:
	match character_id:
		"avigdor": return 112.0
		"bibi": return 104.0
		"yair_golan": return 102.0
		"mansour_abbas": return 116.0
		"benny_gantz": return 108.0
		"gadi_eisenkot": return 114.0
		"itamar_ben_gvir": return 98.0
		"yair_lapid": return 96.0
		_: return 100.0


func set_controls(axis: float, jump: bool, block: bool, crouch: bool, requested_attack: String, depth: float = 0.0) -> void:
	input_axis = clampf(axis, -1.0, 1.0)
	input_depth = clampf(depth, -1.0, 1.0)
	input_jump = jump
	input_block = block
	input_crouch = crouch
	if requested_attack != "":
		attack_request = requested_attack


func _physics_process(delta: float) -> void:
	if rival == null or round_over:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		if not is_on_floor(): velocity.y -= 22.0 * delta
		move_and_slide()
		return
	if is_cpu:
		_run_cpu(delta)
	if attack_request != "":
		if stun <= 0.0 and knockdown_time <= 0.0 and recovery_time <= 0.0:
			buffered_attack = attack_request
			buffer_time = INPUT_BUFFER_SECONDS
		attack_request = ""
	if buffer_time > 0.0:
		buffer_time = maxf(0.0, buffer_time - delta)
		if buffer_time <= 0.0: buffered_attack = ""
	if hit_stop > 0.0:
		hit_stop = maxf(0.0, hit_stop - delta)
		if not _animation_paused:
			_paused_velocity = velocity
			_visual.sprite.pause()
			_visual.motion.freeze_motion(true)
			_animation_paused = true
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if _animation_paused:
		_visual.sprite.play()
		_visual.motion.freeze_motion(false)
		_animation_paused = false
		velocity = _paused_velocity
	# Facing is free only in neutral. Committed attacks and hit reactions keep
	# their direction so crossing bodies cannot reverse a strike mid-animation.
	if attack_kind == "" and stun <= 0.0 and knockdown_time <= 0.0 and recovery_time <= 0.0:
		var facing_delta_x := rival.global_position.x - global_position.x
		if absf(facing_delta_x) > 0.08: facing = signf(facing_delta_x)
	if attack_kind == "": _visual.sprite.flip_h = facing < 0.0
	busy = maxf(0.0, busy - delta)
	stun = maxf(0.0, stun - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	knockdown_time = maxf(0.0, knockdown_time - delta)
	recovery_time = maxf(0.0, recovery_time - delta)
	if getup_pending and knockdown_time <= 0.0 and recovery_time <= 0.0:
		recovery_time = 0.25
		getup_pending = false
		invulnerable = maxf(invulnerable, 0.32)
	if recovery_time > 0.0 and recovery_time <= delta:
		_visual.sprite.rotation.z = 0.0
		_visual.sprite.position.y = float(_visual.ground_y)
	if combo_count > 0:
		combo_timer = maxf(0.0, combo_timer - delta)
		if combo_timer <= 0.0 and attack_kind == "": _clear_combo()
	if attack_kind != "":
		attack_time = maxf(0.0, attack_time - delta)
		var move: Dictionary = MOVES[attack_kind]
		var elapsed := attack_duration - attack_time
		if not attack_hit and elapsed >= move.startup and elapsed <= move.startup + move.active:
			_try_hit()
		if _can_chain_now(move, elapsed) and buffer_time > 0.0 and _can_chain_to(buffered_attack):
			var next_move := buffered_attack
			buffered_attack = ""
			buffer_time = 0.0
			_start_attack(next_move, true)
		elif attack_time <= 0.0:
			_finish_attack()
	var speed := 3.25
	if character_id == "avigdor": speed = 2.9
	elif character_id == "bibi": speed = 3.0
	elif character_id == "yair_golan": speed = 3.35
	elif character_id == "benny_gantz": speed = 2.95
	elif character_id in ["mansour_abbas", "gadi_eisenkot"]: speed = 2.8
	elif character_id in ["yair_lapid", "itamar_ben_gvir", "bezalel_smotrich"]: speed = 3.45
	if is_cpu: speed *= 0.90 + 0.035 * cpu_level
	var action_allowed := stun <= 0.0 and busy <= 0.0 and attack_kind == "" and knockdown_time <= 0.0 and recovery_time <= 0.0
	var move_input := input_axis if action_allowed and not input_block else 0.0
	if input_crouch: move_input *= 0.65
	var acceleration := 13.0 if absf(move_input) > 0.01 else 18.0
	velocity.x = move_toward(velocity.x, move_input * speed, acceleration * delta)
	var depth_input := input_depth if action_allowed and not input_block and not input_crouch else 0.0
	velocity.z = move_toward(velocity.z, depth_input * 1.7, (12.0 if absf(depth_input) > 0.01 else 17.0) * delta)
	if jump_crossing and not is_on_floor():
		var lane_error := jump_lane_target_z - global_position.z
		velocity.z = move_toward(velocity.z, clampf(lane_error * 6.0, -2.4, 2.4), 12.0 * delta)
	elif jump_crossing and is_on_floor():
		jump_crossing = false
	# Lunge is part of the committed attack only. Being hit cancels the move and
	# must also cancel its residual forward impulse (otherwise hit-stun can look
	# like a fresh punch or make the victim slide into the attacker).
	if attack_lunge > 0.0 and attack_kind != "" and stun <= 0.0 and knockdown_time <= 0.0:
		velocity.x = lunge_speed
		attack_lunge = maxf(0.0, attack_lunge - delta)
	else:
		attack_lunge = 0.0
		lunge_speed = 0.0
	if input_jump and is_on_floor() and action_allowed:
		velocity.y = 7.1
		jump_phase = "takeoff"
		jump_phase_time = 0.10
		jump_crossing = absf(rival.global_position.x - global_position.x) < 1.65 and signf(rival.global_position.x - global_position.x) == signf(input_axis) and absf(rival.global_position.z - global_position.z) < 0.54
		if jump_crossing:
			jump_lane_target_z = clampf(rival.global_position.z + (-0.60 if who == 0 else 0.60), -arena_depth_bounds, arena_depth_bounds)
	if not is_on_floor(): velocity.y -= 22.0 * delta
	elif velocity.y < 0.0: velocity.y = 0.0
	if action_allowed and not input_block and not input_crouch and buffered_attack != "":
		var opening_move := buffered_attack
		buffered_attack = ""
		buffer_time = 0.0
		_start_attack(opening_move)
	if input_block and action_allowed:
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	position.x = clampf(position.x, -arena_bounds, arena_bounds)
	position.z = clampf(position.z, -arena_depth_bounds, arena_depth_bounds)
	var grounded_before_move := is_on_floor()
	move_and_slide()
	if grounded_before_move and not is_on_floor():
		jump_phase = "takeoff"
		jump_phase_time = 0.10
	elif not grounded_before_move and is_on_floor():
		jump_phase = "landing"
		jump_phase_time = 0.11
	if jump_phase_time > 0.0:
		jump_phase_time = maxf(0.0, jump_phase_time - delta)
	var separation := global_position.x - rival.global_position.x
	var lane_separation := absf(global_position.z - rival.global_position.z)
	if is_on_floor() and rival.is_on_floor() and knockdown_time <= 0.0 and rival.knockdown_time <= 0.0 and lane_separation < 0.54 and absf(separation) < 1.05:
		global_position.x = rival.global_position.x + (1.05 if separation >= 0.0 else -1.05)
		velocity.x = 0.0
	_animate()
	input_jump = false


func _run_cpu(delta: float) -> void:
	ai_clock += delta
	ai_attack_cooldown = maxf(0.0, ai_attack_cooldown - delta)
	var distance := absf(global_position.x - rival.global_position.x)
	var enemy_attacking := rival.attack_kind != "" and rival.attack_time > 0.0
	var dir := signf(rival.global_position.x - global_position.x)
	var lane_dir := signf(rival.global_position.z - global_position.z)
	var axis := 0.0
	var block := false
	var crouch := false
	var request := ""
	if stun > 0.0 or knockdown_time > 0.0 or recovery_time > 0.0:
		ai_mode = "recover"
		attack_request = ""
		set_controls(0.0, false, false, false, "")
		return
	var enemy_move: Dictionary = MOVES.get(rival.attack_kind, {})
	var enemy_elapsed := rival.attack_duration - rival.attack_time if not enemy_move.is_empty() else 0.0
	var reaction_window := maxf(0.025, float(enemy_move.get("startup", 0.0)) - (0.035 + cpu_level * 0.012))
	if enemy_attacking and distance < 1.82 and absf(rival.global_position.z - global_position.z) < 0.85 and not enemy_move.is_empty():
		if enemy_elapsed >= reaction_window and enemy_elapsed <= float(enemy_move.startup) + float(enemy_move.active) and randf() < (0.50 + 0.10 * cpu_level):
			block = true
			ai_block_time = 0.20 + cpu_level * 0.025
	if ai_block_time > 0.0:
		ai_block_time -= delta
		block = true
	var elapsed := attack_duration - attack_time
	var current_move: Dictionary = MOVES.get(attack_kind, {})
	var cancel_window: bool = not current_move.is_empty() and attack_confirmed and elapsed >= float(current_move.cancel_from) and elapsed <= float(current_move.cancel_to)
	if cancel_window and combo_count < MAX_COMBO_HITS and randf() < delta * (1.7 + cpu_level * 0.8):
		request = "heavy" if attack_kind == "light" else ("special" if meter >= 55.0 else "heavy")
	elif not block and distance > (1.48 + 0.06 * cpu_level):
		ai_mode = "approach"
		if absf(rival.global_position.z - global_position.z) > 0.54: crouch = false
		axis = dir
	elif not block and distance < 1.48 and busy <= 0.0 and stun <= 0.0 and attack_kind == "":
		ai_mode = "engage"
		# Sometimes disengage before a committed attack; CPU punish choices depend on the rival's recovery.
		if rival.attack_kind != "" and rival.attack_time < 0.16 and randf() < delta * (1.1 + cpu_level * 0.25):
			ai_mode = "retreat"
			axis = -dir
		elif ai_attack_cooldown <= 0.0 and randf() < delta * (0.75 + cpu_level * 0.34):
			var roll := randf()
			if roll < 0.57: request = "light"
			elif roll < 0.84: request = "heavy"
			elif meter >= 55.0: request = "special"
			else: request = "light"
			ai_attack_cooldown = 0.28 if request == "light" else 0.42
		if not block and cpu_level >= 2 and rival.attack_kind == "heavy" and distance < 1.82 and enemy_elapsed >= reaction_window and randf() < delta * (1.1 + cpu_level * 0.28):
			crouch = true
	elif block:
		ai_mode = "defend"
	var depth := 0.0
	if not block and (distance < 2.1 or absf(rival.global_position.z - global_position.z) > 0.3):
		depth = lane_dir if absf(rival.global_position.z - global_position.z) > 0.52 else 0.0
		if enemy_attacking and cpu_level >= 3 and randf() < delta * 0.75: depth = -lane_dir
	set_controls(axis, false, block, crouch, request, depth)


func _start_attack(kind: String, chained: bool = false) -> void:
	if kind == "special" and meter < 55.0: kind = "heavy"
	if not MOVES.has(kind): return
	if chained and not _can_chain_to(kind): return
	if not chained and combo_count > 0: _clear_combo()
	if kind == "special":
		meter -= 55.0
		meter_changed.emit(who, meter)
	var move: Dictionary = MOVES[kind]
	attack_kind = kind
	attack_facing = facing
	attack_hit = false
	attack_confirmed = false
	attack_duration = move.duration
	attack_time = move.duration
	busy = move.duration
	attack_lunge = 0.12 if kind == "light" else (0.15 if kind == "heavy" else 0.16)
	lunge_speed = attack_facing * move.lunge
	var clip_name := str(move.clip)
	if kind == "heavy" and chained and combo_count == 1: clip_name = "cross"
	_visual.sprite.animation = clip_name
	attack_clip = clip_name
	_visual.sprite.set_frame_and_progress(0, 0.0)
	_visual.sprite.play()
	_animate()


func _can_chain_now(move: Dictionary, elapsed: float) -> bool:
	return attack_confirmed and elapsed >= move.cancel_from and elapsed <= move.cancel_to and combo_count < MAX_COMBO_HITS


func _can_chain_to(next_move: String) -> bool:
	if attack_kind == "special" or combo_count >= MAX_COMBO_HITS: return false
	if attack_kind == "light": return next_move in ["light", "heavy", "special"]
	if attack_kind == "heavy": return next_move in ["heavy", "special"]
	return false


func _finish_attack() -> void:
	var ended_move := attack_kind
	var connected := attack_confirmed
	attack_kind = ""
	attack_clip = ""
	attack_time = 0.0
	attack_duration = 0.0
	attack_hit = false
	attack_confirmed = false
	busy = 0.0
	attack_lunge = 0.0
	buffered_attack = ""
	buffer_time = 0.0
	if ended_move == "special" or not connected: _clear_combo()


func _try_hit() -> void:
	var dx := rival.global_position.x - global_position.x
	var distance := absf(dx)
	var move: Dictionary = MOVES[attack_kind]
	if distance > move.reach or dx * attack_facing <= 0.0 or absf(rival.global_position.z - global_position.z) > 0.58: return
	if absf(rival.global_position.y - global_position.y) > 0.95 and attack_kind != "special": return
	# Ducking evades a high heavy strike; the attacker still spends its active window.
	if attack_kind == "heavy" and rival.input_crouch and rival.is_on_floor():
		attack_hit = true
		return
	attack_hit = true
	var blocked := rival.input_block and rival.stun <= 0.0 and rival.is_on_floor()
	if blocked:
		meter = minf(100.0, meter + 11.0)
		meter_changed.emit(who, meter)
		rival.stun = maxf(rival.stun, 0.18)
		rival.hit_stop = maxf(rival.hit_stop, 0.045)
		hit_stop = maxf(hit_stop, 0.045)
		_clear_combo()
		strike_landed.emit(who, rival.who, attack_kind, true, combo_count)
		return
	var damage: float = move.damage
	if character_id == "avigdor": damage *= 1.16
	if is_cpu: damage *= 0.72 + 0.07 * cpu_level
	if attack_kind == "special": damage *= 1.18
	if character_id == "yair_golan": damage *= 0.96
	if character_id == "bibi" and attack_kind == "light": damage *= 0.93
	if character_id in ["mansour_abbas", "gadi_eisenkot"]: damage *= 1.10
	if character_id in ["yair_lapid", "bezalel_smotrich"]: damage *= 0.93
	attack_confirmed = true
	combo_count += 1
	combo_timer = 0.9
	combo_changed.emit(who, combo_count)
	rival.receive_hit(damage, attack_facing, attack_kind)
	rival.hit_stop = maxf(rival.hit_stop, 0.075 if attack_kind != "light" else 0.055)
	hit_stop = maxf(hit_stop, 0.055 if attack_kind == "light" else 0.075)
	meter = minf(100.0, meter + 16.0 + damage * 0.45)
	meter_changed.emit(who, meter)
	strike_landed.emit(who, rival.who, attack_kind, false, combo_count)


func receive_hit(damage: float, direction: float, kind: String) -> void:
	if invulnerable > 0.0 or round_over or knockdown_time > 0.0 or recovery_time > 0.0: return
	var blocked := input_block and stun <= 0.0 and is_on_floor()
	if blocked:
		damage *= 0.22
		stun = 0.18
	else:
		stun = 0.34 if kind == "light" else (0.48 if kind == "heavy" else 0.55)
		_clear_combo()
		attack_kind = ""
		attack_clip = ""
		attack_time = 0.0
		attack_duration = 0.0
		attack_hit = false
		attack_confirmed = false
		attack_lunge = 0.0
		lunge_speed = 0.0
		busy = stun
		buffered_attack = ""
		buffer_time = 0.0
		attack_request = ""
	health = maxf(0.0, health - damage)
	velocity.x = direction * (0.75 if blocked else (2.3 if kind == "light" else 2.85))
	if not blocked:
		facing = -signf(direction)
		_visual.sprite.flip_h = facing < 0.0
	if not blocked and kind == "special":
		# A special knockback ends in a brief grounded knockdown and visible get-up.
		knockdown_time = 0.62
		getup_pending = true
		stun = knockdown_time
		busy = knockdown_time
		# Keep the capsule active so the fighter stays on the arena floor.
		knockdown_rotation = 0.0
		_visual.sprite.rotation.z = 0.0
		_visual.sprite.position.y = float(_visual.ground_y)
		_visual.sprite.scale = Vector3.ONE
	# Switch to hit/fall art immediately, before either fighter's hit-stop can
	# freeze the victim on the last frame of a punch.
	_animate()
	invulnerable = 0.12
	health_changed.emit(who, health)
	if health <= 0.0: defeated.emit(who)


func reset_round(position_x: float, health_value: float = 100.0) -> void:
	position = Vector3(position_x, 0.0, 0.0)
	velocity = Vector3.ZERO
	health = health_value
	meter = 0.0
	stun = 0.0
	busy = 0.0
	attack_kind = ""
	attack_clip = ""
	attack_time = 0.0
	attack_duration = 0.0
	attack_hit = false
	attack_confirmed = false
	attack_lunge = 0.0
	lunge_speed = 0.0
	hit_stop = 0.0
	_paused_velocity = Vector3.ZERO
	_animation_paused = false
	knockdown_time = 0.0
	recovery_time = 0.0
	getup_pending = false
	knockdown_rotation = 0.0
	jump_crossing = false
	ai_attack_cooldown = 0.0
	jump_phase = ""
	jump_phase_time = 0.0
	_collider.disabled = false
	_visual.sprite.rotation.z = 0.0
	_visual.sprite.position.y = float(_visual.ground_y)
	combo_timer = 0.0
	combo_count = 0
	buffered_attack = ""
	buffer_time = 0.0
	invulnerable = 1.1
	input_block = false
	input_crouch = false
	input_axis = 0.0
	input_depth = 0.0
	attack_request = ""
	round_over = false
	combo_changed.emit(who, 0)
	health_changed.emit(who, health)
	meter_changed.emit(who, meter)


func _clear_combo() -> void:
	if combo_count != 0:
		combo_count = 0
		combo_timer = 0.0
		combo_changed.emit(who, 0)


func _animate() -> void:
	var sprite = _visual.sprite
	var clip := "idle"
	if knockdown_time > 0.0: clip = "knockdown"
	elif recovery_time > 0.0: clip = "getup"
	elif stun > 0.0: clip = "hit"
	elif input_block and is_on_floor(): clip = "block"
	elif attack_kind != "": clip = attack_clip
	elif input_crouch and is_on_floor(): clip = "crouch"
	elif not is_on_floor(): clip = "jump_start" if jump_phase == "takeoff" and jump_phase_time > 0.0 else "jump_air"
	elif jump_phase == "landing" and jump_phase_time > 0.0: clip = "jump_land"
	elif absf(velocity.x) > 0.35:
		clip = "walk_forward" if velocity.x * facing > 0.0 else "walk_back"
	if sprite.animation != clip: sprite.play(clip)
	sprite.flip_h = (attack_facing if attack_kind != "" else facing) < 0.0
	var motion_state := clip
	if knockdown_time > 0.0: motion_state = "knockdown"
	elif recovery_time > 0.0: motion_state = "getup"
	var target_duration := 0.0
	if attack_kind != "": target_duration = attack_duration
	elif knockdown_time > 0.0: target_duration = maxf(knockdown_time, 0.08)
	elif recovery_time > 0.0: target_duration = maxf(recovery_time, 0.08)
	elif stun > 0.0: target_duration = maxf(stun, 0.08)
	_visual.motion.play_state(motion_state, false, target_duration)
	_visual.motion.set_facing(attack_facing if attack_kind != "" else facing)
	var walking := clip in ["walk_forward", "walk_back"]
	if knockdown_time <= 0.0 and recovery_time <= 0.0:
		sprite.position.y = float(_visual.ground_y)
		sprite.scale.y = 1.0
		sprite.rotation.z = 0.0
	if recovery_time <= 0.0 and knockdown_time <= 0.0 and is_on_floor():
		sprite.rotation.z = 0.0
	_visual.shadow.scale.x = 1.45 + (0.15 if not is_on_floor() else 0.0)
	_visual.shadow.scale.z = 0.63 + (0.07 if not is_on_floor() else 0.0)
	# The visual root follows the fighter capsule into the air. Counter that world
	# height so the projected contact shadow remains attached to the arena floor.
	_visual.shadow.position.y = 0.018 - global_position.y
