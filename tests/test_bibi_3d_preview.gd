extends SceneTree

const PREVIEW_SCENE := preload("res://scenes/bibi_3d_preview.tscn")

func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run() -> void:
	var preview := PREVIEW_SCENE.instantiate()
	get_root().add_child(preview)
	await process_frame
	if preview.get_node_or_null("BibiRig") == null:
		_fail("Bibi 3D preview does not assemble the Bibi rig")
		return
	if preview.find_child("Skeleton3D", true, false) == null:
		_fail("Bibi 3D preview has no Skeleton3D")
		return
	if preview.find_child("QuaterniusMotion", true, false) == null:
		_fail("Bibi 3D preview has no motion controller")
		return
	if preview.find_child("AnimatedSprite3D", true, false) != null:
		_fail("Bibi 3D preview contains a sprite billboard")
		return
	preview.queue_free()
	quit(0)
