extends Node3D

signal finisher_requested(attacker: GameFighter, defender: GameFighter, definition: Dictionary)

const GameFighterScript = preload("res://scripts/fighter.gd")
const MatchState = preload("res://scripts/finishers/match_state.gd")
var match_state: int = MatchState.Value.ROUND_INTRO
const FinisherRules = preload("res://scripts/finishers/finisher_rules.gd")
const SpecialHold = preload("res://scripts/finishers/special_hold.gd")
var _special_hold = SpecialHold.new()
var _input_held := {}
var _special_was_held := false
var _special_release_pending := false
var _special_cancel_after_pause := false
var _finisher_catalog: RefCounted
const FinisherDirectorScript = preload("res://scripts/finishers/finisher_director.gd")
var _finisher_director: Node
const VirtualStickScript = preload("res://scripts/virtual_stick.gd")
const TouchActionButtonScript = preload("res://scripts/touch_action_button.gd")
const SlantBarScript = preload("res://scripts/hud/slant_bar.gd")
const CIRCLE_MASK_SHADER = preload("res://scripts/hud/circle_mask.gdshader")
const DESIGN_SIZE := Vector2(1280, 720)
const HUD_FRAME_HEIGHT := 132.0
const HUD_PANEL_SIZE := Vector2(540, 124)
const HUD_HP_BAR_X := 126.0
const HUD_HP_BAR_WIDTH := 390.0
const CONTROL_BINDINGS := {
	"move": [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT],
	"jump": [KEY_W, KEY_UP],
	"guard": [KEY_S, KEY_H],
	"crouch": [KEY_C],
	"light": [KEY_J, KEY_1],
	"heavy": [KEY_K, KEY_2],
	"kick": [KEY_U, KEY_4],
	"special": [KEY_L, KEY_3],
	"pause": [KEY_ESCAPE]
}
const OpponentSelectorScript = preload("res://scripts/opponent_selector.gd")
const ARENA_EDGE := 5.8
const MAIN_HERO_PATH := "res://assets/ui/main-hero-b.png"
const CELEBRATION_PLAYBACK_SCALE := 0.40
const CELEBRATION_CLEAR_SECONDS := 3.0
# A finisher is a heavy blow, not an automatic win: it deals this share of the
# rival's max HP. It only ends a round when that damage empties the bar, and only
# a match-winning KO plays the celebration.
const FINISHER_DAMAGE_RATIO := 0.30
# Phone action cluster, matching the supplied HUD reference. Centres are measured
# from the bottom-right corner (x = from the right edge, y = from the bottom) so
# the cluster stays anchored on every aspect ratio. Diamonds are 116 px wide and
# sit 64 px apart on the diagonal grid, leaving a visible gap between hit areas.
const TOUCH_PAD_SIZE := Vector2(360, 290)
const TOUCH_CONTROL_LAYOUT := [
	{"action": "max", "title": "MAX", "center": Vector2(206, 210), "size": Vector2(116, 116), "color": "#d9792b", "shape": "diamond", "icon": "bolt"},
	{"action": "heavy", "title": "CROSS", "center": Vector2(78, 210), "size": Vector2(116, 116), "color": "#d24a5c", "shape": "diamond", "icon": "cross"},
	{"action": "light", "title": "JAB", "center": Vector2(270, 146), "size": Vector2(116, 116), "color": "#1f9e95", "shape": "diamond", "icon": "fist"},
	{"action": "special", "title": "SP", "center": Vector2(142, 146), "size": Vector2(80, 80), "color": "#c79a22", "shape": "circle", "icon": "spark"},
	{"action": "block", "title": "GUARD", "center": Vector2(206, 82), "size": Vector2(116, 116), "color": "#4e6573", "shape": "diamond", "icon": "shield"}
]

var player: GameFighter
var enemy: GameFighter
var ui: CanvasLayer
var hud_root: Control
var menu_root: Control
var select_root: Control
var map_select_root: Control
var pending_mode := "quick"
var selected_stage_id := "knesset_exterior"
var stage_buttons: Array[Button] = []
var menu_left_art: TextureRect
var menu_right_art: TextureRect
var select_name_label: Label
var select_style_label: Label
var select_stats_label: Label
var select_portrait: TextureRect
var select_rival_portrait: TextureRect
var select_rival_name: Label
var select_rival_style: Label
var roster_tiles: Array[Button] = []
var pause_root: Control
var result_root: Control
var player_health_bar: SlantBarScript
var enemy_health_bar: SlantBarScript
var player_recoverable_bar: SlantBarScript
var enemy_recoverable_bar: SlantBarScript
var player_meter_bar: SlantBarScript
var enemy_meter_bar: SlantBarScript
var player_meter_label: Label
var enemy_meter_label: Label
var player_meter_percent: Label
var enemy_meter_percent: Label
var player_hud_portrait: TextureRect
var enemy_hud_portrait: TextureRect
var player_round_markers: Array[Panel] = []
var enemy_round_markers: Array[Panel] = []
var timer_label: Label
var round_label: Label
var message_label: Label
var combo_label: Label
var result_winner_art: TextureRect
var result_accent: Panel
var _web_menu_callback: JavaScriptObject
var _web_pause_callback: JavaScriptObject
var combo_label_time := 0.0
var special_feedback_time := 0.0
var fight_live := false
var paused := false
var selecting := "bennet"
var campaign_mode := false
var bout := 0
var player_rounds := 0
var enemy_rounds := 0
var round_clock := 60.0
var intermission := 0.0
var campaign_wins := 0
var stick: VirtualStick
var buttons: Dictionary = {}
var _input_down := {}
var _attack_key_held := {}
var _arena: Node3D
var _fight_camera: Camera3D
var camera_shake := 0.0
var camera_home := Vector3(0, 3.6, 9.7)
var _audio_player: AudioStreamPlayer
var _sounds := {}
var _art_cache := {}
var _last_second := -1
var round_ready := false
var player_recover_delay := 0.0
var enemy_recover_delay := 0.0
var _opponent_selector := OpponentSelectorScript.new()
var _celebration_clear_elapsed := 0.0
var _celebration_result_marked := false
var _celebration_won := false
var _touch_special_consumed := false
var current_rival_id := ""
var current_level := 1

const BOUTS := [
	{"name": "Avigdor", "id": "avigdor", "level": 1, "title": "THE QUIET ROOM"},
	{"name": "Bennet", "id": "bennet", "level": 2, "title": "THE PITCH FLOOR"},
	{"name": "Yair Golan", "id": "yair_golan", "level": 3, "title": "THE FIELD COMMAND"},
	{"name": "Bibi — THE BOSS", "id": "bibi", "level": 4, "title": "THE FINAL OFFICE"}
]
const FIGHTER_DATA := {
	"bennet": {"name": "BENNET", "callout": "THE FOUNDER  /  COMBO STRIKER", "style": "Close-range pressure", "signature": "Founder’s Rush"},
	"avigdor": {"name": "AVIGDOR LIEBERMAN", "callout": "THE FIXER  /  COUNTER HEAVY", "style": "Patient guard", "signature": "Iron Verdict"},
	"bibi": {"name": "BIBI", "callout": "THE STATESMAN  /  STEADY STRIKER", "style": "Measured counter fighter", "signature": "Blue Line"},
	"yair_golan": {"name": "YAIR GOLAN", "callout": "THE FIELD COMMANDER  /  MOBILE", "style": "Adaptive pressure", "signature": "Desert Pivot"},
	"aryeh_deri": {"name": "ARYEH DERI", "callout": "THE PURPLE ROGUE  /  TRICKSTER", "style": "Deceptive close combat", "signature": "Golden Detour"},
	"yair_lapid": {"name": "YAIR LAPID", "callout": "THE BOXER  /  FAST HANDS", "style": "Footwork and combinations", "signature": "Prime-Time Cross"},
	"mansour_abbas": {"name": "MANSOUR ABBAS", "callout": "THE DIPLOMAT  /  HEAVYWEIGHT", "style": "Grounded power", "signature": "Coalition Breaker"},
	"benny_gantz": {"name": "BENNY GANTZ", "callout": "THE TOWER  /  LONG GUARD", "style": "Range and defense", "signature": "Steel Horizon"},
	"itamar_ben_gvir": {"name": "ITAMAR BEN-GVIR", "callout": "THE WARDEN  /  WILD PRESSURE", "style": "Relentless rushdown", "signature": "Crocodile Charge"},
	"bezalel_smotrich": {"name": "BEZALEL SMOTRICH", "callout": "THE ESCAPIST  /  QUICK COUNTER", "style": "Lean evasive striking", "signature": "Orange Exit"},
	"gadi_eisenkot": {"name": "GADI EISENKOT", "callout": "THE COMPACT CHIEF  /  POWER", "style": "Short-range heavyweight", "signature": "Red Beret"},
	"trump": {"name": "DONALD TRUMP", "callout": "THE SHOWMAN  /  POWER BOXER", "style": "Big swings and pressure", "signature": "Golden Counter"},
	"joint_list": {"name": "JOINT LIST", "callout": "TWO HEADS  /  ONE FIGHTER", "style": "Dual-minded counterplay", "signature": "Coalition Split"}
}
const PLAYABLE_IDS := ["bennet", "avigdor", "bibi", "yair_golan", "aryeh_deri", "yair_lapid", "mansour_abbas", "benny_gantz", "itamar_ben_gvir", "bezalel_smotrich", "gadi_eisenkot", "trump", "joint_list"]
const STAGES := [
	{"id": "knesset_exterior", "name": "KNESSET • OUTSIDE", "subtitle": "Jerusalem · Night session", "image": "res://assets/stages/knesset-exterior-arena.png", "kind": "knesset_outside", "accent": "#cda760", "base": "#1a2634"},
	{"id": "knesset_chamber", "name": "KNESSET • CHAMBER", "subtitle": "Inside the debating hall", "image": "res://assets/stages/knesset-chamber-arena.png", "kind": "knesset_inside", "accent": "#e2bd63", "base": "#392b22", "backdrop_y": 0.78, "backdrop_scale": 1.18, "camera_target_y": 1.42},
	{"id": "patriots_studio", "name": "THE PATRIOTS", "subtitle": "Live studio · Red alert", "image": "res://assets/stages/patriots-studio-arena.png", "kind": "studio", "accent": "#42cafa", "base": "#102033"},
	{"id": "friday_studio", "name": "FRIDAY STUDIO", "subtitle": "Prime time · Jerusalem", "image": "res://assets/stages/friday-studio-arena.png", "kind": "studio", "accent": "#e5b944", "base": "#132238"},
	{"id": "hatzinor_studio", "name": "THE PIPELINE", "subtitle": "The Hatzinor newsroom", "image": "res://assets/stages/hatzinor-studio-arena.png", "kind": "studio", "accent": "#3ccafa", "base": "#101a2c"}
]


