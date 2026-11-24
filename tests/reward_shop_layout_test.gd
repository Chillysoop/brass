extends SceneTree

const Arena = preload("res://arena.tscn")
const ArenaSim = preload("res://scripts/arena_sim.gd")
const FrontierRun = preload("res://scripts/frontier_run.gd")
const LONG_TILES := ["vanishing_cut_upgrade_legendary_power", "shieldshock_upgrade_legendary_technique", "wildfire_globe_upgrade_legendary_technique"]

var failures: Array[String] = []
var paths: Array[String] = []
var game: Control


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	game = Arena.instantiate()
	root.add_child(game)
	await _settle()
	game.set_physics_process(false)
	for viewport_size: Vector2i in [Vector2i(1280, 800), Vector2i(856, 565), Vector2i(856, 535)]:
		root.size = viewport_size
		for heroes: int in [1, 2, 3]:
			for stats: bool in [false, true]:
				await _full_reward_text(heroes, stats)
		await _merchant_shop()
	await _crowded_header()
	await _preview_lifecycle()
	await _actual_reward_click_and_drag()
	game.queue_free()
	await _settle()
	for path: String in paths:
		for suffix: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Full non-scrolling reward text, grounded ability cards, merchant stock/services, icon prices, menu actions, and real reward input passed.")
	quit(0 if failures.is_empty() else 1)


func _fixture(heroes := 1) -> FrontierRun:
	var run := FrontierRun.new()
	var path := "user://reward-shop-layout-%d-%d.json" % [Time.get_ticks_usec(), paths.size()]
	paths.append(path)
	run.load_save(path)
	_check(run.start_run(42), "Create a fresh layout fixture.")
	run.data.offers = ["warden"]
	_check(run.choose_hero("warden") and run.choose_relic("pocket_bell") and run.choose_starter("shield_tap"), "Prepare a playable hero.")
	for index in range(1, heroes):
		var id: String = ["warden", "starshot", "apothecary"][index]
		run.data.heroes.append({"id": id, "hp": 100, "max_hp": 100})
		run.loadout.lanes.append([_tile("shot", 0)])
		run.loadout.defaults.append("nearest")
	_check(run.finish_combat(true, run.data.heroes.map(func(hero: Dictionary): return hero.hp)), "Reach a real saved reward.")
	run.data.reward_lane = heroes - 1
	run.data.reward_remaining = []
	game.run = run
	game.campaign = false
	game.state = "setup"
	return run


func _full_reward_text(heroes: int, stats: bool) -> void:
	var run := _fixture(heroes)
	run.data.offers = LONG_TILES.duplicate()
	game.combat_meter_open = stats
	game.run_return()
	await _settle()
	var viewport: Rect2 = root.get_visible_rect().grow(1)
	for id: String in LONG_TILES:
		var action := game.frontier_screen.find_child("RewardTile_" + id, true, false) as Button
		if not _check(action != null, "Every Legendary ability remains a selectable reward."):
			continue
		var panel := action.get_parent() as Control
		var body := panel.find_child("ChoiceDetails", true, false) as RichTextLabel
		_check(panel.get_meta("grounded_tile_choice", false) and panel.get_theme_stylebox("panel") is StyleBoxFlat,
			"Ability rewards have defined card surfaces, distinct from borderless relics.")
		_check(body.fit_content and not body.scroll_active and body.get_parsed_text() == ArenaSim.TILES[id].description,
			"The entire %s ability remains present without a text scroller." % id)
		_check(body.get_content_height() <= body.size.y + 1 and viewport.encloses(body.get_global_rect())
			and viewport.encloses(panel.get_global_rect()) and game.frontier_screen.get_global_rect().grow(1).encloses(panel.get_global_rect()),
			"Every line of %s is visible in %d-hero %s rewards (stats %s): %d in %s; card %s; overlay %s." % [id, heroes, root.size, stats, body.get_content_height(), body.size, panel.get_global_rect(), game.frontier_screen.size])
		var stats_row := panel.find_child("TileStats", true, false)
		_check(stats_row.find_child("AttackIcon", true, false) != null, "Attack damage has the shared sword icon.")
	_check(not game.storage_screen.visible and game.storage_screen._docked and game.storage_button.is_visible_in_tree(),
		"The right storage drawer remains reachable without reducing full-text choice width.")
	var menu: Control = game.action_menu
	var skip := menu.content.find_child("SkipReward", true, false) as Button
	var reroll := menu.content.find_child("RerollReward", true, false) as Button
	_check(skip != null and reroll != null and skip.find_child("GoldIcon", true, false) != null
		and reroll.find_child("GoldIcon", true, false) != null, "Reward utility actions use coin prices in the top-right menu.")
	if root.size.x == 856 and heroes == 3 and stats:
		await _proof("full-text-three-hero")


