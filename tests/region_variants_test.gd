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
	await _check_compact_map(game, run)
	game.queue_free()
	await process_frame
	for profile: String in [save_path, save_path + ".repeat", save_path + ".map"]:
		for suffix: String in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(profile + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(profile + suffix))
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Glass boss and reinforcement choices and compact route layout passed.")
	quit(0 if failures.is_empty() else 1)


func _check_opening(game: Control, run: FrontierRun) -> void:
	var preview := run.first_boss_preview()
	game.run_return()
	await process_frame
	var scout := game.frontier_screen.find_child("OpeningBossScout", true, false) as Label
	_check(preview.get("title") == "The Refraction Engine" and scout == null,
		"The seeded alternate Glass boss remains assigned without an opening scout panel.")
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
	_check(game.campaign and game.encounter_setup and game.arena_screen.is_visible_in_tree(),
		"Choosing the reinforcement node opens battle setup directly.")
	_check(run.encounter() == options and run.data.node.pilot_formation == stored,
		"Reading the encounter repeatedly does not consume any of the stored formation.")
	if not _check(run.load_save(save_path) and run.encounter() == options and run.data.node.pilot_formation == stored,
		"Reloading a battle checkpoint preserves both parts of the formation and arrival beat."):
		return false
	game.run_return()
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
	_check(button != null and button.text.contains("Refraction Engine"),
		"The Glass map keeps the assigned Refraction Engine boss node.")
	if not _press(game.frontier_screen, "RefractionEngineBossNode"):
		return
	await process_frame
	if not _check(run.load_save(save_path) and run.encounter().get("boss_id") == REFRACTION_ENGINE and run.is_final_boss(),
		"The alternate final boss remains selected when resuming at its battle."):
		return
	game.run_return()
	await process_frame
	_check(game.campaign and game.encounter_setup and _enemies(game.sim) == [REFRACTION_ENGINE],
		"Resuming opens the Refraction Engine battle directly.")
	var before := int(run.profile.marks)
	_check(run.finish_combat(true, 65) and run.profile.glass_medium_unlocked and int(run.profile.marks) == before + 19
		and run.reward("skip") and run.data.result == "victory", "The alternate boss pays the normal Glass Easy clear reward and opens Medium.")


func _check_compact_map(game: Control, run: FrontierRun) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(856, 535)
	run.load_save(save_path + ".map")
	if not _check(run.start_run(66381030, "easy", "brass") and _draft_opening(run), "Enter the playtest route on a fresh profile."):
		return
	var destination: Dictionary
	for layer: Array in run.data.layers:
		for node: Dictionary in layer:
			if node.type == "elite":
				destination = node
				break
		if not destination.is_empty():
			break
	if not _check(not destination.is_empty(), "The playtest route contains an elite.") or not _reach_adjacent(run, destination):
		return
	game.run_return()
	await process_frame
	await process_frame
	var board := game.frontier_screen.find_child("ExpeditionMapBoard", true, false) as Control
	var elite := _reachable_button(board, destination.label)
	if not _check(elite != null, "The reachable elite is a usable button at the compact size."):
		return
	var before := elite.get_global_rect()
	var board_before := board.get_global_rect()
	elite.mouse_entered.emit()
	elite.grab_focus()
	await process_frame
	_check(elite.get_global_rect() == before and board.get_global_rect() == board_before,
		"Mouse and keyboard focus keep the elite and map under the player’s pointer.")
	run.data.relics = FrontierRun.RELICS.keys()
	run.data.node_notice = "Relic acquired. ".repeat(24)
	run.loadout.storage[1] = [{"id": "triage_kit", "start": 0, "target": "ally_lowest"}]
	run.data.reward_placement = {"id": "triage_kit", "row": 1, "start": 0}
	game.run_return()
	await process_frame
	await process_frame
	board = game.frontier_screen.find_child("ExpeditionMapBoard", true, false) as Control
	var footer := game.frontier_screen.find_child("ExpeditionMapFooter", true, false) as Control
	var key := game.frontier_screen.find_child("RouteKey", true, false) as Control
	var status := game.frontier_screen.find_child("RouteDetails", true, false) as ScrollContainer
	var storage := footer.find_child("OpenRewardStorage", true, false) as Button
	var viewport := game.get_viewport_rect()
	_check(board.get_global_rect() == board_before, "Relic history and a reward receipt keep the route board at the same size.")
	_check(storage != null and viewport.encloses(storage.get_global_rect()) and viewport.encloses(footer.get_global_rect())
		and viewport.encloses(key.get_global_rect()), "The route key, reward receipt, and footer actions fit in the compact viewport.")
	_check(status.get_v_scroll_bar().visible, "Overflowing route details can scroll independently.")
	var occupied: Array[Rect2] = []
	for child: Node in board.get_children():
		if child is Button:
			var rect: Rect2 = child.get_global_rect()
			_check(board.get_global_rect().encloses(rect), "All route buttons fit within the map board.")
			_check(not occupied.any(func(other: Rect2): return rect.intersects(other)), "Route buttons do not overlap at the compact size.")
			occupied.append(rect)
	elite = _reachable_button(board, destination.label)
	if _check(elite != null and elite.get_global_rect() == before, "The elite remains reachable at the same position after long notices."):
		elite.pressed.emit()
		_check(run.data.phase == "combat" and run.data.node.id == destination.id, "The elite opens on the first press.")


func _reachable_button(board: Control, label: String) -> Button:
	for child: Node in board.get_children():
		if child is Button and not child.disabled and child.text == label:
			return child
	return null


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
