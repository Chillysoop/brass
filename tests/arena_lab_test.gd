extends SceneTree

const ArenaScene = preload("res://arena.tscn")
const ArenaSim = preload("res://scripts/arena_sim.gd")
const ArenaView = preload("res://scripts/arena_view.gd")
const FrontierRun = preload("res://scripts/frontier_run.gd")
const TilePacking = preload("res://scripts/tile_packing.gd")
const GameIcons = preload("res://scripts/game_icons.gd")
const TileKeywords = preload("res://scripts/tile_keywords.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var lab = ArenaScene.instantiate()
	root.add_child(lab)
	await process_frame
	lab.run_practice()
	await process_frame
	lab.set_physics_process(false)
	await _check_practice_exit(lab)
	await _check_compact_game_menu(lab)
	_check(lab.lanes.size() == 2, "Duo setup should start with two lanes.")
	var preview = lab.sim.target_for(0, "pull", "farthest")
	_check(preview.get("id") == "clockwork", "Pull's default preview should identify the far enemy.")
	var palette_tile: Button = lab.palette.get_child(2)
	await _open_menu(lab)
	_click(palette_tile.get_global_rect().get_center())
	await process_frame
	_check(lab.selected.get("id") == "guard", "Clicking the palette should select that tile.")
	var first_lane: Control = lab.lane_stack.get_child(0).get_child(1)
	var sixth_beat: Button = first_lane.get_child(5)
	_click(sixth_beat.get_global_rect().get_center())
	await process_frame
	_check(lab.lanes[0].size() == 3, "An occupied span must reject a clicked placement.")
	var second_lane: Control = lab.lane_stack.get_child(1).get_child(1)
	var third_beat: Button = second_lane.get_child(2)
	_click(third_beat.get_global_rect().get_center())
	await process_frame
	_check(lab.lanes[1].size() == 4, "Clicking an open span should place the selected tile.")
	lab._load_fixture("duo")
	await process_frame
	palette_tile = lab.palette.get_child(2)
	await _open_menu(lab)
	second_lane = lab.lane_stack.get_child(1).get_child(1)
	third_beat = second_lane.get_child(2)
	var from := palette_tile.get_global_rect().get_center()
	var to := third_beat.get_global_rect().get_center()
	_button_input(from, true)
	_motion(from, from.lerp(to, 0.6), true)
	_motion(from.lerp(to, 0.6), to, true)
	_button_input(to, false)
	await process_frame
	_check(lab.lanes[1].size() == 4, "Dragging the palette tile to an open span should place it.")
	await _check_nudge(lab)
	await _check_timeline_rearrange(lab)
	await _check_practice_arsenal(lab)
	await _check_tile_identity(lab)
	await _check_target_icons(lab)
	_check_enemy_windup(lab)
	_check_combat_numbers()
	_check_pause_visuals(lab)
	lab._load_fixture("duo")
	var original: Array = lab.lanes.duplicate(true)
	lab._place({"id": "pull"}, 0, 11)
	_check(lab.lanes == original, "An out-of-bounds drop must leave the layout unchanged.")
	lab._place({"id": "bash", "lane": 1, "start": 4}, 0, 2)
	_check(lab.lanes == original, "A failed cross-lane move must leave the original tile in place.")
	lab._place({"id": "guard"}, 0, 11)
	_check(lab.lanes == original, "A second out-of-bounds placement must leave the layout unchanged.")
	lab._place({"id": "guard"}, 1, 2)
	_check(lab.lanes[1].size() == original[1].size() + 1, "A tile should fit into a free span.")
	lab._load_fixture("duo")
	lab._action()
	_click(lab.speed_buttons[2].get_global_rect().get_center())
	lab._physics_process(1.0 / 60.0)
	_check(lab.speed == 3 and lab.sim.tick == 3 and lab.speed_buttons[2].button_pressed
		and not lab.speed_buttons[0].button_pressed, "The triple play icon runs exactly three fixed steps and selects only 3×.")
	lab._load_fixture("duo")
	lab._action()
	_click(lab.speed_buttons[1].get_global_rect().get_center())
	lab._physics_process(1.0 / 60.0)
	_check(lab.speed == 2 and lab.sim.tick == 2 and not lab.speed_buttons[2].button_pressed,
		"The double play icon advances exactly two fixed steps and deselects 3×.")
	lab._action()
	lab._physics_process(1.0 / 60.0)
	_check(lab.sim.tick == 2, "Pause should preserve the simulation tick.")
	lab._action()
	await process_frame
	var first_pulse: ColorRect = lab.tile_cards[0].values().front().get_meta("timing_marker").get_child(0)
	var second_pulse: ColorRect = lab.tile_cards[1].values().front().get_meta("timing_marker").get_child(0)
	_check(first_pulse.color != second_pulse.color, "Pulses use distinct colors for the two hero lanes.")
	await _menu_click(lab, lab.combat_meter_toggle)
	await process_frame
	_check(lab.combat_meter.visible and lab.arena.visible, "Toggle the meter without leaving live combat.")
	await _menu_click(lab, lab.combat_meter_toggle)
	for step_index in range(3000):
		lab._physics_process(1.0 / 60.0)
		if lab.sim.tick == 84:
			var head: Control = lab.playheads[0]
			var marker: Control = lab.tile_cards[0][1].get_meta("timing_marker")
			_check(marker.visible and absf(head.get_global_rect().get_center().x - marker.get_global_rect().end.x) <= 1.0,
				"The playhead and firing tile must share the same right edge at 2×.")
		if lab.state == "finished":
			break
	_check(lab.sim.outcome == "victory", "The full fight should finish through the arena controls.")
	await process_frame
	await _menu_click(lab, lab.combat_meter_toggle)
	await process_frame
	_check(lab.combat_meter.visible and lab.arena.visible and not lab.combat_meter.totals.ranked("damage").is_empty(),
		"The right-side meter retains damage recorded while hidden and leaves the finished arena visible.")
	lab.combat_meter.set_metric("kills")
	_check(not lab.combat_meter.totals.ranked("kills").is_empty(), "Switching metrics shows the killing tiles.")
	await _menu_click(lab, lab.combat_meter_toggle)
	await process_frame
	_check(not lab.combat_meter.visible and lab.arena.visible, "Closing the meter leaves the arena visible.")
	lab._reset_fight()
	_check(lab.state == "setup" and lab.lanes == original, "Reset should return to setup and retain the edited layout.")
	lab._load_fixture("solo")
	_check(lab.lanes.size() == 1, "Solo setup should switch to one lane.")
	await _check_storage_tile_geometry(lab)
	await _check_keyword_hints()
	await _check_storage_popup(lab)
	_check_forge(lab)
	_check_blink_forge(lab)
	_check_forge_layout_edit(lab)
	_check_retry_boss_telegraphs(lab)
	if failures.is_empty():
		print("Arena controls checks passed.")
	else:
		for failure in failures:
			printerr(failure)
	lab.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _check_practice_exit(lab: Control) -> void:
	await _open_menu(lab)
	_check(lab.return_button.is_visible_in_tree() and not lab.save_title_button.is_visible_in_tree()
		and lab.return_button.get_parent() == lab.save_title_button.get_parent()
		and lab.action_menu.panel.get_global_rect().encloses(lab.return_button.get_global_rect())
		and lab.action_menu.trigger.global_position.x > root.size.x * 0.5,
		"Practice has one Title exit in the top-right game menu used by campaign Save & title.")
	_click(lab.return_button.get_global_rect().get_center())
	await process_frame
	_check(not lab.arena_screen.is_visible_in_tree() and lab.frontier_screen.is_visible_in_tree(),
		"The menu's Practice Title button returns to the real title menu.")
	lab.run_practice()
	await process_frame
	await process_frame
	lab._action()
	await _open_menu(lab)
	_check(lab.return_button.is_visible_in_tree() and lab.action_menu.panel.get_global_rect().encloses(lab.return_button.get_global_rect()),
		"Practice keeps its Title exit available in the game menu while combat is running.")
	lab.action_menu.close(false)
	lab._reset_fight()
	await process_frame


func _check_practice_arsenal(lab: Control) -> void:
	lab._load_fixture("duo")
	await process_frame
	await _menu_click(lab, lab.arsenal_button)
	await process_frame
	var jab: Button = lab.arsenal_panel.find_child("PracticeTile_jab", true, false)
	var watchfire: Button = lab.arsenal_panel.find_child("PracticeTile_watchfire", true, false)
	_check(lab.arsenal_panel.visible and jab != null and watchfire != null, "Practice must open a picker with Common and Uncommon expansion tiles.")
	if jab == null or watchfire == null:
		return
	_click(jab.get_global_rect().get_center())
	await process_frame
	var board: Control = lab.lane_stack.get_child(0).get_child(1)
	_click((board.get_child(0) as Control).get_global_rect().get_center())
	await process_frame
	_check(lab.tile_cards[0].has(0) and lab.tile_cards[0][0].get_meta("tile").id == "jab",
		"The one-beat tile should equip through the picker and timeline.")
	if lab.tile_cards[0].has(0):
		_check(_tile_has_badges(lab.tile_cards[0][0].get_child(0), "common", "hexwright"),
			"A one-beat timeline tile should still show both rarity and owner.")
	await _menu_click(lab, lab.arsenal_button)
	await process_frame
	board = lab.lane_stack.get_child(1).get_child(1)
	var from := watchfire.get_global_rect().get_center()
	var to := (board.get_child(2) as Control).get_global_rect().get_center()
	var target_start := 2
	_button_input(from, true)
	_motion(from, from.lerp(to, 0.6), true)
	_motion(from.lerp(to, 0.6), to, true)
	_button_input(to, false)
	await process_frame
	_check(lab.tile_cards[1].has(target_start) and lab.tile_cards[1][target_start].get_meta("tile").id == "watchfire",
		"An Uncommon tile should drag directly from the picker onto a timeline.")
	if not lab.arsenal_panel.visible:
		await _menu_click(lab, lab.arsenal_button)
	await process_frame
	var collection := lab.arsenal_panel.find_child("PracticeTileCollection", true, false) as OptionButton
	collection.select(2)
	collection.item_selected.emit(2)
	await process_frame
	var upgrade_id: String = TilePacking.next_options("gravity_spike")[1]
	var upgrade := lab.arsenal_panel.find_child("PracticeTile_" + upgrade_id, true, false) as Button
	_check(upgrade != null and upgrade.is_visible_in_tree(), "The signature page should expose upgraded tiles in Practice.")
	var upgrade_at_bottom: String = TilePacking.next_options("needle_point")[1]
	var bottom_tile := lab.arsenal_panel.find_child("PracticeTile_" + upgrade_at_bottom, true, false) as Button
	var signature_scroll := lab.arsenal_panel.find_child("PracticeSignatureScroll", true, false) as ScrollContainer
	if bottom_tile == null or signature_scroll == null:
		_check(false, "Duelist's upgrades should appear in the scrollable signature page.")
		return
	signature_scroll.ensure_control_visible(bottom_tile)
	await process_frame
	_click(bottom_tile.get_global_rect().get_center())
	_check(lab.selected.get("id") == upgrade_at_bottom, "The signature page should scroll to Duelist and let a player equip the upgrade.")

func _check_tile_identity(lab: Control) -> void:
	var common := GameIcons.rarity({})
	var uncommon := GameIcons.rarity({"rarity": "uncommon"})
	var rare := GameIcons.rarity({"rarity": "rare"})
	var epic := GameIcons.rarity({"rarity": "epic"})
	var legendary := GameIcons.rarity({"rarity": "legendary"})
	_check(common.s < 0.18 and uncommon.h > 0.24 and uncommon.h < 0.45
		and rare.h > 0.50 and rare.h < 0.67 and epic.h > 0.69 and epic.h < 0.87
		and legendary.h > 0.06 and legendary.h < 0.18,
		"Rarity colors should read as gray, green, blue, purple, and gold.")

	lab._load_fixture("duo")
	lab.lanes[0].assign([lab._entry("gravity_spike", 0, "nearest")])
	lab.lanes[1].clear()
	lab.storage_rows[0].assign([lab._entry("jab", 0, "nearest")])
	lab._reset_fight()
	await process_frame
	var tile: Button = lab.tile_cards[0][0].get_child(0)
	_check(_tile_has_badges(tile, "uncommon", "hexwright"),
		"The equipped signature should show its rarity and the current lane's class.")
	_click(tile.get_global_rect().get_center())
	await process_frame
	var warden_lane: Control = lab.lane_stack.get_child(1).get_child(1)
	_click(_cell_point(warden_lane, 0, ArenaSim.BEATS))
	await process_frame
	if not lab.tile_cards[1].has(0):
		_check(false, "Tile labels must allow selecting and moving a signature to another hero.")
		return
	tile = lab.tile_cards[1][0].get_child(0)
	_check(_tile_has_badges(tile, "uncommon", "warden") and "Warden" in tile.tooltip_text and "Hexwright" in tile.tooltip_text,
		"After transfer, the badge names the new owner and the tooltip still identifies the signature's class.")
	_click(tile.get_global_rect().get_center())
	await process_frame
	tile = lab.tile_cards[1][0].get_child(0)
	_check(_tile_has_badges(tile, "uncommon", "warden"),
		"Selecting an equipped tile should retain both visible indicators.")

	lab._open_storage()
	await process_frame
	var storage_row: Control = lab.storage_screen._board.get_child(0).get_child(1)
	_click(_cell_point(storage_row, 2, TilePacking.STORAGE_COLUMNS))
	await process_frame
	var stored: Control = lab.storage_screen.find_child("StoredTile_gravity_spike_0_2", true, false)
	var generic: Control = lab.storage_screen.find_child("StoredTile_jab_0_0", true, false)
	_check(_tile_has_badges(stored, "uncommon", "hexwright") and _tile_has_badges(generic, "common", ""),
		"Shared storage should retain rarity everywhere and identify signature origin for class tiles.")
	lab.storage_close()


func _tile_has_badges(tile: Control, rarity: String, hero: String) -> bool:
	if not is_instance_valid(tile):
		return false
	var rarity_badge := tile.find_child("TileRarityBadge", true, false) as Label
	var hero_badge := tile.find_child("TileHeroBadge", true, false) as Control
	var spec := {"rarity": rarity}
	var rarity_matches: bool = (rarity_badge != null and rarity_badge.is_visible_in_tree()
		and rarity_badge.get_meta("rarity", "") == rarity
		and rarity_badge.get_theme_color("font_color") == GameIcons.rarity(spec)
		and (rarity_badge.text == GameIcons.rarity_pips(spec) or rarity_badge.text == GameIcons.rarity_name(spec)))
	if hero.is_empty():
		return rarity_matches and (hero_badge == null or not hero_badge.is_visible_in_tree())
	return (rarity_matches and hero_badge != null and hero_badge.is_visible_in_tree()
		and hero_badge.get_meta("hero_class", "") == hero)


func _check_nudge(lab: Control) -> void:
	lab.lanes[0].assign([lab._entry("bash", 1, "nearest"), lab._entry("shot", 3, "lowest_hp"), lab._entry("bash", 7, "farthest")])
	lab._reset_fight()
	await process_frame
	var board: Control = lab.tile_cards[0][3].get_parent()
	var palette_tile: Button = lab.palette.get_child(4)
	await _open_menu(lab)
	var origin := palette_tile.get_global_rect().get_center()
	var destination := board.get_global_rect().position + Vector2(board.size.x * 2.5 / ArenaSim.BEATS, 12)
	var before: Array = lab.lanes.duplicate(true)
	_button_input(origin, true)
	_motion(origin, origin.lerp(destination, 0.5), true)
	_motion(origin.lerp(destination, 0.5), destination, true)
	_check(lab.lanes == before and lab.drag_overlay != null and lab.drag_overlay.get_child_count() == 3,
		"Dragging onto an occupied span should preview the incoming tile and both nudged neighbors without editing inventory.")
	_button_input(destination, false)
	await process_frame
	_check(lab.lanes[0] == [lab._entry("bash", 0, "nearest"), lab._entry("blink", 2, "nearest"),
		lab._entry("shot", 5, "lowest_hp"), lab._entry("bash", 7, "farthest")],
		"Dropping commits the preview and retains each moved tile's target rule.")
	_check(lab.drag_overlay == null, "A completed drop clears the drag overlay.")
	var blocked: Array = lab.lanes.duplicate(true)
	lab._place({"id": "event_horizon"}, 0, 0, true)
	_check(lab.lanes == blocked, "A full lane should reject the drop without moving any tile.")
	var blink: Control = lab.tile_cards[0][2]
	var blink_button: Control = blink.get_child(0)
	origin = blink_button.get_global_rect().position + Vector2(blink.size.x * 0.82, 12)
	destination = Vector2(12, 12)
	_button_input(origin, true)
	_motion(origin, origin.lerp(destination, 0.5), true)
	_motion(origin.lerp(destination, 0.5), destination, true)
	_button_input(destination, false)
	await process_frame
	_check(lab.lanes == blocked and lab.drag_overlay == null, "Releasing a drag outside the lanes should cancel it cleanly.")
	lab._load_fixture("duo")


func _check_timeline_rearrange(lab: Control) -> void:
	var bash: Dictionary = lab._entry("bash", 1, "farthest")
	var shot: Dictionary = lab._entry("shot", 6, "lowest_hp")
	shot.enchantment = "longshot"
	lab.lanes[0].assign([bash, shot])
	lab._reset_fight()
	await process_frame
	var source: Button = lab.tile_cards[0][1].get_child(0)
	var board: Control = source.get_parent().get_parent()
	var origin := source.global_position + Vector2(source.size.x * 0.25, source.size.y * 0.5)
	var destination := _cell_point(board, 6, ArenaSim.BEATS)
	_drag(origin, destination)
	_check(lab.drag_overlay != null and lab.drag_overlay.get_child_count() == 2
		and bash.start == 1 and shot.start == 6, "An equal-width overlap previews a swap before the drop.")
	if lab.drag_overlay != null and lab.drag_overlay.get_child_count() == 2:
		var moving: Control = lab.drag_overlay.get_child(0)
		var initial := moving.position.x
		await create_timer(0.20).timeout
		_check(moving.position.x < initial, "The outgoing tile visibly slides toward the source slot.")
	_button_input(destination, false)
	await process_frame
	_check(lab.lanes[0] == [shot, bash] and shot.start == 1 and bash.start == 6
		and shot.target == "lowest_hp" and shot.enchantment == "longshot",
		"Dropping a swap exchanges slots and keeps each tile's settings.")

	var incoming: Dictionary = lab._entry("stave_crush", 0, "nearest")
	var crowded: Array = []
	for beat in range(ArenaSim.BEATS):
		crowded.append(lab._entry("tap_bolt", beat, "lowest_hp"))
	var displaced: Dictionary = crowded[6]
	displaced.enchantment = "longshot"
	lab.lanes[0].assign([incoming])
	lab.lanes[1].assign(crowded)
	for row: Array in lab.storage_rows:
		row.clear()
	lab._reset_fight()
	lab._place({"id": incoming.id, "lane": 0, "start": 0}, 1, 5, true)
	_check(lab.lanes[0].is_empty() and lab.lanes[1].size() == 10 and incoming.start == 5
		and lab.storage_rows[0].size() == 3 and displaced in lab.storage_rows[0]
		and displaced.target == "lowest_hp" and displaced.enchantment == "longshot",
		"A crowded lane slides what it can and stows displaced tiles with their settings.")
	if lab.forge_screen.visible:
		lab.forge_close()
	for row: Array in lab.storage_rows:
		row.clear()
		for column in range(TilePacking.STORAGE_COLUMNS):
			row.append(lab._entry("tap_bolt", column, "nearest"))
	lab.lanes[0].assign([lab._entry("stave_crush", 0, "nearest")])
	for beat in range(ArenaSim.BEATS):
		crowded[beat] = lab._entry("tap_bolt", beat, "nearest")
	lab.lanes[1].assign(crowded)
	lab._reset_fight()
	var before: Array = [lab.lanes.duplicate(true), lab.storage_rows.duplicate(true)]
	lab._place({"id": "stave_crush", "lane": 0, "start": 0}, 1, 5, true)
	_check([lab.lanes, lab.storage_rows] == before, "A drop that needs unavailable storage changes neither lane nor storage.")
	lab._load_fixture("duo")


func _check_target_icons(lab: Control) -> void:
	lab._load_fixture("duo")
	await process_frame
	var bash: Control = lab.tile_cards[1][4]
	var farthest: Button = bash.find_child("Target_farthest", true, false)
	_click(farthest.get_global_rect().get_center())
	await process_frame
	_check(farthest.button_pressed and lab.lanes[1][1].target == "farthest" and lab.lanes[1][2].target == "nearest",
		"Clicking the farthest icon changes only the tile that owns it.")
	var identity: Control = lab.lane_stack.get_child(1).get_child(0)
	var lowest: Button = identity.find_child("Target_lowest_hp", true, false)
	_click(lowest.get_global_rect().get_center())
	await process_frame
	identity = lab.lane_stack.get_child(1).get_child(0)
	lowest = identity.find_child("Target_lowest_hp", true, false)
	_check(lowest.button_pressed and lab.defaults[1] == "lowest_hp" and lab.lanes[1][0].target == "self"
		and lab.lanes[1][1].target == "lowest_hp" and lab.lanes[1][2].target == "lowest_hp"
		and lab.lanes[0][0].target == "farthest",
		"Clicking the hero's lowest HP icon updates their compatible tiles and preserves Guard and the other hero.")


func _check_combat_numbers() -> void:
	var view := ArenaView.new()
	root.add_child(view)
	view.set_process(false)
	view.size = Vector2(555, 348)
	var field := Rect2(56, 95, 443, 207)
	var charge_bar := Rect2(12, 36, 100, 38)
	var near_edge := Vector2(-70, 18)
	var events := [
		{"kind": "hit", "amount": 29, "critical": true, "target": "scout", "actor": "hero_0", "tile": "shot", "from": near_edge, "to": near_edge},
		{"kind": "hit", "amount": 14, "target": "drone", "actor": "hero_1", "tile": "bash", "from": near_edge, "to": near_edge},
		{"kind": "heal", "amount": 8, "target": "hero_0", "actor": "hero_1", "tile": "mend", "from": near_edge, "to": near_edge},
		{"kind": "guard", "amount": 5, "target": "hero_0", "actor": "hero_0", "tile": "guard", "from": near_edge, "to": near_edge},
	]
	view.present([], events, 60, [], 3)
	view._layout_combat_numbers(field, 0.43, [charge_bar], [])
	var critical: Dictionary = view._combat_numbers[0]
	var original: Rect2 = critical.bounds
	_check(critical.label == "29!" and view._combat_numbers[2].glyph == "heal" and view._combat_numbers[3].glyph == "guard",
		"Critical damage, healing, and Guard use distinct combat numbers.")
	view._process(0.55)
	view.present([], [events[1]], 159, [], 3)
	view._layout_combat_numbers(field, 0.43, [charge_bar], [])
	var placed: Array[Rect2] = [charge_bar]
	var viewport := Rect2(Vector2.ZERO, view.size)
	for number: Dictionary in view._combat_numbers:
		var bounds: Rect2 = number.bounds
		_check(bounds.has_area() and viewport.encloses(bounds) and not placed.any(func(other: Rect2): return other.intersects(bounds)),
			"Simultaneous and staggered combat numbers on nearby units get separate visible space.")
		placed.append(bounds)
	_check(critical.bounds == original, "A later popup does not displace an active critical hit.")
	view._process(0.55)
	_check(view._combat_numbers.size() == 2 and critical in view._combat_numbers,
		"Critical hits stay visible after ordinary numbers from the same beat expire at 3×.")
	view.playback_paused = true
	view._process(0.5)
	_check(critical in view._combat_numbers, "Pause holds the remaining screen time for critical hits.")
	view.playback_paused = false
	view._process(0.5)
	_check(view._combat_numbers.is_empty(), "Combat numbers expire in real time after playback resumes.")
	view.queue_free()


func _check_enemy_windup(lab: Control) -> void:
	lab._load_fixture("duo")
	lab.lanes[0].clear()
	lab.lanes[1].clear()
	lab.speed = 1
	lab._action()
	var window := Vector2i.ZERO
	for step_index in range(360):
		lab._physics_process(1.0 / 60.0)
		if lab.arena._windups.has("scout"):
			window = lab.arena._windups.scout
			break
	_check(window.x > 0 and window.x == lab.sim.tick and window.y > window.x,
		"The Scout's windup should display as soon as the combat simulation announces its attack.")
	if window == Vector2i.ZERO:
		return
	var halfway := window.x + floori((window.y - window.x) * 0.5)
	for tick in range(window.x, halfway):
		lab._physics_process(1.0 / 60.0)
	_check(lab.arena._windups.get("scout") == window and lab.arena.combat_tick == halfway,
		"The windup gauge should progress against its original start and attack ticks.")
	for tick in range(halfway, window.y):
		lab._physics_process(1.0 / 60.0)
	_check(lab.arena.combat_tick == window.y and not lab.arena._windups.has("scout"),
		"The Scout's windup gauge should clear on the attack tick.")


func _check_pause_visuals(lab: Control) -> void:
	lab._load_fixture("duo")
	lab.lanes[0].assign([lab._entry("shot", 1, "nearest")])
	lab.lanes[1].clear()
	lab.speed = 1
	lab.action.pressed.emit()
	var release_tick := 3 * ArenaSim.TICKS_PER_BEAT
	for step in range(release_tick):
		lab._physics_process(1.0 / 60.0)
	var casts: Array = lab.arena._attack_casts.duplicate(true)
	var effects: Array = lab.arena._effects.duplicate(true)
	_check(not casts.is_empty() and not effects.is_empty(), "Shot should have an active animation and hit feedback on its firing beat.")
	lab.action.pressed.emit()
	lab.arena._process(0.8)
	_check(lab.sim.tick == release_tick and lab.arena._attack_casts == casts and lab.arena._effects == effects,
		"Pause should keep the simulation, active attack animations, and hit feedback on the firing beat.")
	lab.action.pressed.emit()
	lab.arena._process(0.8)
	_check(lab.arena._attack_casts.is_empty() and lab.arena._effects.is_empty(),
		"After resuming, the shot animation and hit feedback should finish normally.")


func _check_storage_tile_geometry(lab: Control) -> void:
	lab._load_fixture("duo")
	lab.lanes = [
		[lab._entry("event_horizon", 0, "nearest"), lab._entry("star_piercer", 6, "nearest")],
		[lab._entry("slam", 0, "nearest"), lab._entry("volley", 4, "nearest"),
		lab._entry("guard", 7, "self"), lab._entry("jab", 9, "nearest")],
	]
	lab.storage_rows = [
		[lab._entry("event_horizon", 0, "nearest"), lab._entry("guard", 6, "self")],
		[lab._entry("star_piercer", 0, "nearest"), lab._entry("volley", 5, "nearest")],
		[lab._entry("slam", 0, "nearest"), lab._entry("jab", 4, "nearest")],
	]
	lab._rebuild_loadout()
	lab._open_storage()
	var original_edge := lab.offset_right
	var previous_width := 0.0
	for right_edge: float in [original_edge, original_edge + 121.0]:
		lab.offset_right = right_edge
		await process_frame
		await process_frame
		var sequence_sizes := {}
		for cards: Dictionary in lab.tile_cards:
			for card: Control in cards.values():
				sequence_sizes[card.get_meta("tile").id] = card.size
		var width: float = sequence_sizes.event_horizon.x
		_check(width > previous_width, "The second layout should widen the timeline tiles.")
		previous_width = width
		for row: int in range(lab.storage_rows.size()):
			for item: Dictionary in lab.storage_rows[row]:
				var name := "StoredTile_%s_%d_%d" % [item.id, row, item.start]
				var tile := lab.storage_screen.find_child(name, true, false) as Control
				_check(tile != null and tile.size.is_equal_approx(sequence_sizes[item.id]),
					"A stored %s should have the same dimensions as its timeline tile after resizing." % item.id)
	lab.offset_right = original_edge
	lab.storage_close()


func _check_keyword_hints() -> void:
	var copy := "Gain 10 Guard. Mark the first target."
	var description := TileKeywords.description(copy, 16, Color.WHITE)
	root.add_child(description)
	description.size = Vector2(420, 40)
	await process_frame
	var hovered := PackedStringArray()
	for x: int in range(300):
		var hint := description.get_tooltip(Vector2(x, 8))
		if not hint.is_empty() and hint not in hovered:
			hovered.append(hint)
	_check(description.get_parsed_text() == copy and hovered.size() == 2,
		"Guard and Mark should expose separate hover definitions without changing the displayed copy.")
	description.queue_free()


func _check_storage_popup(lab: Control) -> void:
	lab._load_fixture("duo")
	lab.storage_rows[0].assign([lab._entry("bash", 0, "farthest"), lab._entry("bash", 2, "nearest")])
	lab._open_storage()
	await process_frame
	await process_frame
	var popup = lab.storage_screen
	var row: Control = popup._board.get_child(0).get_child(1)
	var bash: Control = lab.tile_cards[1][4].get_child(0)
	var origin := bash.get_global_rect().position + Vector2(bash.size.x * 0.25, bash.size.y * 0.5)
	var destination := _cell_point(row, 4, TilePacking.STORAGE_COLUMNS)
	_check(popup.is_visible_in_tree() and lab.arena.is_visible_in_tree() and bash.is_visible_in_tree(),
		"Opening storage keeps the arena and its timeline visible.")
	_drag(origin, destination)
	_check(lab.storage_rows[0].size() == 2, "Dragging above storage must leave the source in place until drop.")
	_button_input(destination, false)
	await process_frame
	await process_frame
	_check(lab.forge_screen.visible and lab.storage_rows[0].size() == 3 and not lab.tile_cards[1].has(4),
		"Dropping the third matching tile in storage moves it and opens the forge.")
	lab.forge_close()
	await process_frame
	_check(popup.visible, "Leaving the forge returns to the storage popup.")
	_check(popup._board.get_child(0).get_child(0).get_child_count() == 1,
		"Returning to storage leaves the Combine prompt available.")
	row = popup._board.get_child(0).get_child(1)
	var timeline: Control = lab.lane_stack.get_child(1).get_child(1)
	origin = _cell_point(row, 4, TilePacking.STORAGE_COLUMNS)
	destination = _cell_point(timeline, 4, ArenaSim.BEATS)
	_drag(origin, destination)
	_button_input(destination, false)
	await process_frame
	await process_frame
	_check(lab.storage_rows[0].size() == 2 and lab.tile_cards[1].has(4),
		"A storage-to-timeline drop should remove the stored copy and equip it.")
	_check(popup._board.get_child(0).get_child(0).get_child_count() == 0,
		"Breaking the triple should remove the storage Combine prompt.")
	lab.storage_close()
	lab._load_fixture("solo")

func _cell_point(row: Control, index: int, columns: int) -> Vector2:
	return row.get_global_rect().position + Vector2(row.size.x * (index + 0.5) / float(columns), row.size.y * 0.4)

func _drag(origin: Vector2, destination: Vector2) -> void:
	_motion(origin, origin, false)
	_button_input(origin, true)
	var midpoint := origin.lerp(destination, 0.5)
	_motion(origin, midpoint, true)
	_motion(midpoint, destination, true)

func _check_forge(lab: Control) -> void:
	lab._open_storage()
	var original: Array = lab.storage_rows[0].duplicate(true)
	lab.storage_combine(0, 0, false)
	lab.decline_dialog.canceled.emit()
	lab.decline_dialog.hide()
	_check(lab.suppressed_combines.is_empty(), "Canceling decline should leave the offer active.")
	lab.storage_combine(0, 0, false)
	lab.decline_dialog.confirmed.emit()
	lab.decline_dialog.hide()
	_check(lab.suppressed_combines.has("bash"), "Confirmed decline should hide offers for Bash.")
	lab.storage_place(2, 0, {"id": "bash", "lane": -1, "row": 0, "start": 4})
	_check(lab.suppressed_combines.has("bash"), "Moving a Bash must not restore a declined offer.")
	lab.storage_place(0, 4, {"id": "bash"})
	_check(not lab.suppressed_combines.has("bash"), "Acquiring a new Bash must restore offers.")
	_check(lab.forge_screen.visible, "Completing a storage triple should open the forge.")
	lab.forge_choose("event_horizon")
	_check(lab.storage_rows[0] == original, "A future tier must not consume any copies.")
	lab.forge_close()
	_check(lab.storage_rows[0] == original and lab.storage_screen.visible, "Back should preserve the triple and return to storage.")
	lab.storage_combine(0, 0, true)
	lab.forge_choose("hook_bash")
	_check(lab.storage_rows[0].size() == 1 and lab.storage_rows[0][0].id == "hook_bash",
		"Storage forge should replace exactly three copies with the chosen upgrade.")
	lab.storage_pick(0, lab.storage_rows[0][0])
	lab.storage_send_to_timeline()
	lab._place_selected(0, 10)
	_check(lab.storage_rows[0].size() == 1, "A blocked transfer must keep the source tile.")
	lab.lanes[0].clear()
	lab._place_selected(0, 2)
	_check(lab.storage_rows[0].is_empty() and lab.lanes[0][0].id == "hook_bash", "Transfer must move the upgraded tile once.")
	lab.lanes[0].clear()
	for beat in [0, 2, 4]:
		lab._place({"id": "bash"}, 0, beat)
	_check(lab.forge_screen.visible, "Completing a timeline triple should open the forge.")
	var matches: Node = lab.forge_screen.find_child("MatchingTiles", true, false)
	_check(matches != null and matches.get_child_count() == 3 and lab.forge_screen._title.text == "Upgrade ready!",
		"The upgrade intro should start by showing all three matching tiles.")
	lab.forge_screen._inspect("shield_ram")
	_check(lab.forge_screen.find_child("ForgeMergeIntro", true, false) == null and not lab.forge_screen._confirm.disabled,
		"Selecting an upgrade path dismisses the intro immediately.")
	lab.forge_choose("shield_ram")
	_check(lab.lanes[0].size() == 1 and lab.lanes[0][0].id == "shield_ram",
		"Timeline forge should replace the triple in place.")
	lab._action()
	for tick in range(252):
		lab._physics_process(1.0 / 60.0)
	_check(lab.sim.trace.any(func(event: Dictionary): return event.tile == "shield_ram"),
		"The equipped forged tile should activate in battle.")
	lab._load_fixture("forge")
	lab._offer_combine(-1, 1, 0, true)
	lab.forge_choose("event_horizon")
	_check(lab.lanes[1].size() == 1 and lab.lanes[1][0].id == "event_horizon",
		"The 12-beat practice triple should combine into the six-wide Legendary.")
	lab._open_storage()
	lab.storage_place(0, 2, {"id": "event_horizon", "lane": 1, "start": 0})
	_check(lab.lanes[1].size() == 1, "Storage should reject overlap with a wide tile.")
	lab.storage_place(2, 0, {"id": "event_horizon", "lane": 1, "start": 0})
	_check(lab.lanes[1].size() == 1, "Storage should keep a wide tile on its timeline if the destination is blocked.")
	lab.storage_rows[2].clear()
	lab.storage_place(2, 2, {"id": "event_horizon", "lane": 1, "start": 0})
	_check(lab.lanes[1].is_empty() and lab.storage_rows[2][0].start == 2,
		"A six-wide Legendary should fit as one tile in eight-column storage.")

func _check_blink_forge(lab: Control) -> void:
	lab._load_fixture("blink_forge")
	lab._offer_combine(-1, 0, 0, true)
	_check(lab.forge_screen.visible and lab.forge_screen._cards.size() == 9
		and lab.forge_screen._cards.has("sanctuary_gate"), "Blink should display its complete nine-tile forge tree.")
	lab.forge_choose("shield_ram")
	_check(lab.lanes[0].size() == 3, "A Bash-family upgrade cannot consume a Blink triple.")
	lab.forge_screen._inspect("sanctuary_gate")
	_check(lab.forge_screen._confirm.disabled, "A future Blink tier is inspectable but cannot be selected for a combine.")
	lab.forge_choose("ward_step")
	_check(lab.lanes[0].size() == 1 and lab.lanes[0][0].id == "ward_step", "Three Blink tiles should combine into Ward Step.")
	_check(TilePacking.next_options("ward_step") == TilePacking.next_options("phase_cut")
		and TilePacking.next_options("ward_step").size() == 2, "Both Uncommon tiles should lead to the same two Rare tiles.")
	lab._offer_combine(-1, 1, 0, true)
	lab.forge_choose("starfall_step")
	_check(lab.lanes[1].size() == 1 and lab.lanes[1][0].id == "starfall_step", "Three Epic Blink tiles should combine into a Legendary.")

	var save_path := "user://blink-forge-test-%d.json" % Time.get_ticks_usec()
	lab.run.load_save(save_path)
	lab.run_start(42)
	lab.run.choose_hero(lab.run.data.offers[0])
	lab.run.choose_relic("pocket_bell")
	lab.run.choose_starter("bash")
	lab.run.loadout.lanes[0].assign([lab._entry("blink", 0, "nearest"),
		lab._entry("blink", 3, "nearest"), lab._entry("blink", 6, "nearest")])
	lab.run_show_arena()
	lab._offer_combine(-1, 0, 0, true)
	_check(lab.forge_screen.visible, "A fresh expedition can combine three matching Blink tiles.")
	lab.forge_choose("ward_step")
	_check(lab.lanes[0].size() == 1 and lab.lanes[0][0].id == "ward_step",
		"Blink's three-copy upgrade works before unlocking its single-tile rest action.")

	lab.run.data.phase = "rest"
	lab.run.loadout.storage[0].assign([lab._entry("blink", 0, "self")])
	lab.run_rest_forge()
	lab._open_storage()
	lab.storage_pick(0, lab.storage_rows[0][0])
	lab.storage_forge()
	_check(lab.forge_screen.visible, "A rest site can upgrade a single owned Blink before its reward-pool unlock.")
	lab.forge_choose("phase_cut")
	var restored := FrontierRun.new()
	_check(restored.load_save(save_path) and restored.data.phase == "map"
		and restored.loadout.storage[0] == [lab._entry("phase_cut", 0, "nearest")],
		"The chosen rest upgrade and its compatible target must save with the consumed rest action.")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))

