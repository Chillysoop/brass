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
	if not _check(ids == ["bastion_medal", "guild_ledger", "tollkeeper_signet"], "Offer each of the three boss relics exactly once."):
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
	ledger.button_pressed = true
	ledger.pressed.emit()
	await process_frame
	var proceed := game.frontier_screen.find_child("Continue", true, false) as Button
	if not _check(proceed != null and not proceed.disabled, "Selecting a relic enables Continue."):
		return
	proceed.pressed.emit()
	await process_frame
	if not _check(run.data.phase == "recruit" and run.data.relics.count("guild_ledger") == 1 and run.profile.marks == marks
		and not run.choose_boss_relic("bastion_medal"), "The claim adds a single relic and preserves the boss payout."):
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
	var ledger_stock: Array = run.data.offers
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
	_check(game.frontier_screen.find_child("GuildLedgerStock", true, false) != null, "The shop shows the extra Ledger stock as a distinct row.")
	var recruit_tile: String = extras[1]
	var purchase := game.frontier_screen.find_child("ShopTile_" + recruit_tile, true, false) as Button
	if not _check(purchase != null and not purchase.disabled, "The recruit's stocked tile can be bought from the shop."):
		return
	var price := run.shop_price(recruit_tile)
	var gold: int = run.data.gold
	var lead_tiles: Array = run.loadout.lanes[0].duplicate(true)
	var recruit_tiles: int = run.loadout.lanes[1].size()
	purchase.pressed.emit()
	await process_frame
	_check(run.data.gold == gold - price and recruit_tile not in run.data.offers and run.loadout.lanes[0] == lead_tiles
		and run.loadout.lanes[1].size() == recruit_tiles + 1
		and run.loadout.lanes[1].any(func(tile: Dictionary): return tile.id == recruit_tile),
		"The shop charges its listed price and places the bought class tile on the recruit's timeline.")


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
