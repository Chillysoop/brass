extends SceneTree

const Arena = preload("res://arena.tscn")
const ArenaSim = preload("res://scripts/arena_sim.gd")
const ClassRelics = preload("res://scripts/class_relics.gd")
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
	await _reward_combine_quick_pick()
	await _rest_forge_one_copy()
	await _storage_previews()
	await _reward_long_descriptions()
	await _relic_labels()
	await _compact_relic_layout()
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
	run.data.reward_hints[id] = "Leave one beat empty before it"
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
	_check((body as RichTextLabel).get_parsed_text() == ArenaSim.TILES[id].description,
		"Reward ability copy stays complete and contains no appended relic-positioning advice.")
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
	var option: Button = game.forge_screen._cards["phase_cut"]
	var preview := option._make_custom_tooltip(option.tooltip_text) as Control
	_check(preview.find_child("TileChoiceArtwork", true, false) != null
		and (preview.find_child("ChoiceDetails", true, false) as RichTextLabel).get_parsed_text() == ArenaSim.TILES.phase_cut.description,
		"Forge options share the illustrated tile preview and full mechanics without a legacy glossary popup.")
	preview.free()
	await _press(game.forge_screen._cards["phase_cut"])
	_check(run.data.phase == "map" and run.loadout.storage[0].size() == 1
		and run.loadout.storage[0][0].id == "phase_cut" and run.loadout.lanes[0][0].id == "jab"
		and run.loadout.storage[0][0].get("enchantment") == "guarded",
		"Rest upgrades only the chosen copy, keeps its compatible enchantment and consumes one rest action.")
	_check(game.arena_screen.is_visible_in_tree() and game.storage_screen.is_visible_in_tree()
		and game.arena.units.is_empty(), "A rest upgrade retains the empty arena and open storage for arranging tiles.")
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


func _reward_combine_quick_pick() -> void:
	var run := _fixture()
	run.data.offers = ["bash", "rake", "guard"]
	run.loadout.lanes[0] = [_tile("bash", 0), _tile("bash", 2)]
	var before := run.loadout.duplicate(true)
	game.run_return()
	await _press(game.frontier_screen.find_child("RewardTile_bash", true, false) as Button)
	_check(game.forge_screen.visible and game.forge_screen._direct_pick
		and not game.forge_screen._confirm.visible and game.forge_screen._merge_intro != null,
		"A reward set plays its merge introduction and offers direct next-tier choices without an extra confirmation.")
	var future: String = TilePacking.forge_tiers("bash").back()[0]
	await _press(game.forge_screen._cards[future])
	_check(run.loadout == before and run.data.has("reward_combine") and game.forge_screen.visible,
		"Clicking an inspectable future rarity cannot consume the pending reward or copies.")
	var choice: String = TilePacking.next_options("bash")[0]
	var path := run.save_path
	run.save_path = path + ".missing/save.json"
	await _press(game.forge_screen._cards[choice])
	_check(run.loadout == before and run.data.has("reward_combine") and game.forge_screen.visible
		and game.forge_screen._error.visible, "A failed direct combine save restores both copies and leaves the same choice open for retry.")
	run.save_path = path
	await _press(game.forge_screen._cards[choice])
	_check(run.data.phase == "map" and not game.forge_screen.visible and not game.arena_screen.visible
		and game.frontier_screen.visible and run.loadout.lanes[0].size() == 1 and run.loadout.lanes[0][0].id == choice,
		"One valid reward path click consumes the set, saves once and returns directly to the map without an empty-arena Continue.")
	var restored := FrontierRun.new()
	_check(restored.load_save(path) and restored.data.phase == "map" and restored.loadout == run.loadout,
		"The direct reward upgrade and advanced phase persist together.")


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
	_check(not text.any(func(value: String): return value.begins_with("Tile offer") or value.begins_with("Tile after")),
		"Relic choices do not advertise a tile before the later draft.")


func _storage_previews() -> void:
	var run := _fixture()
	var stored := _tile("bash", 0)
	stored.enchantment = "guarded"
	run.loadout.storage[0] = [stored]
	game.run_return()
	await process_frame
	for docked: bool in [true, false]:
		if not docked:
			game.run_expand_reward_storage()
			await process_frame
		var card := game.storage_screen.find_child("StoredTile_bash_0_0", true, false) as Button
		var preview := card._make_custom_tooltip(card.tooltip_text) as Control
		root.add_child(preview)
		await process_frame
		var body := preview.find_child("ChoiceDetails", true, false) as RichTextLabel
		var location := preview.find_child("StorageTileLocation", true, false) as Label
		_check(preview.find_child("TileChoiceArtwork", true, false) != null
			and preview.find_child("TileStats", true, false) != null,
			"Stored tiles use the illustrated reward preview with icon statistics in both storage modes.")
		_check(body != null and ArenaSim.TILES.bash.description in body.get_parsed_text()
			and "Guarded" in body.get_parsed_text() and location != null and location.text == "Shared storage",
			"The storage preview retains the full ability, enchantment and shared-storage ownership.")
		_check(not "beats" in card.tooltip_text and not "Beat ·" in body.get_parsed_text(),
			"Storage no longer adds the legacy beat explanation to its preview.")
		if docked:
			await _proof("storage-preview")
		preview.queue_free()
		await process_frame
	game.storage_close()


