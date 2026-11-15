extends SceneTree

const ArenaScene = preload("res://arena.tscn")
const ArenaSim = preload("res://scripts/arena_sim.gd")
const FrontierRun = preload("res://scripts/frontier_run.gd")
const SOLO_RELIC_IDS := ["afterimage", "barrage_rack", "siege_fuse", "switchback_lens", "longshot_prism"]
const ROLES := ["Fits your build", "Pivot", "Wildcard"]

var failures: Array[String] = []
var save_path := "user://elite-relic-draft-test-%d.json" % Time.get_ticks_usec()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_seeded_draft()
	_check_party_eligibility()
	await _check_reward_screen()
	await _check_review_filter()
	_check_bounty_and_legacy()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("First elite draft, companion rewards, persistence, and reward screen checks passed.")
	quit(0 if failures.is_empty() else 1)


func _check_seeded_draft() -> void:
	var run := FrontierRun.new()
	run.load_save(save_path)
	var wildcard_roles := {}
	var observed := {}
	var same_seed: Array = []
	# This route starts the post-elite battle with both enemies in the arena, so Siege Fuse can pull on beat four.
	var comparison_seed := 32
	for seed_value in range(1, comparison_seed + 1):
		if not _start(run, seed_value):
			return
		run.loadout.lanes[0].append({"id": "shot", "start": 2, "target": "nearest"})
		var elite: Dictionary = _elites(run)[0]
		var preview := _reach_elite(run, elite)
		if not _win_elite(run, preview):
			return
		var draft: Array = run.elite_relic_offers()
		_check(draft.map(func(offer: Dictionary): return offer.role) == ROLES,
			"Every first elite draft must explain fit, pivot, and wildcard.")
		if draft.size() != 3:
			return
		var ids := {}
		for offer: Dictionary in draft:
			_check(offer.id in SOLO_RELIC_IDS and not ids.has(offer.id),
				"A solo draft must contain distinct solo-compatible relics.")
			if offer.id in ["switchback_lens", "longshot_prism"]:
				_check(offer.companion.is_empty(), "The new relics let the player choose their own tile pairings.")
			ids[offer.id] = true
			observed[offer.id] = true
		_check(draft[0].id == "barrage_rack" and draft[0].companion.is_empty(),
			"Two already-equipped short attacks should make Barrage Rack the fit.")
		wildcard_roles[draft[2].id] = true
		if seed_value == comparison_seed and ids.has("afterimage") and ids.has("siege_fuse"):
			same_seed = draft.duplicate(true)
	_check(wildcard_roles.size() > 1, "Seeds should change the roles of otherwise equally viable offers.")
	_check(observed.size() == SOLO_RELIC_IDS.size(), "The eligible relics must all be reachable across seeded drafts.")
	_check(not same_seed.is_empty(), "The companion comparison needs a draft offering both prototype relics.")
	if same_seed.is_empty() or not _start(run, comparison_seed):
		return
	run.loadout.lanes[0].append({"id": "shot", "start": 2, "target": "nearest"})
	var preview := _reach_elite(run, _elites(run)[0])
	if not _win_elite(run, preview):
		return
	_check(same_seed == run.elite_relic_offers(), "The same seed, node, and equipment must produce the same draft.")
	_check(not run.choose_elite_relic("not_an_offer") and not run.reward("skip") and not run.reward(preview.tile),
		"Invalid relic picks, skips, and tile claims must leave a pending relic draft intact.")
	var same_checkpoint := FrontierRun.new()
	_check(same_checkpoint.load_save(save_path), "Load an identical first-elite checkpoint for a second build.")
	_check(run.choose_elite_relic("afterimage") and same_checkpoint.choose_elite_relic("siege_fuse"),
		"The same draft should support either the teleport or heavy-attack choice.")
	var teleport: String = _companion(same_seed, "afterimage")
	var heavy: String = _companion(same_seed, "siege_fuse")
	_check(teleport in run.data.offers and heavy in same_checkpoint.data.offers
		and run.data.offers != same_checkpoint.data.offers,
		"Two relic picks on the same seed must surface different companion tiles.")
	if not teleport.is_empty() and not heavy.is_empty():
		_check_same_seed_battle(run, same_checkpoint, teleport, heavy)


