extends Node3D

const GameFighterScript = preload("res://scripts/fighter.gd")
const VirtualStickScript = preload("res://scripts/virtual_stick.gd")
const OpponentSelectorScript = preload("res://scripts/opponent_selector.gd")
const ARENA_EDGE := 5.8
const MAIN_HERO_PATH := "res://assets/ui/main-hero-b.png"

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
var player_health_bar: ProgressBar
var enemy_health_bar: ProgressBar
var player_meter_bar: ProgressBar
var enemy_meter_bar: ProgressBar
var player_meter_label: Label
var enemy_meter_label: Label
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
var combo_label_time := 0.0
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
var _opponent_selector := OpponentSelectorScript.new()

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
	{"id": "knesset_chamber", "name": "KNESSET • CHAMBER", "subtitle": "Inside the debating hall", "image": "res://assets/stages/knesset-chamber-arena.png", "kind": "knesset_inside", "accent": "#e2bd63", "base": "#392b22", "backdrop_y": 0.78, "backdrop_scale": 1.18},
	{"id": "patriots_studio", "name": "THE PATRIOTS", "subtitle": "Live studio · Red alert", "image": "res://assets/stages/patriots-studio-arena.png", "kind": "studio", "accent": "#42cafa", "base": "#102033"},
	{"id": "friday_studio", "name": "FRIDAY STUDIO", "subtitle": "Prime time · Jerusalem", "image": "res://assets/stages/friday-studio-arena.png", "kind": "studio", "accent": "#e5b944", "base": "#132238"},
	{"id": "hatzinor_studio", "name": "THE PIPELINE", "subtitle": "The Hatzinor newsroom", "image": "res://assets/stages/hatzinor-studio-arena.png", "kind": "studio", "accent": "#3ccafa", "base": "#101a2c"}
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	randomize()
	_build_arena()
	_build_ui()
	_create_audio()
	_show_menu()


func _process(delta: float) -> void:
	if is_instance_valid(_fight_camera):
		camera_shake = maxf(0.0, camera_shake - delta * 1.8)
		var t := float(Time.get_ticks_msec())
		var kick := camera_shake
		_fight_camera.position = camera_home + Vector3(sin(t * 0.079) * kick, sin(t * 0.113) * kick * 0.55, 0)
	if fight_live and not paused:
		round_clock = maxf(0.0, round_clock - delta)
		timer_label.text = "%02d" % ceili(round_clock)
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
	if not fight_live or paused or player == null or not round_ready:
		# Sample held keys outside combat too, so resuming never creates an attack.
		_attack_key_held["light"] = Input.is_key_pressed(KEY_J) or Input.is_key_pressed(KEY_1)
		_attack_key_held["heavy"] = Input.is_key_pressed(KEY_K) or Input.is_key_pressed(KEY_2)
		_attack_key_held["special"] = Input.is_key_pressed(KEY_L) or Input.is_key_pressed(KEY_3)
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
	var special := _consume("special", KEY_L, KEY_3)
	player.set_controls(
		axis,
		Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or _input_down.get("jump", false) or (stick != null and stick.axis.y < -0.62),
		Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_H) or _input_down.get("block", false),
		Input.is_key_pressed(KEY_C) or _input_down.get("crouch", false) or (stick != null and stick.axis.y > 0.62),
		"special" if special else ("heavy" if heavy else ("light" if light else "")),
		depth_axis
	)
	_input_down["jump"] = false
	for action in ["light", "heavy", "special"]: _input_down[action] = false


