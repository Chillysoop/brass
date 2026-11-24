extends SceneTree

const Arena := preload("res://arena.tscn")
const ArenaSim := preload("res://scripts/arena_sim.gd")
const FrontierRun := preload("res://scripts/frontier_run.gd")
const TilePacking := preload("res://scripts/tile_packing.gd")
const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
const TILE_TUNING := [
	"base_tile", "damage", "description", "family", "forge_name", "icon", "label", "range",
	"rarity", "short_label", "targets", "upgrade_path", "width",
]
const COMBAT_COUNTS := ["chorus_echo_charges", "collision_chain_hops", "convergence_targets", "rune_quick_hits"]

var failures: Array[String] = []
var save_path := "user://tile-upgrade-test-%d.json" % Time.get_ticks_usec()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_paths()
	_check_forge_ranks()
	if failures.is_empty():
		_check_upgraded_attack()
		_check_generated_burn()
	var game = Arena.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.run.load_save(save_path)
	await _check_reward_combine(game)
	await _check_reward_copy_pips(game)
	await _check_enchanted_tile_movement(game)
	await _check_distributed_storage(game)
	await _check_alternate_copies(game)
	await _check_authored_forge_choices(game)
	await _check_assisted_camp_forge(game)
	game.queue_free()
	await process_frame
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Tile upgrade paths, upgraded combat, enchantment storage, and reward combine with save and resume passed.")
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


func _check_forge_ranks() -> void:
	for family: String in ArenaSim.FORGE_FAMILIES:
		var names := {}
		var previous: Array = []
		for tier: Array in ArenaSim.FORGE_FAMILIES[family]:
			if tier.is_empty():
				continue
			for id: String in tier:
				var tile: Dictionary = ArenaSim.TILES[id]
				var name: String = tile.get("forge_name", tile.label)
				_check(not name.is_empty() and not names.has(name),
					"%s repeats the forge name %s in the %s family." % [id, name, family])
				names[name] = true
				# Core tiles also implement effects in their dedicated cast methods.
				if not ArenaSim.CORE_FORGE_FAMILIES.has(family):
					for source: String in previous:
						_check(_adds_combat_effect(ArenaSim.TILES[source], tile),
							"%s only changes tuning when upgraded from %s." % [id, source])
			previous = tier


func _adds_combat_effect(source: Dictionary, upgraded: Dictionary) -> bool:
	for field: String in upgraded:
		if field in TILE_TUNING:
			continue
		var value: Variant = upgraded[field]
		if not source.has(field):
			return true
		if (value is String or value is bool or field in COMBAT_COUNTS) and value != source[field]:
			return true
	return false


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


