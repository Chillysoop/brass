extends SceneTree

const ArenaScene = preload("res://arena.tscn")
const ArenaSim = preload("res://scripts/arena_sim.gd")
const FrontierRun = preload("res://scripts/frontier_run.gd")
const SAVE_PATH := "user://hud-reward-drawer-test.json"

var failures: Array[String] = []
var game: Control


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(856, 535)
	game = ArenaScene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var run: FrontierRun = game.run
	run.load_save(SAVE_PATH)
	run.profile.hard_unlocked = true
	if not _check(run.start_run(42, "hard") and run.choose_hero("warden")
		and run.choose_relic("pocket_bell") and run.choose_starter("shield_tap"), "Prepare the real reward model."):
		quit(1)
		return
	run.data.segment = 3
	run.data.node = run._node("battle", "Drawer checks", FrontierRun.NODES_PER_SEGMENT * 2, 0)
	run.data.heroes.append({"id": "starshot", "hp": 100, "max_hp": 100})
	run.data.heroes.append({"id": "apothecary", "hp": 100, "max_hp": 100})
	run.loadout.lanes.append([_tile("shot", 0)])
	run.loadout.lanes.append([_tile("first_aid", 0)])
	run.loadout.defaults.append_array(["nearest", "nearest"])
	run.loadout.storage[0] = [_tile("shot", 0)]
	_check(run.finish_combat(true, [93, 91, 89]) and run.reward_count() == 3, "Queue a reward for each hero.")
	game.combat_meter_open = true
	game.run_return()
	await _settle()
	var full_field: Rect2 = game.arena.get_global_rect()
	_check(not game.storage_screen.visible and not game.combat_sidebar.visible and game.combat_meter_open,
		"Drafts start at full width with both drawers collapsed and the previous stats preference retained.")
	_check(game.lane_stack.get_child(0).visible and not game.lane_stack.get_child(1).visible
		and not game.lane_stack.get_child(2).visible, "Only the hero currently receiving a tile needs a visible placement lane.")
	_check(game.storage_button.is_visible_in_tree() and game.storage_button.get_parent() == game.action.get_parent()
		and "2 / 24" == game.storage_button.text, "The existing storage action is a top-right icon and capacity during a draft.")
	_check(game.storage_button.size.x >= 68 and game.storage_button.size.x <= 112
		and (game.storage_button.size_flags_horizontal & Control.SIZE_EXPAND) == 0,
		"Pinned storage stays a compact icon and capacity control instead of stretching across the header.")
	_click(game.storage_button.get_global_rect().get_center())
	await _settle()
	_check(game.reward_drawer_open and game.storage_screen.visible and game.storage_screen._docked
		and game.storage_screen._close.is_visible_in_tree()
		and root.get_visible_rect().grow(0.1).encloses(game.storage_screen._frame.get_global_rect()),
		"One click opens a contained right storage drawer with an accessible Close action.")
	_check(game.arena.get_global_rect().is_equal_approx(full_field), "Opening storage never compresses or reflows the full-text choices.")
	var stored := game.storage_screen.find_child("StoredTile_shot_0_0", true, false) as Control
	if stored == null:
		printerr("Drawer fixture: %s / %s / %s / %s / %s" % [run.loadout.storage, game.storage_rows, game.reward_drawer_open, game.storage_screen.visible, game.storage_button.get_global_rect()])
		for failure: String in failures:
			printerr(failure)
		quit(1)
		return
	var board := game.tile_cards[0].values().front().get_parent() as Control
	await _drag(stored.get_global_rect().get_center(), board.global_position + Vector2(board.size.x * 3.0 / ArenaSim.BEATS, 15))
	_check(run.data.phase == "reward" and run.loadout.storage[0].is_empty()
		and run.loadout.lanes[0].any(func(tile: Dictionary): return tile.id == "shot"),
		"Owned tiles still drag out of the drawer into the active sequence without claiming the offered tile.")
	_click(game.storage_button.get_global_rect().get_center())
	await _settle()
	_check(not game.storage_screen.visible and not game.reward_storage_drawer.visible, "The same header icon closes storage and restores the unobscured choices.")
	await _menu_press(game.combat_meter_toggle)
	_check(game.reward_stats_open and game.combat_meter.visible and not game.storage_screen.visible
		and game.combat_meter.get_parent() == game.reward_storage_drawer
		and game.combat_meter_open and game.arena.get_global_rect().is_equal_approx(full_field),
		"The stats command opens a visible overlay drawer without losing the outside-combat preference or resizing choices.")
	await _menu_press(game.combat_meter_toggle)
	_check(not game.reward_stats_open and not game.reward_storage_drawer.visible and game.combat_meter_open,
		"Closing the stats drawer restores all choices while retaining the combat preference.")
	var id: String = run.data.offers.front()
	var choice := game.frontier_screen.find_child("RewardTile_" + id, true, false) as Control
	var origin := choice.get_global_rect().get_center()
	_button_input(origin, true)
	_motion(origin, origin + Vector2(18, 0))
	await _settle()
	var edge := Vector2(full_field.end.x - 5, full_field.position.y + 100)
	_motion(origin + Vector2(18, 0), edge)
	await _settle()
	_check(game.reward_drawer_open and game.storage_screen.visible, "Dragging a reward toward the right edge opens storage without an extra click.")
	var cell: Control
	for candidate: Node in game.storage_screen.find_children("*", "Button", true, false):
		if candidate.tooltip_text == "Storage row 1, column 1":
			cell = candidate
			break
	if _check(cell != null, "The opened drawer exposes a free storage destination."):
		var target := cell.get_global_rect().get_center()
		_motion(edge, target)
		_button_input(target, false)
		await _settle()
		_check(run.reward_lane() == 1 and run.loadout.storage[0].any(func(tile: Dictionary): return tile.id == id),
			"Dropping into the opened drawer claims and saves the reward for the correct hero.")
		_check(not game.reward_drawer_open and not game.storage_screen.visible
			and not game.lane_stack.get_child(0).visible and game.lane_stack.get_child(1).visible,
			"The next hero starts with full-text choices, collapsed drawers and their own visible lane.")
		_click(game.storage_button.get_global_rect().get_center())
		await _settle()
		_click(game.storage_screen._expand.get_global_rect().get_center())
		await _settle()
		var active_board := game.lane_stack.get_child(1).get_child(1) as Control
		_check(not game.storage_screen._docked
			and is_equal_approx(game.storage_screen._popup_tile_row_size.x / 8.0, active_board.size.x / ArenaSim.BEATS),
			"Expanded storage keeps exact tile pitch with the active hero, including the second hero's draft.")
		_click(game.storage_screen._close.get_global_rect().get_center())
		await _settle()
		_check(not game.storage_screen.visible, "Closing expanded storage returns to collapsed full-text choices.")
	game.run.data.phase = "combat"
	game.run_return()
	await _settle()
	_check(range(3).all(func(index: int): return game.lane_stack.get_child(index).visible)
		and game.combat_meter.visible and game.combat_meter.get_parent() == game.reward_storage_drawer,
		"All party lanes and the previous stats preference return outside tile selection.")
	_check(game.storage_button.get_parent() == game.action_menu.content
		and game.storage_button.size_flags_horizontal == Control.SIZE_EXPAND_FILL,
		"Storage becomes a full-width menu item again outside tile selection.")
	await _all_combat_stats_states()
	game.queue_free()
	await process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Full-width reward choices, contextual inventory, stats overlay, edge-drag storage and active hero placement passed.")
	quit(0 if failures.is_empty() else 1)


