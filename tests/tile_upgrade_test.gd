extends SceneTree

const Arena := preload("res://arena.tscn")
const ArenaSim := preload("res://scripts/arena_sim.gd")
const FrontierRun := preload("res://scripts/frontier_run.gd")
const TilePacking := preload("res://scripts/tile_packing.gd")
const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]

var failures: Array[String] = []
var save_path := "user://tile-upgrade-test-%d.json" % Time.get_ticks_usec()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_paths()
	if failures.is_empty():
		_check_upgraded_attack()
	var game = Arena.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.run.load_save(save_path)
	await _check_reward_combine(game)
	await _check_distributed_storage(game)
	game.queue_free()
	await process_frame
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Tile upgrade paths, upgraded combat, split storage, and reward combine with save and resume passed.")
	quit(0 if failures.is_empty() else 1)


func _check_paths() -> void:
	for id: String in ArenaSim.TILES:
		var source: Dictionary = ArenaSim.TILES[id]
		var tier := RARITIES.find(source.get("rarity", "common"))
		var choices := TilePacking.next_options(id)
		if tier == RARITIES.size() - 1:
			_check(choices.is_empty(), "%s is already Legendary." % id)
			continue
		var pair_is_valid: bool = tier >= 0 and choices.size() == 2 and choices[0] != choices[1]
		_check(pair_is_valid, "%s needs exactly two distinct next-tier choices." % id)
		if not pair_is_valid:
			continue
		for choice: String in choices:
			var upgraded: Dictionary = ArenaSim.TILES.get(choice, {})
			_check(upgraded.get("rarity") == RARITIES[tier + 1],
				"%s must advance by one rarity from %s." % [choice, id])
			_check(not upgraded.is_empty() and upgraded.width <= source.width * 3,
				"%s must fit where three touching copies of %s fit." % [choice, id])
		_check(TilePacking.next_options(choices[0]) == TilePacking.next_options(choices[1]),
			"%s's two branches should offer the same pair one rarity later." % id)


func _check_upgraded_attack() -> void:
	var upgrade_id: String = TilePacking.next_options("iron_arc")[0]
	var spec: Dictionary = ArenaSim.TILES[upgrade_id]
	var sim := ArenaSim.new()
	sim.start([[_tile(upgrade_id, 0)]], "solo", {"encounter": "opening", "heroes": [{"hero": "warden"}]})
	var hero: Dictionary = sim.units[0]
	var foe: Dictionary = sim.units[1]
	hero.speed = 0.0
	foe.speed = 0.0
	foe.next_attack = 99999
	foe.pos = hero.pos + Vector2(90, 0)
	foe.prev_pos = foe.pos
	hero.guard = 1
	foe.hp = 200
	foe.max_hp = 200
	var firing_tick: int = spec.width * ArenaSim.TICKS_PER_BEAT
	for tick in range(firing_tick - 1):
		sim.step()
	_check(sim.activations.is_empty(), "An upgraded tile still waits for its right edge.")
	sim.step()
	_check(sim.activations.size() == 1 and sim.activations[0].tile == upgrade_id
		and int(sim.activations[0].damage) == int(spec.damage) + int(spec.get("guard_bonus", 0)),
		"An upgraded Iron Arc retains and applies its listed Guard bonus.")


