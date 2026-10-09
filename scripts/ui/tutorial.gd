extends Control

## One-time first-fight tutorial ("wizard").
##
## Runs inside the first real fight: the CPU stands still as a target, the
## round clock is frozen, and each step waits for the player to actually do
## the move (move, JAB, CROSS, KICK, jump, GUARD), then fills Special Energy to
## 100% and points at the glowing SP button for the first finisher. A pulsing
## ring points at the control to use. Completion or SKIP is remembered in
## user:// so the tutorial never shows again on that device.

signal finished(skipped: bool)

const SAVE_PATH := "user://tutorial.cfg"
const CYAN := Color("#59f0ff")
const GOLD := Color("#f2c35a")
const STEPS := [
	{"id": "move", "title": "MOVE", "text": "Drag the joystick left or right to walk.", "key": "A / D", "target": "stick"},
	{"id": "jab", "title": "JAB", "text": "Tap JAB for a fast punch.", "key": "J", "target": "light"},
	{"id": "cross", "title": "CROSS", "text": "Tap CROSS for a heavy punch.", "key": "K", "target": "heavy"},
	{"id": "kick", "title": "KICK", "text": "Tap KICK for a long-range kick.", "key": "U", "target": "kick"},
	{"id": "jump", "title": "JUMP", "text": "Push the joystick up to jump.", "key": "W", "target": "stick"},
	{"id": "guard", "title": "GUARD", "text": "Hold GUARD to block incoming hits.", "key": "S", "target": "block"},
	{"id": "special", "title": "SPECIAL ENERGY", "text": "Hits fill the gold SPECIAL ENERGY bar. At 100% the SP button lights up - tap SP for your finisher!", "key": "L", "target": "special"},
]

var host: Node
var step := 0
var active := false
var _progress := 0.0
var _clock := 0.0
var _panel: Panel
var _title: Label
var _text: Label
var _key: Label
var _dots: Array[Panel] = []


static func is_completed() -> bool:
	var config := ConfigFile.new()
	return config.load(SAVE_PATH) == OK and bool(config.get_value("tutorial", "done", false))


static func mark_completed(value: bool = true) -> void:
	var config := ConfigFile.new()
	config.set_value("tutorial", "done", value)
	config.save(SAVE_PATH)


func setup(main: Node, font: Font) -> void:
	host = main
	name = "Tutorial"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = Panel.new()
	_panel.name = "CoachPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.03, 0.06, 0.9)
	style.border_color = Color(CYAN, 0.75)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(CYAN, 0.25)
	style.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_left = -330
	_panel.offset_right = 330
	_panel.offset_top = 150
	_panel.offset_bottom = 282
	_title = _make_label(font, 24, GOLD, Rect2(22, 10, 470, 32))
	_title.name = "StepTitle"
	_text = _make_label(font, 17, Color("#e9f6f8"), Rect2(22, 44, 616, 50))
	_text.name = "StepText"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_key = _make_label(font, 13, Color("#9fb4ba"), Rect2(22, 100, 300, 22))
	_key.name = "KeyHint"
	var skip := Button.new()
	skip.name = "SkipTutorial"
	skip.text = "SKIP TUTORIAL"
	skip.add_theme_font_override("font", font)
	skip.add_theme_font_size_override("font_size", 13)
	skip.position = Vector2(500, 10)
	skip.size = Vector2(140, 34)
	skip.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus"]:
		var skip_style := StyleBoxFlat.new()
		skip_style.bg_color = Color("#263845") if state != "hover" else Color("#30485a")
		skip_style.border_color = Color(CYAN, 0.45)
		skip_style.set_border_width_all(1)
		skip_style.set_corner_radius_all(3)
		skip.add_theme_stylebox_override(state, skip_style)
	skip.add_theme_color_override("font_color", Color("#e8eef0"))
	skip.pressed.connect(skip_tutorial)
	_panel.add_child(skip)
	for i in range(STEPS.size()):
		var dot := Panel.new()
		dot.position = Vector2(420 + i * 30, 107)
		dot.size = Vector2(22, 8)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_child(dot)
		_dots.append(dot)
	visible = false


func _make_label(font: Font, size_px: int, color: Color, rect: Rect2) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(label)
	return label


func begin() -> void:
	active = true
	visible = true
	step = 0
	host._track("tutorial_start")
	host.player.attack_started.connect(_on_attack_started)
	# The match host pauses per-frame updates while a finisher plays, so the SP
	# step listens for the finisher starting instead of polling for it.
	if not host._finisher_director.sequence_started.is_connected(_on_finisher_started):
		host._finisher_director.sequence_started.connect(_on_finisher_started)
	_show_step()