func _consume(action: String, key: Key, alt_key: Key) -> bool:
	# Attacks are edge-triggered. Holding a key during hit-stun must not refill
	# the input buffer every frame and launch a surprise attack on recovery.
	var held := Input.is_key_pressed(key) or Input.is_key_pressed(alt_key)
	var pressed: bool = bool(_input_down.get(action, false)) or (held and not bool(_attack_key_held.get(action, false)))
	_attack_key_held[action] = held
	_input_down[action] = false
	return pressed


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
	# The supplied stage art already contains the environment, floor and lighting.
	# Keep it as a single camera-facing backplate so invented walls, studio desks,
	# columns and crowd meshes cannot cover half the reference image.
	var backdrop := MeshInstance3D.new()
	backdrop.name = "FullFrameStageBackdrop"
	var backdrop_mesh := QuadMesh.new()
	var distance := 18.0
	var frame_height := 2.0 * distance * tan(deg_to_rad(_fight_camera.fov * 0.5))
	var frame_aspect := get_viewport().get_visible_rect().size.x / maxf(1.0, get_viewport().get_visible_rect().size.y)
	var backdrop_scale := float(stage.get("backdrop_scale", 1.0))
	backdrop_mesh.size = Vector2(frame_height * frame_aspect, frame_height) * backdrop_scale
	backdrop.mesh = backdrop_mesh
	var backdrop_material := StandardMaterial3D.new()
	backdrop_material.albedo_texture = load(str(stage.image))
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
	var shadow := _panel(hud_root, Rect2(12, 12, 1256, 98), Color(0.0, 0.0, 0.0, 0.42))
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := _panel(hud_root, Rect2(8, 6, 1264, 98), Color(0.012, 0.021, 0.034, 0.86))
	top.name = "CombatHUDFrame"
	_panel(top, Rect2(0, 0, 1264, 3), Color("#e4bd6a"))
	_panel(top, Rect2(0, 3, 4, 95), Color("#35cfca"))
	_panel(top, Rect2(1260, 3, 4, 95), Color("#df5968"))
	var left_wing := _panel(top, Rect2(96, 36, 462, 4), Color(0.85, 0.70, 0.36, 0.65))
	left_wing.name = "LeftHealthWing"
	var right_wing := _panel(top, Rect2(706, 36, 462, 4), Color(0.85, 0.70, 0.36, 0.65))
	right_wing.name = "RightHealthWing"

	var player_portrait_frame := _panel(top, Rect2(12, 10, 76, 78), Color("#102b33"))
	player_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_hud_portrait = TextureRect.new()
	player_hud_portrait.name = "PlayerPortrait"
	player_hud_portrait.texture = load(_fighter_thumbnail_path("bennet"))
	player_hud_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_hud_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	player_hud_portrait.position = Vector2(16, 14)
	player_hud_portrait.size = Vector2(68, 70)
	player_hud_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_portrait_frame.add_child(player_hud_portrait)
	player_hud_portrait.reparent(top)
	player_hud_portrait.position = Vector2(16, 14)

	var enemy_portrait_frame := _panel(top, Rect2(1176, 10, 76, 78), Color("#351923"))
	enemy_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_hud_portrait = TextureRect.new()
	enemy_hud_portrait.name = "EnemyPortrait"
	enemy_hud_portrait.texture = load(_fighter_thumbnail_path("avigdor"))
	enemy_hud_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_hud_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	enemy_hud_portrait.flip_h = true
	enemy_hud_portrait.position = Vector2(1180, 14)
	enemy_hud_portrait.size = Vector2(68, 70)
	enemy_hud_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(enemy_hud_portrait)

	var left_name := _label(top, "BENNET", Rect2(100, 5, 372, 28), 23, Color("#f2f6f3"), HORIZONTAL_ALIGNMENT_LEFT)
	left_name.name = "PlayerName"
	var right_name := _label(top, "AVIGDOR", Rect2(792, 5, 372, 28), 23, Color("#f2f6f3"), HORIZONTAL_ALIGNMENT_RIGHT)
	right_name.name = "EnemyName"
	_label(top, "PLAYER 1", Rect2(486, 8, 66, 18), 8, Color("#65d8d3"), HORIZONTAL_ALIGNMENT_RIGHT)
	_label(top, "CPU", Rect2(712, 8, 66, 18), 8, Color("#ed8e98"), HORIZONTAL_ALIGNMENT_LEFT)
	_panel(top, Rect2(96, 41, 462, 29), Color("#071019"))
	_panel(top, Rect2(706, 41, 462, 29), Color("#071019"))
	var player_recoverable := _bar(top, Rect2(104, 47, 446, 16), Color("#d6b968"))
	player_recoverable.name = "PlayerRecoverableHealth"
	var enemy_recoverable := _bar(top, Rect2(714, 47, 446, 16), Color("#d6b968"))
	enemy_recoverable.name = "EnemyRecoverableHealth"
	enemy_recoverable.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	player_health_bar = _bar(top, Rect2(104, 47, 446, 16), Color("#34d5d0"))
	enemy_health_bar = _bar(top, Rect2(714, 47, 446, 16), Color("#e15a6a"))
	enemy_health_bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	for i in range(1, 10):
		var left_cut := _panel(top, Rect2(104 + i * 44, 47, 2, 16), Color(0.02, 0.06, 0.08, 0.62))
		left_cut.name = "PlayerHealthCut%d" % i
		left_cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var right_cut := _panel(top, Rect2(714 + i * 44, 47, 2, 16), Color(0.09, 0.025, 0.035, 0.62))
		right_cut.name = "EnemyHealthCut%d" % i
		right_cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_meter_bar = _bar(top, Rect2(104, 76, 268, 5), Color("#d4b967"), 100)
	enemy_meter_bar = _bar(top, Rect2(892, 76, 268, 5), Color("#d4b967"), 100)
	enemy_meter_bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	player_meter_label = _label(top, "SPECIAL  0%", Rect2(104, 80, 150, 14), 8, Color("#d8c184"), HORIZONTAL_ALIGNMENT_LEFT)
	player_meter_label.name = "PlayerSpecialLabel"
	enemy_meter_label = _label(top, "SPECIAL  0%", Rect2(995, 80, 115, 14), 8, Color("#d8c184"), HORIZONTAL_ALIGNMENT_RIGHT)
	enemy_meter_label.name = "EnemySpecialLabel"

	var timer_medallion := _panel(top, Rect2(576, 4, 112, 82), Color("#172431"))
	timer_medallion.name = "TimerMedallion"
	_panel(timer_medallion, Rect2(7, 5, 98, 70), Color("#080f18"))
	timer_label = _label(top, "60", Rect2(588, 8, 88, 54), 43, Color("#ffe9ba"), HORIZONTAL_ALIGNMENT_CENTER)
	round_label = _label(top, "ROUND 1", Rect2(542, 80, 180, 16), 9, Color("#c6cdd0"), HORIZONTAL_ALIGNMENT_CENTER)

	var player_markers := Control.new()
	player_markers.name = "PlayerRoundMarkers"
	player_markers.position = Vector2(392, 73)
	player_markers.size = Vector2(70, 18)
	top.add_child(player_markers)
	var enemy_markers := Control.new()
	enemy_markers.name = "EnemyRoundMarkers"
	enemy_markers.position = Vector2(802, 73)
	enemy_markers.size = Vector2(70, 18)
	top.add_child(enemy_markers)
	for i in range(2):
		var player_marker := _panel(player_markers, Rect2(i * 26, 1, 18, 10), Color("#263943"))
		player_marker.name = "Round%d" % (i + 1)
		player_round_markers.append(player_marker)
		var enemy_marker := _panel(enemy_markers, Rect2(52 - i * 26, 1, 18, 10), Color("#432630"))
		enemy_marker.name = "Round%d" % (i + 1)
		enemy_round_markers.append(enemy_marker)

	var pause_btn := _button(top, "Ⅱ", Rect2(1122, 70, 38, 22), "#253847", 12)
	pause_btn.pressed.connect(_toggle_pause)
	var side_score := _label(top, "0  —  0", Rect2(582, 64, 100, 16), 9, Color("#9daab0"), HORIZONTAL_ALIGNMENT_CENTER)
	side_score.name = "Score"
	message_label = _label(hud_root, "", Rect2(280, 144, 720, 78), 32, Color("#f0f4f3"), HORIZONTAL_ALIGNMENT_CENTER)
	message_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	message_label.add_theme_constant_override("shadow_offset_x", 2)
	message_label.add_theme_constant_override("shadow_offset_y", 3)
	combo_label = _label(hud_root, "", Rect2(460, 232, 360, 48), 25, Color("#ffe1a0"), HORIZONTAL_ALIGNMENT_CENTER)
	combo_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	combo_label.add_theme_constant_override("shadow_offset_x", 2)
	combo_label.add_theme_constant_override("shadow_offset_y", 3)
	combo_label.visible = false
	_build_touch_controls()
	hud_root.visible = false


