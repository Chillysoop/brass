extends SceneTree

const Arena := preload("res://arena.tscn")
const ArenaSim := preload("res://scripts/arena_sim.gd")
const FrontierRun := preload("res://scripts/frontier_run.gd")
const ClassDecks := preload("res://scripts/class_decks.gd")
const ClassExpansionTiles := preload("res://scripts/class_expansion_tiles.gd")
const TilePacking := preload("res://scripts/tile_packing.gd")
const ORIGINAL_STARTERS := {
	"warden": "shield_tap", "bulwark": "pike_thrust", "breaker": "breaker_maul", "hexwright": "grapple",
	"wayfarer": "blink", "lancer": "retreat_shot", "cantor": "signal_flare", "apothecary": "snap_shot",
	"rune_smith": "slam", "starshot": "rivet_bolt", "cinder_mage": "shrapnel", "duelist": "jab",
}

var failures: Array[String] = []
var save_path := "user://party-reward-test-%d.json" % Time.get_ticks_usec()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Arena.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.run.load_save(save_path)
	_check_class_decks()
	_check_signature_elite_progression()
	_check_signature_milestones()
	await _check_medium_rewards(game)
	game.queue_free()
	await process_frame
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Class decks and party reward controls, inventory, resume, and trophies passed.")
	quit(0 if failures.is_empty() else 1)


func _check_class_decks() -> void:
	var run := FrontierRun.new()
	run.load_save(save_path)
	var distinct_pools := {}
	var signature_owners := {}
	for class_id: String in FrontierRun.HEROES:
		var signature := ClassDecks.signature(class_id)
		_check(not signature.is_empty() and not signature_owners.has(signature),
			"%s needs its own signature tile." % class_id)
		signature_owners[signature] = class_id
	for class_id: String in FrontierRun.HEROES:
		var common: Array = ClassDecks.common(class_id)
		var uncommon: Array = ClassDecks.uncommon(class_id)
		var signature := ClassDecks.signature(class_id)
		_check(common.size() == 18 and common.all(func(id: String):
			return common.count(id) == 1 and ArenaSim.TILES.has(id) \
				and ArenaSim.TILES[id].get("rarity", "common") == "common"), "%s should have 18 distinct Commons." % class_id)
		_check(uncommon.size() == 8 and uncommon.all(func(id: String):
			return uncommon.count(id) == 1 and ArenaSim.TILES.get(id, {}).get("rarity") == "uncommon"),
			"%s should have 8 distinct Uncommons." % class_id)
		var new_commons := common.filter(func(id: String): return id in ClassExpansionTiles.COMMON_IDS)
		var new_uncommons := uncommon.filter(func(id: String): return id in ClassExpansionTiles.UNCOMMON_IDS)
		_check(new_commons.size() == 8 and new_uncommons.size() == 4,
			"%s should gain eight new Commons and four new Uncommons." % class_id)
		_check(uncommon.filter(func(id: String): return signature_owners.has(id)) == [signature],
			"%s should list only its own signature." % class_id)
		common.sort()
		var key := str(common)
		_check(not distinct_pools.has(key), "%s needs its own Common deck." % class_id)
		distinct_pools[key] = true
		run.start_run(1)
		run.data.offers = [class_id]
		var starter := ClassDecks.starter(class_id)
		var started := run.choose_hero(class_id) and run.choose_relic("pocket_bell")
		started = started and run.data.offers.size() == 3 and starter in run.data.offers and run.choose_starter(starter)
		_check(started and starter == ORIGINAL_STARTERS[class_id], "%s should still be able to pick its original starter." % class_id)
		if not started:
			run.abandon_run()
			continue
		var class_pool := common + uncommon
		var seen := {}
		for seed_value in range(1, 385):
			run.data.seed = seed_value
			run.data.phase = "combat"
			_check(run.finish_combat(true, 95), "%s must be able to draft a regular victory reward." % class_id)
			var offers: Array = run.data.offers
			_check(offers.size() == 3 and offers.all(func(id: String): return offers.count(id) == 1),
				"%s should draft three distinct tiles per reward." % class_id)
			for id: String in offers:
				if ArenaSim.TILES[id].get("rarity", "common") == "common":
					_check(id in common, "%s drew a Common outside its deck: %s." % [class_id, id])
				if signature_owners.has(id):
					_check(signature_owners[id] == class_id, "%s drew another class's signature: %s." % [class_id, id])
				if id in class_pool:
					seen[id] = true
			if seen.size() == class_pool.size():
				break
		_check(seen.size() == class_pool.size(), "%s must be able to draw every class tile across seeded victories." % class_id)
		run.abandon_run()