func _check_reward_combine(game: Control) -> void:
	var run: FrontierRun = game.run
	run.profile.medium_unlocked = true
	var started := run.start_run(42, "medium")
	if started:
		run.data.offers = ["warden"]
		started = (run.choose_hero("warden") and run.choose_relic("pocket_bell")
			and run.choose_starter("shield_tap") and run.finish_combat(true, 100) and run.reward("skip"))
	if started:
		run.data.node = run.data.layers[FrontierRun.NODES_PER_SEGMENT - 1][0]
		run.data.phase = "combat"
		started = run.finish_combat(true, 100) and run.reward("skip") and run.choose_boss_relic("skip")
	if started:
		var recruit: String = run.data.offers[0]
		started = run.choose_recruit(recruit) and run.choose_recruit_starter(run.data.offers[0])
	_check(started, "A new Medium run must reach a two-hero combat draft.")
	if not started:
		return

	# There is a copy on each hero, but only the reward recipient and shared storage may contribute.
	var source := "iron_arc"
	run.loadout.lanes[0] = [_tile(source, 0, "farthest"), _tile("worldbreaker", 4),
		_tile("jab", 9), _tile("shield_tap", 10)]
	run.loadout.lanes[1] = [_tile(source, 0, "lowest_hp")]
	run.loadout.storage = [[_tile(source, 0), _tile("slam", 4)],
		[_tile("slam", 0), _tile("slam", 4)], [_tile("slam", 0), _tile("slam", 4)]]
	run.data.node = {"id": "tile-upgrade-patrol", "row": FrontierRun.NODES_PER_SEGMENT,
		"column": 0, "type": "battle", "label": "Upgrade test patrol", "next": []}
	run.data.phase = "combat"
	var rewarded: bool = run.finish_combat(true, [100, 100]) and source in run.data.offers
	_check(rewarded, "A regular victory must offer the held pair's third copy.")
	if not rewarded:
		return
	var before: Dictionary = run.loadout.duplicate(true)
	var next_hero_offers: Array = run.data.reward_remaining[0].offers.duplicate()
	game.run_return()
	await _click(game.frontier_screen, "RewardTile_" + source)
	await _click(game.frontier_screen, "Continue")
	_check(game.forge_screen.visible and game.forge_screen._source_id == source
		and run.reward_lane() == 0 and run.loadout == before,
		"A third copy can open the upgrade picker with no room for the original tile.")
	if not game.forge_screen.visible:
		return

	var keep := game.forge_screen.find_child("KeepRewardTile", true, false) as Button
	_check(keep != null and keep.disabled and not game.run_claim_reward("skip"),
		"A full inventory cannot keep the source tile, and the pending choice cannot be bypassed.")
	await _click(game.forge_screen, "BackFromForge")
	_check(not game.forge_screen.visible and run.reward_lane() == 0 and source in run.data.offers and run.loadout == before,
		"Backing out keeps the source reward available and consumes nothing.")
	await _click(game.frontier_screen, "RewardTile_" + source)
	await _click(game.frontier_screen, "Continue")
	await _click(game.forge_screen, "SaveRewardCombine")
	_check(game.frontier_screen.visible and not game.forge_screen.visible,
		"Save and title exits the upgrade picker while preserving the reward.")
	_check(run.load_save(save_path) and run.reward_lane() == 0 and run.loadout == before,
		"An unconfirmed reward combine is saved separately from inventory.")
	game.run_resume()
	_check(game.forge_screen.visible and game.forge_screen._source_id == source,
		"Continuing a saved run reopens the pending upgrade choice.")
	if not game.forge_screen.visible:
		return

	var choice: String = TilePacking.next_options(source)[0]
	game.forge_choose(choice)
	_check(run.reward_lane() == 1 and run.data.offers == next_hero_offers and not game.forge_screen.visible,
		"Confirming the upgrade spends exactly one reward and restores the second hero's draft.")
	_check(run.loadout.lanes[0].filter(func(tile: Dictionary): return tile.id == choice).size() == 1
		and not run.loadout.lanes[0].any(func(tile: Dictionary): return tile.id == source)
		and not run.loadout.storage[0].any(func(tile: Dictionary): return tile.id == source)
		and run.loadout.lanes[1] == before.lanes[1],
		"Confirming consumes exactly the reward recipient's and shared storage copies.")
	_check(run.load_save(save_path) and run.reward_lane() == 1 and run.data.offers == next_hero_offers
		and run.loadout.lanes[0].any(func(tile: Dictionary): return tile.id == choice),
		"The chosen upgrade and next hero's draft survive a second reload.")


func _check_distributed_storage(game: Control) -> void:
	game.run_practice()
	var source := "runic_anvil"
	var choices := TilePacking.next_options(source)
	if choices.is_empty():
		return
	var choice: String = choices[1]
	var kept_tile := _tile("jab", 0)
	game.lanes = [[_tile(source, 0)], []]
	game.storage_rows = [[_tile(source, 1), kept_tile], [_tile(source, 0)], []]
	game.storage_rows[0].sort_custom(func(a: Dictionary, b: Dictionary): return a.start < b.start)
	game._open_storage()
	game.storage_pick(1, game.storage_rows[1][0])
	await _click(game.storage_screen, "CombineSelected")
	_check(game.forge_screen.visible and game.forge_screen._source_id == source,
		"The storage popup can combine three five-wide tiles across two rows and the timeline.")
	if not game.forge_screen.visible:
		return
	game.forge_choose(choice)
	var upgrade_count := 0
	var original_count := 0
	for row: Array in game.lanes + game.storage_rows:
		for tile: Dictionary in row:
			upgrade_count += int(tile.id == choice)
			original_count += int(tile.id == source)
	_check(game.storage_screen.visible and upgrade_count == 1 and original_count == 0
		and kept_tile in game.storage_rows[0] and ArenaSim.TILES[choice].rarity == "rare",
		"Distributed storage combine grants one Rare, consumes the three matches, and keeps other tiles.")


func _tile(id: String, start: int, target := "nearest") -> Dictionary:
	return {"id": id, "start": start, "target": target}


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
