extends SceneTree

const Arena := preload("res://arena.tscn")
const ArenaSim := preload("res://scripts/arena_sim.gd")
const FrontierRun := preload("res://scripts/frontier_run.gd")
const TilePacking := preload("res://scripts/tile_packing.gd")
const TileEnchantments := preload("res://scripts/tile_enchantments.gd")
const TEST_SEED := 81243

var failures: Array[String] = []
var save_path := "user://expedition-menu-test-%d.json" % Time.get_ticks_usec()
var game: Control
var menu: Control
var chart: Control


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game = Arena.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.run.load_save(save_path)
	game.run.profile.marks = 60
	game.run_menu()
	menu = game.frontier_screen.find_child("ExpeditionMenu", true, false)
	chart = game.frontier_screen.find_child("AetherChartMenu", true, false)
	_check(menu != null and chart != null, "Title and chart must be integrated in the actual game scene.")
	if menu != null and chart != null:
		await _check_navigation()
		await _check_chart()
		await _check_brass_medium_routes()
		await _check_slam_at_rest()
		await _check_practice_retry()
		await _check_crown_entry()
		await _check_moonwreck_entry()
		await _check_glass_hard_entry()
		await _check_enchantment_reward()
		await _check_class_roster()
		await _check_save_slots()
	game.queue_free()
	await process_frame
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Expedition menu, saved run resume, and Aether Chart checks passed.")
	quit(0 if failures.is_empty() else 1)


func _check_save_slots() -> void:
	var folder := "user://menu-slots-%d" % Time.get_ticks_usec()
	var directory := ProjectSettings.globalize_path(folder)
	_check(DirAccess.make_dir_absolute(directory) == OK, "Use a separate folder for the save slot test.")
	var legacy := FrontierRun.new()
	var old_path := folder.path_join("frontier-save.json")
	legacy.load_save(old_path)
	legacy.profile.marks = 37
	legacy.profile.meta = ["stout_start"]
	legacy.profile.hard_unlocked = true
	_check(legacy.start_run(991) and legacy.choose_hero(legacy.data.offers[0]), "Write a legacy Slot 1 and backup.")
	var run: FrontierRun = game.run
	_check(run.load_active_save_slot(folder) and run.save_path == old_path and run.active_save_slot == 1,
		"With no slot index, startup opens the existing Slot 1 file directly.")
	game.run_menu()
	_check(menu.find_child("NewGame", true, false) == null, "The title has no separate destructive New Game action.")
	await _press_named(menu, "SaveSlots")
	_check(menu.find_children("SaveSlot_*", "Button", true, false).size() == 3
		and menu.find_children("ResetSaveSlot_*", "Button", true, false).size() == 1,
		"Save slots offers three independent slots and a reset action only for occupied Slot 1.")
	await _press_named(menu, "SaveSlot_2")
	_check(run.active_save_slot == 2 and run.data.is_empty() and run.profile == FrontierRun.DEFAULT_PROFILE,
		"Selecting an empty slot opens its blank profile.")
	await _press_named(menu, "NewExpedition")
	await _press_named(menu, "Region_brass")
	await _press_named(menu, "Difficulty_easy")
	var new_seed: int = run.data.get("seed", 0)
	_check(run.active_save_slot == 2 and run.data.phase == "hero" and run.data.hp == 100
		and run.profile == FrontierRun.DEFAULT_PROFILE, "A blank slot starts a fresh Brass Easy hero draft.")
	game.run_save_title()
	await _press_named(menu, "SaveSlots")
	await _press_named(menu, "SaveSlot_3")
	_check(run.active_save_slot == 3 and run.data.is_empty() and run.profile == FrontierRun.DEFAULT_PROFILE,
		"Selecting the remaining blank slot starts with neither an expedition nor unlocked progress.")
	_check(run.start_run(300), "Create an independent expedition in Slot 3.")
	game.run_save_title()
	await _press_named(menu, "SaveSlots")
	await _press_named(menu, "SaveSlot_1")
	_check(run.active_save_slot == 1 and run.data.seed == 991 and run.profile.marks == 37,
		"Switching back restores the original expedition and Marks in Slot 1.")
	var blocked_index := ProjectSettings.globalize_path(folder.path_join(FrontierRun.SLOT_INDEX_FILE + ".tmp"))
	_check(DirAccess.make_dir_absolute(blocked_index) == OK, "Block the slot index write for the recovery check.")
	_check(not run.start_new_game_in_slot(1, true, 1529) and not run.select_save_slot(3)
		and run.active_save_slot == 1 and run.save_path == old_path and run.data.seed == 991 and run.profile.marks == 37,
		"A failed slot switch or reset leaves the active profile and original checkpoint intact.")
	_check(DirAccess.remove_absolute(blocked_index) == OK, "Unblock the slot index write.")
	var restored := FrontierRun.new()
	_check(restored.load_active_save_slot(folder) and restored.active_save_slot == 1 and restored.data.seed == 991,
		"Restart still resolves to the original slot after a failed index write.")
	game.run_menu()
	await _press_named(menu, "SaveSlots")
	var scale := root.content_scale_mode
	var window_size := root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(856, 535)
	await process_frame
	await process_frame
	for button: Button in menu.find_children("ResetSaveSlot_*", "Button", true, false):
		_check(root.get_visible_rect().encloses(button.get_global_rect()), "Each occupied slot’s reset action fits at compact width.")
	root.content_scale_mode = scale
	root.size = window_size
	await _press_named(menu, "ResetSaveSlot_1")
	var confirmation := menu.find_child("ConfirmSaveSlotReset", true, false) as ConfirmationDialog
	_check(confirmation != null and confirmation.visible and run.data.seed == 991 and run.profile.marks == 37,
		"Reset Save Slot requires explicit confirmation before the reset.")
	if confirmation != null:
		confirmation.canceled.emit()
		await process_frame
		_check(run.data.seed == 991 and run.profile.marks == 37 and not run.start_new_game_in_slot(1),
			"Cancel preserves the expedition and profile, and an unconfirmed occupied reset is rejected.")
		await _press_named(menu, "ResetSaveSlot_1")
		confirmation = menu.find_child("ConfirmSaveSlotReset", true, false) as ConfirmationDialog
	if confirmation != null:
		confirmation.confirmed.emit()
		await process_frame
		_check(run.active_save_slot == 1 and run.data.phase == "hero" and run.profile == FrontierRun.DEFAULT_PROFILE,
			"Confirming an occupied slot resets all of that slot's progress.")
		_check(run.save(), "Create a backup of the fresh profile.")
		var primary := FileAccess.open(run.save_path, FileAccess.WRITE)
		if primary != null:
			primary.store_string("broken save")
			primary.close()
		var invalid_index := ConfigFile.new()
		invalid_index.set_value("slots", "active", 8)
		invalid_index.save(folder.path_join(FrontierRun.SLOT_INDEX_FILE))
		_check(restored.load_active_save_slot(folder) and restored.active_save_slot == 1
			and restored.data.phase == "hero" and restored.profile == FrontierRun.DEFAULT_PROFILE,
			"The save and index backups recover the fresh profile without restoring its old unlocks.")
		_check(restored.select_save_slot(2) and restored.data.seed == new_seed
			and restored.select_save_slot(3) and restored.data.seed == 300,
			"Resetting Slot 1 leaves Slot 2 and Slot 3 unchanged.")
		_check(restored.load_active_save_slot(folder) and restored.active_save_slot == 3 and restored.data.seed == 300,
			"The active slot persists across a restart.")
	for name: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)