func _tile(id: String, start: int) -> Dictionary:
	return {"id": id, "start": start, "target": ArenaSim.TILES[id].targets[0]}


func _all_combat_stats_states() -> void:
	var heroes: Array = game.run.data.heroes.duplicate(true)
	var lanes: Array = game.run.loadout.lanes.duplicate(true)
	var defaults: Array = game.run.loadout.defaults.duplicate()
	for dimensions: Vector2i in [Vector2i(1280, 800), Vector2i(856, 535)]:
		root.size = dimensions
		for count in range(1, 4):
			game.run.data.heroes = heroes.slice(0, count)
			game.run.loadout.lanes = lanes.slice(0, count)
			game.run.loadout.defaults = defaults.slice(0, count)
			game.run.data.phase = "combat"
			game.run_return()
			game.combat_meter_open = false
			for mode: String in ["setup", "running", "finished"]:
				game.state = mode
				game._update_controls()
				await _settle()
				var field: Rect2 = game.arena.get_global_rect()
				var actor: Vector2 = game.sim.units[0].pos
				var projected: Vector2 = game.arena._project(actor, Rect2(Vector2.ZERO, game.arena.size))
				await _menu_press(game.combat_meter_toggle)
				_check(game.combat_meter.is_visible_in_tree() and game.combat_meter.get_parent() == game.reward_storage_drawer
					and not game.combat_sidebar.visible and game.arena.get_global_rect().is_equal_approx(field)
					and game.arena._project(actor, Rect2(Vector2.ZERO, game.arena.size)).is_equal_approx(projected),
					"Stats overlap without arena or actor projection changes for %d heroes, %s, %s." % [count, dimensions, mode])
				_check(root.get_visible_rect().grow(0.1).encloses(game.reward_storage_drawer.get_global_rect())
					and field.intersects(game.reward_storage_drawer.get_global_rect()),
					"The visible stats window overlays the right arena edge and stays on screen.")
				await _menu_press(game.combat_meter_toggle)
				_check(not game.combat_meter.visible and game.arena.get_global_rect().is_equal_approx(field),
					"Closing statistics never changes the arena geometry.")
			game.state = "setup"
			game._update_controls()
			game._open_storage()
			await _settle()
			var storage_field: Rect2 = game.arena.get_global_rect()
			await _menu_press(game.combat_meter_toggle)
			_check(game.combat_meter.visible and game.storage_screen.is_visible_in_tree()
				and game.arena.get_global_rect().is_equal_approx(storage_field)
				and game.storage_popup_layer.get_index() > game.reward_storage_drawer.get_index(),
				"Expanded storage stays above overlapping stats, with no extra arena reflow.")
			game.storage_close()
			game.combat_meter_open = false
			game._update_controls()
			await _settle()


func _menu_press(button: Control) -> void:
	game.action_menu.open()
	await _settle()
	game.action_menu._scroller.ensure_control_visible(button)
	await _settle()
	_click(button.get_global_rect().get_center())
	await _settle()


func _drag(from: Vector2, to: Vector2) -> void:
	_button_input(from, true)
	_motion(from, from.lerp(to, 0.4))
	await process_frame
	_motion(from.lerp(to, 0.4), to)
	_button_input(to, false)
	await _settle()


func _click(point: Vector2) -> void:
	_button_input(point, true)
	_button_input(point, false)


func _button_input(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	root.push_input(event, true)


func _motion(from: Vector2, to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.relative = to - from
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)


func _settle() -> void:
	for frame in range(6):
		await process_frame


func _check(value: bool, message: String) -> bool:
	if not value:
		failures.append(message)
	return value
