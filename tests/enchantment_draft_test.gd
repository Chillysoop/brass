extends SceneTree

const FrontierRun := preload("res://scripts/frontier_run.gd")
const ArenaSim := preload("res://scripts/arena_sim.gd")
const TileEnchantments := preload("res://scripts/tile_enchantments.gd")
const ClassDecks := preload("res://scripts/class_decks.gd")

var failures: Array[String] = []
var path := "user://enchantment-draft-test-%d.json" % Time.get_ticks_usec()


func _initialize() -> void:
	_check_draft()
	_check_recruit_draft()
	_check_legacy_save()
	for suffix: String in ["", ".tmp", ".bak"]:
		var saved := path + suffix
		if FileAccess.file_exists(saved):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(saved))
	if failures.is_empty():
		print("Enchantment gate, seeded drafts, recruitment, save rollback, and legacy migration pass.")
	for failure in failures:
		printerr(failure)
	quit(0 if failures.is_empty() else 1)


func _check_draft() -> void:
	var run := FrontierRun.new()
	run.load_save(path)
	run.profile.marks = 21
	_check(not run.buy_meta("enchantments"), "Tile Enchantments must require Gravity Hook.")
	if not _check(run.start_run(42) and _win_opening(run), "Win the opening on a locked profile."):
		return
	_check(run.data.get("phase") == "map" and run.enchantment_offers().is_empty()
		and not run.choose_enchantment("guarded") and not run.buy_meta("enchantments"),
		"A locked expedition cannot draft or buy enchantments.")
	if not _check(run.abandon_run() and run.buy_meta("stout_start") and run.buy_meta("curated_cache")
			and run.buy_meta("enchantments"), "Buy Tile Enchantments between expeditions with the prerequisite."):
		return
	_check(run.profile.marks == 0 and not run.buy_meta("enchantments"), "Charge 8 Marks once for the enchantment unlock.")
	if not _check(run.start_run(42) and _draft_opening(run) and run.finish_combat(false, 0)
			and run.data.get("phase") == "result" and run.enchantment_offers().is_empty() and run.abandon_run(),
			"Defeat at the opening must not open the enchantment draft."):
		return

	run.profile.medium_unlocked = true
	run.profile.hard_unlocked = true
	for difficulty: String in ["easy", "medium", "hard"]:
		if not _check(run.start_run(42, difficulty) and _win_opening(run), "Win the Brass Frontier opening on %s." % difficulty):
			return
		var draft := run.enchantment_offers()
		var ids := _offer_ids(run)
		var starter: String = run.loadout.lanes[0][0].id
		var eligible := ids.filter(func(id: String): return TileEnchantments.is_eligible(id, ArenaSim.TILES[starter], starter))
		if not _check(run.data.phase == "enchantment" and ids.size() == 3 and eligible == ids
				and ids.all(func(id: String): return ids.count(id) == 1),
				"The opening draft offers three distinct enchantments that fit the starter when possible."):
			return
		_check(run.load_save(path) and run.enchantment_offers() == draft, "Resume the same open draft.")
		var original_save_path := run.save_path
		run.save_path = path + ".missing/file.json"
		_check(not run.choose_enchantment(ids[0], {"lane": 0, "start": 0, "id": starter})
			and run.data.get("phase") == "enchantment" and run.enchantments().is_empty()
			and not run.loadout.lanes[0][0].has("enchantment"),
			"A failed inline equip save must restore the open draft and the original tile.")
		run.save_path = original_save_path
		var chosen: String = "skip" if difficulty == "medium" else ids[0]
		_check(not run.choose_enchantment("mending") and run.choose_enchantment(chosen),
			"Reject an undrafted effect and confirm a valid pick or skip.")
		_check(run.load_save(path) and run.data.get("phase") == "map" and run.enchantments() ==
			([] if chosen == "skip" else [chosen]) and run.data.enchantment_drafts == ["opening"]
			and not run.choose_enchantment(ids[0]),
			"The draft resolves to the map and the choice persists without another claim.")
		_check(run.abandon_run(), "Return to title before starting another expedition.")
	var options := {}
	var seed_draft: Array = []
	for seed in [42, 43, 44, 45, 46, 47, 48, 42]:
		if not _check(run.start_run(seed, "medium") and _win_opening(run), "Draft with seed %d." % seed):
			return
		var ids := _offer_ids(run)
		if seed == 42:
			_check(seed_draft.is_empty() or ids == seed_draft, "The same seed produces the same ordered draft.")
			seed_draft = ids
		var pool := ids.duplicate()
		pool.sort()
		options[str(pool)] = true
		_check(run.abandon_run(), "Return to title after checking the seeded draft.")
	_check(options.size() > 1, "Different seeds offer different combinations of enchantments.")
	run.profile.glass_easy_unlocked = true
	_check(run.start_run(42, "easy", "glass") and _win_opening(run) and run.data.get("phase") == "map",
		"The first enchantment draft applies only to Brass Frontier.")
	_check(run.abandon_run(), "Return to title after checking Glass Foundry.")


