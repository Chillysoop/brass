extends SceneTree

const ArenaScene = preload("res://arena.tscn")
const ArenaSim = preload("res://scripts/arena_sim.gd")
const FrontierRun = preload("res://scripts/frontier_run.gd")

const SAVE_PATH := "user://arena-checkpoint-test.json"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var lab = ArenaScene.instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	var run: FrontierRun = lab.run
	run.load_save(SAVE_PATH)
	if _check(run.start_run(42) and run.choose_hero("warden")
		and run.choose_relic(run.data.offers[0]) and run.choose_starter("bash"), "Start the real first fight with one tile."):
		_check_discard(lab)
		_check_battle_save(lab)
		_check_camp_save(lab)
		await _check_compact_reward_overlay(lab)
		_check_defeat_animation(lab)
		await _check_crowded_reward_drop(lab)
	lab.queue_free()
	await process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		var path := ProjectSettings.globalize_path(SAVE_PATH + suffix)
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Battle setup, save retry, compact rewards and rerolls, and camp forge rollback passed.")
	quit(0 if failures.is_empty() else 1)


func _check_discard(lab: Control) -> void:
	lab.run_resume()
	_check(lab.campaign and lab.encounter_setup and lab.state == "setup" and lab.arena_screen.is_visible_in_tree(),
		"Continuing a saved opening fight should open battle setup directly.")
	lab._open_storage()
	var first := {"id": "bash", "lane": 0, "start": 0}
	lab._select(first)
	var discard := lab.storage_screen.find_child("DiscardSelected", true, false) as Button
	discard.pressed.emit()
	_check(not lab.discard_dialog.visible and lab.lanes[0].size() == 1,
		"Discard selected must refuse to open confirmation for the last equipped tile.")
	lab.storage_place(0, 0, first)
	lab._action()
	_check(lab.state == "setup" and lab.storage_rows[0].size() == 1,
		"Moving the last tile to storage is allowed and prevents starting until it is equipped.")
	lab.storage_pick(0, lab.storage_rows[0][0])
	discard.pressed.emit()
	_check(not lab.discard_dialog.visible and lab.storage_rows[0].size() == 1,
		"The last tile cannot be discarded from storage either.")
	var stored := {"id": "bash", "lane": -1, "row": 0, "start": 0}
	if _set_save_block(true):
		lab._place(stored, 0, 2)
		_check(lab.lanes[0].is_empty() and lab.storage_rows[0].size() == 1 and not lab.run.save_error.is_empty(),
			"A rejected write rolls the tile move back to storage.")
		_set_save_block(false)
	lab._place(stored, 0, 2)
	var restored := FrontierRun.new()
	_check(restored.load_save(SAVE_PATH) and restored.loadout.lanes[0].size() == 1
		and restored.loadout.lanes[0][0].start == 2 and restored.loadout.storage[0].is_empty(),
		"A normal transfer restores the last tile to the timeline and saves its firing position.")


