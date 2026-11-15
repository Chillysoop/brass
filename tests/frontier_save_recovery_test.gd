extends SceneTree

const FrontierRun = preload("res://scripts/frontier_run.gd")
const ClassDecks = preload("res://scripts/class_decks.gd")

var failures: Array[String] = []
var paths: Array[String] = []


func _initialize() -> void:
	_check_backup_recovery()
	_check_failed_drafts()
	_check_failed_boss_save()
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