func _build_touch_controls() -> void:
	stick = VirtualStickScript.new()
	stick.position = Vector2(40, 486)
	stick.size = Vector2(194, 194)
	stick.visible = false
	hud_root.add_child(stick)
	var specs := [
		{"action": "light", "title": "JAB", "pos": Vector2(1090, 543), "color": "#2b8c8f"},
		{"action": "heavy", "title": "CROSS", "pos": Vector2(1172, 474), "color": "#ae565d"},
		{"action": "special", "title": "MAX", "pos": Vector2(1010, 466), "color": "#906341"},
		{"action": "jump", "title": "↑", "pos": Vector2(953, 564), "color": "#334a58"},
		{"action": "block", "title": "GUARD", "pos": Vector2(1161, 618), "color": "#445761"}
	]
	for spec in specs:
		var b := _button(hud_root, spec.title, Rect2(spec.pos.x, spec.pos.y, 72 if spec.action != "block" else 94, 72 if spec.action != "block" else 52), spec.color, 15)
		b.visible = DisplayServer.is_touchscreen_available()
		b.button_down.connect(func(): _input_down[spec.action] = true)
		b.button_up.connect(func(): if spec.action == "block": _input_down[spec.action] = false)
		b.pressed.connect(func():
			if spec.action in ["light", "heavy", "special"]:
				_input_down[spec.action] = true
		)
		buttons[spec.action] = b


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
	_label(action_panel, "A/D MOVE   W JUMP   S GUARD", Rect2(0, 404, 340, 20), 9, Color("#b6c2c7"), HORIZONTAL_ALIGNMENT_LEFT)
	_label(action_panel, "J/K/L ATTACK   ESC PAUSE", Rect2(0, 428, 340, 20), 9, Color("#b6c2c7"), HORIZONTAL_ALIGNMENT_LEFT)
	_label(action_panel, "OFFLINE  •  13 FIGHTERS", Rect2(0, 484, 340, 20), 9, Color("#7f929b"), HORIZONTAL_ALIGNMENT_LEFT)
	_label(menu_root, "WORLD FIGHT  /  ELECTION EDITION", Rect2(58, 676, 420, 20), 9, Color("#8999a0"), HORIZONTAL_ALIGNMENT_LEFT)