func _check_party_eligibility() -> void:
	var run := FrontierRun.new()
	run.load_save(save_path)
	if not _start(run, 42):
		return
	var preview := _reach_elite(run, _elites(run)[0])
	if preview.is_empty():
		return
	run.data.heroes.append({"id": "warden", "hp": 100, "max_hp": 100})
	var sweep := {"id": "sweep", "start": 0, "target": "nearest"}
	run.loadout.lanes = [[sweep], [sweep.duplicate()]]
	run.loadout.defaults = ["nearest", "nearest"]
	_check(run.save(), "Save the two-hero battle before the elite win.")
	var survivor := FrontierRun.new()
	_check(survivor.load_save(save_path) and survivor.finish_combat(true, [80, 0]),
		"Resolve the same elite with one hero down.")
	_check(not survivor.elite_relic_offers().any(func(offer: Dictionary): return offer.id == "twin_bell"),
		"A defeated recruit must not make Twin Bell eligible.")
	_check(run.finish_combat(true, [80, 80]), "Resolve a win with both heroes alive.")
	var offers: Array = run.elite_relic_offers().duplicate(true)
	_check(offers.size() == 3 and offers[0].id == "twin_bell" and offers[0].role == "Fits your build",
		"Matched attack finishing beats across two living heroes should rank Twin Bell as the fit.")
	var restored := FrontierRun.new()
	_check(restored.load_save(save_path) and restored.elite_relic_offers() == offers,
		"The expanded party draft must preserve its exact offers on resume.")
	var tiles: Array = restored.data.offers.duplicate()
	_check(restored.choose_elite_relic("twin_bell") and restored.data.offers == tiles,
		"Selecting Twin Bell should preserve the hero's tile draft.")
	_check("twin_bell" not in restored._available_relics() and "switchback_lens" in restored._available_relics(),
		"Shop and event pools should unlock elite relics after the draft without offering held relics.")


func _check_same_seed_battle(first: FrontierRun, second: FrontierRun, teleport: String, heavy: String) -> void:
	var runs := [first, second]
	var relics := ["afterimage", "siege_fuse"]
	var tiles := [teleport, heavy]
	var beats := [5, 4]
	var shared_encounter := {}
	for index in range(runs.size()):
		var run: FrontierRun = runs[index]
		var width: int = ArenaSim.TILES[tiles[index]].width
		run.loadout.lanes[0] = [
			{"id": tiles[index], "start": 0, "target": "farthest" if index == 0 else "nearest"},
			{"id": "bash", "start": width, "target": "nearest"},
			{"id": "shot", "start": width + 2, "target": "nearest"},
		]
		_check(run.reward(tiles[index]), "Claim the companion used in the alternate build.")
		var route: Array = run.available_nodes()
		var battles := route.filter(func(node: Dictionary): return node.type == "battle")
		if battles.is_empty():
			if not _check_next_route_node(run, route):
				return
			battles = run.available_nodes().filter(func(node: Dictionary): return node.type == "battle")
		if battles.is_empty() or not run.choose_node(battles[0].id):
			_check(false, "Both builds must reach a shared post-elite battle.")
			return
		var encounter := run.encounter()
		var comparable := encounter.duplicate(true)
		comparable.erase("relics")
		if index == 0:
			shared_encounter = comparable
			if encounter.get("formation", []).size() < 2:
				_check(false, "Siege Fuse needs two enemies in the starting formation before the first heavy attack.")
				return
		else:
			_check(comparable == shared_encounter, "Both builds must fight the same seeded encounter from the same checkpoint.")
		var sim := ArenaSim.new()
		sim.start(run.loadout.lanes, "solo", encounter)
		while sim.tick < 6000 and sim.outcome.is_empty():
			sim.step()
		var procced := sim.trace.any(func(event: Dictionary):
			return event.kind == "relic_proc" and event.tile == relics[index] \
				and event.tick == beats[index] * ArenaSim.TICKS_PER_BEAT)
		_check(sim.outcome == "victory", "%s should win the shared encounter." % relics[index])
		_check(procced, "%s should activate on beat %d of the first loop." % [relics[index], beats[index]])


func _check_next_route_node(run: FrontierRun, route: Array) -> bool:
	var passed := not route.is_empty() and run.choose_node(route[0].id) and run.leave_node()
	_check(passed, "Pass the intermediate noncombat node on the shared route.")
	return passed


