extends SceneTree

const Arena := preload("res://arena.tscn")
const ArenaSim := preload("res://scripts/arena_sim.gd")
const ClassDecks := preload("res://scripts/class_decks.gd")
const FrontierRun := preload("res://scripts/frontier_run.gd")
const RecruitLoadouts := preload("res://scripts/recruit_loadouts.gd")
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
	_check_recruit_kit_catalog()
	_check_seeded_recruit_kits()
	game.queue_free()
	await process_frame
	for base: String in [save_path, save_path + ".legacy", save_path + ".seeded"]:
		for suffix in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(base + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(base + suffix))
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Bellmaker setup, first-clear mastery, and recruit loadout progression passed.")
	quit(0 if failures.is_empty() else 1)


func _check_bellmaker_unlock(game: Control) -> String:
	var run: FrontierRun = game.run
	if not _check(run.start_run(BELLMAKER_SEED), "Start a fresh Brass Easy expedition."):
		return ""
	var first_preview := run.first_boss_preview()
	game.run_return()
	await process_frame
	var opening := game.frontier_screen.find_child("OpeningBossScout", true, false) as Label
	_check(first_preview.get("title") == "The Bellmaker" and opening == null,
		"The seeded Bellmaker assignment is kept without adding an opening draft preview.")
	var hero_id: String = run.data.offers.front()
	_check(game.frontier_screen.find_child("ChooseMasteryFor_" + hero_id, true, false) == null,
		"A fresh hero card does not advertise an unearned mastery.")
	if not _check(run.choose_hero(hero_id) and run.mastery_offers().is_empty()
		and not run.choose_mastery("anchor_ward") and _finish_opening(run),
		"A fresh hero cannot select a mastery and can still reach the route."):
		return ""
	_stage_boss_on_map(run)
	game.run_return()
	await process_frame
	var route := game.frontier_screen.find_child("BellmakerBossNode", true, false) as Button
	_check(route != null and route.visible and route.text.contains("Bellmaker"),
		"The map labels the Bellmaker's boss node.")
	if not _press(game.frontier_screen, "BellmakerBossNode"):
		return ""
	await process_frame
	_check(run.encounter().get("boss_id") == "brass_bellmaker" and game.campaign and game.encounter_setup
		and game.sim.units.any(func(unit: Dictionary): return unit.get("attack_id") == "brass_bellmaker"),
		"Choosing the boss node opens the arena with the Bellmaker ready to fight.")
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
	if not _check(run.start_run(BELLMAKER_SEED, "medium") and hero_id in run.data.offers,
		"The mastered class can start a new Medium expedition."):
		return
	await _check_compact_mastery_choices(game, "ChooseHero_")
	if not _press(game.frontier_screen, "ChooseHero_" + hero_id):
		return
	await process_frame
	_check(run.data.phase == "relic" and game.frontier_screen.find_child("ChooseClassMastery", true, false) != null,
		"The ordinary hero action goes straight to relics with the existing mastery option.")
	if not _check(run.abandon_run() and run.start_run(BELLMAKER_SEED, "medium"), "Restart the draft to try its direct mastery action."):
		return
	game.run_return()
	await process_frame
	if not _press(game.frontier_screen, "ChooseMasteryFor_" + hero_id):
		return
	await process_frame
	var masteries := run.mastery_offers()
	if not _check(run.data.phase == "relic" and run.data.hero == hero_id and masteries.size() == 2
		and masteries[0].id != masteries[1].id and run.selected_mastery().is_empty()
		and game.frontier_screen.find_child("MasteryOption_" + str(masteries[0].id), true, false) != null,
		"The mastered hero card selects the class and opens its two optional mastery choices."):
		return
	if not _press(game.frontier_screen, "ContinueMasteryDraft"):
		return
	await process_frame
	_check(run.selected_mastery().is_empty(), "Continuing straight to relics leaves the optional mastery unselected.")
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
	if not _check(run.finish_combat(true, 61), "The Medium Bellmaker grants a Legendary tile before its relics."):
		return
	game.run_return()
	if not _check(game.run_send_reward_to_storage(run.data.offers.front()), "Store the reward so its receipt is present on the recruit draft."):
		return
	var relics := run.boss_relic_offers().map(func(offer: Dictionary): return offer.id)
	relics.sort()
	if not _check(relics == ["bellmaker_clapper", "bellmaker_long_echo", "bellmaker_resonant_plate"]
		and not run.choose_boss_relic("guild_ledger") and run.choose_boss_relic("bellmaker_clapper"),
		"The Bellmaker offers three distinctive relics before recruitment."):
		return
	var recruit: String = run.data.offers.front()
	run.profile.mastered_classes.append(recruit)
	await _check_compact_mastery_choices(game, "ChooseRecruit_")
	if not _press(game.frontier_screen, "ChooseMasteryFor_" + recruit):
		return
	await process_frame
	var recruit_masteries := run.mastery_offers()
	if not _check(run.data.phase == "recruit_starter" and recruit_masteries.size() == 2,
		"The mastered recruit card opens mastery selection before loadouts."):
		return
	var recruit_mastery: String = recruit_masteries[0].id
	if not _press(game.frontier_screen, "MasteryOption_" + recruit_mastery):
		return
	await process_frame
	var kits := run.recruit_loadout_offers()
	if not _check(kits.size() == 2 and kits[0].id != kits[1].id and kits[0].tiles != kits[1].tiles,
		"The recruit gets two mechanically distinct loadouts."):
		return
	var legacy := FrontierRun.new()
	if _check(legacy.load_save(save_path), "Read a separate copy of the saved recruit draft."):
		legacy.save_path = save_path + ".legacy"
		legacy.data.erase("recruit_kits")
		_check(legacy.save() and legacy.load_save(legacy.save_path) \
			and legacy.recruit_loadout_offers() == RecruitLoadouts.choices(recruit).slice(0, 2),
			"A pending two-kit save still shows its original Assault and Support cards in order.")
		legacy.data.erase("recruit_loadouts")
		_check(legacy.save() and legacy.load_save(legacy.save_path) and legacy.recruit_loadout_offers().is_empty()
			and legacy.choose_recruit_starter(ClassDecks.starter(recruit)) and legacy.loadout.lanes[1].size() == 1,
			"An existing one-tile recruit draft remains playable.")
	if not _check(run.load_save(save_path) and run.recruit_loadout_offers() == kits and run.selected_mastery() == recruit_mastery,
		"The recruit loadout draft and optional mastery survive restart."):
		return
	var unoffered := RecruitLoadouts.choices(recruit).filter(func(kit: Dictionary): return kit not in kits)
	_check(unoffered.size() == 1 and not run.choose_recruit_loadout(unoffered[0].id) \
		and run.recruit_loadout_offers() == kits and run.loadout.lanes.size() == 1,
		"A known kit outside the saved pair cannot change the draft or roster.")
	var lead: Array = run.loadout.lanes[0].duplicate(true)
	game.run_return()
	await process_frame
	for kit: Dictionary in kits:
		var button := game.frontier_screen.find_child("RecruitLoadout_" + str(kit.id), true, false) as Button
		if not _check(button != null and button.is_visible_in_tree() and not button.disabled, "Both recruit kits can be equipped."):
			return
		var durations := button.get_parent().find_children("BeatSquares", "HBoxContainer", true, false)
		_check(durations.size() == kit.tiles.size(), "Every recruit tile shows its duration.")
		for index in mini(durations.size(), kit.tiles.size()):
			_check(durations[index].get_child_count() == ArenaSim.TILES[kit.tiles[index]].width,
				"Each occupied beat is represented by one duration square.")
	if not _press(game.frontier_screen, "RecruitLoadout_" + str(kits[1].id)):
		return
	await process_frame
	if not _check(run.data.phase == "map" and run.data.heroes.size() == 2 and run.loadout.lanes.size() == 2,
		"Choosing the second offered kit equips the recruit exactly once and returns to the map."):
		return
	var lane: Array = run.loadout.lanes[1]
	_check(run.loadout.lanes[0] == lead and run.data.heroes[1].id == recruit and run.data.heroes[1].mastery == recruit_mastery and lane.size() == 2
		and lane.map(func(tile: Dictionary): return tile.id) == kits[1].tiles and not run.choose_recruit_loadout(kits[0].id),
		"Only the selected kit's tiles are equipped and the lead timeline stays intact.")
	if lane.size() != 2:
		return
	_check(lane[0].start == 0 and lane[1].start == ArenaSim.TILES[lane[0].id].width
		and lane[1].start + ArenaSim.TILES[lane[1].id].width <= ArenaSim.BEATS,
		"The two recruit tiles share a timeline without overlapping or exceeding its length.")
	var equipped := lane.duplicate(true)
	_check(run.load_save(save_path) and run.loadout.lanes[1] == equipped, "The recruit retains both selected tiles after reloading.")