func _ready() -> void:
	if ResourceLoader.exists("res://scripts/finishers/finisher_catalog.gd"):
		_finisher_catalog = load("res://scripts/finishers/finisher_catalog.gd").new()
		_finisher_catalog.load_default()
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	randomize()
	_build_arena()
	_finisher_director = FinisherDirectorScript.new()
	add_child(_finisher_director)
	_finisher_director.configure(self, _arena, _fight_camera)
	finisher_requested.connect(_try_begin_finisher)
	_finisher_director.final_hit.connect(_on_finisher_final_hit)
	_finisher_director.celebration_started.connect(_on_celebration_started)
	_finisher_director.result_ready.connect(_on_celebration_result_ready)
	_finisher_director.cancelled.connect(_on_finisher_cancelled)
	_finisher_director.sequence_finished.connect(_on_finisher_sequence_finished)
	_build_ui()
	get_viewport().size_changed.connect(_fit_stage_backdrop.bind(null))
	_create_audio()
	_show_menu()
	_install_web_menu_bridge()


func _process(delta: float) -> void:
	if match_state == MatchState.Value.CELEBRATION:
		if not paused:
			_celebration_clear_elapsed += delta
			if is_instance_valid(_finisher_director) and _finisher_director.active:
				_finisher_director.advance(delta * CELEBRATION_PLAYBACK_SCALE)
			_maybe_reveal_celebration_result()
		return
	if is_instance_valid(_finisher_director) and _finisher_director.active:
		if not paused:
			_finisher_director.advance(delta)
		return
	if is_instance_valid(_fight_camera) and not paused:
		camera_shake = maxf(0.0, camera_shake - delta * 1.8)
		var t := float(Time.get_ticks_msec())
		var kick := camera_shake
		_fight_camera.position = camera_home + Vector3(sin(t * 0.079) * kick, sin(t * 0.113) * kick * 0.55, 0)
	if fight_live and not paused and match_state in [MatchState.Value.FIGHTING, MatchState.Value.FINISHER_PROMPT]:
		round_clock = maxf(0.0, round_clock - delta)
		timer_label.text = "%02d" % ceili(round_clock)
		_update_recoverable_health(delta)
		if round_clock <= 0.0:
			_end_round("time")
	if intermission > 0 and not paused:
		intermission -= delta
		if intermission <= 0 and fight_live:
			_start_round()
	if combo_label_time > 0.0 and not paused:
		combo_label_time -= delta
		if combo_label_time <= 0.0 and is_instance_valid(combo_label):
			combo_label.visible = false
	if special_feedback_time > 0.0 and not paused:
		special_feedback_time -= delta
		if special_feedback_time <= 0.0 and is_instance_valid(message_label):
			message_label.visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and fight_live:
			_toggle_pause()
		elif event.keycode == KEY_ESCAPE and select_root.visible:
			_show_menu()
		elif event.keycode == KEY_ESCAPE and map_select_root.visible:
			map_select_root.visible = false
			select_root.visible = true
		elif event.keycode in [KEY_LEFT, KEY_A] and select_root.visible:
			_select_fighter(PLAYABLE_IDS[wrapi(PLAYABLE_IDS.find(selecting) - 1, 0, PLAYABLE_IDS.size())])
		elif event.keycode in [KEY_RIGHT, KEY_D] and select_root.visible:
			_select_fighter(PLAYABLE_IDS[wrapi(PLAYABLE_IDS.find(selecting) + 1, 0, PLAYABLE_IDS.size())])
		elif event.keycode in [KEY_ENTER, KEY_SPACE] and menu_root.visible:
			_open_select("quick")
		elif event.keycode in [KEY_ENTER, KEY_SPACE] and map_select_root.visible:
			_start_selected_mode()
		elif event.keycode in [KEY_LEFT, KEY_A] and map_select_root.visible:
			_cycle_stage(-1)
		elif event.keycode in [KEY_RIGHT, KEY_D] and map_select_root.visible:
			_cycle_stage(1)
		elif event.keycode in [KEY_ENTER, KEY_SPACE] and select_root.visible:
			_confirm_selection()


func _physics_process(_delta: float) -> void:
	if is_instance_valid(_finisher_director) and _finisher_director.active:
		return
	if not fight_live or paused or player == null or not round_ready:
		# Sample held keys outside combat too, so resuming never creates an attack.
		_attack_key_held["light"] = Input.is_key_pressed(KEY_J) or Input.is_key_pressed(KEY_1)
		_attack_key_held["heavy"] = Input.is_key_pressed(KEY_K) or Input.is_key_pressed(KEY_2)
		_attack_key_held["special"] = Input.is_key_pressed(KEY_L) or Input.is_key_pressed(KEY_3)
		if paused and _special_hold.active and not (Input.is_key_pressed(KEY_L) or Input.is_key_pressed(KEY_3) or _input_held.get("special", false)):
			_special_cancel_after_pause = true
		_special_was_held = Input.is_key_pressed(KEY_L) or Input.is_key_pressed(KEY_3) or _input_held.get("special", false)
		_input_down["special"] = false
		return
	var axis := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): axis -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): axis += 1.0
	var depth_axis := 0.0
	if Input.is_key_pressed(KEY_Q): depth_axis -= 1.0
	if Input.is_key_pressed(KEY_E): depth_axis += 1.0
	if stick != null and stick.visible:
		axis = clampf(axis + stick.axis.x, -1.0, 1.0)
		if absf(stick.axis.y) >= 0.22 and absf(stick.axis.y) < 0.62:
			depth_axis = -stick.axis.y
	var light := _consume("light", KEY_J, KEY_1)
	var heavy := _consume("heavy", KEY_K, KEY_2)
	var kick := _consume("kick", KEY_U, KEY_4)
	var max_move := bool(_input_down.get("max", false))
	var special_action := _sample_special_input(_delta)
	var special := special_action == "special" or max_move
	if special and player.meter < GameFighterScript.SPECIAL_COST:
		# MAX never silently downgrades to another attack.
		special = false
		_show_special_feedback("MAX NEEDS %d%% SPECIAL ENERGY" % int(GameFighterScript.SPECIAL_COST))
	if special_action == "finisher":
		finisher_requested.emit(player, enemy, _current_finisher_definition())
		if _finisher_director.active:
			return
	player.set_controls(
		axis,
		Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or _input_down.get("jump", false) or (stick != null and stick.axis.y < -0.62),
		Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_H) or _input_down.get("block", false),
		Input.is_key_pressed(KEY_C) or _input_down.get("crouch", false) or (stick != null and stick.axis.y > 0.62),
		"special" if special else ("kick" if kick else ("heavy" if heavy else ("light" if light else ""))),
		depth_axis
	)
	_input_down["jump"] = false
	for action in ["light", "heavy", "kick", "special", "max"]: _input_down[action] = false


func _consume(action: String, key: Key, alt_key: Key) -> bool:
	# Attacks are edge-triggered. Holding a key during hit-stun must not refill
	# the input buffer every frame and launch a surprise attack on recovery.
	var held := Input.is_key_pressed(key) or Input.is_key_pressed(alt_key)
	var pressed: bool = bool(_input_down.get(action, false)) or (held and not bool(_attack_key_held.get(action, false)))
	_attack_key_held[action] = held
	_input_down[action] = false
	return pressed


func _current_finisher_definition() -> Dictionary:
	if _finisher_catalog == null or not is_instance_valid(player):
		return {}
	return _finisher_catalog.definition_for(player.character_id)


func _on_touch_action_down(action: String) -> void:
	# Every touch action dispatches exactly once, on press. Release only ends a
	# hold (GUARD); it never queues a second attack.
	if action == "special":
		_submit_touch_special()
		return
	if action == "max" and is_instance_valid(player) and player.meter < GameFighterScript.SPECIAL_COST:
		_show_special_feedback("MAX NEEDS %d%% SPECIAL ENERGY" % int(GameFighterScript.SPECIAL_COST))
		return
	_input_down[action] = true
	_input_held[action] = true
	_vibrate(12 if action != "block" else 0)


func _submit_touch_special() -> void:
	if _touch_special_consumed:
		return
	_touch_special_consumed = true
	_input_down["special"] = false
	_input_held["special"] = false
	_special_release_pending = false
	if paused or not fight_live or not round_ready or match_state not in [MatchState.Value.FIGHTING, MatchState.Value.FINISHER_PROMPT] or not is_instance_valid(player) or not is_instance_valid(enemy):
		_show_special_feedback("SP NOT AVAILABLE")
		return
	if _finisher_eligible():
		finisher_requested.emit(player, enemy, _current_finisher_definition())
		return
	if player.meter < float(_current_finisher_definition().get("meter_cost", 100.0)):
		_show_special_feedback("SP NEEDS 100% SPECIAL ENERGY")
		return
	_show_special_feedback(_current_finisher_hint())


func _show_special_feedback(text: String) -> void:
	if not is_instance_valid(message_label):
		return
	message_label.text = text
	message_label.visible = true
	special_feedback_time = 1.25


func _install_web_menu_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_web_menu_callback = JavaScriptBridge.create_callback(_on_web_menu_action)
	_web_pause_callback = JavaScriptBridge.create_callback(_on_web_pause_request)
	var window := JavaScriptBridge.get_interface("window")
	if window != null:
		window.worldFightMenuAction = _web_menu_callback
		window.worldFightPauseRequest = _web_pause_callback
		JavaScriptBridge.eval("window.worldFightSetReady?.(true); window.worldFightSetMenuVisible?.(true);")
		var pending = window.worldFightPendingAction
		if pending != null and not str(pending).is_empty():
			_on_web_menu_action([str(pending)])


func _on_web_pause_request(_arguments: Array) -> void:
	# The browser left fullscreen (or the tab lost the game surface): freeze the
	# fight until the player taps back into fullscreen and resumes.
	if fight_live and not paused:
		_toggle_pause()


func _on_web_menu_action(arguments: Array) -> void:
	if arguments.is_empty():
		return
	var action := str(arguments[0])
	match action:
		"quick": _open_select("quick")
		"campaign": _open_select("campaign")
		"lab": get_tree().change_scene_to_file("res://scenes/character_debug.tscn")
		_: return
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.worldFightAcknowledgeAction?.('%s')" % action)


func _on_touch_action_up(action: String) -> void:
	_input_held[action] = false
	if action == "special":
		_touch_special_consumed = false
		_special_release_pending = false
	if action == "block":
		_input_down[action] = false


func _sample_special_input(delta: float) -> String:
	var held: bool = Input.is_key_pressed(KEY_L) or Input.is_key_pressed(KEY_3) or _input_held.get("special", false)
	var pressed: bool = bool(_input_down.get("special", false)) or (held and not _special_was_held)
	var released := _special_release_pending or (_special_was_held and not held)
	_special_release_pending = false
	_input_down["special"] = false
	_special_was_held = held
	if _special_cancel_after_pause:
		_special_cancel_after_pause = false
		_cancel_special_hold()
		return "none"
	return _update_special_hold(delta, pressed, released)


func _finisher_eligible() -> bool:
	var context := _current_finisher_context()
	if context.is_empty():
		return false
	return FinisherRules.is_eligible(context, _current_finisher_definition())


