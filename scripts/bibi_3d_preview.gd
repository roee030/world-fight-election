extends Node3D

const RiggedFighterVisual := preload("res://scripts/rigged_fighter_visual.gd")
const Motion := preload("res://scripts/quaternius_motion.gd")

const POSES := ["idle", "walk_forward", "jab", "cross", "hook", "hit", "knockdown", "getup"]

var rig: Dictionary
var motion: QuaterniusMotion
var pose_index := 0
var status: Label

func _ready() -> void:
	_build_world()
	_build_bibi()
	_build_ui()


func _build_bibi() -> void:
	rig = RiggedFighterVisual.new().build("bibi")
	if not str(rig.get("error", "")).is_empty():
		push_error(str(rig.error))
		return
	rig.root.name = "BibiRig"
	add_child(rig.root)
	motion = Motion.new()
	motion.name = "QuaterniusMotion"
	rig.root.add_child(motion)
	motion.bind(rig.skeleton, rig.bone_map, rig.root)
	_play_pose("idle")


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101a28")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b7d9f0")
	env.ambient_light_energy = 0.65
	environment.environment = env
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45, -28, 0)
	key.light_energy = 1.5
	key.shadow_enabled = true
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25, 145, 0)
	rim.light_color = Color("65c8ff")
	rim.light_energy = 0.85
	add_child(rim)
	var camera := Camera3D.new()
	camera.position = Vector3(3.15, 1.7, 5.1)
	camera.fov = 31.0
	add_child(camera)
	camera.look_at(Vector3(0, 0.98, 0), Vector3.UP)
	var floor := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(8.0, 8.0)
	floor.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("1b2a3b")
	material.metallic = 0.35
	material.roughness = 0.5
	floor.material_override = material
	add_child(floor)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "BIBI • 3D FIGHTER PROTOTYPE"
	title.position = Vector2(28, 22)
	title.add_theme_font_size_override("font_size", 28)
	layer.add_child(title)
	status = Label.new()
	status.position = Vector2(28, 60)
	status.size = Vector2(700, 44)
	status.add_theme_font_size_override("font_size", 15)
	layer.add_child(status)
	var row := HBoxContainer.new()
	row.position = Vector2(28, 650)
	row.size = Vector2(1100, 44)
	row.add_theme_constant_override("separation", 7)
	layer.add_child(row)
	for pose in POSES:
		var button := Button.new()
		button.text = pose.to_upper().replace("_", " ")
		button.custom_minimum_size = Vector2(108, 42)
		button.pressed.connect(func(value: String = pose): _play_pose(value))
		row.add_child(button)
	var back := Button.new()
	back.text = "BACK TO MENU"
	back.position = Vector2(1080, 24)
	back.size = Vector2(170, 42)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	layer.add_child(back)
	_play_pose(POSES[pose_index])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		elif event.keycode in [KEY_LEFT, KEY_A]:
			pose_index = wrapi(pose_index - 1, 0, POSES.size())
			_play_pose(POSES[pose_index])
		elif event.keycode in [KEY_RIGHT, KEY_D]:
			pose_index = wrapi(pose_index + 1, 0, POSES.size())
			_play_pose(POSES[pose_index])


func _play_pose(pose: String) -> void:
	if motion == null:
		return
	pose_index = POSES.find(pose)
	motion.play_state(pose, true)
	if status != null:
		status.text = "SKELETAL 3D • %s • arrow keys to inspect poses" % pose.to_upper().replace("_", " ")
