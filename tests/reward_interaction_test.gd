extends SceneTree

const Arena = preload("res://arena.tscn")
const ArenaSim = preload("res://scripts/arena_sim.gd")
const FrontierRun = preload("res://scripts/frontier_run.gd")
const TilePacking = preload("res://scripts/tile_packing.gd")
var failures: Array[String] = []
var paths: Array[String] = []
var game: Control


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 900)
	game = Arena.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	await _click_reward_equips()
	await _full_lane_stores()
	await _full_inventory_and_save_failure()
	await _rest_forge_one_copy()
	await _relic_labels()
	game.queue_free()
	await process_frame
	for path in paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Single-click reward equip/storage, full-inventory/save safeguards, borderless choices, storage expansion and direct rest upgrades passed.")
	quit(0 if failures.is_empty() else 1)


func _fixture() -> FrontierRun:
	var run := FrontierRun.new()
	var path := "user://reward-interaction-%d-%d.json" % [Time.get_ticks_usec(), paths.size()]
	paths.append(path)
	run.load_save(path)
	_check(run.start_run(42), "A fresh fixture starts.")
	run.data.offers = ["warden"]
	_check(run.choose_hero("warden") and run.choose_relic("pocket_bell")
		and run.choose_starter("shield_tap") and run.finish_combat(true, 100), "Fixture reaches the first reward.")
	run.loadout.lanes = [[]]
	run.loadout.storage = [[], [], []]
	game.run = run
	game.campaign = false
	game.state = "setup"
	return run


func _click_reward_equips() -> void:
	var run := _fixture()
	var id: String = run.data.offers[0]
	game.run_return()
	await process_frame
	var action := game.frontier_screen.find_child("RewardTile_" + id, true, false) as Button
	_check(action != null and action.text.is_empty()
		and action.get_parent().get_theme_stylebox("panel") is StyleBoxEmpty,
		"A reward is borderless artwork with no separate storage CTA.")
	_check(game.storage_screen.visible and game.storage_screen._docked
		and game.storage_screen._heading.text == "STORAGE", "The named shared stash stays visible beside rewards.")
	await _proof("reward")
	await _press(game.storage_screen.find_child("ExpandStorage", true, false) as Button)
	_check(game.storage_screen.visible and not game.storage_screen._docked
		and game.storage_screen._tile_row_size == game.storage_screen._popup_tile_row_size,
		"Storage expands to the same exact tile dimensions as the timeline.")
	await _proof("storage")
	await _press(game.storage_screen.find_child("CloseStorage", true, false) as Button)
	_check(game.storage_screen._docked and game.storage_screen.visible, "Closing expanded reward storage returns the visible sidebar.")
	var body := action.get_parent().find_child("ChoiceDetails", true, false) as Control
	await _click_at(body.get_global_rect().get_center())
	_check(run.data.phase == "map" and run.loadout.lanes[0].size() == 1
		and run.loadout.lanes[0][0].id == id and run.loadout.lanes[0][0].start == 0
		and run.loadout.storage[0].is_empty(), "One body click equips the reward in the first fitting span and advances.")
	var restored := FrontierRun.new()
	_check(restored.load_save(run.save_path) and restored.loadout.lanes == run.loadout.lanes,
		"Automatic placement is saved immediately.")
	_check(not game.run_claim_reward(id) and run.loadout.lanes[0].size() == 1, "A repeated claim cannot duplicate the tile.")


func _full_lane_stores() -> void:
	var run := _fixture()
	run.loadout.lanes[0] = _filled(ArenaSim.BEATS)
	var id: String = run.data.offers.filter(func(value: String): return value != "jab")[0]
	game.run_return()
	await _press(game.frontier_screen.find_child("RewardTile_" + id, true, false) as Button)
	_check(run.data.phase == "map" and run.loadout.lanes[0].size() == ArenaSim.BEATS
		and run.loadout.storage[0].size() == 1 and run.loadout.storage[0][0].id == id,
		"A full recipient timeline automatically sends the chosen tile to storage.")
	var receipt := game.frontier_screen.find_child("RewardPlacement", true, false) as Label
	_check(receipt != null and receipt.text == "Stored · " + ArenaSim.TILES[id].label,
		"A passive storage receipt confirms the destination without a send button.")


func _full_inventory_and_save_failure() -> void:
	var run := _fixture()
	var id: String = run.data.offers.filter(func(value: String): return value != "jab")[0]
	run.loadout.lanes[0] = _filled(ArenaSim.BEATS)
	for row in range(TilePacking.STORAGE_ROWS):
		run.loadout.storage[row] = _filled(TilePacking.STORAGE_COLUMNS)
	var before := run.loadout.duplicate(true)
	game.run_return()
	await _press(game.frontier_screen.find_child("RewardTile_" + id, true, false) as Button)
	_check(run.data.phase == "reward" and run.loadout == before, "A full inventory retains the reward and every existing tile.")
	run.loadout.lanes[0] = []
	game.run_return()
	var path := run.save_path
	run.save_path = path + ".missing/save.json"
	await _press(game.frontier_screen.find_child("RewardTile_" + id, true, false) as Button)
	_check(run.data.phase == "reward" and run.loadout.lanes[0].is_empty() and not run.save_error.is_empty(),
		"A failed save rolls back the automatic equip and preserves the same reward.")
	run.save_path = path
	await _press(game.frontier_screen.find_child("RewardTile_" + id, true, false) as Button)
	_check(run.data.phase == "map" and run.loadout.lanes[0].size() == 1, "Retry claims and saves the reward exactly once.")


