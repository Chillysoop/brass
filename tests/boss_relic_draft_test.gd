extends SceneTree

const Arena := preload("res://arena.tscn")
const ArenaSim := preload("res://scripts/arena_sim.gd")
const ClassDecks := preload("res://scripts/class_decks.gd")
const FrontierRun := preload("res://scripts/frontier_run.gd")

var failures: Array[String] = []
var save_path := "user://boss-relic-test-%d.json" % Time.get_ticks_usec()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Arena.instantiate()
	root.add_child(game)
	await process_frame
	await _check_draft_and_shop(game)
	game.queue_free()
	await process_frame
	for path in [save_path, save_path + ".control"]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Boss relic draft, save and resume, and Guild Ledger shop branch passed on the same seed.")
	quit(0 if failures.is_empty() else 1)


func _check_draft_and_shop(game: Control) -> void:
	var run: FrontierRun = game.run
	run.load_save(save_path)
	run.profile.medium_unlocked = true
	if not _check(run.start_run(42, "medium", "brass") and run.choose_hero(run.data.offers[0])
		and run.choose_relic("pocket_bell") and run.choose_starter("bash"), "Start the same Brass crew for both branches."):
		return
	var boss_row := FrontierRun.NODES_PER_SEGMENT - 1
	run.data.phase = "map"
	run.data.node = run.data.layers[boss_row - 1][0]
	if not _check(run.choose_node(run.data.layers[boss_row][0].id) and run.finish_combat(true, 66), "Win the Tollkeeper encounter."):
		return
	var marks: int = run.profile.marks
	var legendary: String = run.data.offers[0]
	if not _check(ArenaSim.TILES[legendary].rarity == "legendary" and game.run_claim_reward(legendary),
		"The original hero must receive the normal Legendary pick before the relic draft."):
		return
	var draft := run.boss_relic_offers()
	var ids := draft.map(func(offer: Dictionary): return offer.id)
	ids.sort()
	if not _check(ids == ["bastion_medal", "guild_ledger", "tollkeeper_repair_kit", "tollkeeper_signet"],
		"Offer each Tollkeeper relic exactly once."):
		return
	_check(not run.choose_boss_relic("pocket_bell") and not run.choose_recruit("warden"), "Only an offered relic or Skip can resolve the draft.")
	var control := FrontierRun.new()
	_check(control.load_save(save_path) and control.boss_relic_offers() == draft, "Reload the saved draft with the same offers and order.")
	control.save_path = save_path + ".control"
	game.run_resume()
	await process_frame
	for id: String in ids:
		_check(game.frontier_screen.find_child("BossRelic_" + id, true, false) is Button, "The resumed draft shows " + id)
	var ledger := game.frontier_screen.find_child("BossRelic_guild_ledger", true, false) as Button
	if ledger == null:
		return
	ledger.pressed.emit()
	await process_frame
	if not _check(run.data.phase == "recruit" and run.data.relics.count("guild_ledger") == 1 and run.profile.marks == marks
		and not run.choose_boss_relic("bastion_medal"), "One relic selection advances to recruitment and preserves the boss payout."):
		return
	var persisted := FrontierRun.new()
	_check(persisted.load_save(save_path) and persisted.data.phase == "recruit" and persisted.data.relics == run.data.relics,
		"Reload the confirmed relic and recruitment checkpoint.")
	if not _check(control.choose_boss_relic("skip") and control.data.offers == run.data.offers, "Skipping moves to the same recruit draft."):
		return
	var recruit: String = run.data.offers[0]
	for branch: FrontierRun in [control, run]:
		if not _check(branch.choose_recruit(recruit) and branch.choose_recruit_starter(ClassDecks.starter(recruit)), "Recruit the same hero in both branches."):
			return
		if not _check(_enter_shop(branch), "Both branches must reach an Act II shop."):
			return
	var ordinary_stock: Array = control.data.offers
	var ledger_stock: Array = run.data.offers.duplicate()
	var deck_offer := control.shop_deck_offer_id()
	_check(not deck_offer.is_empty() and deck_offer in ordinary_stock and run.shop_deck_offer_id() == deck_offer,
		"The regular class-deck tile is stocked before the Ledger adds its extra cards.")
	_check(run.data.gold == control.data.gold, "Guild Ledger keeps the gold from skipped combat rewards.")
	_check(run.data.node.id == control.data.node.id and ledger_stock.slice(0, ordinary_stock.size()) == ordinary_stock,
		"The Guild Ledger adds stock to the same shop without replacing its normal offers.")
	var extras := ledger_stock.slice(ordinary_stock.size())
	if not _check(extras.size() == 2 and extras[0] != extras[1], "The Guild Ledger stocks one distinct extra tile for each hero."):
		return
	var saved_shop := FrontierRun.new()
	_check(saved_shop.load_save(save_path) and saved_shop.data.offers == ledger_stock, "Reload the same Ledger stock.")
	for lane in range(extras.size()):
		var owner: String = run.data.heroes[lane].id
		var tile: String = extras[lane]
		_check(tile in ClassDecks.common(owner) + ClassDecks.uncommon(owner)
			and saved_shop.shop_class_offer_lane(tile) == lane and run.shop_class_offer_owner(tile) == owner,
			"Each extra tile comes from its displayed hero's class deck and keeps that association after reloading.")
	game.run_resume()
	await process_frame
	var ledger_row := game.frontier_screen.find_child("GuildLedgerStock", true, false) as Control
	var deck_card := game.frontier_screen.find_child("ShopTile_" + deck_offer, true, false) as Button
	_check(ledger_row != null and deck_card != null and not ledger_row.is_ancestor_of(deck_card)
		and not run.shop_class_offer_owner(deck_offer).is_empty() and saved_shop.shop_deck_offer_id() == deck_offer,
		"The regular class card keeps its owner and stays in regular stock beside the separate Ledger row.")
	var recruit_tile: String = extras[1]
	var purchase := game.frontier_screen.find_child("ShopTile_" + recruit_tile, true, false) as Button
	if not _check(purchase != null and not purchase.disabled, "The recruit's stocked tile can be bought from the shop."):
		return
	var destination := purchase.get_parent().find_child("ChoiceDetails", true, false) as RichTextLabel
	_check(destination.get_parsed_text().contains("Goes to " + FrontierRun.HEROES[recruit].label),
		"The recruit's card states its destination before purchase.")
	var price := run.shop_price(recruit_tile)
	var gold: int = run.data.gold
	var card_slot := purchase.get_parent().get_parent().get_index()
	var lead_tiles: Array = run.loadout.lanes[0].duplicate(true)
	var recruit_tiles: int = run.loadout.lanes[1].size()
	purchase.pressed.emit()
	await process_frame
	_check(run.data.gold == gold - price and recruit_tile not in run.data.offers and run.loadout.lanes[0] == lead_tiles
		and run.loadout.lanes[1].size() == recruit_tiles + 1
		and run.loadout.lanes[1].any(func(tile: Dictionary): return tile.id == recruit_tile),
		"The shop charges its listed price and places the bought class tile on the recruit's timeline.")
	var receipt := game.frontier_screen.find_child("RewardPlacement", true, false) as Label
	_check(receipt != null and receipt.text == "%s added to %s’s timeline" % [ArenaSim.TILES[recruit_tile].label, FrontierRun.HEROES[recruit].label],
		"The shop confirms which hero received the purchased tile.")
	purchase = game.frontier_screen.find_child("ShopTile_" + recruit_tile, true, false) as Button
	_check(purchase != null and purchase.disabled and purchase.text == "Purchased"
		and purchase.get_parent().get_parent().get_index() == card_slot and run.shop_stock() == ledger_stock,
		"The purchased Ledger tile should stay in its original stock slot.")
	await _check_storage_purchase(game, deck_offer)


