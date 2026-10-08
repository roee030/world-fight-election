extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var main = scene.instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame

	var hero: TextureRect = main.menu_root.get_node_or_null("MainHeroBackground") as TextureRect
	if hero == null or hero.texture == null:
		return _fail("main menu has no full-screen hero artwork")
	var action_panel: Node = main.menu_root.get_node_or_null("MenuActionPanel")
	if action_panel == null:
		return _fail("main menu action panel is missing")
	if action_panel.find_children("*", "Button", true, false).size() != 3:
		return _fail("main menu must expose exactly three actions")
	if main.menu_root.get_node_or_null("FullscreenButton") == null:
		return _fail("main menu has no fullscreen control for phone browsers")
	if not main.menu_root.find_children("*", "ScrollContainer", true, false).is_empty():
		return _fail("main menu still contains a selectable roster strip")
	if main.menu_root.get_node_or_null("HeroLineup") != null:
		return _fail("main menu still splits the screen into fighter strips")
	for label in main.menu_root.find_children("*", "Label", true, false):
		if "A/D MOVE" in label.text or "J JAB" in label.text:
			return _fail("keyboard combat instructions are still visible on the startup menu")

	var mystery := main.select_root.get_node_or_null("MysteryCpuMark") as Label
	if mystery == null or mystery.text != "?":
		return _fail("fighter select does not show a mystery CPU slot")
	if main.select_rival_name.text != "RANDOM OPPONENT":
		return _fail("fighter select exposes a fixed rival")
	var roster_grid := main.select_root.get_node_or_null("RosterGrid") as GridContainer
	if roster_grid == null:
		return _fail("fighter select has no fixed roster grid")
	if roster_grid.columns != 7 or roster_grid.get_child_count() != main.PLAYABLE_IDS.size():
		return _fail("all fighters are not visible in the wide two-row grid")
	if not main.select_root.find_children("*", "ScrollContainer", true, false).is_empty():
		return _fail("fighter select roster still scrolls")
	for id in main.PLAYABLE_IDS:
		if not main._fighter_thumbnail_path(id).contains("/portraits/"):
			return _fail("fighter select does not use face portrait for %s" % id)

	var frame: Control = main.hud_root.get_node_or_null("CombatHUDFrame") as Control
	if frame == null:
		return _fail("combat HUD frame is missing")
	if frame.size.y > 140.0:
		return _fail("combat HUD is not thin enough")
	if main.player_health_bar.size.y < 24.0 or main.enemy_health_bar.size.y < 24.0:
		return _fail("combat health bars are too thin to read like the supplied fighting-game reference")
	if main.player_meter_bar.size.y < 6.0 or main.enemy_meter_bar.size.y < 6.0:
		return _fail("special meters are too thin to distinguish from the health bars")
	if main.player_health_bar.segments < 5 or not main.enemy_health_bar.mirrored:
		return _fail("health bars must be segmented and mirrored like the reference")
	for node_name in ["PlayerPortrait", "EnemyPortrait", "TimerMedallion", "TimerLabel", "RoundLabel", "PlayerRoundMarkers", "EnemyRoundMarkers", "PlayerRecoverableHealth", "EnemyRecoverableHealth", "PlayerHUDWingPlate", "EnemyHUDWingPlate", "TimerHexPlate", "PlayerPortraitRing", "EnemyPortraitRing", "PlayerTag", "EnemyTag", "FullscreenButton", "PauseButton"]:
		if frame.find_child(node_name, true, false) == null:
			return _fail("combat HUD is missing %s" % node_name)
	for node_name in ["PlayerSpecialLabel", "EnemySpecialLabel"]:
		var special_label := frame.find_child(node_name, true, false) as Label
		if special_label == null or special_label.text != "SPECIAL ENERGY":
			return _fail("combat HUD does not identify the gold bar as Special Energy")
	if not main.round_label.text.begins_with("BEST OF 3"):
		return _fail("round clock does not show the best-of-three round")
	if (frame.find_child("PlayerRoundMarkers", true, false) as Node).get_child_count() != 2:
		return _fail("player round markers are incomplete")
	if (frame.find_child("EnemyRoundMarkers", true, false) as Node).get_child_count() != 2:
		return _fail("enemy round markers are incomplete")
	var enemy_group := frame.find_child("EnemyHUDGroup", true, false) as Control
	if enemy_group == null or not is_equal_approx(enemy_group.anchor_left, 1.0):
		return _fail("CPU panel must anchor to the right edge on wide phones")
	main._on_meter_changed(0, 100.0)
	if main.player_meter_percent.text != "SP READY":
		return _fail("full Special Energy does not announce SP")

	var result_art := main.result_root.get_node_or_null("ResultWinnerArt") as TextureRect
	if result_art == null:
		return _fail("result screen has no winner artwork")
	if main.result_root.get_node_or_null("ResultMenuButton") == null:
		return _fail("result screen has no menu action")
	var darken := main.result_root.get_node_or_null("ResultDarken") as Panel
	if darken == null or (darken.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a > 0.38:
		return _fail("result presentation hides the arena")
	if main.result_root.get_node("ResultContent/ResultTitle").get_theme_font_size("font_size") > 90:
		return _fail("result title covers too much of the winner celebration")
	var result_content: Control = main.result_root.get_node("ResultContent") as Control
	if result_content.position.x > 80.0 or result_content.size.x > 480.0:
		return _fail("result text still occupies the center of the winner celebration")
	var corner_card: Panel = main.result_root.get_node_or_null("ResultCornerCard") as Panel
	if corner_card == null or corner_card.position.x > 80.0 or corner_card.size.x > 500.0:
		return _fail("result screen has no compact corner card")
	main._show_result(true)
	if result_art.texture == null:
		return _fail("victory result does not populate winner artwork")
	if main.result_root.get_node("ResultContent/ResultTitle").text != "YOU WIN":
		return _fail("victory result title is incorrect")
	main._show_result(false)
	if main.result_root.get_node("ResultContent/ResultTitle").text != "YOU LOSE":
		return _fail("defeat result title is incorrect")
	if not main.result_root.get_node("ContinueButton").visible or not main.result_root.get_node("ResultMenuButton").visible:
		return _fail("defeat result actions are not visible")

	main.free()
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