func _rest_forge_one_copy() -> void:
	var run := _fixture()
	run.data.phase = "rest"
	run.data.node = run.data.layers[FrontierRun.NODES_PER_SEGMENT - 2][0]
	run.profile.meta.clear()
	var checked := 0
	for id: String in ArenaSim.TILES:
		var options := TilePacking.next_options(id)
		if options.is_empty():
			continue
		run.loadout.lanes[0] = [_tile(id, 0)]
		_check(not run.camp_forge_plan({"id": id, "lane": 0, "start": 0}, options[0]).is_empty(),
			"Rest can advance a single owned %s before any reward-pool unlock." % id)
		checked += 1
	_check(checked > 500, "Direct rest eligibility covers every non-Legendary catalog variant.")
	run.loadout.lanes[0] = [_tile("jab", 0)]
	run.loadout.storage[0] = [_tile("blink", 0)]
	run.data.enchantments = ["guarded"]
	run.loadout.storage[0][0].enchantment = "guarded"
	game.run_rest_forge()
	await process_frame
	await _press(game.storage_screen.find_child("StoredTile_blink_0_0", true, false) as Button)
	_check(game.forge_screen.visible and not game.forge_screen._is_combine
		and game.forge_screen.find_child("ForgeMergeIntro", true, false) == null,
		"One click on a stored tile opens direct next-tier paths without combining copies.")
	await _proof("forge")
	_check(game.forge_screen._direct_pick and not game.forge_screen._confirm.visible,
		"The rest forge needs no extra Upgrade confirmation after choosing a path.")
	await _press(game.forge_screen._cards["phase_cut"])
	_check(run.data.phase == "map" and run.loadout.storage[0].size() == 1
		and run.loadout.storage[0][0].id == "phase_cut" and run.loadout.lanes[0][0].id == "jab"
		and run.loadout.storage[0][0].get("enchantment") == "guarded",
		"Rest upgrades only the chosen copy, keeps its compatible enchantment and consumes one rest action.")
	var restored := FrontierRun.new()
	_check(restored.load_save(run.save_path) and restored.loadout.storage[0] == run.loadout.storage[0],
		"The one-click upgrade and its enchantment persist together.")
	_check(not run.choose_camp_upgrade({"id": "phase_cut", "row": 0, "start": 0}, "rift_lunge"),
		"The same rest site cannot be spent twice.")
	run.data.phase = "rest"
	run.loadout.lanes[0] = [_tile("blink", 0), _tile("blink", 3), _tile("blink", 6)]
	run.loadout.storage = [[], [], []]
	game.run_rest_forge()
	await process_frame
	await _press(game.tile_cards[0][0].get_child(0) as Button)
	_check(game.forge_screen.visible and game.forge_screen._direct_pick and not game.forge_screen._is_combine,
		"A rest tile click takes precedence over an adjacent matching triple.")
	await _press(game.forge_screen._cards["phase_cut"])
	_check(run.loadout.lanes[0].size() == 3 and run.loadout.lanes[0][0].id == "phase_cut"
		and run.loadout.lanes[0][1].id == "blink" and run.loadout.lanes[0][2].id == "blink",
		"The rest action advances only the clicked copy, leaving its two matching neighbors intact.")


func _relic_labels() -> void:
	var run := _fixture()
	for layer: Array in run.data.layers:
		var elites := layer.filter(func(node: Dictionary): return node.type == "elite")
		if not elites.is_empty():
			run.data.node = elites[0]
			break
	run.data.phase = "combat"
	_check(run.finish_combat(true, 100), "An elite fixture yields a relic draft.")
	game.run_return()
	await process_frame
	var text := _texts(game.frontier_screen)
	_check(not ["Fits your build", "Fit your build", "Pivot", "Wildcard", "Closest fit", "Long-term pivot"].any(
		func(value: String): return value in text), "Relic choices omit fit, pivot and wildcard direction labels.")


func _filled(capacity: int) -> Array:
	var result := []
	for index in range(capacity):
		result.append(_tile("jab", index))
	return result


func _tile(id: String, start: int) -> Dictionary:
	return {"id": id, "start": start, "target": ArenaSim.TILES[id].targets[0]}


func _press(button: Button) -> void:
	await process_frame
	if not _check(button != null and button.is_visible_in_tree() and not button.disabled, "The intended choice is visible and interactive."):
		return
	await _click_at(button.get_global_rect().get_center())


func _click_at(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame
	await process_frame


func _proof(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(OS.get_environment("TEMP").path_join("brass-reward-" + label + ".png"))


func _texts(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node is Label or node is Button:
		result.append(node.text)
	for child in node.get_children():
		result.append_array(_texts(child))
	return result


func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
	return condition
