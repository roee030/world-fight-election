extends Node3D

const CombatWorldScript := preload("res://scripts/combat/combat_world.gd")
const RiggedFighterVisual := preload("res://scripts/rigged_fighter_visual.gd")
const Motion := preload("res://scripts/quaternius_motion.gd")
const COMBAT_DT := 1.0 / 60.0

var combat_world: RefCounted
var player_attack := ""
var player_axis := 0.0
var accumulator := 0.0
var bibi: Dictionary
var roee_monster: Dictionary
var fighter_nodes := {}
var fighter_motions := {}
var fighter_states := {}
var player_hp: Label
var bibi_hp: Label
var status: Label

func _ready() -> void:
	_build_world()
	_build_combat_world()
	_build_fighters()
	_build_hud()
	_render_combat_state([])


func _build_combat_world() -> void:
	var holder := Node.new()
	holder.name = "CombatWorld"
	add_child(holder)
	combat_world = CombatWorldScript.new(20261011)
	combat_world.fighters[0].x = -0.6
	combat_world.fighters[1].x = 0.6


func _build_fighters() -> void:
	roee_monster = _build_rig("avigdor", "RoeeMonsterRig", true)
	bibi = _build_rig("bibi", "BibiRig", false)


func _build_rig(source_id: String, node_name: String, monster: bool) -> Dictionary:
	var built := RiggedFighterVisual.new().build(source_id)
	if not str(built.get("error", "")).is_empty():
		push_error(str(built.error))
		return {}
	built.root.name = node_name
	add_child(built.root)
	var motion = Motion.new()
	motion.name = "%sMotion" % node_name
	built.root.add_child(motion)
	motion.bind(built.skeleton, built.bone_map, built.root)
	if monster:
		_style_roee_monster(built)
	var fighter_id := 0 if monster else 1
	fighter_nodes[fighter_id] = built.root
	fighter_motions[fighter_id] = motion
	fighter_states[fighter_id] = ""
	return built


func _style_roee_monster(built: Dictionary) -> void:
	var outfit := built.root.find_child("ContinuousOutfit", true, false) as MeshInstance3D
	if outfit != null and outfit.material_override is StandardMaterial3D:
		(outfit.material_override as StandardMaterial3D).albedo_color = Color("46586c")
	var hair := built.root.find_child("GrayHair", true, false) as MeshInstance3D
	if hair != null and hair.material_override is StandardMaterial3D:
		(hair.material_override as StandardMaterial3D).albedo_color = Color("17191e")
	var beard := built.root.find_child("GrayBeard", true, false) as MeshInstance3D
	if beard != null and beard.material_override is StandardMaterial3D:
		(beard.material_override as StandardMaterial3D).albedo_color = Color("17191e")
	_add_horn(built.skeleton, "horn_l", Vector3(-0.12, 0.13, 0.01), -28.0)
	_add_horn(built.skeleton, "horn_r", Vector3(0.12, 0.13, 0.01), 28.0)
	_add_arm_guard(built.skeleton, "lowerarm_l", "StoneArmLeft")
	_add_arm_guard(built.skeleton, "lowerarm_r", "StoneArmRight")


func _add_horn(skeleton: Skeleton3D, node_name: String, offset: Vector3, angle: float) -> void:
	var attachment := BoneAttachment3D.new()
	attachment.name = node_name
	attachment.bone_name = "head"
	skeleton.add_child(attachment)
	var horn := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.012
	mesh.bottom_radius = 0.065
	mesh.height = 0.28
	horn.mesh = mesh
	horn.position = offset
	horn.rotation_degrees = Vector3(0, 0, angle)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("293748")
	material.metallic = 0.35
	material.roughness = 0.42
	horn.material_override = material
	attachment.add_child(horn)