func _merchant_shop() -> void:
	var run := _fixture(3)
	run.data.phase = "shop"
	run.data.gold = 200
	run.data.node = {"type": "shop", "label": "Relay Market", "row": 2, "lane": 0, "id": "shop-layout"}
	run.data.offers = ["bash", "shot", "armor_crush", "shield_tap", "pull", "guard"]
	run.data.shop_stock = run.data.offers.duplicate()
	run.data.shop_deck_offer = "shield_tap"
	run.data.shop_class_offers = {"shield_tap": "warden", "shot": "starshot", "guard": "apothecary"}
	run.data.shop_healed = false
	run.data.elite_relic_drafted = true
	var relics := run._available_relics()
	relics.sort_custom(func(a: String, b: String): return FrontierRun.RELICS[a].description.length() > FrontierRun.RELICS[b].description.length())
	run.data.shop_relic = relics[0]
	run.data.heroes[0].hp = 80
	game.combat_meter_open = false
	game.run_return()
	await _settle()
	_check(game.frontier_screen.find_child("ShopSign", true, false) != null
		and game.frontier_screen.find_child("MerchantCounter", true, false) != null
		and game.frontier_screen.find_child("ShopServices", true, false) != null,
		"A merchant sign, inventory shelves and service counter distinguish shops from battle choices.")
	_check(game.frontier_screen.find_child("GuildLedgerStock", true, false) != null, "Party stock retains its distinct Ledger section.")
	for body: Node in game.frontier_screen.find_children("ChoiceDetails", "RichTextLabel", true, false):
		_check(body.fit_content and not body.scroll_active and body.get_content_height() <= body.size.y + 1,
			"Every inventory item's complete effect is visible within its card; only the inventory catalog may scroll.")
	var services := game.frontier_screen.find_child("ShopServices", true, false) as Control
	_check(root.get_visible_rect().grow(1).encloses(services.get_global_rect()), "The complete merchant service counter stays on screen for %s at %s: %s." % [run.data.shop_relic, root.size, services.get_global_rect()])
	var relic_body := services.find_child("ShopRelicDescription", true, false) as RichTextLabel
	_check(not relic_body.scroll_active and relic_body.get_content_height() <= relic_body.size.y + 1,
		"The shop relic effect is fully readable without scrolling.")
	_check(services.find_child("HealthIcon", true, false) != null, "The recovery service uses a heart and value.")
	var purchase := game.frontier_screen.find_child("ShopTile_bash", true, false) as Button
	_check(purchase.find_child("GoldIcon", true, false) != null and not purchase.disabled, "Inventory prices use an actual coin icon and amount.")
	if root.size.x == 856:
		await _proof("merchant-shop")
	var saved_path := run.save_path
	var before := run.data.duplicate(true)
	var inventory := run.loadout.duplicate(true)
	run.save_path = saved_path + ".missing/purchase.json"
	await _click(purchase.get_global_rect().get_center())
	var failed_notice := game.frontier_screen.find_child("ShopNotice", true, false) as Label
	_check(not run.save_error.is_empty() and run.data == before and run.loadout == inventory
		and failed_notice != null and failed_notice.is_visible_in_tree() and failed_notice.text == run.save_error,
		"A first-purchase save failure visibly explains the error while preserving gold, stock and inventory: saved error %s, data %s, inventory %s, notice %s." % [not run.save_error.is_empty(), run.data == before, run.loadout == inventory, failed_notice.is_visible_in_tree() if failed_notice != null else false])
	_check(root.get_visible_rect().grow(1).encloses(services.get_global_rect())
		and root.get_visible_rect().grow(1).encloses(failed_notice.get_global_rect()),
		"A wrapped shop failure leaves the complete service counter and error on screen.")
	run.save_path = saved_path
	await _click(purchase.get_global_rect().get_center())
	var bought := game.frontier_screen.find_child("ShopTile_bash", true, false) as Button
	_check(bought != null and bought.disabled and bought.text == "Purchased" and "bash" not in run.data.offers
		and run.data.gold == 200 - run.shop_price("bash"), "Purchasing preserves and greys the stock card instead of removing it.")
	var header := game.frontier_screen.find_child("RunHeader", true, false) as Control
	var top_menu: Control = game.frontier_screen._action_menu
	_check(top_menu.trigger.get_global_rect().position.x > root.size.x * 0.75
		and header.find_child("RunRelics", true, false).get_global_rect().position.x < root.size.x * 0.15,
		"Shop controls are grouped top-right and owned relics start at the top-left.")