func _check_signature_elite_progression() -> void:
	for pairing in [["warden", "starshot"], ["breaker", "wayfarer"], ["apothecary", "hexwright"],
		["rune_smith", "duelist"], ["cantor", "rune_smith"], ["bulwark", "lancer"], ["cinder_mage", "warden"]]:
		_check_signature_elite_pair(pairing[0], pairing[1])


func _check_signature_elite_pair(lead: String, recruit: String) -> void:
	var run := FrontierRun.new()
	run.load_save(save_path)
	run.profile.medium_unlocked = true
	if not run.start_run(42, "medium"):
		_check(false, "Expected a new run for signature upgrade rewards.")
		return
	run.data.offers = [lead]
	var started := run.choose_hero(lead) and run.choose_relic("pocket_bell") \
		and run.choose_starter(ClassDecks.starter(lead)) and run.finish_combat(true, 100) and run.reward("skip")
	_enter_boss(run, false)
	started = started and run.finish_combat(true, 100) and run.reward("skip")
	started = started and run.choose_boss_relic("skip")
	run.data.offers = [recruit]
	started = started and run.choose_recruit(recruit) and run.choose_recruit_starter(ClassDecks.starter(recruit))
	_check(started, "Expected a two-hero party for signature upgrade rewards.")
	if not started:
		return

	var lead_signature := ClassDecks.signature(lead)
	var recruit_signature := ClassDecks.signature(recruit)
	var lead_rare: String = TilePacking.next_options(lead_signature)[0]
	var lead_epics := TilePacking.next_options(lead_rare)
	run.data.elite_relic_drafted = true
	run.loadout.lanes[0] = [_signature_tile(lead_signature, 0), _signature_tile(lead_signature, ArenaSim.TILES[lead_signature].width)]
	run.loadout.lanes[1] = [_signature_tile(recruit_signature, 0)]
	run.loadout.storage[0] = [_signature_tile(lead_rare, 0)]
	var row := FrontierRun.NODES_PER_SEGMENT + 3
	var elite: Dictionary = run.data.layers[row].filter(func(node: Dictionary): return node.type == "elite")[0]
	run.data.node = run.data.layers[row - 1][elite.column]
	var preview := run.elite_preview(elite)
	var won := run.choose_node(elite.id) and run.finish_combat(true, [100, 100])
	_check(won and run.data.offers.size() == 3 and preview.get("tile") in run.data.offers
		and lead_signature in run.data.offers and run.reward_hint(lead_signature) == "Third copy"
		and run.data.offers.any(func(id: String): return id in lead_epics),
		"Later elites retain the preview and third copy, and offer an Epic for %s's owned Rare." % lead)
	_check(won and run.reward("skip") and run.reward_lane() == 1
		and run.data.offers.any(func(id: String): return id in TilePacking.next_options(recruit_signature))
		and not run.data.offers.any(func(id: String): return id in lead_epics),
		"%s receives their own Rare signature upgrade in the second draft." % recruit)
	run.abandon_run()


func _signature_tile(id: String, start: int) -> Dictionary:
	return {"id": id, "start": start, "target": ArenaSim.TILES[id].targets[0]}