func _check_navigation() -> void:
	_check(menu.is_visible_in_tree() and not chart.is_visible_in_tree(), "A fresh game opens on the title menu.")
	var hint := menu.find_child("NewExpeditionHint", true, false) as Label
	_check(hint != null and hint.is_visible_in_tree() and hint.text.contains("unlocks and Aether Marks"),
		"The title visibly explains the profile progress carried into a new expedition.")
	await _press_named(menu, "NewExpedition")
	_check(game.run.data.is_empty(), "Starting from the title must open region selection before creating a run.")
	_check_disabled(menu, "Region_glass", "Locked")
	_check_disabled(menu, "Region_crown", "Locked")
	_check_disabled(menu, "Region_moonwreck", "Locked")
	_check(menu.find_children("LockBadge", "Control", true, false).size() == 3,
		"The three locked regions each show an art overlay lock.")
	await _press_named(menu, "Back")
	await _press_named(menu, "NewExpedition")
	await _press_named(menu, "Region_brass")
	_check(game.run.data.is_empty(), "Selecting a region must open difficulty selection before creating a run.")
	_check_disabled(menu, "Difficulty_medium", "Locked")
	_check_disabled(menu, "Difficulty_hard", "Locked")
	_check(menu.find_children("LockBadge", "Control", true, false).size() == 2,
		"Only the locked difficulties show art overlay locks.")
	var seed := menu.find_child("RunSeed", true, false) as LineEdit
	_check(seed != null, "Difficulty selection exposes the optional run seed.")
	if seed != null:
		seed.text = "0"
		seed.text_changed.emit(seed.text)
		_check_disabled(menu, "Difficulty_easy", "Start Easy")
		seed.text = str(TEST_SEED)
		seed.text_changed.emit(seed.text)
	await _press_named(menu, "Difficulty_easy")
	_check(game.run.data.get("phase") == "hero", "An available difficulty starts the hero draft.")
	_check(game.run.data.get("location") == "brass" and game.run.data.get("difficulty") == "easy",
		"The chosen region and difficulty must reach the run model.")
	_check(game.run.data.get("seed") == TEST_SEED, "The optional seed must reach the run model.")
	if game.run.data.get("phase") != "hero":
		return
	_check(game.frontier_screen.find_child("ChooseStarterFromRoster", true, false) == null,
		"The first expedition starts with a three-class draft.")
	await _press_text(game.frontier_screen, "Choose")
	_check(game.run.data.get("phase") == "relic", "Choosing a hero advances the draft.")
	await _press_text(game.frontier_screen, "Save & title")
	_check(menu.is_visible_in_tree(), "Save & title returns from a draft to the title.")
	var restored := FrontierRun.new()
	_check(restored.load_save(save_path) and restored.data.get("phase") == "relic",
		"The latest draft phase is saved on disk.")
	await _press_named(menu, "ContinueRun")
	_check(game.run.data.get("phase") == "relic" and not menu.is_visible_in_tree(),
		"Continue reopens the saved draft.")
	await _press_text(game.frontier_screen, "Save & title")