func current_id() -> String:
	return str(STEPS[step].id) if step < STEPS.size() else ""


func _show_step() -> void:
	_progress = 0.0
	var data: Dictionary = STEPS[step]
	_title.text = "STEP %d / %d  ·  %s" % [step + 1, STEPS.size(), data.title]
	_text.text = str(data.text)
	_key.text = "KEYBOARD: %s" % data.key
	for i in range(_dots.size()):
		var dot_style := StyleBoxFlat.new()
		dot_style.bg_color = GOLD if i < step else (CYAN if i == step else Color("#33495a"))
		dot_style.set_corner_radius_all(3)
		_dots[i].add_theme_stylebox_override("panel", dot_style)
	if data.id == "special":
		# Fill the bar so the player sees SP light up.
		host.player.meter = 100.0
		host.player.meter_changed.emit(0, 100.0)
	queue_redraw()


func _complete_step() -> void:
	host._track("tutorial_step", {"step": current_id()})
	host._announce_tutorial("NICE!")
	step += 1
	if step >= STEPS.size():
		_finish(false)
	else:
		_show_step()


func abort() -> void:
	# Leaving the fight mid-tutorial: stop without marking it as done.
	if not active:
		return
	active = false
	visible = false
	_disconnect_host()


func skip_tutorial() -> void:
	if active:
		host._track("tutorial_skip", {"step": current_id()})
		_finish(true)


func _finish(skipped: bool) -> void:
	active = false
	visible = false
	mark_completed()
	_disconnect_host()
	if not skipped:
		host._track("tutorial_complete")
	finished.emit(skipped)


func _on_finisher_started(_attacker_id: String) -> void:
	if active and current_id() == "special":
		_complete_step()


func _disconnect_host() -> void:
	if is_instance_valid(host.player) and host.player.attack_started.is_connected(_on_attack_started):
		host.player.attack_started.disconnect(_on_attack_started)
	if host._finisher_director.sequence_started.is_connected(_on_finisher_started):
		host._finisher_director.sequence_started.disconnect(_on_finisher_started)


func _on_attack_started(attacker: int, move: String) -> void:
	if not active or attacker != 0:
		return
	var want := {"jab": "light", "cross": "heavy", "kick": "kick"}
	if want.get(current_id(), "") == move:
		_complete_step()


func advance(delta: float) -> void:
	# Called by the match host every frame while the tutorial runs.
	if not active:
		return
	_clock += delta
	var player = host.player
	match current_id():
		"move":
			if absf(player.velocity.x) > 0.8: _progress += delta
			if _progress >= 0.35: _complete_step()
		"jump":
			if not player.is_on_floor(): _complete_step()
		"guard":
			if player.input_block: _progress += delta
			if _progress >= 0.35: _complete_step()
	queue_redraw()


func target_rect() -> Rect2:
	var data: Dictionary = STEPS[mini(step, STEPS.size() - 1)]
	var target := str(data.target)
	var node: Control = host.stick if target == "stick" else host.buttons.get(target)
	if node == null or not node.is_visible_in_tree():
		return Rect2()
	return Rect2(node.get_global_rect().position - get_global_rect().position, node.get_global_rect().size)


func _draw() -> void:
	if not active:
		return
	var rect := target_rect()
	if rect.size == Vector2.ZERO:
		return
	var center := rect.get_center()
	var pulse := 0.5 + 0.5 * sin(_clock * 6.0)
	var radius := maxf(rect.size.x, rect.size.y) * (0.6 + 0.08 * pulse)
	draw_arc(center, radius, 0.0, TAU, 48, Color(GOLD, 0.9), 4.0, true)
	draw_arc(center, radius + 10.0, 0.0, TAU, 48, Color(GOLD, 0.3 * pulse), 8.0, true)
	# Arrow from the coach panel toward the control.
	var tip := center - Vector2(0, radius + 8.0)
	var bob := Vector2(0, -8.0 * pulse)
	draw_colored_polygon(PackedVector2Array([tip + bob, tip + bob + Vector2(-14, -22), tip + bob + Vector2(14, -22)]), GOLD)
	if current_id() == "special" and host.player_meter_bar != null:
		var bar: Control = host.player_meter_bar
		var bar_rect := Rect2(bar.get_global_rect().position - get_global_rect().position, bar.get_global_rect().size).grow(6)
		draw_rect(bar_rect, Color(GOLD, 0.5 + 0.5 * pulse), false, 3.0)