func _check_signature_milestones() -> void:
	for takes_uncommon in [false, true]:
		var run := FrontierRun.new()
		run.load_save(save_path)
		run.profile.hard_unlocked = true
		_check(run.start_run(42, "hard"), "Expected a Hard route for signature pacing.")
		run.data.offers = ["bulwark"]
		run.choose_hero("bulwark")
		run.choose_relic("pocket_bell")
		run.choose_starter(ClassDecks.starter("bulwark"))
		run.finish_combat(true, 100)
		run.reward("skip")
		var lead := ClassDecks.signature("bulwark")
		if takes_uncommon:
			run.loadout.storage[0].append(_signature_tile(lead, 0))
			run.data.node = run.data.layers[1].filter(func(node: Dictionary): return node.type == "battle")[0]
			run.data.phase = "combat"
			_check(run.finish_combat(true, 100) and _draft_offers_rare(run, lead),
				"The lead can draft a Rare after taking their Leg 1 Uncommon.")
			run.reward("skip")
		for recruit in ["lancer", "cinder_mage"]:
			var leg: int = run.data.heroes.size()
			run.data.node = run.data.layers[FrontierRun.NODES_PER_SEGMENT * leg - 1][0]
			run.data.phase = "combat"
			var hp := [100] if leg == 1 else [100, 100]
			_check(run.finish_combat(true, hp), "Expected a victory before recruiting.")
			for hero_index in range(leg):
				run.reward("skip")
			if leg == 1:
				_check(run.choose_boss_relic("skip"), "Skip the Tollkeeper relic in the signature pacing test.")
			run.data.offers = [recruit]
			_check(run.choose_recruit(recruit) and run.choose_recruit_starter(ClassDecks.starter(recruit)),
				"Expected the recruit to have a normal starter.")
			var gate: Dictionary = run.data.layers[FrontierRun.NODES_PER_SEGMENT * leg][0]
			hp.append(100)
			_check(run.choose_node(gate.id) and run.finish_combat(true, hp), "Expected a real gate reward draft.")
			if leg == 1 and not takes_uncommon:
				_check(_draft_offers_rare(run, lead), "The Leg 2 gate offers the lead a Rare if they missed the Leg 1 chance.")
			for hero_index in range(leg):
				run.reward("skip")
			_check(run.reward_lane() == leg and _draft_offers_rare(run, ClassDecks.signature(recruit)),
				"The new recruit should see a Rare on their first gate win.")
			_check(run.data.offers.size() == 3 and run.load_save(save_path)
				and _draft_offers_rare(run, ClassDecks.signature(recruit)), "The three gate offers should survive reload.")
			run.reward("skip")
		run.abandon_run()


func _draft_offers_rare(run: FrontierRun, signature: String) -> bool:
	return run.data.offers.any(func(id: String): return id in TilePacking.next_options(signature))


