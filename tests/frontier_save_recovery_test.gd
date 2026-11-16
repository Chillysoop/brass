extends SceneTree

const FrontierRun = preload("res://scripts/frontier_run.gd")
const ClassDecks = preload("res://scripts/class_decks.gd")

var failures: Array[String] = []
var paths: Array[String] = []


func _initialize() -> void:
	_check_backup_recovery()
	_check_failed_drafts()
	_check_failed_recruit_kit()
	_check_failed_boss_save()
	_check_failed_intermediate_boss_reward()
	_check_empty_timeline_recovery()
	for path: String in paths:
		for suffix: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Frontier saves passed backup recovery, failed autosave retry, and empty timeline recovery.")
	quit(0 if failures.is_empty() else 1)


func _check_backup_recovery() -> void:
	var run := _begin_battle("backup")
	if run == null:
		return
	var path := run.save_path
	if not _expect(run.finish_combat(true, 82), "Save a reward with a playable battle as its backup."):
		return
	var backup := FileAccess.get_file_as_string(path + ".bak")
	var incomplete_recruit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	incomplete_recruit.run.phase = "recruit_starter"
	var restored := FrontierRun.new()
	if not _expect(_overwrite(path, JSON.stringify(incomplete_recruit)) and restored.load_save(path)
		and restored.data.get("phase") == "combat", "Fall back to backup when a recruit draft is missing its pending recruit."):
		return
	var partial := JSON.stringify({"version": 1, "profile": {}, "run": {"phase": "reward"}, "loadout": {}})
	if not _expect(_overwrite(path, partial), "Truncate the primary to an incomplete but valid JSON record."):
		return
	if not _expect(restored.load_save(path) and restored.data.get("phase") == "combat",
		"An incomplete primary falls back to the playable combat backup."):
		return
	if not _expect(restored.finish_combat(true, 82), "Save after resuming from backup."):
		return
	_expect(restored.load_save(path) and restored.data.get("phase") == "reward", "The new save becomes the primary checkpoint.")
	_expect(FileAccess.get_file_as_string(path + ".bak") == backup, "Saving after recovery preserves the playable backup.")
	if not _expect(_overwrite(path, "{truncated"), "Damage the new primary for a second recovery."):
		return
	_expect(restored.load_save(path) and restored.data.get("phase") == "combat", "The backup remains usable when the new primary becomes unreadable.")


func _check_failed_drafts() -> void:
	var run := _fresh("draft")
	if not _block_write(run):
		return
	_expect(not run.start_run(42) and run.data.is_empty() and run.loadout.is_empty() and not run.save_error.is_empty(),
		"A failed expedition start leaves the profile ready to start again.")
	_unblock_write(run)
	if not _expect(run.start_run(42) and run.choose_hero(run.data.offers[0]), "Start an expedition and reach the relic draft."):
		return
	var relic: String = run.data.offers[0]
	if not _block_write(run):
		return
	_expect(not run.choose_relic(relic) and run.data.phase == "relic" and run.data.relics.is_empty(),
		"A failed relic write keeps the draft open and the relic available.")
	_unblock_write(run)
	if not _expect(run.choose_relic(relic), "Claim the same relic once the save is writable."):
		return
	if not _block_write(run):
		return
	_expect(not run.choose_starter("bash") and run.data.phase == "starter" and run.loadout.lanes[0].is_empty(),
		"A failed starter write restores the timeline and starter draft together.")
	_unblock_write(run)
	_expect(run.choose_starter("bash") and run.data.relics == [relic] and run.loadout.lanes[0].size() == 1,
		"Retrying both drafts equips one starter tile and grants one relic.")


func _check_failed_recruit_kit() -> void:
	var run := _fresh("recruit-kits")
	run.profile.medium_unlocked = true
	if not _expect(run.start_run(42, "medium") and run.choose_preferred_hero("warden") \
			and run.choose_relic("pocket_bell") and run.choose_starter(ClassDecks.starter("warden")) \
			and run.finish_combat(true, 88) and run.reward("skip"), "Reach the route with the lead's opening tile."):
		return
	var boss_row := FrontierRun.NODES_PER_SEGMENT - 1
	run.data.node = run.data.layers[boss_row - 1][0]
	if not _expect(run.choose_node(run.data.layers[boss_row][0].id) and run.finish_combat(true, 75) \
			and run.reward("skip") and run.choose_boss_relic("skip"), "Reach the pending Act II recruit choice."):
		return
	var choice: String = run.data.offers.front()
	var before := run.data.duplicate(true)
	if not _block_write(run):
		return
	_expect(not run.choose_recruit(choice) and run.data == before and not run.data.has("recruit_kits"),
		"A failed recruit selection keeps the draft and its available heroes intact.")
	_unblock_write(run)
	if not _expect(run.choose_recruit(choice), "Retry the same recruit selection once the save is writable."):
		return
	var kits := run.recruit_loadout_offers()
	if not _expect(kits.size() == 2, "The resumed recruit has two kit choices."):
		return
	_check_invalid_kit_pairs(run)
	var inventory := run.loadout.duplicate(true)
	before = run.data.duplicate(true)
	if not _block_write(run):
		return
	_expect(not run.choose_recruit_loadout(kits[0].id) and run.data == before and run.loadout == inventory \
		and run.recruit_loadout_offers() == kits and not run.save_error.is_empty(),
		"A failed kit write keeps the same ordered pair and no recruit tiles or hero are added.")
	_unblock_write(run)
	_expect(run.load_save(run.save_path) and run.recruit_loadout_offers() == kits \
		and run.choose_recruit_loadout(kits[0].id) and not run.choose_recruit_loadout(kits[1].id) \
		and run.loadout.lanes.size() == 2 and run.loadout.lanes[1].map(func(tile: Dictionary): return tile.id) == kits[0].tiles,
		"Resume the pending draft and commit its exact selected tiles once.")


