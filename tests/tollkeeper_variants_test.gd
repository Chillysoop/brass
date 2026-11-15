extends SceneTree

const Arena := preload("res://arena.tscn")
const FrontierRun := preload("res://scripts/frontier_run.gd")
const GameIcons := preload("res://scripts/game_icons.gd")

var failures: Array[String] = []
var save_prefix := "user://tollkeeper-variants-%d" % Time.get_ticks_usec()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Arena.instantiate()
	root.add_child(game)
	await process_frame
	var seeds := _tollkeeper_seeds()
	_check(seeds.size() == 2, "Both Tollkeeper forms must still appear across nearby Easy seeds.")
	for variant: String in seeds:
		await _check_route(game, seeds[variant], variant)
	game.queue_free()
	await process_frame
	for seed_value in seeds.values():
		for suffix in ["", ".tmp", ".bak"]:
			var path := "%s-%d.json%s" % [save_prefix, seed_value, suffix]
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Both Tollkeeper fights matched the saved encounter and Easy clear rewards.")
	quit(0 if failures.is_empty() else 1)


func _tollkeeper_seeds() -> Dictionary:
	var run := FrontierRun.new()
	var seeds := {}
	for seed_value in range(1, 33):
		var boss: Dictionary = run._make_map(seed_value).back()[0]
		if boss.boss_id == "tollkeeper" and not seeds.has(boss.boss_variant):
			seeds[boss.boss_variant] = seed_value
	return seeds


func _check_route(game: Control, seed_value: int, variant: String) -> void:
	var run: FrontierRun = game.run
	var path := "%s-%d.json" % [save_prefix, seed_value]
	run.load_save(path)
	if not _check(run.start_run(seed_value) and run.choose_hero(run.data.offers[0])
		and run.choose_relic("pocket_bell") and run.choose_starter("bash")
		and run.finish_combat(true, 90) and run.reward("skip"), "Reach the first map for seed %d." % seed_value):
		return
	var preview := run.tollkeeper_preview()
	if not _check(preview.get("variant") == variant, "Keep the seeded boss before any route choice."):
		return
	game.run_resume()
	await process_frame
	var title := game.frontier_screen.find_child("TollkeeperScoutTitle", true, false) as Label
	var hint := game.frontier_screen.find_child("TollkeeperScoutHint", true, false) as Label
	var node := game.frontier_screen.find_child("TollkeeperBossNode", true, false) as Button
	_check(title == null and hint == null and node != null and node.text.contains("Tollkeeper"),
		"The map retains the Tollkeeper route node and leaves attack details to the arena.")
	if not _check(_reach_boss(run), "Travel to the Tollkeeper using the seeded route."):
		return
	var actual := run.encounter()
	_check(actual.get("boss_id") == "tollkeeper" and actual.get("boss_variant") == variant and run.is_final_boss(),
		"Both variants keep the final Tollkeeper identity and pass the saved version into combat.")
	_check(run.load_save(path) and run.encounter() == actual and run.tollkeeper_preview() == preview,
		"Save and resume must keep the predicted fight.")
	game.run_resume()
	var drones: Array = game.sim.units.filter(func(unit: Dictionary): return unit.get("sprite") == "tollkeeper_drone")
	_check(game.campaign and game.encounter_setup and drones.size() == (1 if variant == "repair_drone" else 0),
		"Resuming opens the arena with the saved Tollkeeper lineup.")
	if variant == "repair_drone":
		_check(drones.size() == 1 and GameIcons.enemy_art(drones[0].sprite) != null,
			"The restored drone resolves to its in-game sprite.")
	var marks: int = run.profile.marks
	_check(run.finish_combat(true, 66) and run.profile.medium_unlocked and run.profile.marks == marks + 19
		and run.reward("skip") and run.data.phase == "result", "Both fights grant the normal Easy clear and open Medium.")


func _reach_boss(run: FrontierRun) -> bool:
	for _step in range(30):
		match run.data.phase:
			"map":
				var nodes := run.available_nodes()
				if nodes.is_empty() or not run.choose_node(nodes[0].id):
					return false
			"combat":
				if run.is_final_boss():
					return true
				if not run.finish_combat(true, 90):
					return false
			"reward":
				var elite := run.elite_relic_offers()
				if not elite.is_empty() and not run.choose_elite_relic(elite[0].id):
					return false
				if not run.reward("skip"):
					return false
			"shop", "rest", "event":
				if not run.leave_node():
					return false
			_:
				return false
	return false


func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
	return ok