func _check_recruit_draft() -> void:
	var run := FrontierRun.new()
	run.load_save(path)
	if not _check(run.start_run(42, "medium") and _win_opening(run), "Draft the first enchantment in Medium."):
		return
	var first: String = _offer_ids(run)[0]
	var starter: String = run.loadout.lanes[0][0].id
	var destination := {"lane": 0, "start": 0, "id": starter}
	if not _check(run.choose_enchantment(first, destination), "Attach the first enchantment to the lead starter."):
		return
	# Start at the Act I boss, then use the normal reward, recruitment, and gate flows.
	run.data.node = run.data.layers[FrontierRun.NODES_PER_SEGMENT - 1][0]
	run.data.visited.append(run.data.node.id)
	run.data.phase = "combat"
	if not _check(run.finish_combat(true, 85) and run.reward("skip"), "Resolve the Act I boss reward."):
		return
	if run.data.phase == "boss_relic":
		_check(run.choose_boss_relic("skip"), "Resolve the boss relic draft before recruiting.")
	if not _check(run.data.phase == "recruit" and run.choose_recruit(run.data.offers[0])
			and run.choose_recruit_loadout(run.recruit_loadout_offers()[0].id), "Recruit a second hero."):
		return
	if not _check(run.choose_node(run.available_nodes()[0].id) and run.finish_combat(true, [85, 85])
			and run.reward("skip") and run.data.phase == "reward" and run.enchantment_offers().is_empty()
			and run.reward("skip"), "Wait for both hero rewards before opening the recruitment draft."):
		return
	var second_draft := _offer_ids(run)
	var compatible := second_draft.filter(func(id: String): return TileEnchantments.is_eligible(id, ArenaSim.TILES[starter], starter))
	if not _check(second_draft.size() == 3 and first not in second_draft and not compatible.is_empty()
			and run.load_save(path) and _offer_ids(run) == second_draft,
			"Persist the seeded recruitment draft and exclude the owned effect."):
		return
	var second: String = compatible[0]
	_check(run.choose_enchantment(second, destination) and run.load_save(path) and run.enchantments() == [first, second]
		and run.loadout.lanes[0][0].enchantment == second and run.data.enchantment_drafts == ["opening", "recruit"],
		"Replacing an attachment keeps the first enchantment available for another tile.")
	run.data.phase = "combat"
	_check(run.finish_combat(true, [85, 85]) and run.reward("skip") and run.reward("skip") and run.data.phase == "map",
		"Further wins cannot reopen the recruitment draft.")
	_check(run.abandon_run(), "Return to title after checking the recruitment draft.")


func _check_legacy_save() -> void:
	var run := FrontierRun.new()
	run.load_save(path)
	if not _check(run.start_run(42, "medium") and _win_opening(run), "Prepare a legacy draft save."):
		return
	run.data.offers = []
	_check(run.save() and run.load_save(path) and _offer_ids(run) == TileEnchantments.LEGACY_IDS,
		"A pending legacy draft still has its original three choices.")
	for previous_pick: String in ["splash", ""]:
		run.data.phase = "map"
		run.data.enchantment = previous_pick
		if not previous_pick.is_empty():
			run.loadout.lanes[0][0].enchantment = previous_pick
		else:
			run.loadout.lanes[0][0].erase("enchantment")
		_check(run.save() and run.load_save(path) and not run.data.has("enchantment")
			and run.data.enchantment_drafts == ["opening"] and run.enchantments() ==
			([] if previous_pick.is_empty() else [previous_pick])
			and run.loadout.lanes[0][0].get("enchantment", "") == previous_pick,
			"Migrate a legacy opening pick or skip without changing its attachment.")
		run.data.erase("enchantments")
		run.data.erase("enchantment_drafts")


func _offer_ids(run: FrontierRun) -> Array:
	return run.enchantment_offers().map(func(offer: Dictionary): return offer.id)


func _win_opening(run: FrontierRun) -> bool:
	return _draft_opening(run) and run.finish_combat(true, 85) and run.reward("skip")


func _draft_opening(run: FrontierRun) -> bool:
	return run.choose_hero(run.data.offers[0]) and run.choose_relic("pocket_bell") \
		and run.choose_starter("bash" if "bash" in run.data.offers else ClassDecks.starter(run.data.hero))


func _check(success: bool, label: String) -> bool:
	if not success:
		failures.append(label)
	return success