func _build_select() -> void:
	select_root = Control.new()
	select_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(select_root)
	_panel(select_root, Rect2(0, 0, 1280, 720), Color("#080e16"))
	_panel(select_root, Rect2(0, 0, 640, 720), Color(0.035, 0.15, 0.19, 0.30))
	_panel(select_root, Rect2(640, 0, 640, 720), Color(0.22, 0.045, 0.075, 0.30))
	_label(select_root, "SELECT YOUR FIGHTER", Rect2(48, 24, 700, 47), 30, Color("#f4f0e7"), HORIZONTAL_ALIGNMENT_LEFT)
	_label(select_root, "CHOOSE ONE FIGHTER  ·  THE CPU IS REVEALED IN THE ARENA", Rect2(51, 69, 690, 22), 11, Color("#99afb7"), HORIZONTAL_ALIGNMENT_LEFT)
	# The player chooses one fighter. The CPU stays concealed until the arena loads.
	select_portrait = TextureRect.new()
	select_portrait.texture = _fighter_art("bennet")
	select_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	select_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	select_portrait.position = Vector2(0, 110); select_portrait.size = Vector2(365, 510)
	select_root.add_child(select_portrait)
	var right_art := TextureRect.new()
	right_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	right_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	right_art.position = Vector2(915, 110); right_art.size = Vector2(365, 510); right_art.modulate = Color(0.22, 0.25, 0.30, 1)
	select_root.add_child(right_art)
	_panel(select_root, Rect2(0, 110, 365, 510), Color(0.035, 0.12, 0.15, 0.46))
	_panel(select_root, Rect2(915, 110, 365, 510), Color(0.18, 0.035, 0.06, 0.50))
	_panel(select_root, Rect2(363, 110, 554, 510), Color(0.018, 0.028, 0.043, 0.96))
	_panel(select_root, Rect2(363, 110, 3, 510), Color("#46c9c5"))
	_panel(select_root, Rect2(914, 110, 3, 510), Color("#d85c68"))
	select_name_label = _label(select_root, "BENNET", Rect2(28, 530, 310, 48), 30, Color("#f7f4eb"), HORIZONTAL_ALIGNMENT_LEFT)
	select_style_label = _label(select_root, "THE FOUNDER  /  COMBO STRIKER", Rect2(30, 578, 315, 24), 11, Color("#76ded8"), HORIZONTAL_ALIGNMENT_LEFT)
	var mystery_mark := _label(select_root, "?", Rect2(948, 185, 300, 275), 160, Color("#e7c27a"), HORIZONTAL_ALIGNMENT_CENTER)
	mystery_mark.name = "MysteryCpuMark"
	select_rival_name = _label(select_root, "RANDOM OPPONENT", Rect2(935, 530, 315, 48), 24, Color("#f7f4eb"), HORIZONTAL_ALIGNMENT_RIGHT)
	select_rival_style = _label(select_root, "REVEALED IN THE ARENA", Rect2(935, 578, 315, 24), 11, Color("#f49b9d"), HORIZONTAL_ALIGNMENT_RIGHT)
	select_rival_portrait = right_art
	select_stats_label = _label(select_root, "STYLE  ·  Close-range pressure\nSIGNATURE  ·  Founder’s Rush", Rect2(385, 126, 510, 52), 12, Color("#c6d1d2"), HORIZONTAL_ALIGNMENT_CENTER)
	_label(select_root, "CHOOSE YOUR FIGHTER", Rect2(385, 184, 510, 26), 12, Color("#d9b566"), HORIZONTAL_ALIGNMENT_CENTER)
	var roster_grid := GridContainer.new()
	roster_grid.name = "RosterGrid"
	roster_grid.position = Vector2(385, 218)
	roster_grid.size = Vector2(510, 300)
	roster_grid.columns = 5
	roster_grid.add_theme_constant_override("h_separation", 8)
	roster_grid.add_theme_constant_override("v_separation", 8)
	select_root.add_child(roster_grid)
	for i in range(PLAYABLE_IDS.size()):
		var fighter_id: String = PLAYABLE_IDS[i]
		var tile := _button(roster_grid, "", Rect2(0, 0, 94, 88), "#172632", 18)
		tile.custom_minimum_size = Vector2(94, 88)
		tile.name = "RosterTile_" + fighter_id
		roster_tiles.append(tile)
		var face := TextureRect.new()
		face.texture = load(_fighter_thumbnail_path(fighter_id))
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.position = Vector2(4, 4); face.size = Vector2(86, 80); face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(face)
		tile.pressed.connect(func(id: String = fighter_id): _select_fighter(id))
	_panel(select_root, Rect2(0, 628, 1280, 92), Color(0.012, 0.022, 0.034, 0.94))
	var back := _button(select_root, "BACK", Rect2(48, 647, 150, 48), "#263844", 14)
	back.pressed.connect(_show_menu)
	var confirm := _button(select_root, "CONFIRM FIGHT", Rect2(1002, 642, 230, 56), "#a4793b", 16)
	confirm.name = "ConfirmFight"
	confirm.pressed.connect(_confirm_selection)
	_label(select_root, "ARROWS  /  SELECT     ENTER  /  CONFIRM", Rect2(453, 649, 374, 30), 10, Color("#9cabb1"), HORIZONTAL_ALIGNMENT_CENTER)
	select_root.visible = false
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
	_refresh_stage_cards()


