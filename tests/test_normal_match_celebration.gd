extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main._setup_bout("bennet", "bibi", 1, "CELEBRATION QA")
	await process_frame
	main.player_rounds = 2
	main.enemy_rounds = 0
	main._show_result_with_celebration(true)
	assert(main.result_root.visible, "result options must appear while the winner celebrates")
	assert(main.result_root.get_node("ResultContent/ResultTitle").text == "YOU WIN")
	assert(main.match_state == main.MatchState.Value.RESULT, "celebration must not replace the result state")
	assert(not main.result_winner_art.visible, "static winner art must not cover the live celebration")
	assert(main._finisher_director.active, "ordinary match victory must run the winner celebration")
	assert(main._finisher_director._attacker == main.player)
	assert(main.enemy._visual.sprite.animation == "knockdown", "loser must stay fallen during the winner celebration")
	main._process(1.0)
	assert(is_equal_approx(main._finisher_director.timeline.elapsed(), 0.55), "winner celebration is still playing too fast")
	assert(main.player._visual.sprite.animation == "authored", "winner celebration art is not visible behind result UI")
	main._finisher_director.cancel()
	main._show_result_with_celebration(false)
	assert(main.result_root.get_node("ResultContent/ResultTitle").text == "YOU LOSE")
	assert(main.match_state == main.MatchState.Value.RESULT)
	assert(main._finisher_director.active and main._finisher_director._attacker == main.enemy, "CPU winner celebration is missing")
	main.free()
	print("PASS: normal win and loss show the correct winner celebration with result options")
	quit(0)