func _crowded_header() -> void:
	var run := _fixture(3)
	root.size = Vector2i(856, 535)
	run.data.phase = "shop"
	run.data.node = {"type": "shop", "label": "Relay Market", "row": 2, "lane": 0, "id": "crowded-header"}
	run.data.offers = ["bash", "shot", "guard"]
	run.data.shop_stock = run.data.offers.duplicate()
	run.data.shop_healed = false
	run.data.shop_relic = ""
	for relic_count: int in [20, 30]:
		run.data.relics = FrontierRun.RELICS.keys().slice(0, relic_count)
		game.run_return()
		await _settle()
		var header := game.frontier_screen.find_child("RunHeader", true, false) as Control
		var menu: Control = game.frontier_screen._action_menu
		var proceed := game.frontier_screen.find_child("Continue", true, false) as Control
		var relics := header.find_child("RunRelics", true, false) as ScrollContainer
		_check(root.get_visible_rect().grow(1).encloses(header.get_global_rect())
			and root.get_visible_rect().grow(1).encloses(proceed.get_global_rect())
			and root.get_visible_rect().grow(1).encloses(menu.trigger.get_global_rect()),
			"Twenty or thirty relics cannot push the three-hero resources, Continue or menu off screen.")
		_check(relics != null and relics.get_child(0).get_child_count() == relic_count
			and relics.size.x < relics.get_child(0).size.x, "All owned relic icons remain in a capped left viewport with passive hover access.")


func _preview_lifecycle() -> void:
	var run := _fixture()
	game.run_return()
	await _settle()
	var screen: Control = game.frontier_screen
	var before := screen.get_signal_connection_list("resized").size()
	var unused: Control = screen.tile_hover_card(LONG_TILES[0], "warden", "")
	unused.free()
	_check(screen.get_signal_connection_list("resized").size() == before,
		"An unshown tooltip never leaves a resize subscription behind.")
	var shown: Control = screen.tile_hover_card(LONG_TILES[1], "warden", "")
	root.add_child(shown)
	await _settle()
	shown.queue_free()
	await _settle()
	_check(screen.get_signal_connection_list("resized").size() == before,
		"Closing a full-text tooltip releases all of its resize subscriptions.")
	screen.resized.emit()
	await _settle()


func _actual_reward_click_and_drag() -> void:
	var run := _fixture()
	run.data.offers = ["bash", "shot", "guard"]
	run.loadout.lanes[0] = []
	game.run_return()
	await _settle()


	var card := game.frontier_screen.find_child("RewardTile_bash", true, false) as Button
	var body := card.get_parent().find_child("ChoiceDetails", true, false) as Control
	await _click(body.get_global_rect().get_center())
	_check(run.data.phase == "map" and run.loadout.lanes[0].any(func(tile: Dictionary): return tile.id == "bash"),
		"A real click on the full grounded ability body equips and advances.")
	run = _fixture()
	run.data.offers = ["bash", "shot", "guard"]
	run.loadout.lanes[0] = []
	game.run_return()
	await _settle()
	card = game.frontier_screen.find_child("RewardTile_bash", true, false) as Button
	var source: Vector2 = card.get_parent().get_global_rect().get_center()
	var board := game.lane_stack.get_child(0).get_child(1) as Control
	var destination := board.get_global_rect().position + Vector2(board.size.x * 5.5 / ArenaSim.BEATS, 12)
	var down := InputEventMouseButton.new()
	down.position = source
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down, true)
	var move := InputEventMouseMotion.new()
	move.position = source + Vector2(20, 12)
	move.relative = Vector2(20, 12)
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(move, true)
	await _settle()
	_check(root.gui_is_dragging(), "A reward drag still begins on its grounded card surface.")
	var arrive := InputEventMouseMotion.new()
	arrive.position = destination
	arrive.relative = destination - move.position
	arrive.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(arrive, true)
	var release := InputEventMouseButton.new()
	release.position = destination
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	root.push_input(release, true)
	await _settle()
	_check(not root.gui_is_dragging() and run.data.phase == "map"
		and run.loadout.lanes[0].size() == 1 and run.loadout.lanes[0][0].id == "bash" and run.loadout.lanes[0][0].start == 5,
		"A real reward drag places the chosen card at its exact sequence span without a stray automatic claim.")
	run = _fixture()
	game.run_return()
	await _settle()
	_check(game.action_menu.content.find_child("SkipReward", true, false) != null,
		"Reward-specific utility actions exist while the reward is shown.")
	game.run_show_arena()
	await _settle()
	_check(game.action_menu.content.find_child("SkipReward", true, false) == null,
		"Hiding a reward screen removes its menu actions from active combat.")
	var depart := InputEventMouseMotion.new()
	depart.position = Vector2(-20, -20)
	depart.relative = depart.position - destination
	root.push_input(depart, true)
	await _settle()


func _tile(id: String, start: int) -> Dictionary:
	return {"id": id, "start": start, "target": ArenaSim.TILES[id].targets[0]}


func _settle() -> void:
	for frame in range(8):
		await process_frame


func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await _settle()


func _proof(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://%s.png" % label)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
	return condition