func _check_chart() -> void:
	if game.run.data.is_empty():
		_check(game.run.start_run(TEST_SEED), "Active-run chart test needs a started expedition.")
		game.run_menu()
	await _press_named(menu, "AetherChart")
	_check(chart.is_visible_in_tree() and not menu.is_visible_in_tree(), "Aether Chart opens from the title.")
	if not chart.is_visible_in_tree():
		return
	await _press_named(chart, "stout_start")
	var unlock := chart.find_child("UnlockUpgrade", true, false) as Button
	_check(unlock != null and unlock.disabled, "Upgrades cannot be purchased during an active run.")
	var marks := int(game.run.profile.marks)
	chart.purchase_requested.emit("stout_start")
	_check(game.run.profile.marks == marks and "stout_start" not in game.run.profile.meta,
		"The run model also rejects an active-run purchase.")
	_check(game.run.abandon_run(), "Close the test expedition before buying chart upgrades.")
	game.run_show_chart()
	await process_frame
	await _press_named(chart, "curated_cache")
	var details := chart.find_child("SelectedUpgrade", true, false) as Label
	_check(details != null and details.text == "Gravity Hook", "A locked graph node remains inspectable.")
	unlock = chart.find_child("UnlockUpgrade", true, false) as Button
	_check(unlock != null and unlock.disabled, "A locked upgrade cannot be purchased before its prerequisite.")
	await _press_named(chart, "stout_start")
	await _press_named(chart, "UnlockUpgrade")
	_check("stout_start" in game.run.profile.meta and int(game.run.profile.marks) == marks - 5,
		"Buying the selected starting upgrade deducts its exact cost.")
	await _press_named(chart, "curated_cache")
	await _press_named(chart, "UnlockUpgrade")
	_check("curated_cache" in game.run.profile.meta and int(game.run.profile.marks) == marks - 13,
		"Purchasing the prerequisite unlocks its downstream chart node.")
	await _press_named(chart, "wayfarers_pin")
	_check(details != null and details.text == "Wayfarer's Pin", "The new relic is visible before unlocking its prerequisite.")
	unlock = chart.find_child("UnlockUpgrade", true, false) as Button
	_check(unlock != null and unlock.disabled, "Wayfarer's Pin requires Blink Artifice.")
	await _press_named(chart, "blink_artifice")
	await _press_named(chart, "UnlockUpgrade")
	_check("blink_artifice" in game.run.profile.meta and int(game.run.profile.marks) == marks - 31,
		"Blink Artifice opens after Gravity Hook and costs 18 Marks.")
	await _press_named(chart, "wayfarers_pin")
	await _press_named(chart, "UnlockUpgrade")
	_check("wayfarers_pin" in game.run.profile.meta and int(game.run.profile.marks) == marks - 45,
		"Wayfarer's Pin opens after Blink Artifice and costs 14 Marks.")
	var restored := FrontierRun.new()
	_check(restored.load_save(save_path) and ["curated_cache", "blink_artifice", "wayfarers_pin"].all(func(id): return id in restored.profile.meta),
		"Artifice purchases persist across reload.")
	await _press_named(chart, "ChartBack")
	_check(menu.is_visible_in_tree() and not chart.is_visible_in_tree(), "Chart Back returns to the title.")