func _add_arm_guard(skeleton: Skeleton3D, bone_name: String, node_name: String) -> void:
	var attachment := BoneAttachment3D.new()
	attachment.name = node_name
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)
	var guard := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.115
	mesh.bottom_radius = 0.13
	mesh.height = 0.42
	guard.mesh = mesh
	guard.rotation_degrees.x = 90.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("263645")
	material.emission_enabled = true
	material.emission = Color("00b6e7")
	material.emission_energy_multiplier = 0.65
	guard.material_override = material
	attachment.add_child(guard)


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0d1722")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b7d8ee")
	env.ambient_light_energy = 0.68
	environment.environment = env
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45, -25, 0)
	key.light_energy = 1.55
	key.shadow_enabled = true
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-22, 145, 0)
	rim.light_color = Color("55c8ff")
	rim.light_energy = 0.9
	add_child(rim)
	var camera := Camera3D.new()
	camera.position = Vector3(3.55, 1.72, 6.25)
	camera.fov = 32.0
	add_child(camera)
	camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	var floor := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(9.0, 7.0)
	floor.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("1b2a3a")
	material.metallic = 0.28
	material.roughness = 0.5
	floor.material_override = material
	add_child(floor)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "BattleHUD"
	add_child(layer)
	var title := Label.new()
	title.text = "NEW ENGINE LAB  •  ROEE MONSTER VS BIBI"
	title.position = Vector2(28, 18)
	title.add_theme_font_size_override("font_size", 24)
	layer.add_child(title)
	player_hp = _hud_label(layer, Vector2(28, 56), "ROEE MONSTER  100")
	bibi_hp = _hud_label(layer, Vector2(928, 56), "BIBI  100")
	bibi_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status = _hud_label(layer, Vector2(320, 94), "A / D MOVE   •   J JAB   •   K CROSS")
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var controls := HBoxContainer.new()
	controls.position = Vector2(440, 650)
	controls.size = Vector2(500, 46)
	controls.add_theme_constant_override("separation", 12)
	layer.add_child(controls)
	for spec in [["JAB", "jab"], ["CROSS", "cross"]]:
		var button := Button.new()
		button.text = spec[0]
		button.custom_minimum_size = Vector2(130, 42)
		button.pressed.connect(func(attack: String = spec[1]): queue_player_attack(attack))
		controls.add_child(button)
	var back := Button.new()
	back.text = "BACK TO MENU"
	back.position = Vector2(1080, 18)
	back.size = Vector2(170, 40)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	layer.add_child(back)


func _hud_label(parent: Node, position_value: Vector2, text_value: String) -> Label:
	var label := Label.new()
	label.position = position_value
	label.size = Vector2(325, 28)
	label.text = text_value
	label.add_theme_font_size_override("font_size", 18)
	parent.add_child(label)
	return label


func _process(delta: float) -> void:
	accumulator += delta
	while accumulator >= COMBAT_DT:
		accumulator -= COMBAT_DT
		step_combat_tick()


func queue_player_attack(attack: String) -> void:
	if attack in ["jab", "cross"]:
		player_attack = attack


func step_combat_tick() -> void:
	if combat_world == null:
		return
	var tick: int = int(combat_world.tick) + 1
	var bibi_state: Dictionary = combat_world.fighters[1]
	var player_state: Dictionary = combat_world.fighters[0]
	var bibi_axis := clampf((float(player_state.x) - float(bibi_state.x)) * 1.3, -1.0, 1.0) if absf(float(player_state.x) - float(bibi_state.x)) > 1.1 else 0.0
	var bibi_attack := "jab" if tick % 72 == 0 and absf(float(player_state.x) - float(bibi_state.x)) <= 1.42 else ""
	var events: Array[Dictionary] = combat_world.step(tick, {
		0: {"axis": player_axis, "attack": player_attack},
		1: {"axis": bibi_axis, "attack": bibi_attack},
	})
	player_attack = ""
	_render_combat_state(events)


func _render_combat_state(events: Array[Dictionary]) -> void:
	for fighter_id in [0, 1]:
		var state: Dictionary = combat_world.fighters[fighter_id]
		var node: Node3D = fighter_nodes.get(fighter_id)
		var motion: QuaterniusMotion = fighter_motions.get(fighter_id)
		if node == null or motion == null:
			continue
		node.position.x = float(state.x)
		motion.set_facing(float(state.facing))
		var desired := str(state.attack) if not str(state.attack).is_empty() else "idle"
		for event in events:
			if int(event.defender) == fighter_id:
				desired = "hit"
		if fighter_states.get(fighter_id, "") != desired:
			motion.play_state(desired, true)
			fighter_states[fighter_id] = desired
	player_hp.text = "ROEE MONSTER  %03d" % roundi(float(combat_world.fighters[0].health))
	bibi_hp.text = "BIBI  %03d" % roundi(float(combat_world.fighters[1].health))
	if not events.is_empty():
		status.text = "%s CONNECTS" % str(events[0].move).to_upper()
	elif float(combat_world.fighters[0].health) <= 0.0 or float(combat_world.fighters[1].health) <= 0.0:
		status.text = "ROUND COMPLETE"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_ESCAPE and event.pressed:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		elif event.keycode in [KEY_A, KEY_LEFT]:
			player_axis = -1.0 if event.pressed else (0.0 if player_axis < 0.0 else player_axis)
		elif event.keycode in [KEY_D, KEY_RIGHT]:
			player_axis = 1.0 if event.pressed else (0.0 if player_axis > 0.0 else player_axis)
		elif event.pressed and event.keycode == KEY_J:
			queue_player_attack("jab")
		elif event.pressed and event.keycode == KEY_K:
			queue_player_attack("cross")