func _check_battle_save(lab: Control) -> void:
	var run: FrontierRun = lab.run
	var before := run.data.duplicate(true)
	if not _set_save_block(true):
		return
	lab.action.pressed.emit()
	for step in range(2600):
		lab._physics_process(1.0 / 60.0)
		if lab.state == "finished":
			break
	_check(lab.sim.outcome == "victory" and lab.action.text == "Retry save" and not lab.result_banner.visible,
		"An unwritten win should stay in the arena with Retry save instead of Victory.")
	_check(run.data == before and not run.save_error.is_empty(), "The failed win leaves the run at its prior checkpoint.")
	var completed_tick: int = lab.sim.tick
	_set_save_block(false)
	lab.action.pressed.emit()
	_check(lab.sim.tick == completed_tick and lab.result_banner.visible and lab.result_text.text.to_lower() == "victory",
		"Retry save records the result without replaying the battle.")
	var restored := FrontierRun.new()
	_check(restored.load_save(SAVE_PATH) and restored.data.phase == "reward" and restored.data.gold == int(before.gold) + 12,
		"Reload after retry grants the opening reward and its gold exactly once.")
	lab._complete_result_animation()
	_check(lab.showing_rewards and lab.arena.is_visible_in_tree() and lab.frontier_screen.is_visible_in_tree()
		and lab.frontier_screen.find_child("SkipReward", true, false) is Button,
		"The victory animation puts the draft and skip option over the arena without another click.")
	_check_reward_rerolls(lab)
	if not _set_save_block(true):
		return
	lab.save_title_button.pressed.emit()
	_check(lab.save_title_button.is_visible_in_tree() and lab.showing_rewards and not run.save_error.is_empty(),
		"Save & title reports a failed save on the current screen.")
	_set_save_block(false)
	lab.save_title_button.pressed.emit()
	_check(not lab.save_title_button.is_visible_in_tree() and run.save_error.is_empty(),
		"Save & title retries the write and opens the title when it succeeds.")


func _check_reward_rerolls(lab: Control) -> void:
	var run: FrontierRun = lab.run
	var gold := int(run.data.gold)
	for price in [5, 10]:
		var button := lab.frontier_screen.find_child("RerollReward", true, false) as Button
		if not _check(button != null and button.is_visible_in_tree() and not button.disabled
			and str(price) in button.text, "The award screen shows the cost of the next reroll."):
			return
		var original: Array = run.data.offers.duplicate()
		button.pressed.emit()
		gold -= price
		_check(lab.showing_rewards and int(run.data.gold) == gold and run.data.offers.size() == 3
			and run.data.offers != original, "A reroll replaces the three offers in place and deducts the displayed cost.")
	var stored := FrontierRun.new()
	if not _check(stored.load_save(SAVE_PATH) and stored.data.offers == run.data.offers and stored.reward_reroll_price() == 20,
		"The roll and doubled cost survive reloading the checkpoint."):
		return
	stored.data.segment += 1
	_check(stored.reward_reroll_price() == 5, "The first reward of the next act uses the starting price again.")


func _check_camp_save(lab: Control) -> void:
	var run: FrontierRun = lab.run
	run.data.phase = "rest"
	run.data.node = run.data.layers[-2][0].duplicate(true)
	run.data.offers = []
	if not _check(run.save(), "Save the camp checkpoint before trying the forge."):
		return
	lab.run_rest_forge()
	lab._select({"id": "bash", "lane": 0, "start": 2})
	lab.camp_button.pressed.emit()
	if not _check(lab.forge_screen.visible and _set_save_block(true), "Open the camp forge and block its write."):
		return
	lab.forge_choose("shield_ram")
	_check(lab.forge_screen.visible and run.data.phase == "rest" and lab.lanes[0][0].id == "bash"
		and not run.save_error.is_empty(), "A failed camp upgrade keeps Bash and the forge open.")
	_set_save_block(false)
	lab.forge_choose("shield_ram")
	var restored := FrontierRun.new()
	_check(restored.load_save(SAVE_PATH) and restored.data.phase == "map" and restored.loadout.lanes[0][0].id == "shield_ram",
		"A successful retry saves the upgrade and consumes the rest site together.")