func _check_reward_screen() -> void:
	var game = ArenaScene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var run: FrontierRun = game.run
	run.load_save(save_path)
	if not _start(run, 42):
		game.queue_free()
		return
	var elites := _elites(run)
	_check(elites.size() == 2, "Moonwreck Easy supplies two elites for the first-only draft test.")
	if elites.size() != 2:
		game.queue_free()
		return
	var preview := _reach_elite(run, elites[0])
	if not _win_elite(run, preview):
		game.queue_free()
		return
	var draft: Array = run.elite_relic_offers().duplicate(true)
	var restored := FrontierRun.new()
	_check(restored.load_save(save_path) and restored.elite_relic_offers() == draft,
		"Resuming a won elite must restore the exact pending draft.")
	game.run_return()
	await process_frame
	var advance := _button(game.frontier_screen, "Continue")
	_check(advance != null and advance.disabled, "Elite Continue must wait for a relic selection.")
	var afterimage: Dictionary = {}
	for offer: Dictionary in draft:
		_check(_button(game.frontier_screen, "EliteRelic_" + str(offer.id)) != null,
			"Every offered relic should have a selectable UI card.")
		if offer.id == "afterimage":
			afterimage = offer
	if afterimage.is_empty():
		_check(false, "Afterimage must be offered in the elite draft.")
		game.queue_free()
		return
	var companion := str(afterimage.companion)
	_check(ArenaSim.TILES.get(companion, {}).get("family") == "blink",
		"A Bash-only build needs a Blink-family tile to use Afterimage.")
	await _click(game.frontier_screen, "EliteRelic_afterimage")
	_check(advance != null and not advance.disabled and "afterimage" not in run.data.relics,
		"Selecting a relic should enable Continue before the relic is committed.")
	await _click(game.frontier_screen, "Continue")
	_check(run.elite_relic_offers().is_empty() and run.data.relics.count("afterimage") == 1,
		"Continuing should grant exactly one relic and open the tile panel.")
	_check(run.data.offers.size() == 3 and companion in run.data.offers and preview.tile in run.data.offers,
		"The companion and advertised tile must coexist among three tile choices.")
	_check(restored.load_save(save_path) and restored.elite_relic_offers().is_empty()
		and restored.data.relics == run.data.relics and restored.data.offers == run.data.offers,
		"Resuming between the relic and tile steps must preserve the chosen relic and offers.")
	_check(not run.choose_elite_relic("siege_fuse"), "The player cannot claim another relic once the draft is complete.")
	await _click(game.frontier_screen, "RewardTile_" + companion)
	await _click(game.frontier_screen, "Continue")
	_check(run.data.phase == "map" and run.loadout.lanes[0].any(func(item: Dictionary): return item.id == companion),
		"Claiming the companion must put it in inventory and return to the route.")
	var next := _reach_elite(run, elites[1])
	var before: int = run.data.relics.size()
	if _win_elite(run, next):
		_check(run.elite_relic_offers().is_empty() and run.data.relics.size() == before + 1 and run.reward("skip"),
			"A later elite should grant its normal relic and let the player leave without a second draft.")
	game.queue_free()
	await process_frame


func _check_bounty_and_legacy() -> void:
	var run := FrontierRun.new()
	run.load_save(save_path)
	if not _start(run, 7):
		return
	run.data.node = run._node("event", "Bounty Board", 2, 0)
	run.data.phase = "event"
	_check(run.event_choice(1) and run.finish_combat(true, run.data.hp)
		and run.elite_relic_offers().size() == 3,
		"The first won bounty should count as an elite and offer the prototype draft.")
	if not _start(run, 7):
		return
	var preview := _reach_elite(run, _elites(run)[0])
	# Recreate a pre-draft checkpoint already on the elite tile reward.
	run.data.phase = "reward"
	run.data.offers = [preview.get("tile", "shield_ram"), "shield_ram", "hook_bash"]
	run.data.relics.append("quartermasters_coin")
	run.data.erase("elite_relic_drafted")
	_check(run.save(), "Write a legacy elite reward checkpoint.")
	var restored := FrontierRun.new()
	_check(restored.load_save(save_path) and restored.elite_relic_offers().is_empty()
		and restored.reward("skip") and restored.data.relics == ["pocket_bell", "quartermasters_coin"],
		"An older checkpoint must keep its previously awarded relic and allow tile resolution.")
	var next := _reach_elite(restored, _elites(restored)[1])
	if _win_elite(restored, next):
		_check(restored.elite_relic_offers().is_empty(),
			"An older run with an elite already cleared should keep the later elite reward flow.")


