extends SceneTree

const Arena := preload("res://arena.tscn")
const ArenaSim := preload("res://scripts/arena_sim.gd")
const FrontierRun := preload("res://scripts/frontier_run.gd")
const ClassDecks := preload("res://scripts/class_decks.gd")

var failures: Array[String] = []
var save_path := "user://party-reward-test-%d.json" % Time.get_ticks_usec()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Arena.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.run.load_save(save_path)
	_check_class_decks()
	await _check_medium_rewards(game)
	game.queue_free()
	await process_frame
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Class decks and party reward controls, inventory, resume, and trophies passed.")
	quit(0 if failures.is_empty() else 1)


func _check_class_decks() -> void:
	var run := FrontierRun.new()
	run.load_save(save_path)
	var distinct_pools := {}
	var seen_by_class := {}
	for class_id: String in FrontierRun.HEROES:
		var common: Array = ClassDecks.common(class_id).duplicate()
		var uncommon: Array = ClassDecks.uncommon(class_id)
		common.sort()
		var key := str(common)
		_check(not distinct_pools.has(key), "%s needs its own Common deck." % class_id)
		distinct_pools[key] = true
		var seen := {}
		for seed_value in range(1, 17):
			if not run.data.is_empty():
				run.abandon_run()
			run.start_run(seed_value)
			run.data.offers = [class_id]
			run.choose_hero(class_id)
			run.choose_relic("pocket_bell")
			run.choose_starter("bash")
			run.finish_combat(true, 95)
			var offers: Array = run.data.offers
			var outside := offers.filter(func(id: String):
				return ArenaSim.TILES[id].get("rarity", "common") == "common" and id != "bash" and id not in common)
			_check(outside.is_empty(), "%s drew a Common outside their deck." % class_id)
			for id: String in offers:
				if id in common or id in uncommon:
					seen[id] = true
		seen_by_class[class_id] = seen
	_check(seen_by_class.size() == 12 and seen_by_class.values().all(func(tiles: Dictionary): return tiles.size() >= 4),
		"All twelve class decks surface several distinct tiles across seeded fights.")
	run.abandon_run()


