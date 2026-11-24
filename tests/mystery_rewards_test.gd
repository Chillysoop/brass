extends SceneTree

const Arena := preload("res://arena.tscn")
const ArenaSim := preload("res://scripts/arena_sim.gd")
const ClassDecks := preload("res://scripts/class_decks.gd")
const FrontierRun := preload("res://scripts/frontier_run.gd")
const TilePacking := preload("res://scripts/tile_packing.gd")
const EASY_SEED := 42
const MYSTERIES := {
	"salvage_bench": "Salvage Bench",
	"traveling_smith": "Traveling Smith",
	"class_cache": "Class Cache",
}

var failures: Array[String] = []
var save_path := "user://mystery-rewards-test-%d.json" % Time.get_ticks_usec()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_routes()
	_check_event_costs()
	var game = Arena.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	await _compare_rewards(game)
	game.queue_free()
	await process_frame
	for path in [save_path, save_path + ".costs", save_path + ".control", save_path + ".salvage_bench",
			save_path + ".traveling_smith", save_path + ".class_cache"]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Act I mystery routes and three distinct Warden timelines passed from seed %d." % EASY_SEED)
	quit(0 if failures.is_empty() else 1)


func _check_event_costs() -> void:
	var run := FrontierRun.new()
	run.load_save(save_path + ".costs")
	if not _check(run.start_run(2197832764) and run.choose_hero(run.data.offers.front())
		and run.choose_relic(run.data.offers.front()) and run.choose_starter(run.data.offers.front()),
		"Open the route from the Jammed Crane playtest."):
		return
	run.data.phase = "event"
	run.data.node = run._node("event", "Jammed Crane", 1, 0)
	run.data.heroes[0].hp = 93
	run.data.heroes[0].max_hp = 108
	run._sync_lead_hero()
	_check(str(run.event_options()[1]).contains("40% take 11 damage") and run.event_choice(1)
		and run.data.hp == 82 and run.data.max_hp == 108 and run.data.node_notice.contains("Took 11 damage"),
		"The crane shows the exact damage for the playtest seed and leaves maximum HP intact.")
	run.data.phase = "event"
	run.data.node = run._node("event", "Relay Auction", 1, 0)
	run.data.relics = ["stepped_gear", "afterimage"]
	_check(str(run.event_options()[1]).contains("Trade Stepped Gear") and run.event_choice(1)
		and run.data.relics == ["afterimage"], "The auction names the exact relic that is removed.")


func _check_routes() -> void:
	var run := FrontierRun.new()
	var seen := {}
	for difficulty: String in ["easy", "medium", "hard"]:
		for seed in range(1, 25):
			var layers := run._make_map(seed, difficulty, "brass")
			var sites := _mystery_nodes(layers)
			if not _check(sites.size() == 1 and sites[0].row < FrontierRun.NODES_PER_SEGMENT - 1
				and _can_reach(layers, sites[0]), "Each new Brass route has one reachable mystery reward before the Tollkeeper."):
				return
			seen[sites[0].label] = true
	_check(seen.size() == 3, "Varying the seed must expose all three build rewards.")
	_check(run._make_map(EASY_SEED, "easy", "brass") == run._make_map(EASY_SEED, "easy", "brass"),
		"Reusing the same seed must produce the same mystery.")
	for location: String in ["glass", "crown", "moonwreck"]:
		_check(_mystery_nodes(run._make_map(EASY_SEED, "hard", location)).is_empty(), "Keep these mystery rewards in Brass Frontier.")


func _mystery_nodes(layers: Array) -> Array:
	var sites := []
	for layer: Array in layers:
		for node: Dictionary in layer:
			if node.type == "event" and node.label in MYSTERIES.values():
				sites.append(node)
	return sites


func _can_reach(layers: Array, destination: Dictionary) -> bool:
	var next: Array = layers[0][0].next
	for index in range(1, destination.row):
		var reachable := []
		for node: Dictionary in layers[index]:
			if node.id in next:
				reachable.append_array(node.next)
		next = reachable
	return destination.id in next