func _check_medium_rewards(game: Control) -> void:
	var run: FrontierRun = game.run
	run.profile.medium_unlocked = true
	var started := run.start_run(42, "medium")
	if not started:
		_check(false, "The test needs an unlocked Medium route.")
		return
	var offered_class: String = run.data.offers[0]
	game.run_return()
	await _click(game.frontier_screen, "ClassDeck_" + offered_class)
	var dialog: AcceptDialog
	for child in game.frontier_screen.get_children():
		if child is AcceptDialog:
			dialog = child
			break
	_check(dialog != null and dialog.visible and FrontierRun.HEROES[offered_class].label in dialog.title,
		"The class draft's deck button should open the selected class deck.")
	if dialog != null:
		var names := _descendant_buttons(dialog)
		var deck := ClassDecks.common(offered_class) + ClassDecks.uncommon(offered_class)
		_check(deck.all(func(id: String): return ArenaSim.TILES[id].label in names),
			"The deck inspector displays the class's Commons, Uncommons, and signature.")
		var stats := dialog.find_child("TileStats", true, false)
		_check(stats != null and stats.get_node_or_null("BeatStat/BeatIcon") != null,
			"The selected deck tile shows its beat through the shared stat icon.")
		dialog.confirmed.emit()
		await process_frame
	started = started and run.choose_hero(run.data.offers[0]) and run.choose_relic("pocket_bell")
	started = started and run.choose_starter(run.data.offers[0]) and run.finish_combat(true, 100)
	_check(started, "A seeded solo opening should produce a combat reward.")
	if not started:
		return
	var lead: String = run.data.heroes[0].id
	_check(run.reward_count() == 1 and run.reward_lane() == 0, "The opening reward belongs only to the original hero.")
	var opening_tile: String = run.data.offers[0]
	_check(game.run_claim_reward(opening_tile) and run.data.phase == "map", "Claiming the solo tile should open the route.")
	_enter_boss(run, false)
	_check(run.finish_combat(true, 100) and run.reward_count() == 1, "The Tollkeeper reward must come before the recruit joins.")
	var first_legendary: String = run.data.offers[0]
	_check(ArenaSim.TILES[first_legendary].rarity == "legendary" and game.run_claim_reward(first_legendary)
		and run.data.phase == "boss_relic", "The original hero earns the first boss tile before the relic draft.")
	game.run_return()
	await _click(game.frontier_screen, "SkipBossRelic")
	if run.data.phase != "recruit":
		_check(false, "The boss relic screen's skip button should open recruitment.")
		return
	var lead_tiles: Array = run.loadout.lanes[0].duplicate(true)
	var recruit: String = run.data.offers[0]
	var recruit_starter := ClassDecks.starter(recruit)
	_check(run.choose_recruit(recruit) and recruit_starter in run.data.offers and run.choose_recruit_starter(recruit_starter),
		"The second hero can join with their own starter tile.")
	_check(run.loadout.lanes[0] == lead_tiles and run.loadout.lanes[0].size() > run.loadout.lanes[1].size()
		and run.loadout.lanes[1].size() == 1, "Recruiting preserves the first hero's head start.")

	var battle := {"id": "party-reward-battle", "row": FrontierRun.NODES_PER_SEGMENT, "column": 0,
		"type": "battle", "label": "Practice Patrol", "next": []}
	# Signatures can move between heroes without entering the recipient's reward pool.
	var lead_signature := ClassDecks.signature(lead)
	var recruit_signature := ClassDecks.signature(recruit)
	run.loadout.lanes[0].assign([{"id": recruit_signature, "start": 0, "target": ArenaSim.TILES[recruit_signature].targets[0]}])
	run.loadout.lanes[1].assign([{"id": lead_signature, "start": 0, "target": ArenaSim.TILES[lead_signature].targets[0]}])
	run.data.node = battle
	run.data.phase = "combat"
	_check(run.finish_combat(true, [100, 100]) and run.reward_count() == 2
		and run.reward_lane() == 0 and run.reward_position() == 0, "The next victory must offer one reward per hero.")
	var first_offers: Array = run.data.offers.duplicate()
	_check(first_offers.size() == 3 and recruit_signature not in first_offers,
		"The original hero sees three choices without copying the recruit's signature.")
	# Free both timelines to verify where the real reward buttons place each chosen tile.
	run.loadout.lanes[0].clear()
	run.loadout.lanes[1].clear()
	game.run_return()
	await process_frame
	_check(_reward_header_has(game.frontier_screen, "RewardHero", FrontierRun.HEROES[lead].label)
		and _reward_header_has(game.frontier_screen, "RewardProgress", "1"),
		"The first reward screen identifies the lead hero and pick position.")
	_check_reward_tile_identity(game.frontier_screen, first_offers, lead)
	var first_tile: String = first_offers[0]
	var first_button := game.frontier_screen.find_child("RewardTile_" + first_tile, true, false) as Button
	var first_details := first_button.get_parent().find_child("ChoiceDetails", true, false) as Control
	var body_point := first_details.get_global_rect().get_center()
	_push_mouse_button(body_point, true)
	_push_mouse_button(body_point + Vector2(15.0, 0.0), false)
	_check(run.reward_position() == 0, "Dragging across a reward card does not claim it.")
	_push_mouse_button(body_point, true)
	_push_mouse_button(body_point, false)
	await process_frame
	_check(run.data.phase == "reward" and run.reward_position() == 1 and run.reward_lane() == 1
		and run.loadout.lanes[0].size() == 1 and run.loadout.lanes[0][0].id == first_tile
		and run.loadout.lanes[1].is_empty(), "Clicking the card body equips the tile and advances to the recruit.")
	_check(_reward_header_has(game.frontier_screen, "RewardPlacement",
		"%s added to %s’s timeline" % [ArenaSim.TILES[first_tile].label, FrontierRun.HEROES[lead].label]),
		"The next pick confirms which timeline received the lead's tile.")
	var second_offers: Array = run.data.offers.duplicate()
	_check(second_offers.size() == 3 and first_offers != second_offers and lead_signature not in second_offers,
		"The recruit sees three separate choices without copying the lead's signature.")

	# Reload from disk between the two heroes' reward claims.
	_check(run.load_save(save_path) and run.reward_count() == 2 and run.reward_position() == 1
		and run.data.offers == second_offers and run.loadout.lanes[0].size() == 1,
		"Resuming midway must retain the recruit's exact cards and the lead's recorded claim.")
	game.run_return()
	await process_frame
	_check(_reward_header_has(game.frontier_screen, "RewardHero", FrontierRun.HEROES[recruit].label)
		and _reward_header_has(game.frontier_screen, "RewardProgress", "2"),
		"The resumed screen identifies the recruit and second pick.")
	_check_reward_tile_identity(game.frontier_screen, second_offers, recruit)
	var second_tile: String = second_offers[0]
	await _claim_from_screen(game.frontier_screen, second_tile)
	_check(run.data.phase == "map" and run.reward_lane() == -1 and run.loadout.lanes[1].size() == 1
		and run.loadout.lanes[1][0].id == second_tile and not game.run_claim_reward(second_tile),
		"Claiming the recruit's tile equips it only once and opens the route.")
	_check_first_elite_signatures(run, lead_signature, recruit_signature)

	run.data.node = battle
	run.data.phase = "combat"
	_check(run.finish_combat(true, [100, 0]) and run.reward_count() == 2,
		"A fallen recruit keeps their reward pick for when the party revives them.")
	var gold_before := int(run.data.gold)
	game.run_return()
	await _click(game.frontier_screen, "SkipReward")
	_check(run.reward_lane() == 1 and int(run.data.gold) == gold_before + 6,
		"The lead can skip for gold and the next hero still receives a choice.")
	await _click(game.frontier_screen, "SkipReward")
	_check(run.data.phase == "map" and int(run.data.gold) == gold_before + 6,
		"Skipping both rewards should award the encounter's skip gold only once.")

	run.data.node = battle
	run.data.phase = "combat"
	run.loadout.lanes[0].clear()
	run.loadout.lanes[1].assign([{"id": "slam", "start": 0, "target": "nearest"},
		{"id": "slam", "start": 4, "target": "nearest"}, {"id": "slam", "start": 8, "target": "nearest"}])
	run.loadout.storage.assign([[], [], []])
	_check(run.finish_combat(true, [100, 100]) and game.run_claim_reward("skip") and run.reward_lane() == 1,
		"The test must reach the recruit's reward with their timeline full.")
	var stowed: String = run.data.offers[0]
	game.run_return()
	await _claim_from_screen(game.frontier_screen, stowed)
	_check(run.data.phase == "map" and run.loadout.lanes[0].is_empty()
		and run.loadout.storage[0].size() == 1 and run.loadout.storage[0][0].id == stowed,
		"When its own timeline is full, a tile reward goes to storage and leaves the other hero's lane alone.")
	_check(_reward_header_has(game.frontier_screen, "RewardPlacement", "%s sent to storage" % ArenaSim.TILES[stowed].label),
		"The route map tells the player which reward was sent to storage.")
	_check(run.load_save(save_path), "Resume the map after a reward goes to storage.")
	game.run_return()
	await _click(game.frontier_screen, "OpenRewardStorage")
	_check(game.storage_screen.visible and game.selected.get("id") == stowed and game.selected.get("row") == 0,
		"The saved receipt opens storage and selects the newly stowed reward.")
	game._place_selected(0, 0)
	game._leave_arena()
	_check(run.loadout.storage[0].is_empty() and run.loadout.lanes[0][0].id == stowed
		and game.frontier_screen.find_child("OpenRewardStorage", true, false) == null,
		"Moving the reward out of storage removes the old receipt and shortcut.")

	_enter_boss(run, true)
	_check(run.finish_combat(true, [100, 100]) and run.reward_count() == 2, "The final boss offers a trophy to both heroes.")
	for hero_id: String in [lead, recruit]:
		var trophy: String = run.data.offers[0]
		_check(ArenaSim.TILES[trophy].rarity == "legendary" and game.run_claim_reward(trophy)
			and run.data.trophies.get(hero_id) == trophy,
			"Each hero receives a Legendary trophy recorded under their own class.")
	_check(run.data.phase == "result" and run.data.trophy == run.data.trophies.get(lead)
		and run.profile.hard_unlocked, "The final pick opens the recap and retains the lead trophy and victory unlock.")


