extends SceneTree

const Arena := preload("res://arena.tscn")
const ArenaSim := preload("res://scripts/arena_sim.gd")
const ClassDecks := preload("res://scripts/class_decks.gd")
const FrontierRun := preload("res://scripts/frontier_run.gd")
const BELLMAKER_SEED := 4
const BOSS_ROW := FrontierRun.NODES_PER_SEGMENT - 1

var failures: Array[String] = []
var save_path := "user://gameplay-options-test-%d.json" % Time.get_ticks_usec()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Arena.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.run.load_save(save_path)
	var mastered_class := await _check_bellmaker_unlock(game)
	if not mastered_class.is_empty():
		await _check_mastery_and_recruit(game, mastered_class)
	game.queue_free()
	await process_frame
	for base: String in [save_path, save_path + ".legacy"]:
		for suffix in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(base + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(base + suffix))
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Bellmaker preview, first-clear mastery, and recruit loadout progression passed.")
	quit(0 if failures.is_empty() else 1)


func _check_bellmaker_unlock(game: Control) -> String:
	var run: FrontierRun = game.run
	if not _check(run.start_run(BELLMAKER_SEED), "Start a fresh Brass Easy expedition."):
		return ""
	var first_preview := run.first_boss_preview()
	game.run_return()
	await process_frame
	var opening := game.frontier_screen.find_child("OpeningBossScout", true, false) as Label
	_check(first_preview.get("title") == "The Bellmaker" and opening != null and opening.visible
		and opening.text.contains("The Bellmaker") and opening.tooltip_text == first_preview.description,
		"The opening draft reveals the seeded Bellmaker and describes its attacks.")
	var hero_id: String = run.data.offers.front()
	if not _check(run.choose_hero(hero_id) and run.mastery_offers().is_empty()
		and not run.choose_mastery("anchor_ward") and _finish_opening(run),
		"A fresh hero cannot select a mastery and can still reach the route."):
		return ""
	_stage_boss_on_map(run)
	game.run_return()
	await process_frame
	var route := game.frontier_screen.find_child("TollkeeperScoutTitle", true, false) as Label
	_check(route != null and route.visible and route.text == first_preview.title,
		"The map shows the same boss as the opening scout.")
	if not _press(game.frontier_screen, "BellmakerBossNode"):
		return ""
	await process_frame
	_check(run.encounter().get("boss_id") == "brass_bellmaker", "The boss node must launch the announced encounter.")
	if not _press(game.frontier_screen, "Continue"):
		return ""
	await process_frame
	_check(game.sim.units.any(func(unit: Dictionary): return unit.get("attack_id") == "brass_bellmaker"),
		"The actual expedition arena spawns the Bellmaker.")
	if not _check(run.finish_combat(false, 0) and run.profile.mastered_classes.is_empty() and run.finish_run(),
		"Defeat cannot earn a class mastery."):
		return ""
	if not _check(run.start_run(BELLMAKER_SEED) and run.first_boss_preview() == first_preview
		and run.choose_hero(hero_id) and _finish_opening(run),
		"The same seed repeats the boss assignment and can be played again."):
		return ""
	_stage_boss_on_map(run)
	if not _check(run.choose_node(first_preview.id), "Enter the seeded Bellmaker battle."):
		return ""
	var marks := int(run.profile.marks)
	if not _check(run.finish_combat(true, 73), "Win the Bellmaker final battle."):
		return ""
	_check(run.data.result == "victory" and run.profile.medium_unlocked and int(run.profile.marks) == marks + 19
		and run.profile.mastered_classes == [hero_id],
		"The Bellmaker awards the ordinary Easy clear payout and earns mastery once for the winning class.")
	var trophy: String = run.data.offers.front()
	if not _check(ArenaSim.TILES[trophy].rarity == "legendary" and run.reward(trophy)
		and run.data.trophies.get(hero_id) == trophy and run.finish_run(),
		"The alternate final boss still grants the Legendary trophy and normal recap."):
		return ""
	_check(run.load_save(save_path) and run.profile.mastered_classes == [hero_id], "The class mastery unlock survives reload.")
	return hero_id


