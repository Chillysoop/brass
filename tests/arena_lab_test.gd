extends SceneTree

const ArenaScene = preload("res://arena.tscn")
const ArenaSim = preload("res://scripts/arena_sim.gd")
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
	_check(lab.lanes.size() == 2, "Duo setup should start with two lanes.")
	var preview = lab.sim.target_for(0, "pull", "farthest")
	_check(preview.get("id") == "clockwork", "Pull's default preview should identify the far enemy.")
	var palette_tile: Button = lab.palette.get_child(2)
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
	await _check_practice_arsenal(lab)
	await _check_tile_identity(lab)
	await _check_target_icons(lab)
	_check_enemy_windup(lab)
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
	lab.speed = 2
	lab._physics_process(1.0 / 60.0)
	_check(lab.sim.tick == 2, "2× speed should advance exactly two fixed steps.")
	lab._action()
	lab._physics_process(1.0 / 60.0)
	_check(lab.sim.tick == 2, "Pause should preserve the simulation tick.")
	lab._action()
	await process_frame
	var first_pulse: ColorRect = lab.tile_cards[0].values().front().get_meta("timing_marker").get_child(0)
	var second_pulse: ColorRect = lab.tile_cards[1].values().front().get_meta("timing_marker").get_child(0)
	_check(first_pulse.color != second_pulse.color, "Pulses use distinct colors for the two hero lanes.")
	_click(lab.combat_meter_toggle.get_global_rect().get_center())
	await process_frame
	_check(lab.combat_meter.visible and lab.arena.visible, "Toggle the meter without leaving live combat.")
	_click(lab.combat_meter_toggle.get_global_rect().get_center())
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
	_click(lab.combat_meter_toggle.get_global_rect().get_center())
	await process_frame
	_check(lab.combat_meter.visible and lab.arena.visible and not lab.combat_meter.totals.ranked("damage").is_empty(),
		"The right-side meter retains damage recorded while hidden and leaves the finished arena visible.")
	lab.combat_meter.set_metric("kills")
	_check(not lab.combat_meter.totals.ranked("kills").is_empty(), "Switching metrics shows the killing tiles.")
	_click(lab.combat_meter_toggle.get_global_rect().get_center())
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
	_check_retry_boss_hud(lab)
	if failures.is_empty():
		print("Arena controls checks passed.")
	else:
		for failure in failures:
			printerr(failure)
	lab.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _check_practice_arsenal(lab: Control) -> void:
	lab._load_fixture("duo")
	await process_frame
	_click(lab.arsenal_button.get_global_rect().get_center())
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
	_click(lab.arsenal_button.get_global_rect().get_center())
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
		_click(lab.arsenal_button.get_global_rect().get_center())
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
	_check(popup.visible and lab.storage_rows[0].size() == 3 and not lab.tile_cards[1].has(4),
		"A timeline-to-storage drop should move the tile while leaving the popup open.")
	_check(popup._board.get_child(0).get_child(0).get_child_count() == 1,
		"The third touching copy should immediately show a storage Combine prompt.")
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
	lab.storage_combine(0, 0, true)
	_check(lab.forge_screen.visible, "Storage Combine should open the forge.")
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
	lab._offer_combine(-1, 0, 0, true)
	_check(lab.forge_screen.visible, "Timeline Combine should open the forge.")
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
	_check(not lab.forge_screen.visible, "The rest site must also respect the Blink forge unlock.")

	lab.run.profile.meta.append("blink_artifice")
	lab.storage_forge()
	_check(lab.forge_screen.visible, "An unlocked expedition can open the Blink forge from storage at rest.")
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
	_check(lab.forge_screen._confirm.disabled and lab.forge_screen._edit_layout.visible
		and "one free beat immediately after Shield Ram" in caption and "Blocked by Hook Sweep" in caption,
		"A camp upgrade should explain which adjacent beat and tile are blocking it.")
	var room: HBoxContainer = lab.forge_screen._layout_preview
	_check(room.get_child_count() == ArenaSim.BEATS and "Beat 10 · Hook Sweep" in room.get_child(9).tooltip_text,
		"The preview should mark the overlapping beat on the twelve-beat strip.")
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
		and not lab.forge_screen._confirm.disabled and lab.forge_firing_beat("bulwark_charge") == 8,
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

func _check_retry_boss_hud(lab: Control) -> void:
	for fixture: Dictionary in [
		{"region": "glass", "id": "tempered_colossus", "label": "colossus_status", "move": "Forge Sweep"},
		{"region": "crown", "id": "crown_regent", "label": "relay_status", "move": "Crown Charge"},
		{"region": "moonwreck", "id": "drowned_admiral", "label": "dock_status", "move": "Undertow Sweep"},
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
		var cue: Label = lab.get(fixture.label)
		_check(cue.visible and fixture.move in cue.text, "%s should show its boss guidance in Retry in Practice setup." % fixture.id)
		lab.action.pressed.emit()
		var countdown := false
		for step in range(500):
			lab._physics_process(1.0 / 60.0)
			if cue.visible and "beats left" in cue.text:
				countdown = true
				break
		_check(countdown, "%s should show a countdown during the practice replay." % fixture.id)
		lab.run_menu()


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