func _check_forge_layout_edit(lab: Control) -> void:
	var save_path := "user://forge-layout-test-%d.json" % Time.get_ticks_usec()
	lab.run.load_save(save_path)
	lab.run_start(42)
	lab.run.choose_hero(lab.run.data.offers[0])
	lab.run.choose_relic("pocket_bell")
	lab.run.choose_starter("bash")
	lab.run.data.phase = "rest"
	lab.run.loadout.lanes[0].assign([lab._entry("bash", 0, "nearest"),
		lab._entry("shield_ram", 7, "highest_hp"), lab._entry("hook_sweep", 9, "nearest")])
	lab.run.loadout.storage[0].assign([lab._entry("shield_ram", 0, "nearest")])
	lab.run_rest_forge()
	var source := {"lane": 0, "id": "shield_ram", "start": 7}
	lab._select(source)
	lab._open_camp_forge()
	lab.forge_screen._inspect("bulwark_charge")
	var caption: String = lab.forge_screen._room_instruction.text
	_check(not lab.forge_screen._confirm.disabled and lab.forge_screen._edit_layout.visible
		and lab.forge_screen._confirm.text == "Upgrade and make room" and "Hook Sweep moves" in caption,
		"A wider camp upgrade should preview the adjacent tile's move and offer manual editing.")
	var room: HBoxContainer = lab.forge_screen._layout_preview
	_check(room.get_child_count() == ArenaSim.BEATS and room.get_child(9).tooltip_text == "Beat 10 · Bulwark Charge",
		"The twelve-beat strip should show which tile will occupy the formerly blocked beat.")
	lab.forge_screen._edit_layout.pressed.emit()
	_check(not lab.forge_screen.visible and lab.storage_screen.visible and lab.action.text == "Back to forge",
		"Edit timeline should open the existing timeline and storage with a direct way back to the chosen upgrade.")
	_check(lab.storage_screen._discard.disabled, "The tile being upgraded should stay safe while the forge is open.")
	lab.run.save_path = "user://missing-forge-folder/forge-layout.json"
	lab._place(source, 0, 5)
	_check(lab.lanes[0][1].start == 7, "If a layout edit cannot save, the pending upgrade should retain its original tile.")
	lab.run.save_path = save_path
	lab._place(source, 0, 5)
	lab.storage_pick(0, lab.storage_rows[0][0])
	lab.action.pressed.emit()
	_check(lab.forge_screen.visible and lab.forge_screen._inspected_id == "bulwark_charge" \
		and not lab.forge_screen._confirm.disabled and room.get_child(7).tooltip_text == "Beat 8 · Bulwark Charge",
		"Returning should preserve the inspected branch and follow the original tile after rearranging.")
	lab.forge_screen._confirm.pressed.emit()
	var restored := FrontierRun.new()
	_check(restored.load_save(save_path) and restored.data.phase == "map"
		and restored.loadout.lanes[0][1] == lab._entry("bulwark_charge", 5, "highest_hp")
		and restored.loadout.storage[0] == [lab._entry("shield_ram", 0, "nearest")],
		"The upgrade should consume the rest and modify only the tile the player chose, even with another copy in storage.")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))