func _open_select(mode: String) -> void:
	pending_mode = mode
	menu_root.visible = false
	map_select_root.visible = false
	select_root.visible = true
	_refresh_roster()


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
	# Keep the arena and final pose visible behind a cinematic fight-result wash.
	var result_darken := _panel(result_root, Rect2(0, 0, 1280, 720), Color(0.005, 0.008, 0.015, 0.52))
	result_darken.name = "ResultDarken"
	_panel(result_root, Rect2(0, 220, 1280, 235), Color(0.010, 0.018, 0.030, 0.78))
	_panel(result_root, Rect2(0, 214, 1280, 5), Color("#d6ad61"))
	_panel(result_root, Rect2(0, 456, 1280, 4), Color(0.90, 0.31, 0.40, 0.82))
	var backdrop_word := _label(result_root, "VICTORY", Rect2(-30, 210, 1340, 250), 154, Color(0.92, 0.76, 0.42, 0.10), HORIZONTAL_ALIGNMENT_CENTER)
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
	result_accent = _panel(result_root, Rect2(160, 438, 960, 6), Color("#39cbc6"))
	result_accent.name = "ResultAccent"
	var content := Control.new()
	content.name = "ResultContent"
	content.position = Vector2(120, 218)
	content.size = Vector2(1040, 235)
	result_root.add_child(content)
	_label(content, "FINAL RESULT", Rect2(0, 0, 1040, 28), 12, Color("#d9b566"), HORIZONTAL_ALIGNMENT_CENTER)
	var title := _label(content, "FIGHT OVER", Rect2(0, 20, 1040, 130), 104, Color("#f7f2e8"), HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "ResultTitle"
	var winner_name := _label(content, "", Rect2(0, 148, 1040, 44), 25, Color("#72d9d4"), HORIZONTAL_ALIGNMENT_CENTER)
	winner_name.name = "WinnerName"
	var detail := _label(content, "", Rect2(0, 190, 1040, 38), 15, Color("#c3cdd0"), HORIZONTAL_ALIGNMENT_CENTER)
	detail.name = "ResultDetail"
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var next := _button(result_root, "CONTINUE", Rect2(438, 506, 196, 54), "#1d777a", 16)
	next.name = "ContinueButton"
	next.pressed.connect(_continue_from_result)
	var menu := _button(result_root, "RETURN TO MENU", Rect2(646, 506, 196, 54), "#3b4852", 13)
	menu.name = "ResultMenuButton"
	menu.pressed.connect(_return_to_menu)
	_label(result_root, "ENTER  /  CONTINUE", Rect2(440, 570, 400, 24), 9, Color("#a0afb5"), HORIZONTAL_ALIGNMENT_CENTER)
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
	return panel


func _wash(parent: Control, rect: Rect2, color: Color) -> ColorRect:
	var wash := ColorRect.new()
	wash.position = rect.position
	wash.size = rect.size
	wash.color = color
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(wash)
	return wash


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


func _bar(parent: Control, rect: Rect2, color: Color, maximum: float = 112.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = rect.position
	bar.size = rect.size
	bar.max_value = maximum
	bar.value = maximum
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#26333d")
	bg.corner_radius_top_left = 5
	bg.corner_radius_top_right = 5
	bg.corner_radius_bottom_left = 5
	bg.corner_radius_bottom_right = 5
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left = 5
	fill.corner_radius_top_right = 5
	fill.corner_radius_bottom_left = 5
	fill.corner_radius_bottom_right = 5
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func _show_menu() -> void:
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
	_build_stage(selected_stage_id)
	var names := hud_root.get_node("CombatHUDFrame")
	(names.get_node("PlayerName") as Label).text = _fighter_name(player_id)
	(names.get_node("EnemyName") as Label).text = _fighter_name(rival_id) + ("  /  BOSS" if campaign_mode and bout == 3 else "")
	player_hud_portrait.texture = load(_fighter_thumbnail_path(player_id))
	enemy_hud_portrait.texture = load(_fighter_thumbnail_path(rival_id))
	var player_name_text := _fighter_name(player_id)
	var enemy_name_text := _fighter_name(rival_id)
	(names.get_node("PlayerName") as Label).add_theme_font_size_override("font_size", 18 if player_name_text.length() > 17 else (20 if player_name_text.length() > 11 else 24))
	(names.get_node("EnemyName") as Label).add_theme_font_size_override("font_size", 18 if enemy_name_text.length() > 17 else (20 if enemy_name_text.length() > 11 else 24))
	message_label.text = stage_title
	message_label.visible = true
	if is_instance_valid(player): player.queue_free()
	if is_instance_valid(enemy): enemy.queue_free()
	player = GameFighterScript.new()
	player.name = "PlayerFighter"
	player.setup(player_id, 0, false)
	add_child(player)
	enemy = GameFighterScript.new()
	enemy.name = "CpuFighter"
	enemy.setup(rival_id, 1, true, level)
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
	round_ready = false
	player.reset_round(-1.85, player.max_health())
	enemy.reset_round(1.85, enemy.max_health())
	player_health_bar.max_value = player.max_health()
	enemy_health_bar.max_value = enemy.max_health()
	var hud_frame := hud_root.get_node("CombatHUDFrame")
	var player_recoverable := hud_frame.get_node("PlayerRecoverableHealth") as ProgressBar
	var enemy_recoverable := hud_frame.get_node("EnemyRecoverableHealth") as ProgressBar
	player_recoverable.max_value = player.max_health()
	player_recoverable.value = player.max_health()
	enemy_recoverable.max_value = enemy.max_health()
	enemy_recoverable.value = enemy.max_health()
	# Keep both fighters in their opening stances until the announcer finishes.
	player.round_over = true
	enemy.round_over = true
	player_rounds = mini(player_rounds, 2)
	enemy_rounds = mini(enemy_rounds, 2)
	round_clock = 60.0
	combo_label.visible = false
	combo_label_time = 0.0
	var round_num := player_rounds + enemy_rounds + 1
	round_label.text = "BEST OF 3   ·   ROUND %d" % round_num
	_update_scores()
	message_label.text = "ROUND %d" % round_num
	message_label.visible = true
	await get_tree().create_timer(0.72, false).timeout
	if fight_live and not paused: message_label.text = "FIGHT!"
	await get_tree().create_timer(0.65, false).timeout
	if fight_live: message_label.visible = false
	round_ready = true
	if is_instance_valid(player): player.round_over = false
	if is_instance_valid(enemy): enemy.round_over = false


func _on_health_changed(who: int, value: float) -> void:
	var bar := player_health_bar if who == 0 else enemy_health_bar
	bar.value = value
	var ratio := value / maxf(1.0, bar.max_value)
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		fill.bg_color = Color("#38d3ce") if ratio > 0.55 and who == 0 else (Color("#df5968") if ratio > 0.55 else (Color("#e1b957") if ratio > 0.25 else Color("#f03f47")))
	if round_ready:
		_spawn_hit_flash(who)


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
	bar.value = value
	label.text = "SPECIAL  READY" if value >= 100.0 else "SPECIAL  %d%%" % roundi(value)
	label.add_theme_color_override("font_color", Color("#ffe18c") if value >= 100.0 else Color("#d8c184"))


func _on_defeated(who: int) -> void:
	if not fight_live or intermission > 0: return
	if who == 0: enemy_rounds += 1
	else: player_rounds += 1
	_update_scores()
	_end_round("ko")


func _end_round(reason: String) -> void:
	if not fight_live or intermission > 0: return
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
		_show_result(player_rounds >= 2)
	else:
		message_label.text = "ROUND FOR YOU" if (reason == "ko" and player_rounds > enemy_rounds) else ("ROUND LOST" if reason == "ko" else "TIME")
		message_label.visible = true
		intermission = 1.55
		if is_instance_valid(player): player.round_over = false
		if is_instance_valid(enemy): enemy.round_over = false


func _update_scores() -> void:
	var top := hud_root.get_node("CombatHUDFrame")
	(top.get_node("Score") as Label).text = "%d  —  %d" % [player_rounds, enemy_rounds]
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
	fight_live = false
	hud_root.visible = false
	result_root.visible = true
	var content := result_root.get_node("ResultContent")
	var title: Label = content.get_node("ResultTitle")
	var winner_name: Label = content.get_node("WinnerName")
	var detail: Label = content.get_node("ResultDetail")
	var button: Button = result_root.get_node("ContinueButton")
	var backdrop_word: Label = result_root.get_node("ResultBackdropWord")
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
		title.text = "VICTORY"
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


func _continue_from_result() -> void:
	if not campaign_mode:
		_start_quick_fight()
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


func _toggle_pause() -> void:
	if not fight_live: return
	paused = not paused
	pause_root.visible = paused
	get_tree().paused = paused


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