func _check_invalid_kit_pairs(run: FrontierRun) -> void:
	var path := run.save_path
	var original := FileAccess.get_file_as_string(path)
	var malformed: Dictionary = JSON.parse_string(original)
	for bad_pair: Array in [["assault", "assault"], ["assault", "unknown"], ["specialty"]]:
		malformed.run.recruit_kits = bad_pair
		var restored := FrontierRun.new()
		_expect(_overwrite(path, JSON.stringify(malformed)) and restored.load_save(path) \
			and restored.data.phase == "recruit", "Invalid stored kit IDs fall back to the previous playable recruit checkpoint.")
	_expect(_overwrite(path, original), "Restore the valid ordered kit pair for failed-write testing.")


func _check_failed_boss_save() -> void:
	var run := _begin_battle("combat")
	if run == null or not _walk_to_camp(run):
		return
	var health: int = run.data.hp
	if not _block_write(run):
		return
	_expect(not run.rest("heal") and run.data.phase == "rest" and run.data.hp == health and run.data.heroes[0].hp == health,
		"A failed rest leaves the camp and both health records intact.")
	_unblock_write(run)
	if not _expect(run.rest("heal") and run.data.hp > health and run.choose_node(run.available_nodes()[0].id)
		and run.is_final_boss(), "Retry healing and enter the final boss fight."):
		return
	var before := run.data.duplicate(true)
	var before_profile := run.profile.duplicate(true)
	if not _block_write(run):
		return
	_expect(not run.finish_combat(true, 78) and run.data == before and run.profile == before_profile
		and not run.save_error.is_empty(), "A failed boss write keeps the fight, saved health, marks, mastery and unlocks at the prior checkpoint.")
	_unblock_write(run)
	var restored := FrontierRun.new()
	_expect(restored.load_save(run.save_path) and restored.data.get("phase") == "combat"
		and not restored.can_start("medium"), "The disk checkpoint still has the unresolved final battle.")
	if not _expect(run.finish_combat(true, 78) and not run.finish_combat(true, 78), "Retry the same boss result exactly once."):
		return
	_expect(restored.load_save(run.save_path) and restored.data.get("phase") == "reward" and restored.can_start("medium")
		and int(restored.profile.marks) == int(before_profile.marks) + 19,
		"The rerun of the save commits the legendary pick, Medium unlock, and one 19-Mark payout together.")


func _check_failed_intermediate_boss_reward() -> void:
	var run := _fresh("boss-party-rewards")
	run.profile.medium_unlocked = true
	run.profile.hard_unlocked = true
	if not _expect(run.start_run(9, "hard") and run.choose_preferred_hero("warden") and run.choose_relic("pocket_bell") \
		and run.choose_starter(ClassDecks.starter("warden")) and run.finish_combat(true, 100) and run.reward("skip") \
		and _enter_act_boss(run, 1) and run.finish_combat(true, 80) and run.reward("skip") and run.choose_boss_relic("skip"),
		"Reach the first Brass Hard recruit and keep the starter lane."):
		return
	var recruit: String = run.data.offers[0]
	if not _expect(run.choose_recruit(recruit) and run.choose_recruit_starter(ClassDecks.starter(recruit)) \
		and _enter_act_boss(run, 2) and run.finish_combat(true, [0, 60]) and run.reward_count() == 2,
		"The Act II boss leaves two Legendary drafts, even with a fallen lead."):
		return
	var before := run.data.duplicate(true)
	var profile := run.profile.duplicate(true)
	var loadout := run.loadout.duplicate(true)
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(run.save_path))
	if not _block_write(run):
		return
	_expect(not run.reroll_reward() and run.data == before and run.profile == profile and run.loadout == loadout,
		"A failed reroll charges no gold and leaves both ordered boss drafts intact.")
	_expect(not run.reward("skip") and run.data == before and run.profile == profile and run.loadout == loadout,
		"A failed first boss pick does not advance the second queued draft or pay skip gold.")
	_unblock_write(run)
	var restore := FrontierRun.new()
	var next: Array = before.reward_remaining[0].offers
	_expect(restore.load_save(run.save_path) and restore.data.offers == before.offers and restore.reward("skip") \
		and restore.reward_lane() == 1 and restore.data.offers == next,
		"Resume and retry with the same first draft and exact next offers.")
	_check_legacy_pending_boss_reward(run, legacy)