func _check_generated_burn() -> void:
	var id: String = TilePacking.forge_tiers("snap_shot")[3][0]
	var sim := ArenaSim.new()
	sim.start([[_tile(id, 0)]], "solo", {"encounter": "opening", "heroes": [{"hero": "warden"}]})
	var hero: Dictionary = sim.units[0]
	var foe: Dictionary = sim.units[1]
	hero.speed = 0.0
	foe.speed = 0.0
	foe.next_attack = 99999
	foe.pos = hero.pos + Vector2(240, 0)
	foe.prev_pos = foe.pos
	foe.hp = 200
	foe.max_hp = 200
	for tick in range(ArenaSim.TICKS_PER_BEAT - 1):
		sim.step()
	_check(foe.get("ember_burns", {}).is_empty(), "Incendiary Snap Shot cannot apply Burn before its edge.")
	sim.step()
	var health: int = foe.hp
	_check(foe.get("ember_burns", {}).has(hero.id), "Incendiary Snap Shot ignites a stationary enemy on hit.")
	for tick in range(ArenaSim.TICKS_PER_BEAT):
		sim.step()
	_check(int(foe.hp) == health - int(ArenaSim.TILES[id].ember_burn_damage),
		"Incendiary Snap Shot's Burn removes its listed damage a beat after the hit.")


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
	run.data.enchantment = "guarded"
	run.loadout.storage[0][0].enchantment = "guarded"
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
	await _click(game.forge_screen, str(game.forge_screen._cards[choice].name))
	_check(run.reward_lane() == 1 and run.data.offers == next_hero_offers and not game.forge_screen.visible,
		"Confirming the upgrade spends exactly one reward and restores the second hero's draft.")
	_check(game.showing_rewards and game.frontier_screen.is_visible_in_tree()
		and game.frontier_screen.find_child("RewardTile_" + str(next_hero_offers[0]), true, false) != null,
		"A fitting reward upgrade immediately displays the next hero's pick without an intervening Continue screen.")
	_check(run.loadout.lanes[0].filter(func(tile: Dictionary): return tile.id == choice).size() == 1
		and not run.loadout.lanes[0].any(func(tile: Dictionary): return tile.id == source)
		and not run.loadout.storage[0].any(func(tile: Dictionary): return tile.id == source)
		and run.loadout.lanes[1] == before.lanes[1],
		"Confirming consumes exactly the reward recipient's and shared storage copies.")
	_check(run.load_save(save_path) and run.reward_lane() == 1 and run.data.offers == next_hero_offers
		and run.loadout.lanes[0].any(func(tile: Dictionary): return tile.id == choice and tile.get("enchantment") == "guarded"),
		"The chosen upgrade inherits the consumed attachment. It and the next hero's draft survive a second reload.")


func _check_reward_copy_pips(game: Control) -> void:
	var run: FrontierRun = game.run
	var lane := run.reward_lane()
	if lane != 1:
		_check(false, "Copy pips need the recruit's active reward.")
		return
	var before := run.loadout.duplicate(true)
	var offers: Array = run.data.offers
	# Both matching copies are stowed, but each only frees two contiguous spaces.
	run.loadout.lanes[0] = [_tile("shield_ram", 0)]
	run.loadout.lanes[lane] = [_tile("slam", 0), _tile("slam", 4), _tile("slam", 8)]
	run.loadout.storage = [
		[_tile("shield_ram", 0), _tile("slam", 2), _tile("hook_bash", 6)],
		[_tile("shield_ram", 0), _tile("slam", 2), _tile("shield_tap", 6)],
		[_tile("slam", 0), _tile("slam", 4)],
	]
	run.data.offers = ["shield_ram", "hook_bash", "meteor_seal"]
	game.run_return()
	await process_frame
	var card := game.frontier_screen.find_child("RewardTile_shield_ram", true, false) as Button
	var pips := _reward_copy_pips(game.frontier_screen, "shield_ram")
	var other := _reward_copy_pips(game.frontier_screen, "hook_bash")
	_check(pips != null and pips.is_visible_in_tree() and int(pips.get_meta("owned_copies")) == 2
		and not pips.get_meta("completes_set") and "Make room" in pips.tooltip_text,
		"Copy pips count the two stowed copies and ignore the other hero, without promising an upgrade that cannot fit.")
	_check(other != null and int(other.get_meta("owned_copies")) == 1
		and _reward_copy_pips(game.frontier_screen, "meteor_seal") == null,
		"Copy pips count exact tile IDs and are absent on Legendary offers.")
	game._place({"id": "slam", "lane": -1, "row": 0, "start": 2}, 0, 4)
	_check(pips != null and pips == _reward_copy_pips(game.frontier_screen, "shield_ram")
		and pips.get_meta("completes_set") and "completes a set of three" in card.accessibility_name,
		"Making room updates the same card and its accessible description without leaving the reward.")
	game._place({"id": "shield_ram", "lane": -1, "row": 0, "start": 0}, 0, 2)
	_check(pips != null and int(pips.get_meta("owned_copies")) == 1 and not pips.get_meta("completes_set"),
		"Moving a matching copy onto the other hero's timeline immediately removes it from the count.")
	_check(run.load_save(save_path), "The edited inventory is saved during the reward.")
	game.run_resume()
	await process_frame
	pips = _reward_copy_pips(game.frontier_screen, "shield_ram")
	_check(pips != null and int(pips.get_meta("owned_copies")) == 1 and not pips.get_meta("completes_set"),
		"Resuming the same reward recomputes the count from the saved inventory.")
	run.loadout = before
	run.data.offers = offers
	_check(run.save(), "Restore the reward fixture for the remaining inventory tests.")


