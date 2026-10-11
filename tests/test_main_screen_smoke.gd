extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var main = scene.instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	if main.PLAYABLE_IDS.size() != 13: return _fail("roster does not contain all 13 fighters")
	for id in main.PLAYABLE_IDS:
		main._select_fighter(id)
		if main.select_portrait.texture == null: return _fail("missing selection art for %s" % id)
	if main.menu_root.get_node_or_null("MenuActionPanel/Bibi3DPrototypeButton") == null:
		return _fail("Bibi 3D prototype is not reachable from the main menu")
	if main.menu_root.get_node_or_null("MenuActionPanel/NewEngineFightButton") == null:
		return _fail("New Engine Fight is not reachable from the main menu")
	main._open_select("quick")
	if not main.select_root.visible or main.menu_root.visible: return _fail("selection screen state is invalid")
	main.free()
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