func _check_brass_medium_routes() -> void:
	game.run.profile.medium_unlocked = true
	game.run.profile.hard_unlocked = true
	game.run.profile.glass_easy_unlocked = true
	game.run_menu()
	await _press_named(menu, "NewExpedition")
	var glass := menu.find_child("Region_glass", true, false) as Button
	_check(glass != null and glass.has_focus() and not glass.disabled, "The new region should receive focus after a Brass Medium clear.")
	await _press_named(menu, "Region_glass")
	await _press_named(menu, "Difficulty_easy")
	_check(game.run.data.get("location") == "glass" and game.run.data.get("difficulty") == "easy",
		"The new Glass Foundry Easy route should open from the title.")
	_check(game.run.abandon_run(), "Close the test Glass expedition.")
	game.run_menu()
	await _press_named(menu, "NewExpedition")
	await _press_named(menu, "Region_brass")
	await _press_named(menu, "Difficulty_hard")
	_check(game.run.data.get("location") == "brass" and game.run.data.get("difficulty") == "hard",
		"Brass Frontier Hard should open from the title after Medium.")
	_check(game.run.abandon_run(), "Close the test Brass Hard expedition.")


func _check_practice_retry() -> void:
	var run = game.run
	_check(run.start_run(TEST_SEED), "Start a seeded expedition for practice retry.")
	_check(run.choose_hero(run.data.offers.front()) and run.choose_relic(run.data.offers.front())
		and run.choose_starter(run.data.offers.front()), "Draft the party for a practice retry.")
	game.run_return()
	await process_frame
	_check(game.campaign and game.encounter_setup and game.state == "setup" and game.arena_screen.is_visible_in_tree(),
		"Resuming a combat checkpoint opens battle setup directly.")
	var original: Dictionary = run.loadout.duplicate(true)
	var formation: Array = game.sim.units.duplicate(true)
	game._action()
	for step in range(6000):
		game._physics_process(1.0 / 60.0)
		if game.state == "finished":
			break
	_check(game.state == "finished", "The expedition fight must finish before practice retry.")
	var resolved: Dictionary = run.data.duplicate(true)
	var profile: Dictionary = run.profile.duplicate(true)
	game._complete_result_animation()
	var meter: Dictionary = game.combat_meter.snapshot()
	await _press_text(game.arena_screen, "Retry in Practice")
	_check(game.state == "setup" and not game.campaign and not game.fixture_picker.visible,
		"Retry should open an editable practice with the expedition's inventory only.")
	_check(game.sim.units == formation and game.lanes == original.lanes and game.storage_rows == original.storage,
		"Retry should use the same seeded formation, health, party, and pre-fight inventory.")
	game._place({"id": game.lanes[0][0].id, "lane": 0, "start": game.lanes[0][0].start}, 0, 7)
	game._action()
	for step in range(6000):
		game._physics_process(1.0 / 60.0)
		if game.state == "finished":
			break
	_check(run.data == resolved and run.profile == profile and run.loadout == original,
		"Edits and combat in practice must preserve the expedition result, profile, and equipment.")
	await _press_text(game.arena_screen, "Back to battle result")
	_check(game.arena.is_visible_in_tree() and game.campaign and game.state == "finished" and game.lanes == original.lanes
		and run.data == resolved and game.combat_meter.snapshot() == meter,
		"Leaving practice restores the original battlefield, equipment, and combat totals.")
	if resolved.phase == "reward":
		game.run_menu()
		var loaded: bool = run.load_save(save_path)
		game.run_resume()
		_check(loaded and game.combat_meter.snapshot() == meter,
			"Resuming the saved reward preserves the original combat totals.")
		var stored_id := str(run.data.offers.front())
		_check(game.storage_screen.is_visible_in_tree() and game.storage_screen.get_parent() == game.combat_sidebar,
			"A resumed reward opens storage beside the original battlefield.")
		await _press_named(game.frontier_screen, "RewardTile_" + stored_id)
		_check(run.data.phase == "map" and run.loadout.storage[0].any(func(tile: Dictionary): return tile.id == stored_id),
			"Sending a reward to storage stows the tile and returns to the route.")
	run.abandon_run()