func _reward_copy_pips(page: Control, id: String) -> Control:
	var button := page.find_child("RewardTile_" + id, true, false) as Button
	return button.get_parent().find_child("RewardCopyPips", true, false) as Control if button != null else null


func _check_enchanted_tile_movement(game: Control) -> void:
	var run: FrontierRun = game.run
	if run.loadout.lanes.is_empty():
		return
	run.data.phase = "map"
	run.data.enchantments = ["splash", "guarded"]
	run.loadout.lanes[0] = [_tile("shot", 0), _tile("shot", 2), _tile("shot", 4)]
	run.loadout.lanes[0][0].enchantment = "splash"
	run.loadout.lanes[0][1].enchantment = "guarded"
	run.loadout.storage = [[], [], []]
	game.run_open_enchantment_loadout()
	var from_lane := {"id": "shot", "lane": 0, "start": 0}
	game.storage_place(0, 0, from_lane, true)
	_check(game.storage_rows[0].size() == 1 and game.storage_rows[0][0].get("enchantment") == "splash",
		"Moving an enchanted tile to storage keeps its attachment.")
	var from_storage := {"id": "shot", "lane": -1, "row": 0, "start": 0}
	game._place(from_storage, 0, 0, true)
	_check(game.lanes[0].size() == 3 and game.lanes[0][0].get("enchantment") == "splash",
		"Moving an enchanted tile back to the same beat keeps its attachment.")
	game._offer_combine(-1, 0, 0, true)
	var before := run.loadout.duplicate(true)
	run.save_path = save_path + ".missing/save.json"
	game.forge_choose("split_shot")
	_check(game.forge_screen.visible and game.forge_screen._error.visible and run.loadout == before,
		"A failed save keeps a touching triple and its enchantment intact in the open forge.")
	run.save_path = save_path
	game.forge_choose("split_shot")
	_check(game.lanes[0].size() == 1 and game.lanes[0][0].id == "split_shot"
		and game.lanes[0][0].get("enchantment", "") == "guarded" and run.enchantments() == ["splash", "guarded"],
		"A combine keeps the eligible attachment and returns the other held enchantment to storage.")
	await process_frame


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