func _current_finisher_context() -> Dictionary:
	if not fight_live or not round_ready or not is_instance_valid(player) or not is_instance_valid(enemy):
		return {}
	var dx := enemy.position.x - player.position.x
	return {
		"state": MatchState.Value.FIGHTING if match_state == MatchState.Value.FINISHER_PROMPT else match_state,
		"paused": paused,
		"match_point": FinisherRules.match_point_for(0, player_rounds, enemy_rounds),
		"health_ratio": enemy.health / enemy.max_health(),
		"meter": player.meter,
		"distance": player.position.distance_to(enemy.position),
		"facing_correct": dx * player.facing > 0.0,
		"grounded": player.is_on_floor() and enemy.is_on_floor(),
		"attacker_actionable": player.busy <= 0.0 and player.stun <= 0.0 and player.knockdown_time <= 0.0 and player.recovery_time <= 0.0 and not player.round_over,
		"actionable": player.busy <= 0.0 and enemy.busy <= 0.0 and player.stun <= 0.0 and enemy.stun <= 0.0 and player.knockdown_time <= 0.0 and enemy.knockdown_time <= 0.0 and player.recovery_time <= 0.0 and enemy.recovery_time <= 0.0 and not player.round_over and not enemy.round_over,
	}


func _update_special_hold(delta: float, pressed: bool, released: bool) -> String:
	var eligible := _finisher_eligible()
	var result: String = _special_hold.update(delta, pressed, released, eligible)
	if _special_hold.active:
		match_state = MatchState.Value.FINISHER_PROMPT
	elif match_state == MatchState.Value.FINISHER_PROMPT:
		match_state = MatchState.Value.FIGHTING
	return result


func _current_finisher_hint() -> String:
	var context := _current_finisher_context()
	if context.is_empty():
		return "SPECIAL ENERGY"
	var definition := _current_finisher_definition()
	if float(context.meter) < float(definition.get("meter_cost", 100.0)):
		return "SPECIAL ENERGY · %d%%" % int(context.meter)
	if bool(context.paused) or int(context.state) != MatchState.Value.FIGHTING:
		return "SP NOT AVAILABLE"
	if not bool(context.attacker_actionable):
		return "SP: WAIT FOR YOUR FIGHTER TO RECOVER"
	if float(context.distance) > float(definition.get("activation_range", 1.75)):
		return "SP READY: GET CLOSER OR IT WILL MISS"
	return "SP READY: TAP SP"


func _cancel_special_hold() -> void:
	_special_hold.cancel()
	if match_state == MatchState.Value.FINISHER_PROMPT:
		match_state = MatchState.Value.FIGHTING


func _try_begin_finisher(attacker: GameFighter, defender: GameFighter, definition: Dictionary) -> bool:
	if not _finisher_eligible() or attacker != player or defender != enemy:
		return false
	var opening_in_range := attacker.position.distance_to(defender.position) <= float(definition.get("activation_range", 1.75))
	var match_definition := definition.duplicate(true)
	match_definition["damage_budget"] = defender.max_health() * FINISHER_DAMAGE_RATIO
	match_definition["celebrate_on_lethal"] = player_rounds + 1 >= 2
	if not _finisher_director.begin(attacker, defender, match_definition, opening_in_range):
		return false
	match_state = MatchState.Value.FINISHER_CINEMATIC
	round_ready = false
	message_label.visible = false
	_input_down.clear()
	return true


func _on_finisher_final_hit(who: int) -> void:
	if match_state != MatchState.Value.FINISHER_CINEMATIC:
		return
	var defender: GameFighter = player if who == 0 else enemy
	if is_instance_valid(defender) and defender.health > 0.0:
		return
	match_state = MatchState.Value.KO_HOLD
	if who == 0:
		enemy_rounds += 1
	else:
		player_rounds += 1
	_update_scores()


func _on_finisher_sequence_finished(lethal: bool) -> void:
	if not fight_live:
		return
	_input_down.clear()
	_cancel_special_hold()
	if lethal:
		# The finisher won this round but not the match: hold the KO, then the
		# next round starts exactly like an ordinary knockout.
		match_state = MatchState.Value.KO_HOLD
		round_ready = false
		for fighter in [player, enemy]:
			if is_instance_valid(fighter): fighter.round_over = true
		message_label.text = "ROUND FOR YOU" if player_rounds > enemy_rounds else "ROUND LOST"
		message_label.visible = true
		intermission = 1.55
		return
	match_state = MatchState.Value.FIGHTING
	round_ready = true
	if is_instance_valid(enemy) and enemy.health > 0.0:
		enemy.round_over = false
		enemy.knock_down_and_recover()
	if is_instance_valid(player):
		player.round_over = false


func _on_celebration_started(_id: String) -> void:
	match_state = MatchState.Value.CELEBRATION
	_celebration_clear_elapsed = 0.0
	_celebration_result_marked = false
	_celebration_won = is_instance_valid(_finisher_director._attacker) and _finisher_director._attacker.who == 0
	round_ready = false
	if is_instance_valid(hud_root):
		hud_root.visible = false
	if is_instance_valid(result_root):
		result_root.visible = false
	if is_instance_valid(result_winner_art):
		result_winner_art.visible = false


func _on_celebration_result_ready(winner: int) -> void:
	_celebration_won = winner == 0
	_celebration_result_marked = true
	_maybe_reveal_celebration_result()


func _maybe_reveal_celebration_result() -> void:
	if match_state != MatchState.Value.CELEBRATION or not _celebration_result_marked:
		return
	if _celebration_clear_elapsed + 0.0001 < CELEBRATION_CLEAR_SECONDS:
		return
	_show_result(_celebration_won)


func _on_finisher_cancelled(_reason: String) -> void:
	if not fight_live:
		return
	if is_instance_valid(enemy) and enemy.health <= 0.0:
		_show_result(true)
	elif is_instance_valid(player) and player.health <= 0.0:
		_show_result(false)
	else:
		match_state = MatchState.Value.FIGHTING
		round_ready = true
		_cancel_special_hold()
		_input_down.clear()


func _build_arena() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#080e16")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#64758e")
	env.ambient_light_energy = 0.68
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	_fight_camera = Camera3D.new()
	_fight_camera.position = camera_home
	_fight_camera.current = true
	_fight_camera.fov = 30
	add_child(_fight_camera)
	_fight_camera.look_at(Vector3(0, 1.15, 0), Vector3.UP)
	_fight_camera.make_current()
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45, -25, 0)
	key.light_energy = 1.2
	key.shadow_enabled = true
	key.shadow_blur = 2.2
	add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0, 4.3, -3.8)
	rim.light_color = Color("#28aeb1")
	rim.light_energy = 1.45
	rim.omni_range = 14
	add_child(rim)
	var red := OmniLight3D.new()
	red.position = Vector3(4, 3, 2)
	red.light_color = Color("#a74855")
	red.light_energy = 0.55
	red.omni_range = 9
	add_child(red)
	_arena = Node3D.new()
	_arena.name = "Arena"
	add_child(_arena)
	_build_stage()


func _build_stage(stage_id: String = "") -> void:
	for child in _arena.get_children(): child.queue_free()
	var old_backdrop := _fight_camera.get_node_or_null("FullFrameStageBackdrop")
	if old_backdrop != null: old_backdrop.free()
	var stage := _stage_data(stage_id if stage_id != "" else selected_stage_id)
	_fight_camera.look_at(Vector3(0, float(stage.get("camera_target_y", 1.15)), 0), Vector3.UP)
	# The supplied stage art already contains the environment, floor and lighting.
	# Keep it as a single camera-facing backplate so invented walls, studio desks,
	# columns and crowd meshes cannot cover half the reference image.
	var backdrop := MeshInstance3D.new()
	backdrop.name = "FullFrameStageBackdrop"
	var backdrop_mesh := QuadMesh.new()
	var distance := 18.0
	var frame_height := 2.0 * distance * tan(deg_to_rad(_fight_camera.fov * 0.5))
	var backdrop_texture := load(str(stage.image)) as Texture2D
	backdrop.mesh = backdrop_mesh
	backdrop.set_meta("frame_height", frame_height)
	backdrop.set_meta("scale", float(stage.get("backdrop_scale", 1.0)))
	backdrop.set_meta("texture_aspect", float(backdrop_texture.get_width()) / maxf(1.0, float(backdrop_texture.get_height())) if backdrop_texture != null else 16.0 / 9.0)
	_fit_stage_backdrop(backdrop)
	var backdrop_material := StandardMaterial3D.new()
	backdrop_material.albedo_texture = backdrop_texture
	backdrop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	backdrop_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	backdrop_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	backdrop.material_override = backdrop_material
	_fight_camera.add_child(backdrop)
	backdrop.position = Vector3(0.0, float(stage.get("backdrop_y", 0.0)), -distance)
	# A collision-only floor keeps movement grounded while the image stays fully visible.
	var floor_body := StaticBody3D.new()
	floor_body.name = "InvisibleArenaFloor"
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(25.0, 0.18, 11.0)
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.12
	floor_body.add_child(floor_shape)
	_arena.add_child(floor_body)


func _fit_stage_backdrop(backdrop: MeshInstance3D = null) -> void:
	# Cover the camera frame without distorting the art: on wider phones the
	# plate grows to the frame width and crops a little top and bottom.
	if backdrop == null and is_instance_valid(_fight_camera):
		backdrop = _fight_camera.get_node_or_null("FullFrameStageBackdrop") as MeshInstance3D
	if backdrop == null or not backdrop.mesh is QuadMesh:
		return
	var visible_size := get_viewport().get_visible_rect().size
	var frame_aspect := visible_size.x / maxf(1.0, visible_size.y)
	var frame_height := float(backdrop.get_meta("frame_height", 1.0))
	var texture_aspect := float(backdrop.get_meta("texture_aspect", 16.0 / 9.0))
	var height := maxf(frame_height, frame_height * frame_aspect / texture_aspect)
	(backdrop.mesh as QuadMesh).size = Vector2(height * texture_aspect, height) * float(backdrop.get_meta("scale", 1.0))


func _glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.roughness = 0.5
	return material


func _box(parent: Node3D, dims: Vector3, at: Vector3, color: Color, collision: bool) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dims
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	if color.r > 0.1 and color.g > 0.4 and color.b > 0.4:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.7
	instance.material_override = mat
	instance.position = at
	parent.add_child(instance)
	if collision:
		var body := StaticBody3D.new()
		body.position = at
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = dims
		shape.shape = box
		body.add_child(shape)
		parent.add_child(body)


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(hud_root)
	_build_hud()
	_build_menu()
	_build_select()
	_build_map_select()
	_build_pause()
	_build_result()


