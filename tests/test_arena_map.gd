extends SceneTree

const ArenaMap := preload("res://scripts/ui/arena_map.gd")

func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run() -> void:
	var map := ArenaMap.new()
	map.size = Vector2(360, 440)
	map.set_stages([
		{"id": "north", "name": "NORTH", "map_position": Vector2(0.5, 0.15)},
		{"id": "south", "name": "SOUTH", "map_position": Vector2(0.5, 0.8)},
	])
	get_root().add_child(map)
	await process_frame
	if map.stage_ids() != ["north", "south"]:
		_fail("Arena map does not preserve stage ids")
		return
	if not map.select_stage("south"):
		_fail("Arena map cannot select an available stage")
		return
	if map.selected_stage_id != "south":
		_fail("Arena map did not retain the selected stage")
		return
	map.select_stage("north")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(180, 330)
	map._gui_input(click)
	if map.selected_stage_id != "south":
		_fail("Arena map node click did not select the matching stage")
		return
	if map.select_stage("missing"):
		_fail("Arena map selected a stage that does not exist")
		return
	map.queue_free()
	quit(0)