func _check_alternate_copies(game: Control) -> void:
	var run := FrontierRun.new()
	game.run = run
	run.save_path = save_path
	if not run.start_run(42):
		_check(false, "Start the alternate-copy expedition.")
		return
	run.data.offers = ["warden"]
	if not _check(run.choose_hero("warden") and run.choose_relic("pocket_bell") and run.choose_starter("bash"),
		"Equip Warden in the alternate-copy expedition."):
		return
	var source := "shield_ram"
	var choice := "bulwark_charge"
	var lane := [_tile(source, 0), _tile("jab", 2), _tile(source, 3), _tile("jab", 5),
		_tile(source, 6), _tile(source, 8), _tile("jab", 10), _tile("jab", 11)]
	var storage := [[_tile("slam", 0), _tile("slam", 4)], [_tile("slam", 0), _tile("slam", 4)], [_tile("slam", 0), _tile("slam", 4)]]
	run.loadout.lanes[0] = lane.duplicate(true)
	run.loadout.storage = storage.duplicate(true)
	run.data.node = {"id": "alternate-copies-test", "row": 2, "column": 0, "type": "battle",
		"label": "Test patrol", "next": []}
	if not _check(run.finish_combat(true, 100) and source in run.data.offers, "Victory offers the owned Shield Ram."):
		return
	game.run_return()
	await _click(game.frontier_screen, "RewardTile_" + source)
	if not _check(game.forge_screen.visible and game.forge_screen._keep_reward.disabled,
		"A full inventory can use a reward with two matching copies that free room for a wider upgrade."):
		return
	var reward_plan: Dictionary = game._reward_upgrade_plan(game.pending_forge.copies, choice)
	_check(game.forge_can_fit(choice) and reward_plan.get("destination", {}).get("start", -1) == 6,
		"The reward combine finds the position made available by the alternate pair.")
	game.forge_choose(choice)
	var expected_reward := [_tile(source, 0), _tile("jab", 2), _tile(source, 3), _tile("jab", 5),
		_tile(choice, 6), _tile("jab", 10), _tile("jab", 11)]
	_check(run.data.phase == "map" and run.loadout.lanes[0] == expected_reward and run.loadout.storage == storage,
		"The reward consumes the pair starting on beats 7 and 9 and preserves both earlier copies.")

	run.loadout.lanes[0] = lane.duplicate(true)
	if not _check(run.save(), "Save the full inventory before the manual combine."):
		return
	game.run_show_arena()
	game._open_storage()
	game.selected = {"id": source, "lane": 0, "start": 0}
	game._render_storage()
	await _click(game.storage_screen, "CombineSelected")
	var inventory_plan: Dictionary = game._inventory_upgrade_plan(choice)
	if not _check(game.forge_screen.visible and game.forge_can_fit(choice)
		and inventory_plan.get("destination", {}).get("start", -1) == 6,
		"Combine 3 includes the selected copy and finds two other copies that make room."):
		return
	run.save_path = save_path + ".missing/save.json"
	game.forge_choose(choice)
	_check(game.forge_screen.visible and game.forge_screen._error.visible
		and run.loadout.lanes[0] == lane and run.loadout.storage == storage,
		"A failed save leaves the manual combine open and restores every tile.")
	run.save_path = save_path
	game.forge_choose(choice)
	var expected_manual := expected_reward.slice(1)
	var restored := FrontierRun.new()
	_check(game.storage_screen.visible and restored.load_save(save_path)
		and restored.loadout.lanes[0] == expected_manual and restored.loadout.storage == storage,
		"Retry consumes the selected copy and the alternate pair in one saved operation.")