func _build_hud() -> void:
	# Layout follows the supplied HUD reference: two angled fighter panels with a
	# circular portrait, a segmented slanted health bar and a Special Energy row,
	# and an octagonal round clock between them. Panels anchor to the screen
	# edges and the clock to the centre, so wide phones get no gaps or overlap.
	var frame := Control.new()
	frame.name = "CombatHUDFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(frame)
	frame.set_anchors_preset(Control.PRESET_TOP_WIDE)
	frame.offset_left = 0
	frame.offset_right = 0
	frame.offset_top = 0
	frame.offset_bottom = HUD_FRAME_HEIGHT
	var player_group := _build_fighter_panel(frame, true)
	var enemy_group := _build_fighter_panel(frame, false)
	player_group.set_anchors_preset(Control.PRESET_TOP_LEFT)
	player_group.offset_left = 10
	player_group.offset_right = 10 + HUD_PANEL_SIZE.x
	player_group.offset_top = 6
	player_group.offset_bottom = 6 + HUD_PANEL_SIZE.y
	enemy_group.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	enemy_group.offset_left = -10 - HUD_PANEL_SIZE.x
	enemy_group.offset_right = -10
	enemy_group.offset_top = 6
	enemy_group.offset_bottom = 6 + HUD_PANEL_SIZE.y

	var timer_group := Control.new()
	timer_group.name = "TimerMedallion"
	timer_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(timer_group)
	timer_group.set_anchors_preset(Control.PRESET_CENTER_TOP)
	timer_group.offset_left = -75
	timer_group.offset_right = 75
	timer_group.offset_top = 4
	timer_group.offset_bottom = 124
	var octagon := PackedVector2Array([Vector2(34, 0), Vector2(116, 0), Vector2(150, 28), Vector2(150, 92), Vector2(122, 120), Vector2(28, 120), Vector2(0, 92), Vector2(0, 28)])
	_polygon(timer_group, "TimerHexPlate", octagon, Color(0.02, 0.05, 0.08, 0.93))
	_outline(timer_group, "TimerHexOutline", octagon, Color(0.40, 0.86, 0.90, 0.75), 2.5)
	timer_label = _label(timer_group, "60", Rect2(0, 6, 150, 74), 60, Color("#e9fbff"), HORIZONTAL_ALIGNMENT_CENTER)
	timer_label.name = "TimerLabel"
	timer_label.add_theme_color_override("font_outline_color", Color(0.10, 0.55, 0.62, 0.9))
	timer_label.add_theme_constant_override("outline_size", 4)
	round_label = _label(timer_group, "BEST OF 3  ·  ROUND 1", Rect2(0, 84, 150, 22), 11, Color("#d3e3e8"), HORIZONTAL_ALIGNMENT_CENTER)
	round_label.name = "RoundLabel"

	# Pause and fullscreen sit under the CPU panel, out of the action area.
	var system_buttons := Control.new()
	system_buttons.name = "SystemButtons"
	frame.add_child(system_buttons)
	system_buttons.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	system_buttons.offset_left = -112
	system_buttons.offset_right = -14
	system_buttons.offset_top = HUD_FRAME_HEIGHT + 2
	system_buttons.offset_bottom = HUD_FRAME_HEIGHT + 44
	var pause_btn := _button(system_buttons, "Ⅱ", Rect2(0, 0, 44, 40), "#1d3140", 16)
	pause_btn.name = "PauseButton"
	pause_btn.pressed.connect(_toggle_pause)
	var fullscreen_btn := _button(system_buttons, "⛶", Rect2(52, 0, 44, 40), "#1d3140", 18)
	fullscreen_btn.name = "FullscreenButton"
	fullscreen_btn.pressed.connect(_toggle_fullscreen)
	message_label = _label(hud_root, "", Rect2(280, 144, 720, 78), 32, Color("#f0f4f3"), HORIZONTAL_ALIGNMENT_CENTER)
	message_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	message_label.add_theme_constant_override("shadow_offset_x", 2)
	message_label.add_theme_constant_override("shadow_offset_y", 3)
	combo_label = _label(hud_root, "", Rect2(460, 232, 360, 48), 25, Color("#ffe1a0"), HORIZONTAL_ALIGNMENT_CENTER)
	combo_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	combo_label.add_theme_constant_override("shadow_offset_x", 2)
	combo_label.add_theme_constant_override("shadow_offset_y", 3)
	combo_label.visible = false
	for overlay in [message_label, combo_label]:
		var rect := Rect2(overlay.position, overlay.size)
		overlay.anchor_left = 0.5
		overlay.anchor_right = 0.5
		overlay.offset_left = rect.position.x - DESIGN_SIZE.x * 0.5
		overlay.offset_right = rect.end.x - DESIGN_SIZE.x * 0.5
	_build_touch_controls()
	hud_root.visible = false


func _build_fighter_panel(frame: Control, is_player: bool) -> Control:
	var side := "Player" if is_player else "Enemy"
	var accent := Color("#46dcd8") if is_player else Color("#f0566b")
	var w := HUD_PANEL_SIZE.x
	var h := HUD_PANEL_SIZE.y
	# x positions are authored for the player panel and mirrored for the CPU.
	var mx := func(x: float, width: float = 0.0) -> float: return x if is_player else w - x - width
	var group := Control.new()
	group.name = side + "HUDGroup"
	group.size = HUD_PANEL_SIZE
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(group)
	var plate_points := PackedVector2Array([Vector2(20, 0), Vector2(w - 16, 0), Vector2(w, 16), Vector2(w, h - 30), Vector2(w - 30, h), Vector2(0, h), Vector2(0, 20)])
	if not is_player:
		for i in range(plate_points.size()): plate_points[i].x = w - plate_points[i].x
	_polygon(group, side + "HUDWingPlate", plate_points, Color(0.015, 0.035, 0.055, 0.88))
	_outline(group, side + "HUDWingOutline", plate_points, Color(accent, 0.55), 2.0)
	var portrait_center := Vector2(mx.call(64.0), 62.0)
	_polygon(group, side + "PortraitRing", _circle_points(portrait_center, 53.0, 40), Color(accent, 0.85))
	_polygon(group, side + "PortraitWell", _circle_points(portrait_center, 48.0, 40), Color(0.03, 0.07, 0.10, 1.0))
	var accent_arc := Line2D.new()
	accent_arc.name = side + "PortraitArc"
	accent_arc.width = 4.0
	accent_arc.default_color = accent.lightened(0.35)
	var arc_from := PI * 1.05 if is_player else -PI * 0.05
	for i in range(13):
		accent_arc.add_point(portrait_center + Vector2.RIGHT.rotated(arc_from + (PI * 0.45 if is_player else -PI * 0.45) * float(i) / 12.0) * 58.0)
	group.add_child(accent_arc)
	var portrait := TextureRect.new()
	portrait.name = side + "Portrait"
	portrait.texture = load(_fighter_thumbnail_path("bennet" if is_player else "avigdor"))
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.position = portrait_center - Vector2(46, 46)
	portrait.size = Vector2(92, 92)
	portrait.flip_h = not is_player
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask := ShaderMaterial.new()
	mask.shader = CIRCLE_MASK_SHADER
	portrait.material = mask
	group.add_child(portrait)
	var align := HORIZONTAL_ALIGNMENT_LEFT if is_player else HORIZONTAL_ALIGNMENT_RIGHT
	var tag := _label(group, "PLAYER 1" if is_player else "CPU", Rect2(mx.call(128.0, 200.0), 4, 200, 20), 14, accent.lightened(0.15), align)
	tag.name = side + "Tag"
	var name_label := _label(group, "BENNET" if is_player else "AVIGDOR", Rect2(mx.call(128.0, 322.0), 22, 322, 38), 28, Color("#f6f8f6"), align)
	name_label.name = side + "Name"
	name_label.clip_text = true
	var markers := Control.new()
	markers.name = side + "RoundMarkers"
	markers.position = Vector2(mx.call(458.0, 64.0), 30)
	markers.size = Vector2(64, 20)
	group.add_child(markers)
	for i in range(2):
		var pip := _panel(markers, Rect2((i * 30) if is_player else (34 - i * 30), 2, 22, 12), Color("#263943"))
		pip.name = "Round%d" % (i + 1)
		(player_round_markers if is_player else enemy_round_markers).append(pip)
	var bar_rect := Rect2(mx.call(HUD_HP_BAR_X, HUD_HP_BAR_WIDTH), 64, HUD_HP_BAR_WIDTH, 28)
	var recoverable := _slant_bar(group, side + "RecoverableHealth", bar_rect, Color(0.96, 0.82, 0.45, 0.72), not is_player, 7, 12.0)
	var health := _slant_bar(group, side + "HealthBar", bar_rect, accent, not is_player, 7, 12.0)
	health.show_back = false
	var meter_title := _label(group, "SPECIAL ENERGY", Rect2(mx.call(HUD_HP_BAR_X + 4.0, 200.0), 94, 200, 18), 12, Color("#e8c45c"), align)
	meter_title.name = side + "SpecialLabel"
	var meter := _slant_bar(group, side + "SpecialBar", Rect2(mx.call(HUD_HP_BAR_X + 4.0, 290.0), 112, 290, 8), Color("#f2c94c"), not is_player, 1, 4.0)
	meter.max_value = 100.0
	meter.value = 0.0
	meter.tail_stripes = 0
	var percent := _label(group, "0%", Rect2(mx.call(HUD_HP_BAR_X + 300.0, 90.0), 100, 90, 24), 15, Color("#f6e6b0"), HORIZONTAL_ALIGNMENT_LEFT if is_player else HORIZONTAL_ALIGNMENT_RIGHT)
	percent.name = side + "SpecialPercent"
	if is_player:
		player_hud_portrait = portrait
		player_recoverable_bar = recoverable
		player_health_bar = health
		player_meter_bar = meter
		player_meter_label = meter_title
		player_meter_percent = percent
	else:
		enemy_hud_portrait = portrait
		enemy_recoverable_bar = recoverable
		enemy_health_bar = health
		enemy_meter_bar = meter
		enemy_meter_label = meter_title
		enemy_meter_percent = percent
	return group


func _slant_bar(parent: Control, node_name: String, rect: Rect2, color: Color, mirrored: bool, segment_count: int, slant: float) -> SlantBarScript:
	var bar := SlantBarScript.new()
	bar.name = node_name
	bar.position = rect.position
	bar.size = rect.size
	bar.max_value = 112.0
	bar.value = 112.0
	bar.fill_color = color
	bar.mirrored = mirrored
	bar.segments = segment_count
	bar.skew = slant
	parent.add_child(bar)
	return bar