func _check_storage_purchase(game: Control, id: String) -> void:
	var run: FrontierRun = game.run
	var full_lane: Array = []
	for beat in range(0, ArenaSim.BEATS, int(ArenaSim.TILES.guard.width)):
		full_lane.append({"id": "guard", "start": beat, "target": "self"})
	run.loadout.lanes = [full_lane, full_lane.duplicate(true)]
	run.data.gold = 100
	var before := run.data.duplicate(true)
	var inventory := run.loadout.duplicate(true)
	run.save_path = save_path + ".missing/purchase.json"
	_check(not game.run_buy_shop(id) and run.data == before and run.loadout == inventory and not run.save_error.is_empty(),
		"A failed tile purchase restores gold, stock, the prior receipt, and inventory.")
	run.save_path = save_path
	game.run_return()
	await process_frame
	var purchase := game.frontier_screen.find_child("ShopTile_" + id, true, false) as Button
	if not _check(purchase != null and not purchase.disabled, "The normal shop tile remains available to buy."):
		return
	var destination := purchase.get_parent().find_child("ChoiceDetails", true, false) as RichTextLabel
	_check(destination.get_parsed_text().contains("Goes to tile storage"), "The shop previews storage when both lanes are full.")
	purchase.pressed.emit()
	await process_frame
	var placement := {"id": id, "row": 0, "start": 0}
	if not _check(run.current_reward_placement() == placement, "A full party sends the purchased tile to storage.") \
		or not _check(run.load_save(save_path), "Resume the shop after the purchase."):
		return
	var restored := run.current_reward_placement()
	_check(restored.get("id") == id and int(restored.get("row", -1)) == 0 and int(restored.get("start", -1)) == 0,
		"The shop keeps the purchased tile's exact location after reloading.")
	game.run_resume()
	await process_frame
	var sold := game.frontier_screen.find_child("ShopTile_" + id, true, false) as Button
	_check(sold != null and sold.disabled and sold.text == "Purchased" and run.shop_deck_offer_id() == id
		and not run.shop_class_offer_owner(id).is_empty(),
		"The purchased class card remains visible with its original ownership after reload.")
	run.data.heroes[0].hp = int(run.data.heroes[0].max_hp) - 20
	game.run_resume()
	await process_frame
	var heal := game.frontier_screen.find_child("ShopHeal", true, false) as Button
	if _check(heal != null and not heal.disabled, "The healing service is available to the injured party."):
		heal.pressed.emit()
		await process_frame
		heal = game.frontier_screen.find_child("ShopHeal", true, false) as Button
		_check(heal != null and heal.disabled and heal.text == "Heal used",
			"The heal button states that the one-time service has been used even if the party still needs healing.")
	var open := game.frontier_screen.find_child("OpenRewardStorage", true, false) as Button
	if not _check(open != null and open.is_visible_in_tree(), "A stored market purchase shows the storage shortcut."):
		return
	open.pressed.emit()
	_check(game.storage_screen.visible and game.selected.get("id") == id and game.selected.get("row") == 0,
		"The shortcut opens storage and selects the purchased tile.")


func _enter_shop(run: FrontierRun) -> bool:
	for _step in range(7):
		var nodes := run.available_nodes()
		if nodes.is_empty():
			return false
		for node: Dictionary in nodes:
			if node.type == "shop":
				return run.choose_node(node.id)
		var battle := nodes.filter(func(node: Dictionary): return node.type == "battle")
		if battle.is_empty() or not run.choose_node(battle[0].id):
			return false
		if not run.finish_combat(true, run.data.heroes.map(func(hero: Dictionary): return hero.hp)):
			return false
		while run.data.phase == "reward":
			if not run.reward("skip"):
				return false
	return false


func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
	return ok
