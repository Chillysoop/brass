extends SceneTree

const ArenaScene = preload("res://arena.tscn")
const ArenaSim = preload("res://scripts/arena_sim.gd")
const FrontierRun = preload("res://scripts/frontier_run.gd")
const SAVE_PATH := "user://compact-party-layout-test.json"

var failures: Array[String] = []
var game: Control


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	game = ArenaScene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.run.load_save(SAVE_PATH)
	game.run.profile.hard_unlocked = true
	_check(game.run.start_run(42, "hard") and game.run.choose_hero("warden")
		and game.run.choose_relic("pocket_bell") and game.run.choose_starter("shield_tap"), "Prepare a real three-hero run.")
	game.run.data.segment = 3
	game.run.data.node = game.run._node("battle", "Compact party", FrontierRun.NODES_PER_SEGMENT * 2, 0)
	game.run.data.heroes.append({"id": "starshot", "hp": 100, "max_hp": 100})
	game.run.data.heroes.append({"id": "apothecary", "hp": 100, "max_hp": 100})
	game.run.loadout.lanes.append([])
	game.run.loadout.lanes.append([])
	game.run.loadout.defaults.append_array(["nearest", "nearest"])
	for window_size: Vector2i in [Vector2i(1280, 800), Vector2i(856, 565), Vector2i(856, 535)]:
		root.size = window_size
		for stats: bool in [false, true]:
			await _ordinary_party(stats)
			await _crowded_party(stats)
	game.run_menu()
	_check(not game.storage_popup_layer.is_visible_in_tree(), "Leaving combat also hides the detached storage popup layer.")
	game.queue_free()
	await process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Compact three-hero sequences, full-size stored tiles, targeting, and crowded-party scrolling passed.")
	quit(0 if failures.is_empty() else 1)


func _ordinary_party(stats: bool) -> void:
	game.run.loadout.lanes = [
		[_tile("jab", 0), _tile("bash", 1), _tile("pull", 3), _tile("slam", 6)],
		[_tile("star_piercer", 0), _tile("jab", 5), _tile("first_aid", 6)],
		[_tile("first_aid", 0), _tile("pull", 2), _tile("slam", 5)],
	]
	game.run.loadout.storage = [
		[_tile("jab", 0), _tile("bash", 1), _tile("pull", 3)],
		[_tile("slam", 0), _tile("first_aid", 4)],
		[_tile("star_piercer", 0)],
	]
	game.combat_meter_open = stats
	game.run_return()
	await _settle()
	var viewport := root.get_visible_rect().grow(0.1)
	_check(viewport.encloses(game.lane_scroller.get_global_rect()),
		"The party sequence viewport stays on screen at %s with stats %s." % [root.size, stats])
	_check(viewport.encloses(game.setup_hint.get_global_rect()) and viewport.encloses(game.action.get_global_rect())
		and viewport.encloses(game.speed_controls.get_global_rect()), "Header actions and setup instructions stay on screen.")
	var sizes := {}
	for lane_index: int in range(game.tile_cards.size()):
		var row := game.lane_stack.get_child(lane_index) as Control
		game.lane_scroller.ensure_control_visible(row)
		await _settle()
		_check(game.lane_scroller.get_global_rect().grow(0.1).encloses(row.get_global_rect()), "Each complete hero sequence is reachable at %s stats %s: %s inside %s." % [root.size, stats, row.get_global_rect(), game.lane_scroller.get_global_rect()])
		var lane: Dictionary = game.tile_cards[lane_index]
		for card: Control in lane.values():
			_check(viewport.encloses(card.get_global_rect()), "Every width-one through width-five equipped tile is fully visible.")
			sizes[card.get_meta("tile").id] = card.size
	game._open_storage()
	await _settle()
	_check(viewport.encloses(game.storage_screen._frame.get_global_rect()), "The expanded storage frame fits the viewport, including with combat stats open.")
	_check(not game.arena.is_ancestor_of(game.storage_screen), "Expanded storage is outside the arena's clipping boundary so Close and footer actions remain visible over the stats sidebar.")
	_check(game.storage_screen._frame.get_global_rect().position.y >= game.action.get_global_rect().end.y,
		"The storage popup never covers the battle header or Save & title.")
	for row: int in range(game.storage_rows.size()):
		for tile: Dictionary in game.storage_rows[row]:
			var stored := game.storage_screen.find_child("StoredTile_%s_%d_%d" % [tile.id, row, tile.start], true, false) as Control
			_check(stored.size.is_equal_approx(sizes[tile.id]), "Storage preserves exact %s dimensions at %s stats %s: %s matches %s." % [tile.id, root.size, stats, stored.size, sizes[tile.id]])
	if root.size.x == 856 and stats:
		await _proof("compact-party-storage")
	game.storage_close()
	await _settle()


func _crowded_party(stats: bool) -> void:
	game.run.loadout.lanes = [
		[_tile("jab", 0), _tile("jab", 1), _tile("jab", 2), _tile("first_aid", 3), _tile("star_piercer", 5)],
		[_tile("jab", 0), _tile("jab", 1), _tile("jab", 2), _tile("bash", 3), _tile("pull", 5)],
		[_tile("jab", 0), _tile("jab", 1), _tile("jab", 2), _tile("slam", 3), _tile("star_piercer", 7)],
	]
	game.combat_meter_open = stats
	game.run_return()
	# Crown Relay adds its existing three enemy targets; narrow tiles need two target rows.
	game.sim.units.back()["crown_role"] = "relay_regent"
	game._rebuild_loadout()
	await _settle()
	_check(game._tile_row_height() >= 89, "The crowded fixture preserves the existing targeting options on one-width tiles.")
	var viewport := root.get_visible_rect().grow(0.1)
	_check(viewport.encloses(game.lane_scroller.get_global_rect()) and viewport.encloses(game.action.get_global_rect()),
		"Crowded sequences and the battle action remain reachable within the viewport.")
	var last_row := game.lane_stack.get_child(2) as Control
	game.lane_scroller.ensure_control_visible(last_row)
	await _settle()
	var visible_lanes: Rect2 = game.lane_scroller.get_global_rect().grow(0.1)
	_check(visible_lanes.encloses(last_row.get_global_rect()), "The third hero and upgrade prompt can be brought fully into view without shrinking tiles.")
	for lane: Dictionary in game.tile_cards:
		for card: Control in lane.values():
			var target_buttons := card.find_children("Target_*", "Button", true, false)
			_check(target_buttons.size() == game.sim.target_rules(card.get_meta("tile").id).size(), "Wrapping preserves every existing targeting option.")
			for target: Node in target_buttons:
				_check((target as Button).custom_minimum_size.y == 22, "Existing target buttons retain their full control height.")
				_check(card.get_global_rect().grow(0.1).encloses((target as Control).get_global_rect()), "Target icons stay within their own tile instead of overlapping neighbors.")
	if root.size.x == 856 and stats:
		await _proof("compact-party-crowded")


func _tile(id: String, start: int) -> Dictionary:
	return {"id": id, "start": start, "target": ArenaSim.TILES[id].targets[0]}


func _settle() -> void:
	for frame in range(6):
		await process_frame


func _proof(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await create_timer(0.06).timeout
	await RenderingServer.frame_post_draw
	_check(root.get_visible_rect().encloses(game.action.get_global_rect()), "The final rendered battle header remains fully visible.")
	root.get_texture().get_image().save_png("user://%s.png" % label)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
	return condition