func _check_review_filter() -> void:
	var game = ArenaScene.instantiate()
	root.add_child(game)
	await process_frame
	game.run_practice()
	game.set_physics_process(false)
	game.state = "finished"
	var opening := {"tile": "pull", "start": 1, "tick": 84, "order": 0, "loop": 1, "beat": 4,
		"hero": "Hexwright", "lane": 0, "status": "landed", "rule": "farthest", "reason": "5 damage"}
	var effect := "Struck from the Blink departure point"
	var follow_up := {"tile": "slam", "start": 8, "tick": 252, "order": 1, "loop": 1, "beat": 12,
		"hero": "Warden", "lane": 1, "status": "landed", "rule": "nearest", "reason": "20 damage",
		"relics": [{"id": "afterimage", "source": "Phase Cut", "source_beat": 8, "effect": effect}]}
	game.arena.hide()
	game.battle_review.open([opening, follow_up], [], "victory")
	await _click(game.battle_review, "Review_relics")
	var events: ItemList = game.battle_review.find_child("ReviewEvents", true, false)
	_check(events.item_count == 1 and "Beat 12" in events.get_item_text(0)
		and "Afterimage" in events.get_item_text(0) and "Slam" in events.get_item_text(0),
		"The relic filter should list only the activation that procced and identify its firing beat.")
	_check(effect in game.battle_review._detail.text and "Phase Cut on beat 8" in game.battle_review._detail.text,
		"Battle Review should explain the relic's actual effect and its setup beat.")
	_check(game.tile_cards[1][8].get_meta("timing_marker").visible,
		"The relic entry should highlight the exact tile that triggered it.")
	game.battle_review.open([opening], [], "victory")
	_check(_button(game.battle_review, "Review_relics") == null, "Hide the relic filter for fights with no procs.")
	game.queue_free()
	await process_frame


func _start(run: FrontierRun, seed_value: int) -> bool:
	if not run.data.is_empty():
		run.abandon_run()
	run.profile.moonwreck_easy_unlocked = true
	var started := (
		run.start_run(seed_value, "easy", "moonwreck") and run.choose_hero(run.data.offers[0])
		and run.choose_relic("pocket_bell") and run.choose_starter("bash")
		and run.finish_combat(true, 95) and run.reward("skip")
	)
	_check(started, "Start the Moonwreck route with a reproducible solo build.")
	return started


func _companion(draft: Array, id: String) -> String:
	for offer: Dictionary in draft:
		if offer.id == id:
			return offer.companion
	return ""


func _elites(run: FrontierRun) -> Array[Dictionary]:
	var elites: Array[Dictionary] = []
	for layer: Array in run.data.layers:
		for node: Dictionary in layer:
			if node.type == "elite":
				elites.append(node)
	return elites


func _reach_elite(run: FrontierRun, destination: Dictionary) -> Dictionary:
	var path := _path_to(run.data.layers, run.data.node, destination)
	_check(not path.is_empty(), "The test needs a connected route to its elite.")
	for node: Dictionary in path:
		var preview := run.elite_preview(node)
		if not run.choose_node(node.id):
			_check(false, "Choose the next reachable route node.")
			return {}
		if node.id == destination.id:
			_check(not preview.is_empty() and preview.get("encounter") == run.encounter(),
				"The elite preview should match its actual encounter.")
			return preview
		match run.data.phase:
			"combat":
				if not run.finish_combat(true, run.data.hp) or not run.reward("skip"):
					_check(false, "Resolve the normal battle on the way to the elite.")
					return {}
			"event", "rest", "shop":
				run.leave_node()
	return {}


func _path_to(layers: Array, node: Dictionary, destination: Dictionary) -> Array[Dictionary]:
	var next_row := int(node.row) + 1
	if next_row > int(destination.row):
		return []
	for candidate: Dictionary in layers[next_row]:
		if candidate.id not in node.next:
			continue
		if candidate.id == destination.id:
			return [candidate]
		var remaining := _path_to(layers, candidate, destination)
		if not remaining.is_empty():
			remaining.push_front(candidate)
			return remaining
	return []


func _win_elite(run: FrontierRun, preview: Dictionary) -> bool:
	var gold := int(run.data.gold)
	var marks := int(run.profile.marks)
	var won := not preview.is_empty() and run.finish_combat(true, run.data.hp)
	_check(won and run.data.phase == "reward" and preview.get("tile") in run.data.offers
		and run.data.gold == gold + 20 and run.profile.marks == marks + 2,
		"Elite victory must keep the previewed tile, 20 gold, and two Marks.")
	return won


func _button(page: Control, name: String) -> Button:
	var button := page.find_child(name, true, false) as Button
	return button if button != null and button.is_visible_in_tree() else null


func _click(page: Control, name: String) -> void:
	await process_frame
	var button := _button(page, name)
	_check(button != null and not button.disabled, "An enabled %s button should be visible." % name)
	if button == null or button.disabled:
		return
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