func _check_compact_mastery_choices(game: Control, choose_prefix: String) -> void:
	var run: FrontierRun = game.run
	var mastered: Array = run.profile.mastered_classes
	var original_scale := root.content_scale_mode
	var original_size := root.size
	run.profile.mastered_classes = run.data.offers.duplicate()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(856, 535)
	game.run_return()
	await process_frame
	await process_frame
	for id: String in run.data.offers:
		for prefix: String in [choose_prefix, "ClassDeck_", "ChooseMasteryFor_"]:
			var button := game.frontier_screen.find_child(prefix + id, true, false) as Button
			var area := button.get_global_rect() if button != null else Rect2()
			_check(button != null and button.is_visible_in_tree() and root.get_visible_rect().encloses(area),
				"%s fits inside the compact draft with all three masteries available (%s in %s)." % [prefix + id, area, root.get_visible_rect()])
	run.profile.mastered_classes = mastered
	root.size = original_size
	root.content_scale_mode = original_scale
	game.run_return()
	await process_frame
	await process_frame


func _check_recruit_kit_catalog() -> void:
	for hero: String in FrontierRun.HEROES:
		var options := RecruitLoadouts.choices(hero)
		_check(options.map(func(kit: Dictionary): return kit.id) == ["assault", "support", "specialty"],
			"Each kit has a stable ID for %s." % hero)
		var timelines := {}
		for kit: Dictionary in options:
			var width := 0
			var damage := 0
			for id: String in kit.tiles:
				var spec: Dictionary = ArenaSim.TILES.get(id, {})
				if _check(not spec.is_empty() and not spec.targets.is_empty(), "%s can equip %s." % [hero, id]):
					width += int(spec.width)
					damage += int(spec.damage)
			_check(kit.tiles.size() == 2 and not str(kit.label).is_empty() and not str(kit.description).is_empty() \
				and width <= ArenaSim.BEATS and damage > 0, "%s's %s is a legal two-tile combat loadout." % [hero, kit.label])
			timelines[str(kit.tiles)] = true
		_check(timelines.size() == 3, "%s's three kits offer different sequences." % hero)