func _compact_relic_layout() -> void:
	var run: FrontierRun = game.run
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for hero_count: int in [1, 3]:
		if hero_count == 3:
			run.data.heroes.append({"id": "starshot", "hp": 100, "max_hp": 100})
			run.data.heroes.append({"id": "apothecary", "hp": 100, "max_hp": 100})
			run.loadout.lanes.append([_tile("shot", 0)])
			run.loadout.lanes.append([{"id": "triage_kit", "start": 0, "target": "ally_lowest"}])
			run.loadout.defaults.append_array(["nearest", "nearest"])
			run.data.elite_relic_offers[2] = {"id": ClassRelics.id_for("warden"), "owner": "warden", "role": "", "companion": ""}
			run.data.party_elite_relic_pending = true
		for window_size: Vector2i in [Vector2i(1280, 800), Vector2i(856, 565)]:
			root.size = window_size
			for show_stats: bool in [false, true]:
				game.combat_meter_open = show_stats
				game.campaign = false
				game.state = "setup"
				game.run_return()
				await process_frame
				await process_frame
				var focused: bool = hero_count > 1
				var area: Control = game.relic_focus_layer if focused else game.arena
				var arena_rect: Rect2 = area.get_global_rect().intersection(root.get_visible_rect()).grow(1)
				_check(game.relic_focus_layer.visible == focused
					and (not focused or game.frontier_screen.get_parent() == game.relic_focus_layer),
					"Party relics use the full combat-area focus while solo relics keep their existing arena layout.")
				_check(game.save_title_button.is_visible_in_tree()
					and game.save_title_button.get_global_rect().end.y < arena_rect.position.y,
					"The existing top-left Save & title stays accessible above relic choices.")
				for offer: Dictionary in run.elite_relic_offers():
					var card := game.frontier_screen.find_child("RelicChoice_" + offer.id, true, false) as Control
					var portrait := card.find_child("RelicPortrait", true, false) as Control
					var details := card.find_child("ChoiceDetails", true, false) as RichTextLabel
					var claim := card.find_child("EliteRelic_" + offer.id, true, false) as Control
					_check(arena_rect.encloses(card.get_global_rect()) and arena_rect.encloses(claim.get_global_rect()),
						"The complete relic choice and claim stay within %d-hero %s rewards (stats %s): %s inside %s; overlay %s, art %s, copy %s." % [hero_count, window_size, show_stats, card.get_global_rect(), arena_rect, game.frontier_screen.size, portrait.custom_minimum_size, details.custom_minimum_size])
					_check((portrait.custom_minimum_size.y >= 84 or arena_rect.size.y < 260)
						and claim.get_global_rect().position.y - details.get_global_rect().end.y <= 4,
						"Relic artwork is prominent and Claim remains next to the description instead of the arena footer.")
					_check(details.get_parsed_text() == FrontierRun.RELICS[offer.id].description
						and details.get_content_height() <= details.size.y + 1,
						"The complete %s effect is readable without scrolling in %d-hero %s choices (%d within %s)." % [offer.id, hero_count, window_size, details.get_content_height(), details.size])
					if focused:
						_check(not details.scroll_active and portrait.custom_minimum_size.y >= 112,
							"Focused party choices show meaningful relic artwork and the full description rather than a small scroll viewport.")
				if window_size.x == 856 and show_stats:
					await _proof("relic-compact-%d" % hero_count)
	var picked: String = run.elite_relic_offers()[0].id
	await _press(game.frontier_screen.find_child("EliteRelic_" + picked, true, false) as Button)
	_check(not game.relic_focus_layer.visible and game.frontier_screen.get_parent() == game.arena
		and game.storage_screen.visible and game.storage_screen._docked and game.combat_meter.visible,
		"Claiming a party relic restores the arena tile draft, open storage and the previous stats preference immediately.")


func _reward_long_descriptions() -> void:
	var run := _fixture()
	run.data.offers = ["armor_crush", "slam", "bash"]
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for window_size: Vector2i in [Vector2i(1280, 800), Vector2i(856, 565)]:
		root.size = window_size
		for show_stats: bool in [false, true]:
			game.combat_meter_open = show_stats
			game.campaign = false
			game.state = "setup"
			game.run_return()
			await process_frame
			await process_frame
			var action := game.frontier_screen.find_child("RewardTile_armor_crush", true, false) as Button
			var body := action.get_parent().find_child("ChoiceDetails", true, false) as RichTextLabel
			var field: Rect2 = game.arena.get_global_rect().intersection(root.get_visible_rect()).grow(1)
			var skip := game.frontier_screen.find_child("SkipReward", true, false) as Control
			_check(field.encloses(action.get_global_rect()) and field.encloses(skip.get_global_rect()),
				"The full ability and Skip remain inside the single-hero reward arena.")
			_check(body.get_parsed_text() == ArenaSim.TILES.armor_crush.description
				and body.get_content_height() <= body.size.y + 1,
				"The complete Armor Crush condition fits the single-hero %s reward (stats %s): %d within %s." % [window_size, show_stats, body.get_content_height(), body.size])
			var preview := action._make_custom_tooltip(action.tooltip_text) as Control
			_check((preview.find_child("ChoiceDetails", true, false) as RichTextLabel).get_parsed_text() == ArenaSim.TILES.armor_crush.description,
				"Reward artwork also opens the full illustrated ability preview without a scroll budget.")
			preview.free()
			if window_size.x == 856 and show_stats:
				await _proof("armor-crush")


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