func _compare_rewards(game: Control) -> void:
	var run: FrontierRun = game.run
	run.load_save(save_path)
	if not _check(run.start_run(EASY_SEED, "easy", "brass") and run.choose_hero("warden")
		and run.choose_relic("pocket_bell") and run.choose_starter("bash"), "Draft the same Warden and starter for each branch."):
		return
	if not _check(_win_battle(run) and "bash" in run.data.offers and game.run_claim_reward("bash"),
		"Win the real opening fight and take its Bash offer to start with a pair."):
		return
	var sites := _mystery_nodes(run.data.layers)
	if not _check(sites.size() == 1, "The saved Easy run includes the seeded mystery reward."):
		return
	var destination: Dictionary = sites[0]
	if not _check(_reach_mystery(run, destination), "Reach the seeded mystery through a legal branch from the opening battle."):
		return
	var inventory: Dictionary = run.loadout.duplicate(true)
	var gold: int = run.data.gold
	var health: int = run.data.hp
	var relics: Array = run.data.relics.duplicate()
	var timelines := {}
	for branch: String in ["control"] + MYSTERIES.keys():
		if not _check(run.load_save(save_path), "Reload the common pre-reward checkpoint."):
			return
		run.save_path = save_path + "." + branch
		# Change the event at the same saved node to isolate the effect of its reward.
		run.data.node.label = MYSTERIES.get(branch, MYSTERIES.salvage_bench)
		if not _check(run.save() and run.load_save(run.save_path), "Resume this branch inside the mystery encounter."):
			return
		game.run_resume()
		var gained := ""
		match branch:
			"control":
				if not await _press(game.frontier_screen, "LeaveMystery"):
					return
				_check(run.loadout == inventory, "Leaving the encounter preserves the original two-Bash inventory.")
			"salvage_bench": gained = await _claim_salvage(game)
			"traveling_smith": gained = await _claim_smith(game)
			"class_cache": gained = await _claim_cache(game)
		if not _check(run.data.phase == "map" and run.data.gold == gold and run.data.hp == health and run.data.relics == relics,
			"The reward or leave action has no cost in gold, health, or relics. " + branch):
			return
		var expected := run.loadout.duplicate(true)
		_check(run.load_save(run.save_path) and run.loadout == expected, "Reload the applied reward and the resulting timeline. " + branch)
		if not _check(_reach_boss(run), "The build can reach the same Tollkeeper checkpoint. " + branch):
			return
		var ids: Array = run.loadout.lanes[0].map(func(tile: Dictionary): return tile.id)
		if branch != "control":
			_check(not gained.is_empty() and gained in ids, "The mystery reward is still equipped at the Tollkeeper. " + branch)
		timelines[str(ids)] = true
		print("Warden seed %d, %s before the Tollkeeper: %s" % [EASY_SEED, branch, str(ids)])
	_check(timelines.size() == 4, "Each reward yields a different timeline than the other rewards and leaving.")


func _claim_salvage(game: Control) -> String:
	var run: FrontierRun = game.run
	if not await _press(game.frontier_screen, "MysterySalvageOpen"):
		return ""
	_check(run.data.offers == ["bash"], "Salvage offers only the owned Common tile, with duplicate IDs collapsed.")
	_check(game.action_menu.content.find_child("RerollReward", true, false) == null, "Mystery tile choices cannot be rerolled for gold.")
	if not await _press(game.frontier_screen, "RewardTile_bash"):
		return ""
	if not _check(game.forge_screen.visible and run.load_save(run.save_path), "The copied Bash opens and saves a three-copy forge choice."):
		return ""
	game.run_resume()
	if not _check(game.forge_screen.visible, "Continuing a saved Salvage Bench copy reopens the forge."):
		return ""
	var pick: String = TilePacking.next_options("bash")[1]
	game.forge_choose(pick)
	_check(run.loadout.lanes[0].size() == 1 and run.loadout.lanes[0][0].id == pick,
		"Salvage uses two owned copies and the free copy to make one upgraded tile.")
	return pick


func _claim_smith(game: Control) -> String:
	var run: FrontierRun = game.run
	if not await _press(game.frontier_screen, "MysterySmithOpen"):
		return ""
	var source: Dictionary = run.loadout.lanes[0][1]
	game._select({"id": source.id, "lane": 0, "start": source.start})
	if not await _press(game.storage_screen, "StorageForgeSelected"):
		return ""
	var options := TilePacking.next_options("bash")
	if not _check(game.forge_screen.visible and game.forge_can_fit(options[0]) and game.forge_can_fit(options[1]),
		"The Traveling Smith opens both one-tier forge branches."):
		return ""
	var pick: String = options[0]
	game.forge_choose(pick)
	var lane: Array = run.loadout.lanes[0]
	_check(lane.size() == 2 and lane[0].id == "bash" and lane[1].id == pick and lane[1].start == source.start,
		"The Traveling Smith replaces only the chosen tile at its original timeline position.")
	return pick


func _claim_cache(game: Control) -> String:
	var run: FrontierRun = game.run
	if not await _press(game.frontier_screen, "MysteryCategory_support"):
		return ""
	var offers: Array = run.data.offers.duplicate()
	if not _check(not offers.is_empty() and offers.all(func(id: String):
		return id in ClassDecks.uncommon("warden") and ArenaSim.TILES[id].get("rarity") == "uncommon"),
		"The chosen cache category drafts Uncommons from Warden’s class deck."):
		return ""
	_check(run.load_save(run.save_path) and run.data.offers == offers, "The chosen cache category and offers survive reload.")
	game.run_resume()
	var pick: String = offers[0]
	await process_frame
	var reward_card := game.frontier_screen.find_child("DragReward_" + pick, true, false) as Control
	if not _check(reward_card != null and reward_card.is_visible_in_tree() and not game.storage_screen.is_visible_in_tree()
		and game.storage_screen._docked and game.storage_screen.get_parent() == game.reward_storage_drawer
		and game.storage_button.is_visible_in_tree() and game.arena.units.is_empty(),
		"Mystery tile rewards keep full-width drag placement and a collapsed storage drawer in an empty arena."):
		return ""
	await _click_at(game.storage_button.get_global_rect().get_center())
	_check(game.storage_screen.is_visible_in_tree(), "The top-right storage control opens the mystery reward drawer.")
	await _click_at(game.storage_button.get_global_rect().get_center())
	await _drag_reward(game, pick, 4)
	var ids: Array = run.loadout.lanes[0].map(func(tile: Dictionary): return tile.id)
	_check(ids == ["bash", "bash", pick], "The Class Cache equips the chosen Uncommon beside the two owned copies.")
	return pick