func _check_retry_boss_telegraphs(lab: Control) -> void:
	for fixture: Dictionary in [
		{"region": "glass", "id": "tempered_colossus", "label": "ColossusStatus", "attack": "colossus_forging"},
		{"region": "crown", "id": "crown_regent", "label": "RelayStatus", "attack": "crown_regent_charge"},
		{"region": "moonwreck", "id": "drowned_admiral", "label": "DockStatus", "attack": "admiral_undertow"},
	]:
		lab.run_practice()
		lab.campaign = true
		lab.state = "finished"
		lab.sim.outcome = "defeat"
		lab.battle_snapshot = {
			"options": {
				"location": fixture.region, "difficulty": "hard", "encounter": "boss", "segment": 3,
				"boss_id": fixture.id, "seed": 42,
				"heroes": [{"hero": "warden"}, {"hero": "starshot"}, {"hero": "duelist"}],
			},
			"lanes": [[lab._entry("bash", 2, "nearest")], [lab._entry("shot", 3, "farthest")],
				[lab._entry("shot", 4, "lowest_hp")]],
			"storage": [[], [], []], "defaults": ["nearest", "farthest", "lowest_hp"], "suppressed": {},
		}
		lab.retry_button.pressed.emit()
		_check(lab.state == "setup" and lab.arena.is_visible_in_tree()
			and lab.arena_screen.find_child(fixture.label, true, false) == null,
			"Retry in Practice should show %s without a boss advice row." % fixture.id)
		lab.speed = 1
		lab.action.pressed.emit()
		var telegraph := Vector2i.ZERO
		var bosses: Array = lab.sim.units.filter(func(unit: Dictionary): return unit.get("sprite") == fixture.id)
		_check(not bosses.is_empty(), "Retry in Practice should retain the original boss %s." % fixture.id)
		if bosses.is_empty():
			lab.run_menu()
			continue
		var boss: Dictionary = bosses.front()
		for step in range(500):
			lab._physics_process(1.0 / 60.0)
			if boss.get("intent_attack_id") == fixture.attack and lab.arena._windups.has(boss.id):
				telegraph = lab.arena._windups[boss.id]
				break
		_check(telegraph.x == lab.arena.combat_tick and telegraph.y > telegraph.x
			and lab.arena_screen.find_child(fixture.label, true, false) == null,
			"%s should keep its timed on-arena windup during the practice replay." % fixture.id)
		lab.run_menu()