func _check_medium_rewards(game: Control) -> void:
	var run: FrontierRun = game.run
	run.profile.medium_unlocked = true
	var started := run.start_run(42, "medium")
	if not started:
		_check(false, "The test needs an unlocked Medium route.")
		return
	var offered_class: String = run.data.offers[0]
	game.run_return()
	await _click(game.frontier_screen, "ClassDeck_" + offered_class)
	var dialog: AcceptDialog
	for child in game.frontier_screen.get_children():
		if child is AcceptDialog:
			dialog = child
			break
	_check(dialog != null and dialog.visible and FrontierRun.HEROES[offered_class].label in dialog.title,
		"The class draft's deck button should open the selected class deck.")
	if dialog != null:
		var names := _descendant_buttons(dialog)
		_check(ClassDecks.common(offered_class).all(func(id: String): return names.any(func(label: String):
			return label.begins_with(ArenaSim.TILES[id].label + " "))),
			"The deck inspector displays the Common tiles used for that class's rewards.")
		dialog.confirmed.emit()
		await process_frame
	started = started and run.choose_hero(run.data.offers[0]) and run.choose_relic("pocket_bell")
	started = started and run.choose_starter(run.data.offers[0]) and run.finish_combat(true, 100)
	_check(started, "A seeded solo opening should produce a combat reward.")
	if not started:
		return
	var lead: String = run.data.heroes[0].id
	_check(run.reward_count() == 1 and run.reward_lane() == 0, "The opening reward belongs only to the original hero.")
	var opening_tile: String = run.data.offers[0]
	_check(game.run_claim_reward(opening_tile) and run.data.phase == "map", "Claiming the solo tile should open the route.")
	_enter_boss(run, false)
	_check(run.finish_combat(true, 100) and run.reward_count() == 1, "The Tollkeeper reward must come before the recruit joins.")
	var first_legendary: String = run.data.offers[0]
	_check(ArenaSim.TILES[first_legendary].rarity == "legendary" and game.run_claim_reward(first_legendary)
		and run.data.phase == "recruit", "The original hero earns the first boss tile before recruitment.")
	var lead_tiles: Array = run.loadout.lanes[0].duplicate(true)
	var recruit: String = run.data.offers[0]
	_check(run.choose_recruit(recruit) and run.choose_recruit_starter(run.data.offers[0]), "The second hero joins with one starter tile.")
	_check(run.loadout.lanes[0] == lead_tiles and run.loadout.lanes[0].size() > run.loadout.lanes[1].size()
		and run.loadout.lanes[1].size() == 1, "Recruiting preserves the first hero's head start.")

	var battle := {"id": "party-reward-battle", "row": FrontierRun.NODES_PER_SEGMENT, "column": 0,
		"type": "battle", "label": "Practice Patrol", "next": []}
	run.data.node = battle
	run.data.phase = "combat"
	_check(run.finish_combat(true, [100, 100]) and run.reward_count() == 2
		and run.reward_lane() == 0 and run.reward_position() == 0, "The next victory must offer one reward per hero.")
	var first_offers: Array = run.data.offers.duplicate()
	_check(first_offers.size() == 3, "The original hero sees three choices.")
	# Free both timelines to verify where the real reward buttons place each chosen tile.
	run.loadout.lanes[0].clear()
	run.loadout.lanes[1].clear()
	game.run_return()
	await process_frame
	_check(_reward_header_has(game.frontier_screen, "RewardHero", FrontierRun.HEROES[lead].label)
		and _reward_header_has(game.frontier_screen, "RewardProgress", "1"),
		"The first reward screen identifies the lead hero and pick position.")
	var first_tile: String = first_offers[0]
	await _claim_from_screen(game.frontier_screen, first_tile)
	_check(run.data.phase == "reward" and run.reward_position() == 1 and run.reward_lane() == 1
		and run.loadout.lanes[0].size() == 1 and run.loadout.lanes[0][0].id == first_tile
		and run.loadout.lanes[1].is_empty(), "Claiming the lead's tile equips it in their own lane and advances to the recruit.")
	var second_offers: Array = run.data.offers.duplicate()
	_check(second_offers.size() == 3 and first_offers != second_offers, "The recruit should see a separate set of three class offers.")

	# Reload from disk between the two button presses.
	_check(run.load_save(save_path) and run.reward_count() == 2 and run.reward_position() == 1
		and run.data.offers == second_offers and run.loadout.lanes[0].size() == 1,
		"Resuming midway must retain the recruit's exact cards and the lead's recorded claim.")
	game.run_return()
	await process_frame
	_check(_reward_header_has(game.frontier_screen, "RewardHero", FrontierRun.HEROES[recruit].label)
		and _reward_header_has(game.frontier_screen, "RewardProgress", "2"),
		"The resumed screen identifies the recruit and second pick.")
	var second_tile: String = second_offers[0]
	await _claim_from_screen(game.frontier_screen, second_tile)
	_check(run.data.phase == "map" and run.reward_lane() == -1 and run.loadout.lanes[1].size() == 1
		and run.loadout.lanes[1][0].id == second_tile and not game.run_claim_reward(second_tile),
		"Claiming the recruit's tile equips it only once and opens the route.")

	run.data.node = battle
	run.data.phase = "combat"
	_check(run.finish_combat(true, [100, 0]) and run.reward_count() == 2,
		"A fallen recruit keeps their reward pick for when the party revives them.")
	var gold_before := int(run.data.gold)
	game.run_return()
	await _click(game.frontier_screen, "SkipReward")
	_check(run.reward_lane() == 1 and int(run.data.gold) == gold_before + 6,
		"The lead can skip for gold and the next hero still receives a choice.")
	await _click(game.frontier_screen, "SkipReward")
	_check(run.data.phase == "map" and int(run.data.gold) == gold_before + 6,
		"Skipping both rewards should award the encounter's skip gold only once.")

	run.data.node = battle
	run.data.phase = "combat"
	run.loadout.lanes[0].clear()
	run.loadout.lanes[1].assign([{"id": "slam", "start": 0, "target": "nearest"},
		{"id": "slam", "start": 4, "target": "nearest"}, {"id": "slam", "start": 8, "target": "nearest"}])
	run.loadout.storage.assign([[], [], []])
	_check(run.finish_combat(true, [100, 100]) and game.run_claim_reward("skip") and run.reward_lane() == 1,
		"The test must reach the recruit's reward with their timeline full.")
	var stowed: String = run.data.offers[0]
	_check(game.run_claim_reward(stowed) and run.loadout.lanes[0].is_empty()
		and run.loadout.storage[0].size() == 1 and run.loadout.storage[0][0].id == stowed,
		"When its own timeline is full, a tile reward goes to storage and leaves the other hero's lane alone.")

	_enter_boss(run, true)
	_check(run.finish_combat(true, [100, 100]) and run.reward_count() == 2, "The final boss offers a trophy to both heroes.")
	for hero_id: String in [lead, recruit]:
		var trophy: String = run.data.offers[0]
		_check(ArenaSim.TILES[trophy].rarity == "legendary" and game.run_claim_reward(trophy)
			and run.data.trophies.get(hero_id) == trophy,
			"Each hero receives a Legendary trophy recorded under their own class.")
	_check(run.data.phase == "result" and run.data.trophy == run.data.trophies.get(lead)
		and run.profile.hard_unlocked, "The final pick opens the recap and retains the lead trophy and victory unlock.")


func _enter_boss(run: FrontierRun, final: bool) -> void:
	var row: int = run.data.layers.size() - 1 if final else FrontierRun.NODES_PER_SEGMENT - 1
	run.data.node = run.data.layers[row][0]
	run.data.phase = "combat"


func _reward_header_has(page: Control, node_name: String, copy: String) -> bool:
	var label := page.find_child(node_name, true, false) as Label
	return label != null and label.is_visible_in_tree() and copy in label.text


func _descendant_buttons(node: Node) -> Array[String]:
	var labels: Array[String] = []
	for child in node.get_children():
		if child is Button:
			labels.append(child.text)
		labels.append_array(_descendant_buttons(child))
	return labels


func _claim_from_screen(page: Control, id: String) -> void:
	await _click(page, "RewardTile_" + id)
	await _click(page, "Continue")


func _click(page: Control, node_name: String) -> void:
	await process_frame
	var button := page.find_child(node_name, true, false) as Button
	var clickable := button != null and button.is_visible_in_tree() and not button.disabled
	_check(clickable, "Expected the visible %s button to accept input." % node_name)
	if not clickable:
		return
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