func _check_compact_reward_overlay(lab: Control) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(856, 535)
	var run: FrontierRun = lab.run
	_check(run.abandon_run(), "Close the old checkpoint before checking the last act.")
	run.profile.hard_unlocked = true
	if not _check(run.start_run(42, "hard") and run.choose_hero("warden")
		and run.choose_relic("pocket_bell") and run.choose_starter("shield_tap"), "Prepare a Hard expedition for compact battle testing."):
		return
	run.data.segment = 3
	run.data.node = run._node("battle", "Compact patrol", FrontierRun.NODES_PER_SEGMENT * 2, 0)
	run.data.heroes.append({"id": "starshot", "hp": 100, "max_hp": 100})
	run.data.heroes.append({"id": "apothecary", "hp": 100, "max_hp": 100})
	run.loadout.lanes.append([{"id": "shot", "start": 0, "target": "nearest"}])
	run.loadout.lanes.append([{"id": "triage_kit", "start": 0, "target": "ally_lowest"}])
	run.loadout.defaults.append_array(["nearest", "nearest"])
	lab.run_return()
	await process_frame
	await process_frame
	var field: Rect2 = lab.arena.get_global_rect()
	var speed_group: Rect2 = lab.speed_controls.get_global_rect()
	_check(lab.speed_controls.is_visible_in_tree() and lab.speed_buttons.size() == 3
		and root.get_visible_rect().encloses(speed_group) and speed_group.end.y <= field.position.y,
		"All three playback controls stay in the top header at compact width.")
	var edge: float = lab.arena_screen.get_global_rect().end.x - lab.arena_screen.get_theme_constant("margin_right")
	_check(lab.arena_screen.find_child("BattleEnemyDetails", true, false) == null
		and not lab.combat_sidebar.is_visible_in_tree() and is_equal_approx(field.end.x, edge),
		"The compact arena uses the full width when the optional meter and reward storage are closed.")
	if not _check(run.finish_combat(true, [81, 88, 91]) and run.reward_count() == 3, "The compact arena has three reward lanes."):
		return
	lab.run_return()
	lab.combat_meter_toggle.set_pressed_no_signal(true)
	lab.combat_meter_toggle.pressed.emit()
	await process_frame
	await process_frame
	var visible_field: Rect2 = lab.arena.get_global_rect().intersection(root.get_visible_rect()).grow(1)
	var meter: Rect2 = lab.combat_meter.get_global_rect()
	_check(lab.combat_meter.is_visible_in_tree() and meter.position.x >= lab.arena.get_global_rect().end.x,
		"The combat stats panel stays on the right of compact rewards.")
	var field_top: float = visible_field.position.y
	var expected_save_top_left: Vector2 = Vector2(lab.arena_screen.get_theme_constant("margin_left"),
		lab.arena_screen.get_theme_constant("margin_top")) + lab.arena_screen.get_global_rect().position
	var save_at: Vector2 = lab.save_title_button.get_global_rect().position
	_check(lab.save_title_button.is_visible_in_tree() and save_at.is_equal_approx(expected_save_top_left)
		and save_at.y < field_top and lab.frontier_screen.find_child("SaveTitle", true, false) == null,
		"The compact overlay retains a single Save & title in the exact top-left header position.")
	var cards_bottom := field_top
	for id: String in run.data.offers:
		var card := lab.frontier_screen.find_child("RewardTile_" + id, true, false) as Button
		var card_rect := Rect2() if card == null else card.get_global_rect()
		if not _check(card != null and card.is_visible_in_tree() and visible_field.encloses(card_rect),
			"Reward %s is fully clickable inside the compact arena (%s within %s)." % [id, card_rect, visible_field]):
			continue
		cards_bottom = maxf(cards_bottom, card.get_global_rect().end.y)
	var skip := lab.frontier_screen.find_child("SkipReward", true, false) as Button
	var skip_rect := Rect2() if skip == null else skip.get_global_rect()
	_check(skip != null and skip.is_visible_in_tree() and visible_field.encloses(skip_rect)
		and skip_rect.position.y >= cards_bottom,
		"Skip for gold is directly below the reward choices and inside the compact arena (%s within %s)." % [skip_rect, visible_field])