func _check_first_elite_signatures(run: FrontierRun, lead_signature: String, recruit_signature: String) -> void:
	var elite_row := FrontierRun.NODES_PER_SEGMENT + 3
	var elite: Dictionary = run.data.layers[elite_row].filter(func(node: Dictionary): return node.type == "elite")[0]
	run.data.node = run.data.layers[elite_row - 1][elite.column]
	var preview := run.elite_preview(elite)
	# Ensure the draft has a relic that can bring a companion tile into the lead's offers.
	for lane: Array in run.loadout.lanes:
		lane.clear()
	var won := run.choose_node(elite.id) and run.finish_combat(true, [100, 100])
	_check(won and run.reward_count() == 2 and preview.get("tile") == lead_signature and lead_signature in run.data.offers,
		"The first elite should advertise and award the lead's signature as a choice.")
	if not won:
		return
	var relics := run.elite_relic_offers().filter(func(offer: Dictionary):
		return not offer.companion.is_empty() and offer.companion not in run.data.offers)
	_check(not relics.is_empty(), "The first-elite test needs a new relic companion tile.")
	if relics.is_empty():
		return
	var relic: Dictionary = relics[0]
	_check(run.load_save(save_path) and run.choose_elite_relic(relic.id) and run.data.offers.size() == 3
		and lead_signature in run.data.offers and relic.companion in run.data.offers,
		"The saved first elite draft must preserve the signature while adding the relic companion.")
	_check(run.reward("skip") and run.reward_lane() == 1 and run.data.offers.size() == 3
		and recruit_signature in run.data.offers and lead_signature not in run.data.offers and run.reward("skip"),
		"The first elite also offers the recruit's signature in their own draft.")