func _check_slam_at_rest() -> void:
	game.run.profile.meta.clear()
	_check(game.run.start_run(42), "The Slam rest test needs a fresh expedition.")
	game.run.choose_hero(game.run.data.offers[0])
	game.run.choose_relic("pocket_bell")
	game.run.choose_starter(game.run.data.offers[0])
	game.run.data.phase = "rest"
	game.run.loadout.lanes[0].assign([game._entry("slam", 0, "nearest"),
		game._entry("slam", 4, "nearest"), game._entry("slam", 8, "nearest")])
	game.run_return()
	await _press_text(game.frontier_screen, "Open forge")
	var offers: Array = game._combine_offers(game.lanes[0])
	_check(offers.size() == 1 and offers[0].id == "slam", "Three touching Slams should offer a combine at the camp forge.")
	await _press_text(game.arena_screen, "Yes")
	_check(game.forge_screen.visible and game.forge_screen._cards.size() == 9,
		"Common Slam should show all nine tiles in its forge tree on a fresh profile.")
	game.forge_choose("shockwave")
	_check(game.lanes[0] == [game._entry("shockwave", 0, "nearest")] and game.run.data.phase == "rest",
		"Combining three Slams should save the chosen tile without consuming the rest action.")
	_check(TilePacking.next_options("shockwave") == TilePacking.next_options("sundering_slam")
		and TilePacking.next_options("quake") == TilePacking.next_options("armor_crush")
		and TilePacking.next_options("fault_line") == TilePacking.next_options("hammerfall"),
		"Slam's two options must lead to the same next tier from either branch.")
	game.storage_rows[0].assign([game._entry("slam", 0, "nearest")])
	game._open_storage()
	game.storage_pick(0, game.storage_rows[0][0])
	game.storage_forge()
	_check(game.forge_screen.visible, "The camp action should open the forge for a single stored Slam.")
	game.forge_choose("sundering_slam")
	var restored := FrontierRun.new()
	_check(restored.load_save(save_path) and restored.data.phase == "map"
		and restored.loadout.storage[0] == [game._entry("sundering_slam", 0, "nearest")],
		"Using the camp action should upgrade the stored Slam, save the result and return to the map.")
	_check(game.run.abandon_run(), "Close the test Slam expedition.")


func _check_crown_entry() -> void:
	game.run.profile.crown_easy_unlocked = true
	game.run_menu()
	await _press_named(menu, "NewExpedition")
	await _press_named(menu, "Region_crown")
	_check_disabled(menu, "Difficulty_medium", "Locked")
	_check_disabled(menu, "Difficulty_hard", "Locked")
	await _press_named(menu, "Difficulty_easy")
	_check(game.run.data.get("phase") == "hero" and game.run.data.get("location") == "crown"
		and game.run.data.get("difficulty") == "easy", "Crown Easy should start from the expedition menu after its unlock.")
	_check(game.run.abandon_run(), "Close the test Crown expedition.")
	game.run.profile.crown_medium_unlocked = true
	game.run_menu()
	await _press_named(menu, "NewExpedition")
	await _press_named(menu, "Region_crown")
	await _press_named(menu, "Difficulty_medium")
	_check(game.run.data.get("phase") == "hero" and game.run.data.get("location") == "crown"
		and game.run.data.get("difficulty") == "medium", "Crown Medium should start from the expedition menu after its unlock.")
	_check(game.run.abandon_run(), "Close the test Crown Medium expedition.")
	game.run.profile.crown_hard_unlocked = true
	game.run_menu()
	await _press_named(menu, "NewExpedition")
	await _press_named(menu, "Region_crown")
	await _press_named(menu, "Difficulty_hard")
	_check(game.run.data.get("phase") == "hero" and game.run.data.get("location") == "crown"
		and game.run.data.get("difficulty") == "hard", "Crown Hard should start from the expedition menu after its unlock.")
	_check(game.run.abandon_run(), "Close the test Crown Hard expedition.")