func _outline(parent: CanvasItem, node_name: String, points: PackedVector2Array, color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.name = node_name
	line.points = points
	line.closed = true
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_SHARP
	parent.add_child(line)
	return line


func _circle_points(center: Vector2, radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		points.append(center + Vector2.RIGHT.rotated(TAU * float(i) / float(count)) * radius)
	return points


func _hud_node(node_name: String) -> Node:
	return hud_root.get_node("CombatHUDFrame").find_child(node_name, true, false)


func _build_touch_controls() -> void:
	stick = VirtualStickScript.new()
	stick.name = "MoveStick"
	stick.visible = false
	hud_root.add_child(stick)
	# Bottom-left anchor: 50 px from the left edge, 36 px above the bottom.
	stick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	stick.offset_left = 50
	stick.offset_right = 50 + 218
	stick.offset_top = -36 - 218
	stick.offset_bottom = -36
	var pad := Control.new()
	pad.name = "TouchActionPad"
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(pad)
	pad.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pad.offset_left = -TOUCH_PAD_SIZE.x
	pad.offset_top = -TOUCH_PAD_SIZE.y
	pad.offset_right = 0
	pad.offset_bottom = 0
	for spec in TOUCH_CONTROL_LAYOUT:
		var center: Vector2 = TOUCH_PAD_SIZE - spec.center
		var button_size: Vector2 = spec.size
		var b = TouchActionButtonScript.new()
		b.configure(str(spec.action), str(spec.title), str(spec.shape), str(spec.icon), Color(str(spec.color)), Rect2(center - button_size * 0.5, button_size))
		b.visible = false
		pad.add_child(b)
		b.button_down.connect(func():
			_on_touch_action_down(spec.action)
		)
		b.button_up.connect(func():
			_on_touch_action_up(spec.action)
		)
		buttons[spec.action] = b
	_set_touch_controls_visible(_detect_mobile_input())


func _refresh_touch_energy_state() -> void:
	if not is_instance_valid(player) or buttons.is_empty():
		return
	var max_ready := player.meter >= GameFighterScript.SPECIAL_COST
	var finish_ready := player.meter >= float(_current_finisher_definition().get("meter_cost", 100.0))
	if buttons.has("max"): buttons.max.set_state(max_ready, false)
	if buttons.has("special"): buttons.special.set_state(finish_ready, finish_ready)


func _vibrate(milliseconds: int) -> void:
	if milliseconds <= 0 or not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("navigator.vibrate && navigator.vibrate(%d)" % milliseconds)


func _mobile_input_available(touchscreen: bool, web_build: bool, web_touch_points: int, short_edge: int) -> bool:
	# Godot's touchscreen flag and JavaScript bridge values vary between mobile
	# browsers. Web controls stay available during combat; the HUD parent keeps
	# them out of menus and desktop players can continue using the keyboard.
	return touchscreen or web_build or web_touch_points > 0 or short_edge <= 600


func _detect_mobile_input() -> bool:
	var touch_points := 0
	var short_edge := 9999
	if OS.has_feature("web"):
		touch_points = int(JavaScriptBridge.eval("navigator.maxTouchPoints || 0"))
		short_edge = int(JavaScriptBridge.eval("Math.min(window.innerWidth, window.innerHeight)"))
	return _mobile_input_available(DisplayServer.is_touchscreen_available(), OS.has_feature("web"), touch_points, short_edge)


func _set_touch_controls_visible(value: bool) -> void:
	if is_instance_valid(stick):
		stick.visible = value
	for action in buttons:
		if is_instance_valid(buttons[action]):
			buttons[action].visible = value


func _build_menu() -> void:
	menu_root = Control.new()
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu_root)
	var hero := TextureRect.new()
	hero.name = "MainHeroBackground"
	hero.texture = load(MAIN_HERO_PATH)
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(hero)
	_wash(menu_root, Rect2(0, 0, 1280, 720), Color(0.005, 0.010, 0.020, 0.18))
	_wash(menu_root, Rect2(0, 0, 470, 720), Color(0.005, 0.012, 0.024, 0.48))
	var action_panel := Control.new()
	action_panel.name = "MenuActionPanel"
	action_panel.position = Vector2(58, 72)
	action_panel.size = Vector2(355, 570)
	menu_root.add_child(action_panel)
	_label(action_panel, "WORLD FIGHT", Rect2(0, 0, 350, 64), 45, Color("#f7f2e8"), HORIZONTAL_ALIGNMENT_LEFT)
	_panel(action_panel, Rect2(0, 69, 76, 3), Color("#df5968"))
	_label(action_panel, "MAIN MENU", Rect2(0, 86, 330, 30), 14, Color("#d9b566"), HORIZONTAL_ALIGNMENT_LEFT)
	var quick := _menu_text_button(action_panel, "START FIGHT", Rect2(0, 152, 330, 52), 21)
	quick.name = "SingleFightButton"
	quick.pressed.connect(func(): _open_select("quick"))
	var campaign := _menu_text_button(action_panel, "CAMPAIGN", Rect2(0, 214, 330, 52), 18)
	campaign.name = "CampaignButton"
	campaign.pressed.connect(func(): _open_select("campaign"))
	var model_lab := _menu_text_button(action_panel, "FIGHTER LAB", Rect2(0, 276, 330, 52), 18)
	model_lab.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/character_debug.tscn"))
	_label(action_panel, "OFFLINE  •  13 FIGHTERS", Rect2(0, 484, 340, 20), 9, Color("#7f929b"), HORIZONTAL_ALIGNMENT_LEFT)
	_label(menu_root, "WORLD FIGHT  /  ELECTION EDITION", Rect2(58, 676, 420, 20), 9, Color("#8999a0"), HORIZONTAL_ALIGNMENT_LEFT)
	var fullscreen_btn := _button(menu_root, "⛶", Rect2(1212, 24, 44, 40), "#233440", 20)
	fullscreen_btn.name = "FullscreenButton"
	fullscreen_btn.tooltip_text = "FULL SCREEN"
	fullscreen_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fullscreen_btn.offset_left = -68
	fullscreen_btn.offset_right = -24
	fullscreen_btn.offset_top = 24
	fullscreen_btn.offset_bottom = 64
	fullscreen_btn.pressed.connect(_toggle_fullscreen)


func _build_select() -> void:
	select_root = Control.new()
	select_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(select_root)
	_panel(select_root, Rect2(0, 0, 1280, 720), Color("#080e16"))
	_wash(select_root, Rect2(0, 0, 640, 720), Color(0.025, 0.16, 0.21, 0.32))
	_wash(select_root, Rect2(640, 0, 640, 720), Color(0.25, 0.035, 0.075, 0.30))
	_label(select_root, "SELECT YOUR FIGHTER", Rect2(340, 18, 600, 44), 29, Color("#f4f0e7"), HORIZONTAL_ALIGNMENT_CENTER)
	_label(select_root, "PLAYER 1 SELECTION  ·  CPU RIVAL IS RANDOM", Rect2(390, 58, 500, 20), 10, Color("#a9b7bc"), HORIZONTAL_ALIGNMENT_CENTER)
	# The player chooses one fighter. The CPU stays concealed until the arena loads.
	select_portrait = TextureRect.new()
	select_portrait.texture = _fighter_art("bennet")
	select_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	select_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	select_portrait.position = Vector2(0, 76); select_portrait.size = Vector2(500, 544)
	select_root.add_child(select_portrait)
	var right_art := TextureRect.new()
	right_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	right_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	right_art.position = Vector2(780, 76); right_art.size = Vector2(500, 544); right_art.modulate = Color(0.22, 0.25, 0.30, 1)
	select_root.add_child(right_art)
	_wash(select_root, Rect2(0, 76, 500, 544), Color(0.025, 0.10, 0.14, 0.30))
	_wash(select_root, Rect2(780, 76, 500, 544), Color(0.18, 0.025, 0.055, 0.48))
	select_name_label = _label(select_root, "BENNET", Rect2(34, 300, 410, 56), 39, Color("#f7f4eb"), HORIZONTAL_ALIGNMENT_LEFT)
	select_style_label = _label(select_root, "THE FOUNDER  /  COMBO STRIKER", Rect2(36, 354, 410, 24), 11, Color("#76ded8"), HORIZONTAL_ALIGNMENT_LEFT)
	var mystery_mark := _label(select_root, "?", Rect2(894, 128, 300, 220), 144, Color("#e7c27a"), HORIZONTAL_ALIGNMENT_CENTER)
	mystery_mark.name = "MysteryCpuMark"
	select_rival_name = _label(select_root, "RANDOM OPPONENT", Rect2(830, 300, 410, 56), 27, Color("#f7f4eb"), HORIZONTAL_ALIGNMENT_RIGHT)
	select_rival_style = _label(select_root, "REVEALED IN THE ARENA", Rect2(830, 354, 410, 24), 11, Color("#f49b9d"), HORIZONTAL_ALIGNMENT_RIGHT)
	select_rival_portrait = right_art
	select_stats_label = _label(select_root, "STYLE  ·  Close-range pressure\nSIGNATURE  ·  Founder’s Rush", Rect2(430, 92, 420, 52), 11, Color("#c6d1d2"), HORIZONTAL_ALIGNMENT_CENTER)
	var roster_back := _panel(select_root, Rect2(286, 398, 708, 208), Color(0.010, 0.019, 0.031, 0.94))
	roster_back.name = "RosterDock"
	_panel(roster_back, Rect2(0, 0, 708, 3), Color("#d8b562"))
	_label(select_root, "FIGHTER ROSTER", Rect2(490, 402, 300, 22), 10, Color("#e2c374"), HORIZONTAL_ALIGNMENT_CENTER)
	var roster_grid := GridContainer.new()
	roster_grid.name = "RosterGrid"
	roster_grid.position = Vector2(308, 430)
	roster_grid.size = Vector2(664, 168)
	roster_grid.columns = 7
	roster_grid.add_theme_constant_override("h_separation", 6)
	roster_grid.add_theme_constant_override("v_separation", 6)
	select_root.add_child(roster_grid)
	for i in range(PLAYABLE_IDS.size()):
		var fighter_id: String = PLAYABLE_IDS[i]
		var tile := _button(roster_grid, "", Rect2(0, 0, 88, 78), "#172632", 18)
		tile.custom_minimum_size = Vector2(88, 78)
		tile.name = "RosterTile_" + fighter_id
		roster_tiles.append(tile)
		var face := TextureRect.new()
		face.texture = load(_fighter_thumbnail_path(fighter_id))
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.position = Vector2(3, 3); face.size = Vector2(82, 72); face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(face)
		tile.pressed.connect(func(id: String = fighter_id): _select_fighter(id))
	_panel(select_root, Rect2(0, 628, 1280, 92), Color(0.012, 0.022, 0.034, 0.96))
	var back := _button(select_root, "BACK", Rect2(48, 647, 150, 48), "#263844", 14)
	back.pressed.connect(_show_menu)
	var confirm := _button(select_root, "CONFIRM FIGHT", Rect2(1002, 642, 230, 56), "#a4793b", 16)
	confirm.name = "ConfirmFight"
	confirm.pressed.connect(_confirm_selection)
	_label(select_root, "ARROWS  /  SELECT     ENTER  /  CONFIRM", Rect2(453, 649, 374, 30), 10, Color("#9cabb1"), HORIZONTAL_ALIGNMENT_CENTER)
	select_root.visible = false
	_center_design_children(select_root)
	_refresh_roster()


func _build_map_select() -> void:
	map_select_root = Control.new()
	map_select_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(map_select_root)
	_panel(map_select_root, Rect2(0, 0, 1280, 720), Color("#080e16"))
	_label(map_select_root, "SELECT YOUR ARENA", Rect2(48, 24, 690, 48), 30, Color("#f4f0e7"), HORIZONTAL_ALIGNMENT_LEFT)
	_label(map_select_root, "FIVE STAGES · PICK THE SETTING FOR YOUR FIGHT", Rect2(51, 70, 700, 22), 11, Color("#99afb7"), HORIZONTAL_ALIGNMENT_LEFT)
	for i in range(STAGES.size()):
		var col := i % 3
		var row := i / 3
		var rect := Rect2(45 + col * 398, 118 + row * 242, 376, 220)
		var card := _button(map_select_root, "", rect, "#14212c", 15)
		card.name = "StageCard_" + str(i)
		var art := TextureRect.new()
		art.texture = load(str(STAGES[i].image))
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.position = Vector2(4, 4); art.size = Vector2(368, 172); art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(art)
		var shade := _panel(card, Rect2(4, 150, 368, 48), Color(0.015, 0.025, 0.04, 0.91))
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var title := _label(card, str(STAGES[i].name), Rect2(14, 151, 348, 23), 14, Color("#f5f1e8"), HORIZONTAL_ALIGNMENT_LEFT)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var subtitle := _label(card, str(STAGES[i].subtitle), Rect2(14, 174, 348, 18), 10, Color("#c1cbd0"), HORIZONTAL_ALIGNMENT_LEFT)
		subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage_buttons.append(card)
		card.pressed.connect(func(id: String = str(STAGES[i].id)): _select_stage(id))
	_panel(map_select_root, Rect2(0, 622, 1280, 98), Color(0.012, 0.022, 0.034, 0.96))
	var back := _button(map_select_root, "BACK TO FIGHTERS", Rect2(48, 646, 220, 48), "#263844", 13)
	back.pressed.connect(func(): map_select_root.visible = false; select_root.visible = true)
	_label(map_select_root, "ARROWS TO BROWSE  ·  ENTER TO FIGHT", Rect2(415, 654, 390, 24), 10, Color("#9cabb1"), HORIZONTAL_ALIGNMENT_CENTER)
	var enter := _button(map_select_root, "ENTER ARENA", Rect2(1000, 642, 230, 56), "#a4793b", 16)
	enter.pressed.connect(_start_selected_mode)
	map_select_root.visible = false
	_center_design_children(map_select_root)
	_refresh_stage_cards()


func _open_select(mode: String) -> void:
	pending_mode = mode
	menu_root.visible = false
	map_select_root.visible = false
	select_root.visible = true
	_refresh_roster()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.worldFightSetMenuVisible?.(false)")


func _select_fighter(id: String) -> void:
	if not FIGHTER_DATA.has(id): return
	selecting = id
	var data: Dictionary = FIGHTER_DATA[id]
	select_portrait.texture = _fighter_art(id)
	select_name_label.text = str(data.name)
	select_style_label.text = str(data.callout)
	select_stats_label.text = "STYLE  ·  %s\nSIGNATURE  ·  %s" % [data.style, data.signature]
	select_rival_portrait.texture = null
	select_rival_name.text = "RANDOM OPPONENT"
	select_rival_style.text = "REVEALED IN THE ARENA"
	_refresh_roster()
	_play_sound("menu")


func _refresh_roster() -> void:
	for i in range(mini(PLAYABLE_IDS.size(), roster_tiles.size())):
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#14242e")
		var is_selected: bool = PLAYABLE_IDS[i] == selecting
		style.border_color = Color("#4ad4ce") if is_selected else Color("#627681")
		style.set_border_width_all(3 if is_selected else 1)
		style.set_corner_radius_all(3)
		roster_tiles[i].add_theme_stylebox_override("normal", style)
		roster_tiles[i].add_theme_stylebox_override("hover", style)


func _confirm_selection() -> void:
	select_root.visible = false
	map_select_root.visible = true
	_refresh_stage_cards()


func _select_stage(id: String) -> void:
	selected_stage_id = id
	_refresh_stage_cards()


func _cycle_stage(step: int) -> void:
	var current := 0
	for i in range(STAGES.size()):
		if str(STAGES[i].id) == selected_stage_id: current = i
	_select_stage(str(STAGES[wrapi(current + step, 0, STAGES.size())].id))


func _refresh_stage_cards() -> void:
	for i in range(mini(STAGES.size(), stage_buttons.size())):
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#172632")
		var selected := str(STAGES[i].id) == selected_stage_id
		style.border_color = Color(str(STAGES[i].accent)) if selected else Color("#627681")
		style.set_border_width_all(4 if selected else 1)
		style.set_corner_radius_all(5)
		stage_buttons[i].add_theme_stylebox_override("normal", style)
		stage_buttons[i].add_theme_stylebox_override("hover", style)


func _start_selected_mode() -> void:
	if pending_mode == "campaign": _start_campaign()
	else: _start_quick_fight()


func _stage_data(id: String) -> Dictionary:
	for stage in STAGES:
		if str(stage.id) == id: return stage
	return STAGES[0]


func _fighter_hero_path(id: String) -> String:
	return "res://assets/characters/%s-card.png" % id.replace("_", "-")


func _fighter_thumbnail_path(id: String) -> String:
	return "res://assets/characters/portraits/%s.png" % id


func _fighter_art(id: String, face_center: bool = false) -> Texture2D:
	var cache_key := id + ("_center" if face_center else "_base")
	if _art_cache.has(cache_key): return _art_cache[cache_key] as Texture2D
	var art := load(_fighter_hero_path(id)) as Texture2D
	if face_center and art != null:
		var mirrored := art.get_image()
		mirrored.flip_x()
		art = ImageTexture.create_from_image(mirrored)
	_art_cache[cache_key] = art
	return art


func _next_rival_id(id: String) -> String:
	var index := PLAYABLE_IDS.find(id)
	return PLAYABLE_IDS[(index + 1) % PLAYABLE_IDS.size()]


func _fighter_name(id: String) -> String:
	return str(FIGHTER_DATA.get(id, FIGHTER_DATA.bennet).name)


func _build_pause() -> void:
	pause_root = Control.new()
	pause_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_root.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	ui.add_child(pause_root)
	_wash(pause_root, Rect2(0, 0, 1280, 720), Color(0.004, 0.008, 0.016, 0.70))
	_wash(pause_root, Rect2(0, 0, 430, 720), Color(0.008, 0.016, 0.028, 0.94))
	var box := Control.new()
	box.position = Vector2(58, 116)
	box.size = Vector2(320, 440)
	pause_root.add_child(box)
	_label(box, "FIGHT PAUSED", Rect2(0, 0, 320, 60), 35, Color("#f0f1e9"), HORIZONTAL_ALIGNMENT_LEFT)
	_panel(box, Rect2(0, 72, 74, 3), Color("#df5968"))
	_label(box, "THE ARENA IS FROZEN", Rect2(0, 90, 320, 24), 11, Color("#a9b8bf"), HORIZONTAL_ALIGNMENT_LEFT)
	var resume := _menu_text_button(box, "RESUME", Rect2(0, 158, 300, 54), 20)
	resume.pressed.connect(_toggle_pause)
	var menu := _menu_text_button(box, "RETURN TO MENU", Rect2(0, 222, 300, 54), 17)
	menu.pressed.connect(_return_to_menu)
	_label(box, "ESC  /  RESUME", Rect2(0, 342, 300, 22), 9, Color("#72858e"), HORIZONTAL_ALIGNMENT_LEFT)
	pause_root.visible = false


func _build_result() -> void:
	result_root = Control.new()
	result_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(result_root)
	# The live winner pose is the focus. Result copy stays in a compact corner
	# card so authored celebrations remain readable from head to toe.
	var result_darken := _panel(result_root, Rect2(0, 0, 1280, 720), Color(0.005, 0.008, 0.015, 0.12))
	result_darken.name = "ResultDarken"
	var corner_card := _panel(result_root, Rect2(40, 112, 448, 244), Color(0.010, 0.018, 0.030, 0.72))
	corner_card.name = "ResultCornerCard"
	var backdrop_word := _label(result_root, "VICTORY", Rect2(46, 126, 430, 58), 43, Color(0.92, 0.76, 0.42, 0.09), HORIZONTAL_ALIGNMENT_LEFT)
	backdrop_word.name = "ResultBackdropWord"
	result_winner_art = TextureRect.new()
	result_winner_art.name = "ResultWinnerArt"
	result_winner_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result_winner_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result_winner_art.position = Vector2(790, 55)
	result_winner_art.size = Vector2(470, 610)
	result_winner_art.modulate = Color(1, 1, 1, 0.42)
	result_winner_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_root.add_child(result_winner_art)
	result_winner_art.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	result_winner_art.offset_left = -490
	result_winner_art.offset_right = -20
	result_winner_art.offset_top = 55
	result_winner_art.offset_bottom = -55
	result_accent = _panel(result_root, Rect2(40, 112, 6, 244), Color("#39cbc6"))
	result_accent.name = "ResultAccent"
	var content := Control.new()
	content.name = "ResultContent"
	content.position = Vector2(66, 132)
	content.size = Vector2(396, 204)
	result_root.add_child(content)
	_label(content, "FINAL RESULT", Rect2(0, 0, 396, 24), 11, Color("#d9b566"), HORIZONTAL_ALIGNMENT_LEFT)
	var title := _label(content, "FIGHT OVER", Rect2(0, 24, 396, 70), 56, Color("#f7f2e8"), HORIZONTAL_ALIGNMENT_LEFT)
	title.name = "ResultTitle"
	var winner_name := _label(content, "", Rect2(0, 94, 396, 32), 21, Color("#72d9d4"), HORIZONTAL_ALIGNMENT_LEFT)
	winner_name.name = "WinnerName"
	var detail := _label(content, "", Rect2(0, 132, 396, 64), 13, Color("#c3cdd0"), HORIZONTAL_ALIGNMENT_LEFT)
	detail.name = "ResultDetail"
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var next := _button(result_root, "CONTINUE", Rect2(40, 620, 210, 54), "#1d777a", 16)
	next.name = "ContinueButton"
	next.pressed.connect(_continue_from_result)
	var new_opponent := _button(result_root, "NEW OPPONENT", Rect2(262, 620, 210, 54), "#7a4a2a", 14)
	new_opponent.name = "NewOpponentButton"
	new_opponent.pressed.connect(_start_quick_fight)
	var menu := _button(result_root, "RETURN TO MENU", Rect2(484, 620, 210, 54), "#3b4852", 13)
	menu.name = "ResultMenuButton"
	menu.pressed.connect(_return_to_menu)
	_label(result_root, "ENTER  /  CONTINUE", Rect2(40, 682, 432, 22), 9, Color("#a0afb5"), HORIZONTAL_ALIGNMENT_LEFT)
	result_root.visible = false


func _panel(parent: Control, rect: Rect2, color: Color) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_color = Color(0.40, 0.72, 0.73, 0.22)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	_fit_design_rect(panel, rect)
	return panel


func _polygon(parent: CanvasItem, node_name: String, points: PackedVector2Array, color: Color) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.name = node_name
	polygon.polygon = points
	polygon.color = color
	parent.add_child(polygon)
	return polygon


func _octagon_points(center: Vector2, radius: float, diagonal_ratio: float) -> PackedVector2Array:
	var diagonal := radius * diagonal_ratio
	return PackedVector2Array([
		center + Vector2(-diagonal, -diagonal), center + Vector2(0, -radius), center + Vector2(diagonal, -diagonal), center + Vector2(radius, 0),
		center + Vector2(diagonal, diagonal), center + Vector2(0, radius), center + Vector2(-diagonal, diagonal), center + Vector2(-radius, 0)
	])


func _make_button_transparent(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.border_color = Color(1, 1, 1, 0)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.06, 0.92))
	button.add_theme_constant_override("outline_size", 5)