func _check_compact_game_menu(lab: Control) -> void:
	var old_size := root.size
	var old_mode := root.content_scale_mode
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for dimensions: Vector2i in [Vector2i(856, 565), Vector2i(856, 535)]:
		root.size = dimensions
		lab.run_practice()
		lab.set_physics_process(false)
		await _open_menu(lab)
		for frame in range(4):
			await process_frame
		var screen := root.get_visible_rect().grow(0.1)
		_check(screen.encloses(lab.action_menu.panel.get_global_rect())
			and lab.action_menu.trigger.global_position.x > dimensions.x * 0.5,
			"Every Practice utility remains in the top-right menu at %s." % dimensions)
		for control: Control in [lab.return_button, lab.storage_button, lab.combat_meter_toggle,
				lab.arsenal_button, lab.fixture_picker, lab.reset_button, lab.palette]:
			lab.action_menu._scroller.ensure_control_visible(control)
			await process_frame
			await process_frame
			_check(control.is_visible_in_tree() and lab.action_menu._scroller.get_global_rect().grow(0.1).encloses(control.get_global_rect()),
				"The full Practice control %s can be reached without shrinking at %s." % [control.name, dimensions])
		_check(lab.battle_heading.text.is_empty() and not lab.battle_heading.visible,
			"Practice removes the in-game brand title instead of retaining Aether text.")
		if dimensions.y == 565:
			await _proof("hud-practice-menu")
		lab.action_menu.close(false)
		lab._action()
		for step in range(180):
			lab._physics_process(1.0 / 60.0)
		lab._action()
		lab.combat_meter_toggle.set_pressed_no_signal(true)
		lab.combat_meter_toggle.pressed.emit()
		await process_frame
		await process_frame
		if dimensions.y == 565:
			await _proof("hud-combat-stats-icons")
		lab.combat_meter_toggle.set_pressed_no_signal(false)
		lab.combat_meter_toggle.pressed.emit()
		await _check_header_relic_capacity(lab)
	root.size = old_size
	root.content_scale_mode = old_mode
	lab.run_practice()
	lab.set_physics_process(false)
	await process_frame
	await process_frame


