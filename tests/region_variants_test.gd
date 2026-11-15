extends SceneTree

const Arena := preload("res://arena.tscn")
const ArenaSim := preload("res://scripts/arena_sim.gd")
const FrontierRun := preload("res://scripts/frontier_run.gd")
const GLASS_SEED := 3
const REFRACTION_ENGINE := "glass_refraction_engine"

var failures: Array[String] = []
var save_path := "user://region-variants-test-%d.json" % Time.get_ticks_usec()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Arena.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var run: FrontierRun = game.run
	run.load_save(save_path)
	run.profile.glass_easy_unlocked = true
	if _check(run.start_run(GLASS_SEED, "easy", "glass"), "Start a seeded Glass Foundry expedition."):
		await _check_opening(game, run)
		if _check(_draft_opening(run), "Finish the opening fight and reach the route map."):
			if await _check_reinforcement_fight(game, run):
				await _check_boss(game, run)
	game.queue_free()
	await process_frame
	for profile: String in [save_path, save_path + ".repeat"]:
		for suffix: String in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(profile + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(profile + suffix))
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Glass boss and reinforcement choices passed seed, save, UI, and arena checks.")
	quit(0 if failures.is_empty() else 1)


func _check_opening(game: Control, run: FrontierRun) -> void:
	var preview := run.first_boss_preview()
	game.run_return()
	await process_frame
	var scout := game.frontier_screen.find_child("OpeningBossScout", true, false) as Label
	_check(preview.get("title") == "The Refraction Engine" and scout != null and scout.is_visible_in_tree()
		and scout.text.contains(preview.title) and scout.tooltip_text == preview.description,
		"The opening draft announces the alternate Glass boss and how to face its attack.")
	var repeat := FrontierRun.new()
	repeat.load_save(save_path + ".repeat")
	repeat.profile.glass_easy_unlocked = true
	_check(repeat.start_run(GLASS_SEED, "easy", "glass") and repeat.first_boss_preview() == preview
		and repeat.data.layers == run.data.layers, "The same seed reproduces the Engine and reinforcement node on another profile.")


func _check_reinforcement_fight(game: Control, run: FrontierRun) -> bool:
	var marked: Array[Dictionary] = []
	for layer: Array in run.data.layers:
		for node: Dictionary in layer:
			if node.has("reinforcement_beat"):
				marked.append(node)
	if not _check(marked.size() == 1 and marked[0].type == "battle" and int(marked[0].reinforcement_beat) in [7, 9],
		"The act has one ordinary battle with a visible scheduled reinforcement."):
		return false
	var destination := marked[0]
	if not _reach_adjacent(run, destination):
		return false
	game.run_return()
	await process_frame
	var button := game.frontier_screen.find_child("ReinforcementNode", true, false) as Button
	_check(button != null and button.tooltip_text.contains("beat %d" % int(destination.reinforcement_beat)),
		"The map advertises the reinforcement beat before choosing the battle.")
	if not _press(game.frontier_screen, "ReinforcementNode"):
		return false
	await process_frame
	var options := run.encounter()
	var opening: Array = options.get("formation", [])
	var incoming: Array = options.get("reinforcements", [])
	var stored: Array = run.data.node.get("pilot_formation", []).duplicate(true)
	var arrival := int(options.get("reinforcement_beat", 0))
	if not _check(not opening.is_empty() and incoming.size() == 1 and arrival == int(destination.reinforcement_beat)
		and opening + incoming == stored, "The encounter divides a saved formation into its opening crew and one later arrival."):
		return false
	var preview := game.frontier_screen.find_child("ReinforcementPreview", true, false) as Label
	_check(preview != null and preview.is_visible_in_tree() and preview.text.contains("beat %d" % arrival),
		"The battle briefing exposes the arrival beat separately from the starting formation.")
	_check(run.encounter() == options and run.data.node.pilot_formation == stored,
		"Generating a briefing repeatedly does not consume any of the stored formation.")
	if not _check(run.load_save(save_path) and run.encounter() == options and run.data.node.pilot_formation == stored,
		"Reloading a battle checkpoint preserves both parts of the formation and arrival beat."):
		return false
	game.run_return()
	await process_frame
	if not _press(game.frontier_screen, "Continue"):
		return false
	await process_frame
	var sim: ArenaSim = game.sim
	_check(sim.pending_reinforcement().get("beat") == arrival and _enemies(sim) == _formation_ids(opening),
		"Arena setup spawns the starting enemies and carries the correct arrival warning.")
	for unit: Dictionary in sim.units:
		unit.speed = 0.0
		unit.next_attack = 99999
	for _tick in range(arrival * ArenaSim.TICKS_PER_BEAT - 1):
		sim.step()
	_check(_enemies(sim) == _formation_ids(opening) and not sim.pending_reinforcement().is_empty(),
		"The announced enemy remains off the field until its beat.")
	sim.step()
	_check(_enemies(sim) == _formation_ids(stored) and sim.pending_reinforcement().is_empty(),
		"The saved reinforcement joins on the advertised beat and its warning clears.")
	return _check(_resolve_node(run), "Resolve the reinforcement fight and continue toward the boss.")


