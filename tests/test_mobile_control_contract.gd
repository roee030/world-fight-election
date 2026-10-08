extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	assert(main.has_method("_mobile_input_available"), "mobile capability fallback is missing")
	assert(main._mobile_input_available(false, true, 0, 900), "every Web build must retain fight controls")
	assert(main._mobile_input_available(false, false, 1, 390), "web touch points must enable phone controls")
	assert(main._mobile_input_available(false, false, 0, 390), "small viewports must enable phone controls")
	assert(not main._mobile_input_available(false, false, 0, 900), "wide native mouse-only builds should hide touch controls")
	main._set_touch_controls_visible(true)
	assert(main.stick.visible, "phone fight has no joystick")
	for action in ["light", "heavy", "special", "jump", "block"]:
		assert(main.buttons.has(action), "missing touch action: " + action)
		assert(main.buttons[action].visible, "hidden touch action: " + action)
	assert(main.CONTROL_BINDINGS == {
		"move": [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT],
		"jump": [KEY_W, KEY_UP],
		"guard": [KEY_S, KEY_H],
		"crouch": [KEY_C],
		"light": [KEY_J, KEY_1],
		"heavy": [KEY_K, KEY_2],
		"special": [KEY_L, KEY_3],
		"pause": [KEY_ESCAPE]
	}, "keyboard controls drifted from the documented game contract")
	main.free()
	print("PASS: keyboard guide and mobile joystick/action contract")
	quit(0)