func _check_header_relic_capacity(lab: Control) -> void:
	var before: Dictionary = lab.run.data.duplicate(true)
	var previous_campaign: bool = lab.campaign
	var previous_encounter: bool = lab.encounter_setup
	lab.campaign = true
	lab.encounter_setup = true
	lab.run.data.node = {"type": "battle", "label": "A deliberately long encounter name for the compact header"}
	lab.run.data.gold = 987
	var available: Array = FrontierRun.RELICS.keys()
	for count: int in [20, 30]:
		lab.run.data.relics = []
		for index in range(count):
			lab.run.data.relics.append(available[index % available.size()])
		lab._rebuild_relic_strip()
		lab._update_controls()
		for frame in range(4):
			await process_frame
		var bounds := root.get_visible_rect().grow(0.1)
		_check(lab.relic_strip.get_child_count() == count and lab.relic_scroller.get_h_scroll_bar().visible,
			"All %d passive relics remain available in the capped left icon strip." % count)
		for control: Control in [lab.action_menu.trigger, lab.action, lab.header_gold, lab.speed_controls]:
			_check(bounds.encloses(control.get_global_rect()),
				"Twenty to thirty relics never displace %s off the compact header." % control.name)
		_check(lab.relic_scroller.get_global_rect().end.x <= lab.speed_controls.global_position.x,
			"Relics remain in the left header while the controls stay on the right.")
		for badge: Control in lab.relic_strip.get_children():
			_check(badge is TextureRect and not badge is BaseButton, "Equipped relics remain passive information, without clickable button highlights.")
			var preview := badge._make_custom_tooltip(badge.tooltip_text) as Control
			var copy := preview.find_child("RelicDescription", true, false) as RichTextLabel
			_check(copy != null and copy.fit_content and not copy.scroll_active
				and copy.text == FrontierRun.RELICS[badge.get_meta("relic_id")].description,
				"Equipped relic hovers preserve the full effect without text scrolling.")
			preview.free()
	lab.run.data = before
	lab.campaign = previous_campaign
	lab.encounter_setup = previous_encounter
	lab._rebuild_relic_strip()
	lab._update_controls()


func _proof(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await create_timer(0.06).timeout
	await RenderingServer.frame_post_draw
	var lab := root.get_child(0) as Control
	_check(root.get_visible_rect().encloses(lab.action.get_global_rect())
		and root.get_visible_rect().encloses(lab.action_menu.trigger.get_global_rect()),
		"The rendered %s keeps its primary action and menu fully inside the screen." % label)
	root.get_texture().get_image().save_png("user://%s.png" % label)


func _open_menu(lab: Control) -> void:
	lab.action_menu.open()
	await process_frame
	await process_frame


func _menu_click(lab: Control, button: Control) -> void:
	await _open_menu(lab)
	lab.action_menu._scroller.ensure_control_visible(button)
	await process_frame
	await process_frame
	_click(button.get_global_rect().get_center())
	await process_frame
	await process_frame


func _check(passed: bool, description: String) -> void:
	if not passed:
		failures.append(description)

func _click(point: Vector2) -> void:
	_button_input(point, true)
	_button_input(point, false)

func _button_input(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)

func _motion(from: Vector2, to: Vector2, dragging: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.relative = to - from
	if dragging:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)