func _check_boss(game: Control, run: FrontierRun) -> void:
	var boss: Dictionary = run.data.layers.back()[0]
	if not _reach_adjacent(run, boss):
		return
	game.run_return()
	await process_frame
	var button := game.frontier_screen.find_child("RefractionEngineBossNode", true, false) as Button
	_check(button != null and button.tooltip_text.contains(run.first_boss_preview().description),
		"The Glass map's final boss matches the opening scout and keeps its counter advice.")
	if not _press(game.frontier_screen, "RefractionEngineBossNode"):
		return
	await process_frame
	if not _check(run.load_save(save_path) and run.encounter().get("boss_id") == REFRACTION_ENGINE and run.is_final_boss(),
		"The alternate final boss remains selected when resuming at its battle."):
		return
	game.run_return()
	await process_frame
	if not _press(game.frontier_screen, "Continue"):
		return
	await process_frame
	_check(_enemies(game.sim) == [REFRACTION_ENGINE], "The battle launches the announced Engine instead of the Crucible Twins.")
	var before := int(run.profile.marks)
	_check(run.finish_combat(true, 65) and run.profile.glass_medium_unlocked and int(run.profile.marks) == before + 19
		and run.reward("skip") and run.data.result == "victory", "The alternate boss pays the normal Glass Easy clear reward and opens Medium.")


func _draft_opening(run: FrontierRun) -> bool:
	return run.choose_hero(run.data.offers.front()) and run.choose_relic(run.data.offers.front()) \
		and run.choose_starter(run.data.offers.front()) and _resolve_node(run)


func _resolve_node(run: FrontierRun) -> bool:
	if run.data.phase != "combat":
		return run.leave_node()
	if not run.finish_combat(true, 85):
		return false
	var relics := run.elite_relic_offers()
	if not relics.is_empty() and not run.choose_elite_relic(relics.front().id):
		return false
	return run.reward("skip")


func _reach_adjacent(run: FrontierRun, destination: Dictionary) -> bool:
	var path := _path_to(run.data.node, destination, run.data.layers)
	if not _check(not path.is_empty(), "Find a playable route to %s." % destination.label):
		return false
	for id: String in path.slice(0, path.size() - 1):
		if not _check(run.choose_node(id) and _resolve_node(run), "Continue along the route at node %s." % id):
			return false
	return true


func _path_to(node: Dictionary, destination: Dictionary, layers: Array) -> Array:
	if int(node.row) + 1 == int(destination.row):
		return [destination.id] if destination.id in node.next else []
	if int(node.row) >= int(destination.row):
		return []
	for candidate: Dictionary in layers[int(node.row) + 1]:
		if candidate.id in node.next:
			var route := _path_to(candidate, destination, layers)
			if not route.is_empty():
				return [candidate.id] + route
	return []


func _enemies(sim: ArenaSim) -> Array:
	return sim.units.filter(func(unit: Dictionary): return unit.side == "enemy") \
		.map(func(unit: Dictionary): return unit.attack_id)


func _formation_ids(formation: Array) -> Array:
	return formation.map(func(entry: Dictionary): return entry.id)


func _press(parent: Control, node_name: String) -> bool:
	var button := parent.find_child(node_name, true, false) as Button
	if not _check(button != null and button.is_visible_in_tree() and not button.disabled,
		"Expected the enabled %s button." % node_name):
		return false
	button.pressed.emit()
	return true


func _check(condition: bool, description: String) -> bool:
	if not condition:
		failures.append(description)
	return condition
