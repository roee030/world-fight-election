extends Node3D

const Catalog = preload("res://scripts/finishers/finisher_catalog.gd")
const Director = preload("res://scripts/finishers/finisher_director.gd")
const Rules = preload("res://scripts/finishers/finisher_rules.gd")
const MatchState = preload("res://scripts/finishers/match_state.gd")
const IDS = preload("res://scripts/character_debug.gd").FIGHTERS
const STEP := 1.0 / 60.0
var catalog := Catalog.new()
var director := Director.new()
var attacker: GameFighter
var defender: GameFighter
var arena := Node3D.new()
var camera := Camera3D.new()
var attacker_selector: OptionButton
var defender_selector: OptionButton
var scenario_selector: OptionButton
var status: Label
var event_label: Label
var scrub: HSlider
var speed := 1.0
var paused := true
var elapsed := 0.0
var outcome := "eligible"
var selected := "bennet"
var safe_frame := true
var bounds := true
var overlay: Control
var _updating_scrub := false

func _ready() -> void:
	add_child(arena)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(16, 0.2, 4)
	floor_shape.shape = box; floor_shape.position.y = -0.1; floor_body.add_child(floor_shape); arena.add_child(floor_body)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.6
	camera.position = Vector3(0, 1.4, 5)
	add_child(camera)
	camera.current = true
	add_child(director)
	director.catalog = catalog
	director.configure(self, arena, camera)
	catalog.load_default()
	_build_ui()

func _build_ui() -> void:
	var layer := CanvasLayer.new(); layer.name = "LabUI"; layer.layer = 20; add_child(layer)
	var panel := VBoxContainer.new(); panel.name = "Controls"; panel.position = Vector2(24, 16); panel.size = Vector2(1232, 180); layer.add_child(panel)
	var title := Label.new(); title.text = "FINISHER LAB  •  Shared match runtime"; title.add_theme_font_size_override("font_size", 25); panel.add_child(title)
	var row := HBoxContainer.new(); panel.add_child(row)
	attacker_selector = _selector(row, "Attacker", IDS)
	defender_selector = _selector(row, "Defender", IDS); defender_selector.select(2)
	scenario_selector = _selector(row, "Scenario", ["eligible", "hit", "miss", "pause-resume"])
	attacker_selector.item_selected.connect(func(index): preview(IDS[index], outcome))
	defender_selector.item_selected.connect(func(_index): preview(selected, outcome))
	scenario_selector.item_selected.connect(func(index): preview(selected, scenario_selector.get_item_text(index)))
	row = HBoxContainer.new(); panel.add_child(row)
	_button(row, "PLAY / PAUSE", func(): set_paused(not paused))
	_button(row, "STEP 1/60", step_frame)
	_button(row, "SPRITE LAB", close)
	var settings := HBoxContainer.new(); panel.add_child(settings)
	for value in [0.25, 0.5, 1.0]: _button(settings, "%s×" % value, func(v = value): set_speed(v))
	_check(settings, "Mobile density", false, set_mobile)
	_check(settings, "Reduced motion", false, set_reduced_motion)
	_check(panel, "SafeFrame", true, func(value): safe_frame = value; overlay.queue_redraw())
	_check(panel, "Bounds", true, func(value): bounds = value; overlay.queue_redraw())
	var legend := Label.new(); legend.text = "Cyan: collision   Green: hurt proxy   Yellow: guard proxy   Orange: reach guide   Mint: world floor"; legend.add_theme_font_size_override("font_size", 14); panel.add_child(legend)
	status = Label.new(); status.position = Vector2(24, 580); status.size = Vector2(1232, 44); layer.add_child(status)
	event_label = Label.new(); event_label.position = Vector2(24, 630); layer.add_child(event_label)
	scrub = HSlider.new(); scrub.position = Vector2(24, 670); scrub.size = Vector2(1232, 28); scrub.step = STEP; layer.add_child(scrub)
	scrub.value_changed.connect(func(value): if not _updating_scrub: seek(value))
	overlay = Control.new(); overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE; overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); layer.add_child(overlay)
	overlay.draw.connect(_draw_overlays)

func _selector(row: Node, label: String, values: Array) -> OptionButton:
	var text := Label.new(); text.text = label; row.add_child(text)
	var button := OptionButton.new(); button.custom_minimum_size.x = 155
	for value in values: button.add_item(value)
	row.add_child(button)
	return button

func _button(row: Node, text: String, callback: Callable) -> void:
	var button := Button.new(); button.text = text; button.pressed.connect(callback); row.add_child(button)

func _check(row: Node, text: String, checked: bool, callback: Callable) -> void:
	var button := CheckBox.new(); button.name = text; button.text = text; button.button_pressed = checked; button.toggled.connect(callback); row.add_child(button)