func _enter_boss(run: FrontierRun, final: bool) -> void:
	var row: int = run.data.layers.size() - 1 if final else FrontierRun.NODES_PER_SEGMENT - 1
	run.data.node = run.data.layers[row][0]
	run.data.phase = "combat"


func _reward_header_has(page: Control, node_name: String, copy: String) -> bool:
	var label := page.find_child(node_name, true, false) as Label
	return label != null and label.is_visible_in_tree() and copy in label.text


func _check_reward_tile_identity(page: Control, offers: Array, hero: String) -> void:
	for id: String in offers:
		var select := page.find_child("RewardTile_" + id, true, false) as Button
		if select == null:
			_check(false, "Expected a reward card for " + id)
			continue
		var card := select.get_parent()
		var owner := card.find_child("TileHeroBadge", true, false) as Control
		var rarity := card.find_child("TileRarityBadge", true, false) as Label
		var spec: Dictionary = ArenaSim.TILES[id]
		_check(owner != null and owner.is_visible_in_tree() and owner.get_meta("hero_class", "") == hero
			and rarity != null and rarity.is_visible_in_tree() and rarity.get_meta("rarity", "") == spec.rarity
			and rarity.text.begins_with(str(spec.rarity).capitalize()),
			"Reward tile %s should show its rarity and recipient %s." % [id, hero])


func _descendant_buttons(node: Node) -> Array[String]:
	var labels: Array[String] = []
	for child in node.get_children():
		if child is Button:
			labels.append(child.text)
		labels.append_array(_descendant_buttons(child))
	return labels


func _claim_from_screen(page: Control, id: String) -> void:
	await _click(page, "RewardTile_" + id)


func _click(page: Control, node_name: String) -> void:
	await process_frame
	var button := page.find_child(node_name, true, false) as Button
	var clickable := button != null and button.is_visible_in_tree() and not button.disabled
	_check(clickable, "Expected the visible %s button to accept input." % node_name)
	if not clickable:
		return
	for down in [true, false]:
		_push_mouse_button(button.get_global_rect().get_center(), down)
	await process_frame


func _push_mouse_button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	root.push_input(event, true)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