func _check_legacy_pending_boss_reward(run: FrontierRun, legacy: Dictionary) -> void:
	var lead_pool := run._class_reward_pool(run.data.heroes[0].id, 4, run._reward_inventory(0))
	var recruit_pool := run._class_reward_pool(run.data.heroes[1].id, 4, run._reward_inventory(1))
	var first := run._sample(lead_pool, 3, run.data.seed, run._node_salt(81))
	var second := run._sample(recruit_pool, 3, run.data.seed, run._node_salt(81 + 1069))
	legacy.run.offers = first
	legacy.run.reward_remaining[0].offers = second
	var path := run.save_path
	if not _expect(_overwrite(path, JSON.stringify(legacy)) and run.load_save(path), "Read the legacy pending Hard boss save."):
		return
	_expect(run.data.offers == first and run.data.reward_remaining[0].offers == second and run.reroll_reward() \
		and run.data.offers.size() == 3 and run.data.offers.all(func(id: String): return id in lead_pool) \
		and run.data.reward_remaining[0].offers == second and run.reward("skip") and run.data.offers == second,
		"A legacy pending boss keeps the saved ordinary drafts, including when rerolled or advanced.")


func _enter_act_boss(run: FrontierRun, act: int) -> bool:
	var row := act * FrontierRun.NODES_PER_SEGMENT - 1
	run.data.node = run.data.layers[row - 1][0]
	return run.choose_node(run.data.layers[row][0].id)


func _check_empty_timeline_recovery() -> void:
	var run := _begin_battle("empty")
	if run == null:
		return
	var path := run.save_path
	var storage_tile: Dictionary = run.loadout.lanes[0].pop_front()
	run.data.relics = ["brass_metronome"]
	if not _expect(run.save(), "Write a legacy combat save with no remaining tiles."):
		return
	var starter := ClassDecks.starter(run.data.hero)
	var restored := FrontierRun.new()
	if not _expect(restored.load_save(path) and restored.recovered_starter == starter
		and restored.loadout.lanes[0].size() == 1 and restored.loadout.lanes[0][0].id == starter
		and restored.loadout.lanes[0][0].start == 1, "Restore the living hero's class starter and leave the Metronome gap."):
		return
	_expect(restored.save() and restored.load_save(path) and restored.recovered_starter.is_empty()
		and restored.loadout.lanes[0].size() == 1, "A subsequent save keeps one recovered tile.")
	run.loadout.storage[0].append(storage_tile)
	_expect(run.save() and restored.load_save(path) and restored.recovered_starter.is_empty()
		and restored.loadout.lanes[0].is_empty() and restored.loadout.storage[0].size() == 1,
		"A tile already in shared storage prevents recovery from creating another.")
	run.loadout.storage[0].clear()
	run.data.phase = "map"
	_expect(run.save() and restored.load_save(path) and restored.recovered_starter == starter
		and restored.loadout.lanes[0].size() == 1,
		"Recover a legacy run that discarded all tiles before choosing its next fight.")


func _begin_battle(label: String) -> FrontierRun:
	var run := _fresh(label)
	if _expect(run.start_run(42) and run.choose_hero(run.data.offers[0])
		and run.choose_relic(run.data.offers[0]) and run.choose_starter("bash"), "Reach the opening battle."):
		return run
	return null


func _walk_to_camp(run: FrontierRun) -> bool:
	for step in 24:
		match run.data.phase:
			"combat":
				if not _expect(run.finish_combat(true, 72), "Reach camp with damaged health."):
					return false
			"reward":
				var relics := run.elite_relic_offers()
				if not relics.is_empty() and not run.choose_elite_relic(relics[0].id):
					return _expect(false, "Resolve the elite relic draft before camp.")
				if not _expect(run.reward("skip"), "Resolve the tile reward before camp."):
					return false
			"map":
				if not _expect(run.choose_node(run.available_nodes()[0].id), "Follow a legal route to camp."):
					return false
			"shop", "event":
				if not _expect(run.leave_node(), "Leave a noncombat stop before camp."):
					return false
			"rest":
				return true
	return _expect(false, "Reach the rest site before the last boss.")


func _fresh(label: String) -> FrontierRun:
	var path := "user://save-recovery-%s-%d.json" % [label, Time.get_ticks_usec()]
	paths.append(path)
	var run := FrontierRun.new()
	run.load_save(path)
	return run


func _block_write(run: FrontierRun) -> bool:
	return _expect(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(run.save_path + ".tmp")) == OK,
		"Place a directory at the temporary save path to block writes.")


func _unblock_write(run: FrontierRun) -> void:
	_expect(DirAccess.remove_absolute(ProjectSettings.globalize_path(run.save_path + ".tmp")) == OK,
		"Remove the temporary obstruction before retrying the save.")


func _overwrite(path: String, contents: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(contents)
	file.close()
	return true


func _expect(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
	return ok