func _check_moonwreck_entry() -> void:
	game.run.profile.moonwreck_easy_unlocked = true
	game.run_menu()
	await _press_named(menu, "NewExpedition")
	await _press_named(menu, "Region_moonwreck")
	_check_disabled(menu, "Difficulty_medium", "Locked")
	_check_disabled(menu, "Difficulty_hard", "Locked")
	await _press_named(menu, "Difficulty_easy")
	_check(game.run.data.get("phase") == "hero" and game.run.data.get("location") == "moonwreck"
		and game.run.data.get("difficulty") == "easy", "Moonwreck Easy should start from the expedition menu after its unlock.")
	_check(game.run.abandon_run(), "Close the test Moonwreck expedition.")
	game.run.profile.moonwreck_medium_unlocked = true
	game.run_menu()
	await _press_named(menu, "NewExpedition")
	await _press_named(menu, "Region_moonwreck")
	await _press_named(menu, "Difficulty_medium")
	_check(game.run.data.get("phase") == "hero" and game.run.data.get("location") == "moonwreck"
		and game.run.data.get("difficulty") == "medium", "Moonwreck Medium should start from the expedition menu after its unlock.")
	_check(game.run.abandon_run(), "Close the test Moonwreck Medium expedition.")
	game.run.profile.moonwreck_hard_unlocked = true
	game.run_menu()
	await _press_named(menu, "NewExpedition")
	await _press_named(menu, "Region_moonwreck")
	await _press_named(menu, "Difficulty_hard")
	_check(game.run.data.get("phase") == "hero" and game.run.data.get("location") == "moonwreck"
		and game.run.data.get("difficulty") == "hard", "Moonwreck Hard should start from the expedition menu after its unlock.")
	_check(game.run.abandon_run(), "Close the test Moonwreck Hard expedition.")


func _check_glass_hard_entry() -> void:
	game.run.profile.glass_easy_unlocked = true
	game.run.profile.glass_medium_unlocked = true
	game.run_menu()
	await _press_named(menu, "NewExpedition")
	await _press_named(menu, "Region_glass")
	_check_disabled(menu, "Difficulty_hard", "Locked")
	game.run.profile.glass_hard_unlocked = true
	game.run_menu()
	await _press_named(menu, "NewExpedition")
	await _press_named(menu, "Region_glass")
	await _press_named(menu, "Difficulty_hard")
	_check(game.run.data.get("phase") == "hero" and game.run.data.get("location") == "glass"
		and game.run.data.get("difficulty") == "hard", "Glass Hard should start from the expedition menu after its unlock.")


func _check_enchantment_reward() -> void:
	var run: FrontierRun = game.run
	_check(run.abandon_run(), "Close the Glass expedition before spending Aether Marks.")
	run.profile.marks = 30
	game.run_show_chart()
	await _press_named(chart, "enchantments")
	var details := chart.find_child("SelectedUpgrade", true, false) as Label
	_check(details != null and details.text == "Tile Enchantments", "The Aether Chart shows the enchantment unlock.")
	var unlock := chart.find_child("UnlockUpgrade", true, false) as Button
	_check(unlock != null and unlock.disabled, "Tile Enchantments requires Gravity Hook.")
	await _press_named(chart, "stout_start")
	await _press_named(chart, "UnlockUpgrade")
	await _press_named(chart, "curated_cache")
	await _press_named(chart, "UnlockUpgrade")
	await _press_named(chart, "enchantments")
	var before := int(run.profile.marks)
	await _press_named(chart, "UnlockUpgrade")
	_check("enchantments" in run.profile.meta and int(run.profile.marks) == before - 8,
		"Unlocking enchantments from the chart spends eight Aether Marks.")
	run.profile.medium_unlocked = true
	if not (run.start_run(42, "medium", "brass") and run.choose_preferred_hero("warden") and run.choose_relic("pocket_bell")
		and run.choose_starter("shield_tap") and run.finish_combat(true, 80)):
		_check(false, "Prepare the opening Brass fight reward with enchantments unlocked.")
		return
	game.run_return()
	var reward_id: String = run.data.offers[0]
	await _drag_reward_to_timeline(reward_id, 4)
	_check(run.data.phase == "enchantment", "The enchantment draft follows the opening tile reward.")
	if run.data.phase != "enchantment":
		return
	_check(run.loadout.lanes[0][1].id == reward_id and run.loadout.lanes[0][1].start == 4,
		"The reward lands on the exact beat dropped before the enchantment draft.")
	var first_id := _find_enchantment_offer(run)
	if first_id.is_empty():
		_check(false, "The opening draft offers an enchantment compatible with Shield Tap and a ranged recruit.")
		return
	await _press_named(game.frontier_screen, "Enchantment_" + first_id)
	_check(run.data.phase == "map" and run.enchantments() == [first_id]
		and not run.loadout.lanes[0][0].has("enchantment"),
		"Choosing the enchantment in one click keeps it available and returns to the map.")
	await _press_text(game.frontier_screen, "Manage tiles")
	await _press_text(game.arena_screen, "Tile storage")
	await _select_enchantment_tile(0, 0)
	await _press_named(game.storage_screen, "EnchantSelected_" + first_id)
	var badge: Node = game.tile_cards[0][0].find_child("TileEnchantmentBadge", true, false)
	_check(badge != null and badge.get_meta("enchantment", "") == first_id,
		"An enchanted timeline tile shows the selected enchantment's badge.")
	if not _reach_second_enchantment(run):
		_check(false, "The first ordinary win with a recruit opens the second enchantment draft.")
		return
	game.run_return()
	var second_id := _find_enchantment_offer(run)
	if second_id.is_empty():
		_check(false, "The recruit draft offers a different enchantment compatible with Shield Tap and Shot.")
		return
	await _equip_draft_on_shot(second_id)
	_check(run.data.phase == "map" and run.enchantments() == [first_id, second_id],
		"Assigning from the second draft adds another distinct enchantment and returns to the map.")
	await _press_text(game.frontier_screen, "Manage tiles")
	await _press_text(game.arena_screen, "Tile storage")
	await _select_enchantment_tile(1, 0)
	var first: Dictionary = game.lanes[0][0]
	var second: Dictionary = game.lanes[1][0]
	_check(first.get("enchantment", "") == first_id and second.get("enchantment", "") == second_id,
		"Draft assignment and storage assignment can coexist on independent tiles.")
	var replace := game.storage_screen.find_child("EnchantSelected_" + first_id, true, false) as Button
	_check(replace != null and replace.text == "Replace", "Moving onto an occupied tile offers replacement.")
	await _press_named(game.storage_screen, "EnchantSelected_" + first_id)
	_check(not first.has("enchantment") and second.get("enchantment", "") == first_id
		and run.enchantments() == [first_id, second_id],
		"Moving an enchantment clears its old host and returns the replaced enchantment to storage.")
	await _press_named(game.storage_screen, "EnchantSelected_" + first_id)
	_check(not second.has("enchantment") and run.enchantments() == [first_id, second_id],
		"Removing the selected enchantment leaves both available to equip.")
	await _press_named(game.storage_screen, "EnchantSelected_" + first_id)
	await _select_enchantment_tile(0, 0)
	await _press_named(game.storage_screen, "EnchantSelected_" + second_id)
	var restored := FrontierRun.new()
	_check(restored.load_save(save_path) and restored.enchantments() == [first_id, second_id]
		and restored.loadout.lanes[0][0].get("enchantment", "") == second_id
		and restored.loadout.lanes[1][0].get("enchantment", "") == first_id,
		"The two held enchantments persist with their individual attached tiles.")