func preview(fighter_id: String, scenario: String) -> void:
	director.cancel()
	director.diagnostic = ""
	selected = fighter_id if IDS.has(fighter_id) else IDS[0]
	outcome = scenario if ["eligible", "hit", "miss", "pause-resume"].has(scenario) else "eligible"
	camera.current = true
	attacker_selector.select(IDS.find(selected))
	scenario_selector.select(["eligible", "hit", "miss", "pause-resume"].find(outcome))
	for fighter in [attacker, defender]:
		if is_instance_valid(fighter): fighter.free()
	attacker = _fighter(selected, 0, -0.8)
	defender = _fighter(IDS[defender_selector.selected], 1, 0.8)
	attacker.rival = defender; defender.rival = attacker
	attacker.meter = 100; defender.health = 15
	attacker.facing = 1; defender.facing = -1
	defender._visual.sprite.flip_h = true
	elapsed = 0
	var definition := catalog.definition_for(selected)
	var celebration := catalog.celebration_for(str(definition.get("celebration_id", "")))
	scrub.max_value = float(definition.get("duration", 0)) + float(celebration.get("duration", 0))
	if not catalog.errors.is_empty(): status.text = "CATALOG ERRORS: " + "; ".join(catalog.errors)
	elif not definition.get("implemented", false): status.text = "PLANNED — %s / %s • assets and timeline pending" % [selected, definition.get("finisher_id", "")]
	elif outcome == "eligible":
		var eligible := Rules.is_eligible({"state": MatchState.Value.FIGHTING, "paused": false, "match_point": true, "grounded": true, "actionable": true, "facing_correct": true, "health_ratio": defender.health / 100, "meter": attacker.meter, "distance": attacker.position.distance_to(defender.position)}, definition)
		status.text = ("ELIGIBLE" if eligible else "INELIGIBLE") + " — full Special Energy, match point, grounded, 15% rival health"
	else:
		director.force_opening_miss = outcome == "miss"
		director.begin(attacker, defender, definition)
		status.text = "RUNNING — " + str(definition.get("finisher_id", ""))
	set_paused(outcome != "hit" or not director.active)
	_update_display()

func _fighter(id: String, who: int, x: float) -> GameFighter:
	var fighter := GameFighter.new(); fighter.setup(id, who, false); arena.add_child(fighter)
	fighter.position.x = x; fighter.set_physics_process(false)
	return fighter

func _process(delta: float) -> void:
	if not visible: return
	if not paused and director.active:
		director.advance(delta * speed); elapsed += delta * speed
	_update_display()

func set_speed(value: float) -> void:
	if value in [0.25, 0.5, 1.0]:
		speed = value
		set_paused(paused)

func set_paused(value: bool) -> void:
	paused = value; director.set_paused(value)
	for fighter in [attacker, defender]:
		if is_instance_valid(fighter):
			fighter._visual.motion.freeze_motion(value)
			fighter._visual.sprite.speed_scale = 0 if value else speed

func step_frame() -> void:
	if not paused or not director.active: return
	director.set_paused(false); director.advance(STEP); elapsed += STEP; set_paused(true)
	_update_display()

func seek(seconds: float) -> void:
	var target := clampf(seconds, 0, scrub.max_value)
	preview(selected, outcome)
	set_paused(true)
	if not director.active: return
	for _frame in range(int(floor(target / STEP))): step_frame()

func set_mobile(value: bool) -> void: director.set_effect_density("mobile" if value else "desktop")
func set_reduced_motion(value: bool) -> void: director.set_reduced_motion(value)

func _update_display() -> void:
	if not director.diagnostic.is_empty(): status.text = "DIRECTOR: " + director.diagnostic
	event_label.text = "EVENT: %s   •   %.3fs   •   %s×   •   %s   •   consumed hits: %s" % [director.current_event_key(), elapsed, speed, "PAUSED" if paused else "PLAYING", ", ".join(director.consumed_hit_ids())]
	_updating_scrub = true; scrub.value = elapsed; _updating_scrub = false
	overlay.queue_redraw()

func _draw_overlays() -> void:
	if safe_frame: overlay.draw_rect(Rect2(64, 36, 1152, 648), Color(0.8, 0.7, 0.3, 0.7), false, 1)
	var a := camera.unproject_position(Vector3(-5, 0, 0)); var b := camera.unproject_position(Vector3(5, 0, 0))
	overlay.draw_line(a, b, Color(0.3, 0.9, 0.65, 0.8), 2)
	if not bounds: return
	for fighter in [attacker, defender]:
		if not is_instance_valid(fighter): continue
		var feet := camera.unproject_position(fighter.position)
		var shape: CapsuleShape3D = fighter._standing_capsule
		var head := camera.unproject_position(fighter.position + Vector3(0, shape.height, 0))
		var height := feet.y - head.y
		var radius := absf(camera.unproject_position(fighter.position + Vector3(shape.radius, 0, 0)).x - feet.x)
		overlay.draw_rect(Rect2(head - Vector2(radius, 0), Vector2(radius * 2, height)), Color.CYAN, false)
		overlay.draw_rect(Rect2(head - Vector2(radius + 4, 3), Vector2(radius * 2 + 8, height + 3)), Color.GREEN, false)
		var reach := 1.32 if fighter.attack_kind.is_empty() else float(GameFighter.MOVES[fighter.attack_kind].reach)
		var edge := camera.unproject_position(fighter.position + Vector3(fighter.facing * reach, 0.9, 0))
		overlay.draw_line(camera.unproject_position(fighter.position + Vector3(0, 0.9, 0)), edge, Color.ORANGE, 2)
		overlay.draw_circle(camera.unproject_position(fighter.position + Vector3(fighter.facing * 0.4, 1, 0)), 12, Color.YELLOW, false)

func close() -> void:
	director.cancel(); visible = false; get_node("LabUI").visible = false
	get_parent().stage.visible = true; get_parent().get_node("DebugUI").visible = true
	get_parent().get_node("SpriteLabCamera").current = true