func _check_defeat_animation(lab: Control) -> void:
	var run: FrontierRun = lab.run
	run.data.phase = "combat"
	lab.run_return()
	lab.action.pressed.emit()
	for unit: Dictionary in lab.sim.units:
		if unit.side == "hero":
			unit.hp = 0
	lab._physics_process(1.0 / 60.0)
	_check(lab.result_banner.is_visible_in_tree() and lab.result_text.text.to_lower() == "defeat"
		and not lab.retry_button.is_visible_in_tree(), "Defeat appears in the arena before the result actions.")
	lab._complete_result_animation()
	_check(lab.arena.is_visible_in_tree() and lab.combat_meter_toggle.is_visible_in_tree()
		and run.data.phase == "result" and run.data.result == "defeat",
		"The defeat state keeps the arena and stats available with the saved result.")
	_check(lab.action.text == "See results", "Campaign defeat offers one exit to the results.")
	lab.retry_button.pressed.emit()
	_check(lab.state == "setup" and not lab.campaign, "Defeat can be retried in Practice.")
	_check(lab.return_button.is_visible_in_tree() and not lab.save_title_button.is_visible_in_tree()
		and lab.return_button.get_parent() == lab.save_title_button.get_parent()
		and lab.return_button.text == "Back to battle result",
		"Retry in Practice uses the single top-left exit to return to the saved battle result.")
	lab.return_button.pressed.emit()
	_check(lab.arena.is_visible_in_tree() and lab.action.text == "See results"
		and lab.sim.outcome == "defeat" and run.data.result == "defeat",
		"Returning from Practice restores the original defeat arena.")


func _check_crowded_reward_drop(lab: Control) -> void:
	var run: FrontierRun = lab.run
	if not _check(run.abandon_run() and run.start_run(42) and run.choose_hero("warden")
		and run.choose_relic("pocket_bell") and run.choose_starter("bash"), "Start a clean run to exercise crowded drops."):
		return
	var equipped: Array = []
	for start in range(ArenaSim.BEATS):
		equipped.append(lab._entry("tap_bolt", start, "lowest_hp"))
	run.loadout.lanes[0].assign(equipped)
	run.loadout.storage[0].append(lab._entry("tap_bolt", 7, "farthest"))
	run.loadout.suppressed.tap_bolt = true
	if not _check(run.finish_combat(true, 100), "Finish the opening battle with a full sequence."):
		return
	lab.run_return()
	await process_frame
	var swap_hint := lab.storage_screen.find_child("StorageSwapHint", true, false) as Label
	_check(swap_hint != null and swap_hint.is_visible_in_tree() and "same-width" in swap_hint.text,
		"The reward storage panel tells players that same-width drops swap tiles.")
	lab._place({"id": "tap_bolt", "row": 0, "lane": -1, "start": 7}, 0, 4, true)
	_check(run.data.phase == "reward" and lab.lanes[0][4].target == "farthest"
		and lab.storage_rows[0][0].start == 7 and lab.storage_rows[0][0].target == "lowest_hp",
		"A same-width drop from storage swaps into its original slot without claiming a reward.")
	var id: String = run.data.offers.front()
	lab._place({"id": id, "reward": true}, 0, 2, true)
	var resumed := FrontierRun.new()
	if not _check(resumed.load_save(SAVE_PATH) and resumed.data.phase == "map", "The reward drop advances and persists in one save."):
		return
	var received: Array = resumed.loadout.lanes[0]
	var stowed: Array = resumed.loadout.storage[0]
	_check(received.any(func(tile: Dictionary): return tile.id == id and tile.start == 2)
		and stowed.size() == 1 + int(ArenaSim.TILES[id].width),
		"A reward installs at the chosen slot and safely stows the tiles it displaces.")


func _set_save_block(blocked: bool) -> bool:
	var path := ProjectSettings.globalize_path(SAVE_PATH + ".tmp")
	var result := DirAccess.make_dir_absolute(path) if blocked else DirAccess.remove_absolute(path)
	return _check(result == OK, "Set isolated save write failure to %s." % blocked)


func _check(passed: bool, description: String) -> bool:
	if not passed:
		failures.append(description)
	return passed