func _equip_draft_on_shot(id: String) -> void:
	var action := game.frontier_screen.find_child("EquipDraftEnchantment_" + id, true, false) as Button
	await _press_named(game.frontier_screen, "EquipDraftEnchantment_" + id)
	if action is MenuButton:
		var choices := (action as MenuButton).get_popup()
		_check(choices.visible, "The optional equip menu opens without claiming the enchantment.")
		var shot := -1
		for index in range(choices.item_count):
			var label: String = choices.get_item_text(index)
			_check(label != "Shield Tap · Warden · 1", "The equip menu leaves occupied tiles out of its choices.")
			if label.begins_with("Shot ·"):
				shot = choices.get_item_id(index)
		_check(shot >= 0, "The draft can equip the enchantment on the recruit's unoccupied Shot.")
		if shot >= 0:
			choices.id_pressed.emit(shot)
			choices.hide()
			await process_frame


func _find_enchantment_offer(run: FrontierRun) -> String:
	for offer: Dictionary in run.enchantment_offers():
		if TileEnchantments.is_eligible(offer.id, ArenaSim.TILES.shield_tap, "shield_tap") \
				and TileEnchantments.is_eligible(offer.id, ArenaSim.TILES.shot, "shot"):
			return offer.id
	return ""


func _reach_second_enchantment(run: FrontierRun) -> bool:
	run.data.node = run.data.layers[FrontierRun.NODES_PER_SEGMENT - 1][0]
	run.data.phase = "combat"
	if not (run.finish_combat(true, 100) and run.reward("skip") and run.choose_boss_relic("skip")
			and run.choose_recruit(run.data.offers[0]) and run.choose_recruit_starter("shot")):
		return false
	var nodes := run.available_nodes()
	return not nodes.is_empty() and run.choose_node(nodes[0].id) and run.finish_combat(true, [100, 100]) \
		and run.reward("skip") and run.reward("skip") and run.data.phase == "enchantment"


func _select_enchantment_tile(lane: int, start: int) -> void:
	await process_frame
	var tile_card: Control = game.tile_cards[lane][start]
	_click(tile_card.get_child(0) as Button, "the timeline tile for the enchantment")
	await process_frame


