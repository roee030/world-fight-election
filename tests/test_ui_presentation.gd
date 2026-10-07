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
	if not main.menu_root.find_children("*", "ScrollContainer", true, false).is_empty():
		return _fail("main menu still contains a selectable roster strip")
	if main.menu_root.get_node_or_null("HeroLineup") != null:
		return _fail("main menu still splits the screen into fighter strips")

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

	var frame: Node = main.hud_root.get_node_or_null("CombatHUDFrame")
	if frame == null:
		return _fail("combat HUD frame is missing")
	if frame.size.y > 104.0:
		return _fail("combat HUD is not thin enough")
	for node_name in ["PlayerPortrait", "EnemyPortrait", "TimerMedallion", "PlayerRoundMarkers", "EnemyRoundMarkers", "PlayerRecoverableHealth", "EnemyRecoverableHealth", "LeftHealthWing", "RightHealthWing"]:
		if frame.get_node_or_null(node_name) == null:
			return _fail("combat HUD is missing %s" % node_name)
	for node_name in ["PlayerSpecialLabel", "EnemySpecialLabel"]:
		if frame.get_node_or_null(node_name) == null:
			return _fail("combat HUD does not explain the special meter")
	for i in range(1, 10):
		if frame.get_node_or_null("PlayerHealthCut%d" % i) == null or frame.get_node_or_null("EnemyHealthCut%d" % i) == null:
			return _fail("health bars are missing segment %d" % i)
	if frame.get_node("PlayerRoundMarkers").get_child_count() != 2:
		return _fail("player round markers are incomplete")
	if frame.get_node("EnemyRoundMarkers").get_child_count() != 2:
		return _fail("enemy round markers are incomplete")

	var result_art := main.result_root.get_node_or_null("ResultWinnerArt") as TextureRect
	if result_art == null:
		return _fail("result screen has no winner artwork")
	if main.result_root.get_node_or_null("ResultMenuButton") == null:
		return _fail("result screen has no menu action")
	var darken := main.result_root.get_node_or_null("ResultDarken") as Panel
	if darken == null or (darken.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a >= 0.75:
		return _fail("result presentation hides the arena")
	main._show_result(true)
	if result_art.texture == null:
		return _fail("victory result does not populate winner artwork")
	if main.result_root.get_node("ResultContent/ResultTitle").text != "VICTORY":
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
