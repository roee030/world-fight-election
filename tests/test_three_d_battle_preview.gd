extends SceneTree

const PreviewScene := preload("res://scenes/three_d_battle_preview.tscn")

func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run() -> void:
	var preview := PreviewScene.instantiate()
	get_root().add_child(preview)
	await process_frame
	if preview.get_node_or_null("BibiRig") == null or preview.get_node_or_null("RoeeMonsterRig") == null:
		_fail("3D battle preview must assemble both Bibi and Roee Monster rigs")
		return
	if preview.get_node_or_null("CombatWorld") == null:
		_fail("3D battle preview must own the deterministic CombatWorld")
		return
	preview.queue_player_attack("jab")
	for _tick in range(30):
		preview.step_combat_tick()
	if float(preview.combat_world.fighters[1].health) >= 100.0:
		_fail("Player attack must use CombatWorld to damage Bibi")
		return
	preview.queue_player_attack("cross")
	if preview.get_node_or_null("BattleHUD") == null:
		_fail("3D battle preview must expose a battle HUD")
		return
	preview.queue_free()
	quit(0)