func _check_authored_forge_choices(game: Control) -> void:
	var run := FrontierRun.new()
	game.run = run
	run.save_path = save_path
	var source := "reversal_plate"
	var choices := ["reversal_plate_upgrade_uncommon_power", "reversal_plate_upgrade_uncommon_technique"]
	var paths := ["Retaliation", "Fellow Guard"]
	var names := ["Shield Edge", "Shared Stance"]
	var tiers := TilePacking.forge_tiers(source)
	if not _check(tiers.map(func(tier: Array): return tier.size()) == [1, 2, 2, 2, 2]
		and tiers[0] == [source] and tiers[1] == choices, "Reversal Plate keeps one Common and two named options per rarity."):
		return
	for branch in range(choices.size()):
		var labels := "camp forge" if branch == 0 else "reward combine"
		if not _check(run.start_run(42), "Start the %s fixture." % labels):
			return
		run.data.offers = ["warden"]
		if not _check(run.choose_hero("warden") and run.choose_relic("pocket_bell") and run.choose_starter("shield_tap"),
			"Equip Warden in the %s fixture." % labels):
			return
		if branch == 0:
			run.data.node = run.data.layers[FrontierRun.NODES_PER_SEGMENT - 2][0]
			run.data.phase = "rest"
			run.loadout.storage[0] = [_tile(source, 0)]
			game.run_rest_forge()
			game.storage_pick(0, game.storage_rows[0][0])
			await _click(game.storage_screen, "StorageForgeSelected")
		else:
			run.loadout.lanes[0] = [_tile(source, 0), _tile(source, 2)]
			if not _check(run.finish_combat(true, 100) and source in run.data.offers,
				"The opening reward offers the held Reversal Plate pair its third copy."):
				return
			game.run_return()
			await _click(game.frontier_screen, "RewardTile_" + source)
		var forge: Control = game.forge_screen
		if not _check(forge.visible and forge._source_id == source and forge._next_ids == choices,
			"The %s opens the same Reversal Plate option IDs." % labels):
			return
		for index in range(choices.size()):
			var option: Button = forge._cards[choices[index]]
			_check(option.is_visible_in_tree() and (option.find_child("ForgeChoiceName", true, false) as Label).text == names[index]
				and ArenaSim.TILES[choices[index]].upgrade_path == paths[index],
				"The %s displays Reversal Plate's %s upgrade name." % [labels, names[index]])
		var choice: String = choices[branch]
		await _click(forge, str(forge._cards[choice].name))
		if not forge._direct_pick:
			await _click(forge, str(forge._confirm.name))
		var restored := FrontierRun.new()
		if not _check(restored.load_save(save_path) and restored.data.phase == "map",
			"The confirmed %s path saves and returns to the map." % labels):
			return
		var family: Array[String] = []
		for row: Array in restored.loadout.lanes + restored.loadout.storage:
			for tile: Dictionary in row:
				if ArenaSim.TILES[tile.id].get("family") == source:
					family.append(tile.id)
		_check(family == [choice], "Reload keeps exactly the %s path chosen in the %s." % [paths[branch], labels])
		run.abandon_run()