func _check_seeded_recruit_kits() -> void:
	var run := FrontierRun.new()
	run.load_save(save_path + ".seeded")
	run.profile.medium_unlocked = true
	run.profile.hard_unlocked = true
	var variants := [{}, {}]
	var original: Array = []
	for seed in range(1, 17):
		var drafts := _draft_seeded_kits(run, seed, "brass")
		if seed == 1:
			original = drafts
		for act in range(drafts.size()):
			var pair: Array = drafts[act].kits.duplicate()
			pair.sort()
			variants[act][str(pair)] = true
	_check(variants[0].size() == 3 and variants[1].size() == 3,
		"All three kit pairs can appear in both the Act II and Act III recruit drafts.")
	_check(_draft_seeded_kits(run, 1, "brass") == original and original.size() == 2,
		"The same seed repeats both recruited classes and their ordered kit pairs.")
	for region: String in ["glass", "crown", "moonwreck"]:
		run.profile[region + "_hard_unlocked"] = true
		_check(_draft_seeded_kits(run, 7, region).size() == 2,
			"The %s region also rolls kits at both existing recruit checkpoints." % region)


func _draft_seeded_kits(run: FrontierRun, seed: int, region: String) -> Array:
	if not run.data.is_empty() and not run.abandon_run():
		return []
	if not _check(run.start_run(seed, "hard", region) and run.choose_preferred_hero("warden") and _finish_opening(run),
		"Begin the Hard %s recruit fixture." % region):
		return []
	_check(run.recruit_loadout_offers().is_empty() and not run.data.has("recruit_kits"),
		"The lead does not receive a recruit kit draft.")
	var observed: Array = []
	for act in range(1, 3):
		var boss_row: int = FrontierRun.NODES_PER_SEGMENT * act - 1
		run.data.node = run.data.layers[boss_row - 1][0]
		var boss: Dictionary = run.data.layers[boss_row][0]
		var hp: Array = run.data.heroes.map(func(hero: Dictionary): return hero.hp)
		if not _check(run.choose_node(boss.id) and run.finish_combat(true, hp), "Win the Act %d boss." % act):
			break
		for _hero_index in range(act):
			_check(run.reward("skip"), "Resolve each boss trophy before recruiting.")
		if run.data.phase == "boss_relic":
			_check(run.choose_boss_relic("skip"), "Resolve the intermediate boss relic before recruiting.")
		if not _check(run.data.phase == "recruit" and not run.data.has("recruit_kits"), "Reach the new hero draft before its kits."):
			break
		var recruit: String = run.data.offers.front()
		if not _check(run.choose_recruit(recruit), "Choose an offered recruit after Act %d." % act):
			break
		var kits := run.recruit_loadout_offers()
		var ids := kits.map(func(kit: Dictionary): return kit.id)
		if not _check(ids.size() == 2 and ids[0] != ids[1] and ids == run.data.recruit_kits \
				and kits.all(func(kit: Dictionary): return kit in RecruitLoadouts.choices(recruit)),
				"Act %d must offer exactly two different kits from the recruit's class." % act):
			break
		if not _check(run.load_save(run.save_path) and run.recruit_loadout_offers() == kits,
			"Reload the same two pending kits in their original order at both recruit checkpoints."):
			break
		observed.append({"hero": recruit, "kits": ids})
		var selected: Dictionary = kits[ids.find("specialty")] if "specialty" in ids else kits[0]
		var previous_lanes: Array = run.loadout.lanes.duplicate(true)
		if not _check(run.choose_recruit_loadout(selected.id) and run.load_save(run.save_path) and run.data.heroes.size() == act + 1 \
				and run.loadout.lanes.slice(0, act) == previous_lanes \
				and run.loadout.lanes[act].map(func(tile: Dictionary): return tile.id) == selected.tiles \
				and not run.data.has("recruit_kits") and run.recruit_loadout_offers().is_empty(),
			"Confirm the selected kit once and preserve its ordered tiles through reload."):
			break
	return observed


func _finish_opening(run: FrontierRun) -> bool:
	return run.choose_relic(run.data.offers.front()) \
		and run.choose_starter("bash" if "bash" in run.data.offers else ClassDecks.starter(run.data.hero)) \
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
