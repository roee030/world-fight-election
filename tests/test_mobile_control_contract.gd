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
	for action in ["light", "heavy", "special", "block"]:
		var diamond: Polygon2D = main.hud_root.get_node_or_null("TouchDiamond_" + action.capitalize()) as Polygon2D
		assert(diamond != null and diamond.polygon.size() == 4, "touch %s must use a four-point diamond plate" % action)
	assert(main.buttons.light.text == "JAB")
	assert(main.buttons.heavy.text == "CROSS")
	assert(main.buttons.special.text == "MAX")
	assert(main.buttons.block.text == "GUARD")
	for action in main.buttons:
		var target: Button = main.buttons[action]
		assert(target.size.x >= 100.0 and target.size.y >= 100.0, "%s touch target is too small for 44 CSS pixels at 568x320" % action)
	for action in main.buttons:
		var touch_button: Button = main.buttons[action]
		assert(touch_button.position.x >= 64.0 and touch_button.position.y >= 400.0, "%s is outside the phone safe frame" % action)
		assert(touch_button.position.x + touch_button.size.x <= 1240.0, "%s is clipped on Chrome's right edge" % action)
		assert(touch_button.position.y + touch_button.size.y <= 700.0, "%s is clipped below Chrome's visual viewport" % action)
	var actions: Array = main.buttons.keys()
	for index in range(actions.size()):
		for other_index in range(index + 1, actions.size()):
			var first: Button = main.buttons[actions[index]]
			var second: Button = main.buttons[actions[other_index]]
			assert(not Rect2(first.position, first.size).intersects(Rect2(second.position, second.size)), "%s and %s touch targets overlap" % [actions[index], actions[other_index]])
	main._setup_bout("bennet", "avigdor", 1, "MAX TOUCH QA")
	await process_frame
	main.fight_live = true
	main.round_ready = true
	main.match_state = main.MatchState.Value.FIGHTING
	main.player.meter = 100.0
	main.enemy.health = main.enemy.max_health()
	main.player.round_over = false
	main.enemy.round_over = false
	main.buttons.special.emit_signal("button_down")
	main.buttons.special.emit_signal("pressed")
	main.buttons.special.emit_signal("button_up")
	main._physics_process(0.016)
	main.player._physics_process(0.016)
	assert(main.player.attack_kind == "special", "tapping MAX with full energy did not start the special attack")
	assert(main.player.meter == 45.0, "MAX special did not spend its documented 55 energy")
	assert(main.message_label.visible and main.message_label.text.contains("MAX"), "MAX touch has no visible confirmation")
	main._physics_process(0.016)
	assert(main.player.meter == 45.0, "one MAX gesture submitted the normal Special more than once")
	main.player.attack_kind = ""
	main.player.busy = 0.0
	main.player.meter = 0.0
	main.buttons.special.emit_signal("button_down")
	main.buttons.special.emit_signal("button_up")
	assert(main.message_label.visible and main.message_label.text.contains("55%"), "unavailable MAX press has no useful energy feedback")
	main._process(1.3)
	assert(not main.message_label.visible, "MAX feedback must expire instead of obscuring combat")
	main.paused = true
	main.player.meter = 100.0
	main.buttons.special.emit_signal("button_down")
	main.buttons.special.emit_signal("button_up")
	main.paused = false
	main._physics_process(0.016)
	assert(main.player.attack_kind == "", "MAX pressed during pause buffered into resumed combat")
	main._finisher_director.cancel()
	main.player.attack_kind = ""
	main.player.busy = 0.0
	main.player.meter = 100.0
	main.player_rounds = 1
	main.enemy.health = minf(15.0, main.enemy.max_health() * 0.15)
	main.player.position = Vector3(-0.6, 0.0, 0.0)
	main.enemy.position = Vector3(0.6, 0.0, 0.0)
	main.player.facing = 1.0
	main.buttons.special.emit_signal("button_down")
	main.buttons.special.emit_signal("pressed")
	main.buttons.special.emit_signal("button_up")
	assert(main._finisher_director.active, "eligible phone MAX tap did not launch the finisher")
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
