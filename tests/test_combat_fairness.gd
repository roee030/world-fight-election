extends SceneTree

## Measures Quick Fight balance with a scripted "average touch player" against
## the level-1 CPU. Fighters are stepped manually at a fixed 60 Hz, so the run is
## deterministic for a given seed and finishes quickly in headless mode.

const DT := 1.0 / 60.0
const ROUNDS := 16
const ROUND_SECONDS := 60.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(20261008)
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	for _frame in range(3):
		await process_frame
	main._setup_bout("bennet", "avigdor", 1, "FAIRNESS QA")
	for _frame in range(6):
		await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	var player = main.player
	var cpu = main.enemy
	player.set_physics_process(false)
	cpu.set_physics_process(false)
	var stats := {"player_dealt": 0.0, "cpu_dealt": 0.0, "player_hits": 0, "player_blocked": 0, "player_wins": 0, "cpu_wins": 0, "energy_full_times": []}
	player.strike_landed.connect(func(attacker: int, _defender: int, _move: String, blocked: bool, _combo: int):
		if attacker == 0:
			stats.player_hits += 1
			if blocked: stats.player_blocked += 1
	)
	for round_index in range(ROUNDS):
		player.reset_round(-1.85, player.max_health())
		cpu.reset_round(1.85, cpu.max_health())
		main.fight_live = true
		main.round_ready = true
		main.intermission = 0.0
		main.match_state = main.MatchState.Value.FIGHTING
		var player_start: float = player.health
		var cpu_start: float = cpu.health
		var elapsed := 0.0
		var attack_cooldown := 0.4
		var guard_time := 0.0
		var guard_decided := false
		var energy_full_at := -1.0
		while elapsed < ROUND_SECONDS and player.health > 0.0 and cpu.health > 0.0:
			elapsed += DT
			attack_cooldown -= DT
			guard_time = maxf(0.0, guard_time - DT)
			var dx: float = cpu.global_position.x - player.global_position.x
			var distance := absf(dx)
			var axis := 0.0
			var request := ""
			# Average phone player: guards 20% of incoming attacks, closes
			# distance, and attacks at a human tapping cadence.
			if cpu.attack_kind != "" and not guard_decided:
				guard_decided = true
				if randf() < 0.20: guard_time = 0.32
			elif cpu.attack_kind == "":
				guard_decided = false
			if guard_time <= 0.0:
				if distance > 1.25:
					axis = signf(dx)
				elif attack_cooldown <= 0.0:
					attack_cooldown = randf_range(0.38, 0.75)
					# No MAX spending here, so the run also measures how long
					# ordinary fighting takes to fill Special Energy.
					request = "light" if randf() < 0.6 else "heavy"
			player.set_controls(axis, false, guard_time > 0.0, false, request)
			player._physics_process(DT)
			cpu._physics_process(DT)
			if energy_full_at < 0.0 and player.meter >= 100.0:
				energy_full_at = elapsed
				player.meter = 0.0
				player.meter_changed.emit(0, 0.0)
		stats.player_dealt += cpu_start - cpu.health
		stats.cpu_dealt += player_start - player.health
		if energy_full_at >= 0.0: stats.energy_full_times.append(energy_full_at)
		var player_ratio: float = player.health / player.max_health()
		var cpu_ratio: float = cpu.health / cpu.max_health()
		if player_ratio > cpu_ratio: stats.player_wins += 1
		else: stats.cpu_wins += 1
	var block_ratio := float(stats.player_blocked) / maxf(1.0, float(stats.player_hits))
	var times: Array = stats.energy_full_times
	var average_energy_time := 0.0
	for t in times: average_energy_time += float(t)
	average_energy_time /= maxf(1.0, float(times.size()))
	print("FAIRNESS: player_wins=%d cpu_wins=%d player_dealt=%.0f cpu_dealt=%.0f cpu_block_ratio=%.2f energy_full_avg=%.1fs (%d rounds reached 100%%)" % [stats.player_wins, stats.cpu_wins, stats.player_dealt, stats.cpu_dealt, block_ratio, average_energy_time, times.size()])
	main.free()
	if float(stats.player_wins) / float(ROUNDS) < 0.55:
		return _fail("an average player must beat the level-1 Quick Fight CPU in most rounds")
	if stats.player_dealt <= stats.cpu_dealt:
		return _fail("an average player loses more HP than the level-1 CPU")
	if block_ratio > 0.40:
		return _fail("the level-1 CPU still guards most player attacks (%.2f)" % block_ratio)
	if times.size() > 0 and average_energy_time < 15.0:
		return _fail("Special Energy fills too fast (%.1fs) — SP would be available several times per round" % average_energy_time)
	print("PASS: level-1 CPU is beatable, damage is player-favoured and Special Energy pacing is sane")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