func _reach_mystery(run: FrontierRun, destination: Dictionary) -> bool:
	while run.data.node.id != destination.id:
		var path := _route_to(run.data.layers, run.data.node, destination)
		if path.is_empty() or not run.choose_node(path[0]):
			return false
		if run.data.node.id != destination.id and not _resolve_travel(run):
			return false
	return run.data.phase == "event"


func _route_to(layers: Array, current: Dictionary, destination: Dictionary) -> Array:
	if current.row >= destination.row:
		return []
	for node: Dictionary in layers[int(current.row) + 1]:
		if node.id not in current.next:
			continue
		if node.id == destination.id:
			return [node.id]
		var tail := _route_to(layers, node, destination)
		if not tail.is_empty():
			return [node.id] + tail
	return []


func _reach_boss(run: FrontierRun) -> bool:
	for _step in range(FrontierRun.NODES_PER_SEGMENT):
		var nodes := run.available_nodes()
		if nodes.is_empty():
			return false
		var ordinary := nodes.filter(func(node: Dictionary): return node.type in ["battle", "shop", "rest", "boss"])
		var node: Dictionary = nodes[0] if ordinary.is_empty() else ordinary[0]
		if not run.choose_node(node.id):
			return false
		if node.type == "boss":
			return run.encounter().get("boss_id") == "tollkeeper"
		if not _resolve_travel(run):
			return false
	return false


func _resolve_travel(run: FrontierRun) -> bool:
	match run.data.phase:
		"combat":
			if not _win_battle(run):
				return false
			var elite := run.elite_relic_offers()
			if not elite.is_empty() and not run.choose_elite_relic(elite[0].id):
				return false
			return run.reward("skip")
		"event": return run.leave_node()
		"shop": return run.leave_node()
		"rest": return run.rest("heal")
	return false


func _win_battle(run: FrontierRun) -> bool:
	var sim := ArenaSim.new()
	sim.start(run.loadout.lanes, "solo", run.encounter())
	while sim.tick < 3500 and sim.outcome.is_empty():
		sim.step()
	return sim.outcome == "victory" and run.finish_combat(true, sim.units[0].hp)


func _press(page: Control, node_name: String) -> bool:
	await process_frame
	var search: Node = page
	var button: Button
	while button == null and search != null:
		button = search.find_child(node_name, true, false) as Button
		search = search.get_parent()
	if button != null and not button.is_visible_in_tree():
		var menu: Node = button.get_parent()
		while menu != null and not menu.has_method("is_open"):
			menu = menu.get_parent()
		if menu != null and not menu.is_open():
			var trigger: Button = menu.get("trigger")
			if not _check(trigger.is_visible_in_tree(), "The game menu trigger is visible before opening a mystery utility action."):
				return false
			await _click_at(trigger.get_global_rect().get_center())
	if not _check(button != null and button.is_visible_in_tree() and not button.disabled,
		"The %s button accepts input." % node_name):
		return false
	await _click_at(button.get_global_rect().get_center())
	return true


func _click_at(at: Vector2) -> void:
	for down: bool in [true, false]:
		_push_mouse_button(at, down)
	await process_frame
	await process_frame


func _drag_reward(game: Control, id: String, start: int) -> void:
	var card := game.frontier_screen.find_child("DragReward_" + id, true, false) as Control
	var details := card.find_child("ChoiceDetails", true, false) as Control
	var source := details.get_global_rect().get_center()
	var board := game.lane_stack.get_child(0).get_child(1) as Control
	var target := board.global_position + Vector2(board.size.x * (start + 0.5) / ArenaSim.BEATS, board.size.y * 0.5)
	var threshold := source + Vector2(18, 0)
	_push_mouse_motion(source, source, false)
	_push_mouse_button(source, true)
	_push_mouse_motion(source, threshold, true)
	_push_mouse_motion(threshold, target, true)
	_check(root.gui_is_dragging(), "Dragging the Class Cache reward body carries its tile.")
	_push_mouse_button(target, false)
	await process_frame
	await process_frame


func _push_mouse_button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	root.push_input(event, true)


func _push_mouse_motion(from: Vector2, to: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.relative = to - from
	if held:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)


func _check(ok: bool, description: String) -> bool:
	if not ok and description not in failures:
		failures.append(description)
	return ok