func _check_mastery_and_recruit(game: Control, hero_id: String) -> void:
	var run: FrontierRun = game.run
	if not _check(run.start_run(BELLMAKER_SEED, "medium") and run.choose_preferred_hero(hero_id),
		"The mastered class can start a new Medium expedition."):
		return
	var masteries := run.mastery_offers()
	if not _check(masteries.size() == 2 and masteries[0].id != masteries[1].id and run.selected_mastery().is_empty(),
		"A future expedition gives the class two optional mastery choices."):
		return
	game.run_return()
	await process_frame
	if not _press(game.frontier_screen, "ChooseClassMastery"):
		return
	await process_frame
	if not _press(game.frontier_screen, "MasteryOption_" + str(masteries[1].id)):
		return
	await process_frame
	_check(run.load_save(save_path) and run.mastery_offers() == masteries and run.selected_mastery() == masteries[1].id,
		"The selected optional mastery and both choices survive a saved draft restart.")
	if not _check(run.choose_mastery("") and run.selected_mastery().is_empty() and run.choose_mastery(masteries[0].id)
		and _finish_opening(run), "The player can clear or change the mastery before deploying."):
		return
	_stage_boss_on_map(run)
	var preview := run.first_boss_preview()
	if not _check(run.choose_node(preview.id), "Reach the Medium Bellmaker."):
		return
	_check(run.encounter().heroes[0].mastery == masteries[0].id, "The active mastery is carried into the encounter.")
	if not _check(run.finish_combat(true, 61) and run.reward("skip") and run.boss_relic_offers().size() == 3
		and run.choose_boss_relic("guild_ledger"), "The alternate Act I boss keeps the ordinary Medium relic rewards."):
		return
	var recruit: String = run.data.offers.front()
	if not _check(run.choose_recruit(recruit), "Select a second hero after the Bellmaker."):
		return
	var kits := run.recruit_loadout_offers()
	if not _check(kits.size() == 2 and kits[0].id == "assault" and kits[1].id == "support" and kits[0].tiles != kits[1].tiles,
		"The recruit gets two mechanically distinct loadouts."):
		return
	var legacy := FrontierRun.new()
	if _check(legacy.load_save(save_path), "Read a separate copy of the saved recruit draft."):
		legacy.save_path = save_path + ".legacy"
		legacy.data.erase("recruit_loadouts")
		_check(legacy.save() and legacy.load_save(legacy.save_path) and legacy.recruit_loadout_offers().is_empty()
			and legacy.choose_recruit_starter(ClassDecks.starter(recruit)) and legacy.loadout.lanes[1].size() == 1,
			"An existing one-tile recruit draft remains playable.")
	if not _check(run.load_save(save_path) and run.recruit_loadout_offers() == kits, "The new recruit loadout draft survives restart."):
		return
	var lead: Array = run.loadout.lanes[0].duplicate(true)
	game.run_return()
	await process_frame
	var assault := game.frontier_screen.find_child("RecruitLoadout_assault", true, false) as Button
	_check(assault != null and assault.visible and not assault.disabled, "The alternative assault kit is offered alongside support.")
	if not _press(game.frontier_screen, "RecruitLoadout_support"):
		return
	await process_frame
	if not _check(run.data.phase == "map" and run.data.heroes.size() == 2 and run.loadout.lanes.size() == 2,
		"Choosing support equips the recruit exactly once and returns to the map."):
		return
	var lane: Array = run.loadout.lanes[1]
	_check(run.loadout.lanes[0] == lead and run.data.heroes[1].id == recruit and lane.size() == 2
		and lane.map(func(tile: Dictionary): return tile.id) == kits[1].tiles and not run.choose_recruit_loadout("assault"),
		"Only the selected support tiles are equipped and the lead timeline stays intact.")
	if lane.size() != 2:
		return
	_check(lane[0].start == 0 and lane[1].start == ArenaSim.TILES[lane[0].id].width
		and lane[1].start + ArenaSim.TILES[lane[1].id].width <= ArenaSim.BEATS,
		"The two recruit tiles share a timeline without overlapping or exceeding its length.")
	var equipped := lane.duplicate(true)
	_check(run.load_save(save_path) and run.loadout.lanes[1] == equipped, "The recruit retains both selected tiles after reloading.")


func _finish_opening(run: FrontierRun) -> bool:
	return run.choose_relic(run.data.offers.front()) and run.choose_starter("bash") \
		and run.finish_combat(true, 85) and run.reward("skip")


func _stage_boss_on_map(run: FrontierRun) -> void:
	# Jump to the last camp after resolving the opening fight to isolate the boss and recruit flow.
	run.data.node = run.data.layers[BOSS_ROW - 1][0]


func _press(parent: Control, node_name: String) -> bool:
	var button := parent.find_child(node_name, true, false) as Button
	if not _check(button != null and button.is_visible_in_tree() and not button.disabled,
		"Expected an enabled %s button." % node_name):
		return false
	button.pressed.emit()
	return true


func _check(condition: bool, description: String) -> bool:
	if not condition:
		failures.append(description)
	return condition