func _check_assisted_camp_forge(game: Control) -> void:
	var run := FrontierRun.new()
	game.run = run
	run.save_path = save_path
	if not _check(run.start_run(42), "Start the assisted forge run."):
		return
	run.data.offers = ["warden"]
	if not _check(run.choose_hero("warden") and run.choose_relic("pocket_bell") and run.choose_starter("shield_tap"),
		"Set up the Forge run."):
		return
	var rest: Dictionary = run.data.layers[FrontierRun.NODES_PER_SEGMENT - 2][0]
	var source := {"id": "longshot", "lane": 0, "start": 0}
	var locked_timeline := [_tile("longshot", 0, "farthest"), _tile("bash", 2), _tile("cover", 5, "self")]
	run.data.node = rest
	run.data.phase = "rest"
	run.loadout.lanes[0] = locked_timeline.duplicate(true)
	_preview_forge_source(game, source)
	_check(run.camp_forge_blocker(source).is_empty() and not run.camp_forge_plan(source, "deadeye").is_empty()
		and run.loadout.lanes[0] == locked_timeline,
		"The rest forge offers an owned tile directly before its reward-pool unlock, without changing inventory on inspection.")
	_preview_forge_source(game, source)
	await _click(game.storage_screen, "StorageForgeSelected")
	var forge: Control = game.forge_screen
	forge._cards["deadeye"].grab_focus()
	await process_frame
	_check(not forge._confirm.disabled and "Bash moves from beat 3 to 4" in forge._room_instruction.text
		and run.loadout.lanes[0] == locked_timeline,
		"Inspecting the wider upgrade previews which neighbor slides, leaving the original timeline intact.")
	await _click(forge, str(forge._cards["deadeye"].name))
	_check(run.data.phase == "map" and run.loadout.lanes[0] == [
		_tile("deadeye", 0, "farthest"), _tile("bash", 3), _tile("cover", 5, "self")],
		"One confirm applies the previewed move and retains existing targeting.")

	var full_lane := [_tile("longshot", 0, "farthest"), _tile("bash", 2), _tile("slam", 4), _tile("slam", 8)]
	full_lane[1].enchantment = "guarded"
	var blocked_storage := [_tile("slam", 0), _tile("slam", 4)]
	run.data.node = rest
	run.data.phase = "rest"
	run.data.enchantments = ["guarded"]
	run.loadout.lanes[0] = full_lane.duplicate(true)
	run.loadout.storage = [blocked_storage.duplicate(true), blocked_storage.duplicate(true), blocked_storage.duplicate(true)]
	_preview_forge_source(game, source)
	await _click(game.storage_screen, "StorageForgeSelected")
	forge._cards["deadeye"].grab_focus()
	await process_frame
	var before := run.loadout.duplicate(true)
	_check(forge._confirm.disabled and "No room" in forge._room_instruction.text
		and not run.choose_camp_upgrade(source, "deadeye") and run.loadout == before and run.data.phase == "rest",
		"A full timeline and storage deny a wider upgrade without consuming the rest stop or moving any tile.")
	game.forge_close()
	run.loadout.storage[0] = []
	_preview_forge_source(game, source)
	await _click(game.storage_screen, "StorageForgeSelected")
	forge._cards["deadeye"].grab_focus()
	await process_frame
	_check(not forge._confirm.disabled and "Bash goes to storage row 1, cell 1" in forge._room_instruction.text,
		"Once storage opens up, the Forge names the tile to stow and its destination before confirmation.")
	before = run.loadout.duplicate(true)
	run.save_path = save_path + ".missing/save.json"
	await _click(forge, str(forge._cards["deadeye"].name))
	_check(forge.visible and forge._error.visible and run.data.phase == "rest" and run.loadout == before,
		"A save failure rolls back the wider upgrade and its storage move and leaves Forge open for retry.")
	run.save_path = save_path
	await _click(forge, str(forge._cards["deadeye"].name))
	var restored := FrontierRun.new()
	_check(restored.load_save(save_path) and restored.data.phase == "map" and restored.loadout.lanes[0][0].id == "deadeye"
		and restored.loadout.storage[0].size() == 1 and restored.loadout.storage[0][0].id == "bash"
		and restored.loadout.storage[0][0].start == 0 and restored.loadout.storage[0][0].get("enchantment") == "guarded",
		"A successful retry saves the upgraded tile and intact displaced tile together.")

	run.profile.meta.append("shot_artifice")
	var smith := {"type": "event", "row": 1, "label": "Traveling Smith"}
	run.data.node = smith
	run.data.phase = "event"
	run.loadout.storage = [[_tile("deadeye", 0), _tile("star_piercer", 3)], [_tile("slam", 4)], blocked_storage.duplicate(true)]
	var stored := {"id": "deadeye", "lane": -1, "row": 0, "start": 0}
	var relocation := run.camp_forge_plan(stored, "rail_shot")
	_check(relocation.get("destination_row", -1) == 1 and run.choose_mystery_upgrade(stored, "rail_shot")
		and run.loadout.storage[0] == [_tile("star_piercer", 3)] and run.loadout.storage[1][0] == _tile("rail_shot", 0),
		"The Traveling Smith uses the same fit to relocate a wider stored tile into an available row.")


func _preview_forge_source(game: Control, source: Dictionary) -> void:
	game.run_rest_forge()
	game.selected = source.duplicate()
	game._rebuild_loadout()


func _tile(id: String, start: int, target := "nearest") -> Dictionary:
	return {"id": id, "start": start, "target": target}


func _click(page: Control, node_name: String) -> void:
	await process_frame
	var button := page.find_child(node_name, true, false) as Button
	if button != null and not button.is_visible_in_tree():
		var menu: Node = button.get_parent()
		while menu != null and not menu.has_method("is_open"):
			menu = menu.get_parent()
		if menu != null and not menu.is_open():
			var trigger: Button = menu.get("trigger")
			await _click(page, trigger.name)
			await process_frame
			button = page.find_child(node_name, true, false) as Button
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


func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
	return condition