func _check_class_roster() -> void:
	var run: FrontierRun = game.run
	_check(run.abandon_run(), "Close the active run before unlocking a class.")
	run.profile.marks = 20
	game.run_show_chart()
	await _press_named(chart, "OpenClassRoster")
	var roster := game.frontier_screen.find_child("ClassRosterMenu", true, false) as Control
	_check(roster != null and roster.is_visible_in_tree(), "Open the class roster from the Aether Chart.")
	if roster == null or not roster.is_visible_in_tree():
		return
	await _press_named(roster, "ClassRoster_breaker")
	await _press_named(roster, "UnlockClass")
	var restored := FrontierRun.new()
	_check(restored.load_save(save_path) and "breaker" in restored.available_classes()
		and int(restored.profile.marks) == 14 and "wayfarer" not in restored.available_classes(),
		"The purchase adds only Breaker and spends six Aether Marks on disk.")
	await _press_named(roster, "BackFromClassRoster")
	_check(chart.is_visible_in_tree(), "Back from the class roster returns to the Aether Chart.")
	run.profile.mastered_classes = ["breaker"]
	_check(run.start_run(TEST_SEED), "Start an expedition with Breaker unlocked.")
	var draft: Array = run.data.offers.duplicate()
	game.run_return()
	await _press_named(game.frontier_screen, "ChooseStarterFromRoster")
	await _press_named(roster, "ClassRoster_wayfarer")
	var choose := roster.find_child("ChooseStarterClass", true, false) as Button
	_check(choose != null and choose.disabled and run.data.offers == draft,
		"Locked classes can be inspected but cannot be picked from the starter roster.")
	await _press_named(roster, "BackFromClassRoster")
	_check(run.data.phase == "hero" and run.data.offers == draft and not roster.is_visible_in_tree(),
		"Returning to Draft Three preserves the seeded choices.")
	await _press_named(game.frontier_screen, "ChooseStarterFromRoster")
	await _press_named(roster, "ClassRoster_breaker")
	await _press_named(roster, "ChooseRosterMastery")
	_check(run.data.phase == "relic" and run.data.hero == "breaker" and not run.mastery_offers().is_empty(),
		"The mastered class action in the full roster selects the class and opens its mastery choices.")
	await _press_named(game.frontier_screen, "ContinueMasteryDraft")
	_check(game.frontier_screen.find_child("ChooseClassMastery", true, false) != null and run.selected_mastery().is_empty(),
		"Skipping from the mastery screen enters the normal relic draft.")


func _press_text(parent: Control, prefix: String) -> void:
	await process_frame
	for control in parent.find_children("*", "Button", true, false):
		var button := control as Button
		if button.is_visible_in_tree() and button.text.begins_with(prefix):
			_click(button, prefix)
			await process_frame
			return
	_check(false, "Expected a visible button starting with “%s”." % prefix)


func _press_named(parent: Control, node_name: String) -> void:
	await process_frame
	var button := parent.find_child(node_name, true, false) as Button
	_click(button, node_name)
	await process_frame


func _click(button: Button, description: String) -> void:
	if button == null or not button.is_visible_in_tree() or button.disabled:
		_check(false, "Expected an enabled button for %s." % description)
		return
	for down in [true, false]:
		_push_button(button.get_global_rect().get_center(), down)


func _drag_reward_to_timeline(id: String, start: int) -> void:
	await process_frame
	var card := game.frontier_screen.find_child("DragReward_" + id, true, false) as Control
	if card == null or not card.is_visible_in_tree():
		_check(false, "Expected the reward tile to be draggable.")
		return
	var details := card.find_child("ChoiceDetails", true, false) as Control
	var source := details.get_global_rect().get_center()
	var board := game.lane_stack.get_child(0).get_child(1) as Control
	var target := board.global_position + Vector2(board.size.x * (start + 0.5) / ArenaSim.BEATS, board.size.y * 0.5)
	var threshold := source + Vector2(18, 0)
	_push_motion(source, source, false)
	_push_button(source, true)
	_push_motion(source, threshold, true)
	_push_motion(threshold, target, true)
	_check(root.gui_is_dragging(), "Dragging the reward body starts the tile drag.")
	_push_button(target, false)
	await process_frame


func _push_button(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	root.push_input(event, true)


func _push_motion(from: Vector2, to: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.relative = to - from
	if held:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)


func _check_disabled(parent: Control, node_name: String, caption: String) -> void:
	var button := parent.find_child(node_name, true, false) as Button
	_check(button != null and button.is_visible_in_tree() and button.disabled and button.text == caption,
		"%s should be visible and disabled with the label %s." % [node_name, caption])


func _check(passed: bool, description: String) -> void:
	if not passed:
		failures.append(description)