func _round_button(button: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color.lightened(0.12) if state == "hover" else color
		if state == "pressed":
			style.bg_color = color.darkened(0.18)
		style.border_color = Color("#ffe06b")
		style.set_border_width_all(3)
		style.set_corner_radius_all(40)
		button.add_theme_stylebox_override(state, style)


func _wash(parent: Control, rect: Rect2, color: Color) -> ColorRect:
	var wash := ColorRect.new()
	wash.position = rect.position
	wash.size = rect.size
	wash.color = color
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(wash)
	_fit_design_rect(wash, rect)
	return wash


func _fit_design_rect(control: Control, rect: Rect2) -> void:
	# The game is authored on a 1280x720 canvas and the window uses the
	# "expand" aspect, so wider phones add width. Full-screen and full-height
	# layers stretch with the window; everything else keeps its authored spot.
	if rect.position.x == 0.0 and rect.size.x == DESIGN_SIZE.x:
		control.anchor_right = 1.0
		control.offset_right = 0.0
	if rect.position.y == 0.0 and rect.size.y == DESIGN_SIZE.y:
		control.anchor_bottom = 1.0
		control.offset_bottom = 0.0


func _center_design_children(root: Control) -> void:
	# Keep a 1280x720 screen centred on wider (or taller) windows. Full-screen
	# backgrounds already stretch; every other control keeps its offset from
	# the design centre.
	for child in root.get_children():
		if not child is Control:
			continue
		var control := child as Control
		var rect := Rect2(control.position, control.size)
		if not is_equal_approx(control.anchor_right, 1.0):
			control.anchor_left = 0.5
			control.anchor_right = 0.5
			control.offset_left = rect.position.x - DESIGN_SIZE.x * 0.5
			control.offset_right = rect.end.x - DESIGN_SIZE.x * 0.5
		if not is_equal_approx(control.anchor_bottom, 1.0):
			control.anchor_top = 0.5
			control.anchor_bottom = 0.5
			control.offset_top = rect.position.y - DESIGN_SIZE.y * 0.5
			control.offset_bottom = rect.end.y - DESIGN_SIZE.y * 0.5


func _label(parent: Control, content: String, rect: Rect2, font_size: int, color: Color, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = content
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label


func _button(parent: Control, title: String, rect: Rect2, color: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = title
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color("#f0f5f1"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#d8eee8"))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(color) if state != "hover" else Color(color).lightened(0.16)
		style.corner_radius_top_left = 2
		style.corner_radius_top_right = 2
		style.corner_radius_bottom_left = 2
		style.corner_radius_bottom_right = 2
		if state == "pressed": style.bg_color = Color(color).darkened(0.15)
		button.add_theme_stylebox_override(state, style)
	parent.add_child(button)
	return button


func _menu_text_button(parent: Control, title: String, rect: Rect2, font_size: int) -> Button:
	var button := Button.new()
	button.text = title
	button.position = rect.position
	button.size = rect.size
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color("#edf2f1"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.02, 0.04, 0.065, 0.10)
		style.border_color = Color(0.87, 0.35, 0.41, 0.0)
		style.border_width_left = 4
		style.content_margin_left = 18
		if state in ["hover", "focus"]:
			style.bg_color = Color(0.55, 0.10, 0.17, 0.82)
			style.border_color = Color("#f06a75")
		elif state == "pressed":
			style.bg_color = Color(0.38, 0.06, 0.11, 0.94)
			style.border_color = Color("#ffd18a")
		button.add_theme_stylebox_override(state, style)
	parent.add_child(button)
	return button


func _show_menu() -> void:
	if is_instance_valid(_finisher_director):
		_finisher_director.cancel()
	_cancel_special_hold()
	fight_live = false
	paused = false
	hud_root.visible = false
	menu_root.visible = true
	select_root.visible = false
	map_select_root.visible = false
	pause_root.visible = false
	result_root.visible = false
	for fighter in [player, enemy]:
		if is_instance_valid(fighter): fighter.queue_free()
	player = null
	enemy = null
	_build_stage()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.worldFightSetMenuVisible?.(true)")


func _start_quick_fight() -> void:
	campaign_mode = false
	bout = 0
	campaign_wins = 0
	var rival_id := _opponent_selector.pick_opponent(PLAYABLE_IDS, selecting)
	if rival_id.is_empty(): return
	_setup_bout(selecting, rival_id, 1, "SINGLE FIGHT")


func _start_campaign() -> void:
	campaign_mode = true
	bout = 0
	campaign_wins = 0
	var rival_id: String = BOUTS[0].id
	if rival_id == selecting: rival_id = _next_rival_id(selecting)
	_setup_bout(selecting, rival_id, BOUTS[0].level, BOUTS[0].title)


func _setup_bout(player_id: String, rival_id: String, level: int, stage_title: String) -> void:
	menu_root.visible = false
	select_root.visible = false
	map_select_root.visible = false
	result_root.visible = false
	pause_root.visible = false
	hud_root.visible = true
	current_rival_id = rival_id
	current_level = level
	_build_stage(selected_stage_id)
	(_hud_node("PlayerName") as Label).text = _fighter_name(player_id)
	(_hud_node("EnemyName") as Label).text = _fighter_name(rival_id) + ("  /  BOSS" if campaign_mode and bout == 3 else "")
	player_hud_portrait.texture = load(_fighter_thumbnail_path(player_id))
	enemy_hud_portrait.texture = load(_fighter_thumbnail_path(rival_id))
	var player_name_text := _fighter_name(player_id)
	var enemy_name_text := _fighter_name(rival_id)
	(_hud_node("PlayerName") as Label).add_theme_font_size_override("font_size", 21 if player_name_text.length() > 17 else (24 if player_name_text.length() > 11 else 28))
	(_hud_node("EnemyName") as Label).add_theme_font_size_override("font_size", 21 if enemy_name_text.length() > 17 else (24 if enemy_name_text.length() > 11 else 28))
	message_label.text = stage_title
	message_label.visible = true
	if is_instance_valid(player): player.queue_free()
	if is_instance_valid(enemy): enemy.queue_free()
	player = GameFighterScript.new()
	player.name = "PlayerFighter"
	player.setup(player_id, 0, false)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	enemy = GameFighterScript.new()
	enemy.name = "CpuFighter"
	enemy.setup(rival_id, 1, true, level)
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(enemy)
	player.rival = enemy
	enemy.rival = player
	player.arena_bounds = ARENA_EDGE
	enemy.arena_bounds = ARENA_EDGE
	player.health_changed.connect(_on_health_changed)
	enemy.health_changed.connect(_on_health_changed)
	player.meter_changed.connect(_on_meter_changed)
	enemy.meter_changed.connect(_on_meter_changed)
	player.defeated.connect(_on_defeated)
	enemy.defeated.connect(_on_defeated)
	player.combo_changed.connect(_on_combo_changed)
	enemy.combo_changed.connect(_on_combo_changed)
	player.attack_started.connect(_on_attack_started)
	enemy.attack_started.connect(_on_attack_started)
	player.strike_landed.connect(_on_strike_landed)
	enemy.strike_landed.connect(_on_strike_landed)
	player_rounds = 0
	enemy_rounds = 0
	fight_live = true
	round_ready = false
	paused = false
	intermission = 0
	_start_round()


func _start_round() -> void:
	if not fight_live or not is_instance_valid(player) or not is_instance_valid(enemy): return
	match_state = MatchState.Value.ROUND_INTRO
	_cancel_special_hold()
	round_ready = false
	player.reset_round(-1.85, player.max_health())
	enemy.reset_round(1.85, enemy.max_health())
	player_health_bar.max_value = player.max_health()
	enemy_health_bar.max_value = enemy.max_health()
	player_health_bar.value = player.health
	enemy_health_bar.value = enemy.health
	player_health_bar.set_fill_color(Color("#46dcd8"))
	enemy_health_bar.set_fill_color(Color("#f0566b"))
	player_recoverable_bar.max_value = player.max_health()
	player_recoverable_bar.value = player.max_health()
	enemy_recoverable_bar.max_value = enemy.max_health()
	enemy_recoverable_bar.value = enemy.max_health()
	player_recover_delay = 0.0
	enemy_recover_delay = 0.0
	# Keep both fighters in their opening stances until the announcer finishes.
	player.round_over = true
	enemy.round_over = true
	player_rounds = mini(player_rounds, 2)
	enemy_rounds = mini(enemy_rounds, 2)
	round_clock = 60.0
	combo_label.visible = false
	combo_label_time = 0.0
	var round_num := player_rounds + enemy_rounds + 1
	round_label.text = "BEST OF 3  ·  ROUND %d" % round_num
	_update_scores()
	message_label.text = "ROUND %d" % round_num
	message_label.visible = true
	await get_tree().create_timer(0.72, false).timeout
	if fight_live and not paused: message_label.text = "FIGHT!"
	await get_tree().create_timer(0.65, false).timeout
	if fight_live: message_label.visible = false
	round_ready = true
	match_state = MatchState.Value.FIGHTING
	if is_instance_valid(player): player.round_over = false
	if is_instance_valid(enemy): enemy.round_over = false


func _on_health_changed(who: int, value: float) -> void:
	var bar := player_health_bar if who == 0 else enemy_health_bar
	bar.value = value
	if who == 0:
		player_recover_delay = 0.32
	else:
		enemy_recover_delay = 0.32
	var ratio := value / maxf(1.0, bar.max_value)
	var healthy := Color("#46dcd8") if who == 0 else Color("#f0566b")
	bar.set_fill_color(healthy if ratio > 0.55 else (Color("#e9bf55") if ratio > 0.25 else Color("#ff3b47")))
	if round_ready:
		_spawn_hit_flash(who)


func _update_recoverable_health(delta: float) -> void:
	player_recover_delay = maxf(0.0, player_recover_delay - delta)
	enemy_recover_delay = maxf(0.0, enemy_recover_delay - delta)
	if player_recover_delay <= 0.0 and is_instance_valid(player_recoverable_bar):
		player_recoverable_bar.value = move_toward(player_recoverable_bar.value, player_health_bar.value, player_recoverable_bar.max_value * 1.35 * delta)
	if enemy_recover_delay <= 0.0 and is_instance_valid(enemy_recoverable_bar):
		enemy_recoverable_bar.value = move_toward(enemy_recoverable_bar.value, enemy_health_bar.value, enemy_recoverable_bar.max_value * 1.35 * delta)


func _on_combo_changed(who: int, hits: int) -> void:
	if who != 0 or not is_instance_valid(combo_label): return
	if hits >= 2:
		combo_label.text = "%d HIT COMBO" % hits
		combo_label.visible = true
		combo_label.scale = Vector2(0.78, 0.78)
		combo_label.modulate.a = 1.0
		combo_label_time = 1.1
		var tween := create_tween().set_parallel(true)
		tween.tween_property(combo_label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if hits >= 3:
			combo_label.add_theme_color_override("font_color", Color("#72e8dc"))
		else:
			combo_label.add_theme_color_override("font_color", Color("#ffe1a0"))


func _on_attack_started(attacker: int, move: String) -> void:
	if attacker == 0 and move == "special":
		_show_special_feedback("SPECIAL ATTACK!")


func _on_strike_landed(attacker: int, defender: int, move: String, blocked: bool, combo: int) -> void:
	if not round_ready: return
	_play_sound("hit")
	if blocked:
		camera_shake = 0.11
	else:
		camera_shake = 0.15 if move == "light" else (0.28 if move == "heavy" else 0.34)
	if move == "special" or (combo >= 3 and attacker == 0):
		_play_sound("special")


func _spawn_hit_flash(victim_index: int) -> void:
	var victim: GameFighter = player if victim_index == 0 else enemy
	var attacker: GameFighter = enemy if victim_index == 0 else player
	if not is_instance_valid(victim) or not is_instance_valid(attacker): return
	var tint := Color("#35e5dc") if attacker.character_id == "bennet" else Color("#f06470")
	var flash := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.11
	ring.outer_radius = 0.35
	ring.rings = 8
	ring.ring_segments = 20
	flash.mesh = ring
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(tint, 0.9)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 1.8
	flash.material_override = material
	flash.rotation.x = deg_to_rad(90.0)
	flash.position = victim.global_position + Vector3(0, 1.42, 0.34)
	_arena.add_child(flash)
	var impact_tween := create_tween().set_parallel(true)
	impact_tween.tween_property(flash, "scale", Vector3(1.5, 1.5, 1.5), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	impact_tween.tween_property(material, "albedo_color", Color(tint, 0.0), 0.16)
	get_tree().create_timer(0.18).timeout.connect(flash.queue_free)


func _on_meter_changed(who: int, value: float) -> void:
	var bar := player_meter_bar if who == 0 else enemy_meter_bar
	var label := player_meter_label if who == 0 else enemy_meter_label
	var percent := player_meter_percent if who == 0 else enemy_meter_percent
	bar.value = value
	label.text = "SPECIAL ENERGY"
	percent.text = "SP READY" if value >= 100.0 else "%d%%" % roundi(value)
	percent.add_theme_color_override("font_color", Color("#fff1a8") if value >= 100.0 else Color("#f6e6b0"))
	(bar as SlantBarScript).set_fill_color(Color("#ffe066") if value >= 100.0 else (Color("#f2a53a") if value >= GameFighterScript.SPECIAL_COST else Color("#f2c94c")))
	if who == 0:
		_refresh_touch_energy_state()


func _on_defeated(who: int) -> void:
	if match_state in [MatchState.Value.FINISHER_CINEMATIC, MatchState.Value.KO_HOLD, MatchState.Value.CELEBRATION] and _finisher_director.active:
		return
	if not fight_live or intermission > 0: return
	if who == 0: enemy_rounds += 1
	else: player_rounds += 1
	_update_scores()
	_end_round("ko")


func _end_round(reason: String) -> void:
	if not fight_live or intermission > 0: return
	match_state = MatchState.Value.KO_HOLD
	_cancel_special_hold()
	round_ready = false
	if is_instance_valid(player): player.round_over = true
	if is_instance_valid(enemy): enemy.round_over = true
	if reason == "time":
		if player.health > enemy.health: player_rounds += 1
		elif enemy.health > player.health: enemy_rounds += 1
		else:
			player_rounds += 1
		_update_scores()
	if player_rounds >= 2 or enemy_rounds >= 2:
		_show_result_with_celebration(player_rounds >= 2)
	else:
		message_label.text = "ROUND FOR YOU" if (reason == "ko" and player_rounds > enemy_rounds) else ("ROUND LOST" if reason == "ko" else "TIME")
		message_label.visible = true
		intermission = 1.55


func _update_scores() -> void:
	for i in range(player_round_markers.size()):
		var player_style := StyleBoxFlat.new()
		player_style.bg_color = Color("#43d7cf") if i < player_rounds else Color("#263943")
		player_style.border_color = Color("#9ff0e8") if i < player_rounds else Color("#47606a")
		player_style.set_border_width_all(1)
		player_style.set_corner_radius_all(3)
		player_round_markers[i].add_theme_stylebox_override("panel", player_style)
	for i in range(enemy_round_markers.size()):
		var enemy_style := StyleBoxFlat.new()
		enemy_style.bg_color = Color("#e4606e") if i < enemy_rounds else Color("#432630")
		enemy_style.border_color = Color("#f2a0a8") if i < enemy_rounds else Color("#68404a")
		enemy_style.set_border_width_all(1)
		enemy_style.set_corner_radius_all(3)
		enemy_round_markers[i].add_theme_stylebox_override("panel", enemy_style)


func _show_result(won: bool) -> void:
	match_state = MatchState.Value.RESULT
	fight_live = false
	hud_root.visible = false
	result_root.visible = true
	result_winner_art.visible = true
	var content := result_root.get_node("ResultContent")
	var title: Label = content.get_node("ResultTitle")
	var winner_name: Label = content.get_node("WinnerName")
	var detail: Label = content.get_node("ResultDetail")
	var button: Button = result_root.get_node("ContinueButton")
	var backdrop_word: Label = result_root.get_node("ResultBackdropWord")
	(result_root.get_node("NewOpponentButton") as Button).visible = not campaign_mode
	var winner_id := selecting
	if won and is_instance_valid(player):
		winner_id = player.character_id
	elif not won and is_instance_valid(enemy):
		winner_id = enemy.character_id
	elif not won:
		winner_id = _next_rival_id(selecting)
	result_winner_art.texture = _fighter_art(winner_id, not won)
	result_winner_art.modulate = Color(0.77, 0.94, 0.93, 0.42) if won else Color(0.96, 0.72, 0.75, 0.38)
	winner_name.text = "%s WINS" % _fighter_name(winner_id)
	var accent_color := Color("#39cbc6") if won else Color("#df5968")
	winner_name.add_theme_color_override("font_color", accent_color.lightened(0.18))
	var accent_style := result_accent.get_theme_stylebox("panel") as StyleBoxFlat
	accent_style.bg_color = accent_color
	if won:
		campaign_wins += 1
		title.text = "YOU WIN"
		backdrop_word.text = "VICTORY"
		detail.text = "You won %d–%d." % [player_rounds, enemy_rounds]
		if campaign_mode and bout < 3:
			detail.text += "  The campaign continues."
			button.text = "NEXT BOUT"
		elif campaign_mode:
			detail.text = "The boss is beaten. You cleared the campaign!"
			button.text = "BACK TO MENU"
		else:
			button.text = "REMATCH"
	else:
		title.text = "YOU LOSE"
		backdrop_word.text = "YOU LOSE"
		detail.text = "The rival took the match. Change your rhythm and take the arena back."
		button.text = "TRY AGAIN" if not campaign_mode else "RETRY BOUT"
	_play_sound("victory" if won else "hit")


func _show_result_with_celebration(won: bool) -> void:
	var winner: GameFighter = player if won else enemy
	var loser: GameFighter = enemy if won else player
	if not is_instance_valid(winner) or not is_instance_valid(loser) or _finisher_catalog == null:
		_show_result(won)
		return
	var definition: Dictionary = _finisher_catalog.definition_for(winner.character_id)
	var celebration_id := str(definition.get("celebration_id", ""))
	_celebration_won = won
	result_root.visible = false
	result_winner_art.visible = false
	hud_root.visible = false
	if not _finisher_director.begin_celebration(winner, loser, celebration_id):
		_show_result(won)


func _continue_from_result() -> void:
	if not campaign_mode:
		_rematch()
		return
	if player_rounds < 2:
		var retry_data: Dictionary = BOUTS[bout]
		var retry_enemy: String = retry_data.id
		if retry_enemy == selecting:
			retry_enemy = _next_rival_id(selecting)
		_setup_bout(selecting, retry_enemy, retry_data.level, retry_data.title)
	elif bout < 3:
		bout += 1
		var fighter_data: Dictionary = BOUTS[bout]
		var enemy_id: String = fighter_data.id
		if enemy_id == selecting:
			enemy_id = _next_rival_id(selecting)
		_setup_bout(selecting, enemy_id, fighter_data.level, fighter_data.title)
	else:
		campaign_mode = false
		_show_menu()


func _rematch() -> void:
	# REMATCH / TRY AGAIN replays the same rival on the same stage.
	if current_rival_id.is_empty() or current_rival_id == selecting:
		_start_quick_fight()
		return
	campaign_mode = false
	_setup_bout(selecting, current_rival_id, current_level, "REMATCH")


func _toggle_pause() -> void:
	if not fight_live: return
	paused = not paused
	if is_instance_valid(_finisher_director):
		_finisher_director.set_paused(paused)
	pause_root.visible = paused
	get_tree().paused = paused


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _return_to_menu() -> void:
	get_tree().paused = false
	_show_menu()


func _create_audio() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.bus = "Master"
	add_child(_audio_player)
	for sound_name in ["hit", "special", "victory", "menu"]:
		var samples := 4800 if sound_name == "hit" else 8400
		var data := PackedByteArray()
		data.resize(samples * 2)
		for i in range(samples):
			var t := float(i) / 48000.0
			var env := exp(-t * (18.0 if sound_name == "hit" else 10.0))
			var hz := 155.0 if sound_name == "hit" else (95.0 if sound_name == "special" else (520.0 if sound_name == "victory" else 340.0))
			var wave := sin(TAU * hz * t) * env * 0.18
			if sound_name == "special": wave += sin(TAU * 340.0 * t) * env * 0.10
			if sound_name == "victory": wave *= 1.0 + 0.3 * sin(TAU * 7.0 * t)
			var sample := int(clampf(wave, -1.0, 1.0) * 32767.0)
			data[i * 2] = sample & 0xff
			data[i * 2 + 1] = (sample >> 8) & 0xff
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 48000
		stream.data = data
		_sounds[sound_name] = stream


func _play_sound(sound_name: String) -> void:
	if _sounds.has(sound_name):
		_audio_player.stream = _sounds[sound_name]
		_audio_player.play()
