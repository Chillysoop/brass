extends SceneTree

const Arena = preload("res://arena.tscn")
const FrontierRun = preload("res://scripts/frontier_run.gd")
const ArenaSim = preload("res://scripts/arena_sim.gd")
const TilePacking = preload("res://scripts/tile_packing.gd")
var failures: Array[String] = []
var save_path := "user://frontier-playtest-%s.json" % str(Time.get_ticks_usec())

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = Arena.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.run.load_save(save_path)
	game.run_start(42)
	var run: RefCounted = game.run
	_check(run.profile.meta.is_empty(), "Fresh save starts with no meta upgrades.")
	var hero: String = "warden" if "warden" in run.data.offers else run.data.offers[0]
	_check(run.choose_hero(hero), "Hero draft")
	_check(run.choose_relic("pocket_bell"), "Relic draft")
	_check(run.choose_starter("bash"), "Starter tile draft")
	var battles := 0
	for step in range(30):
		match run.data.phase:
			"combat":
				game.run_show_arena()
				_check(game.setup_hint.text.begins_with("Drag Bash") == (battles == 0), "Teach dragging the starter in the first opening battle only.")
				_check(not game.result_banner.visible, "The result stays hidden during setup.")
				if battles == 0:
					game._place({"id": "bash", "lane": 0, "start": 0}, 0, 1)
					_check(game.lanes[0][0].start == 1 and "right edge" in game.setup_hint.text,
						"Moving the starter preserves the lesson about the tile's right edge.")
					game._place({"id": "bash", "lane": 0, "start": 1}, 0, 0)
				game._action()
				_check(game.state == "running", "The battle starts without requiring a timeline edit.")
				game.speed = 2
				var firing_edge_seen := false
				var second_loop_seen := false
				for tick in range(3000):
					game._physics_process(1.0 / 60)
					if battles == 0 and game.state == "running":
						if game.sim.tick == 2 * ArenaSim.TICKS_PER_BEAT + 2:
							var card: Control = game.tile_cards[0][0]
							firing_edge_seen = card.get_meta("timing_marker").visible
						if game.sim.tick == ArenaSim.LOOP_TICKS + 2:
							second_loop_seen = is_equal_approx(game.playheads[0].anchor_left, ArenaSim.loop_progress(2))
					if game.state == "finished":
						break
				_check(game.sim.outcome == "victory", "Win %s (%d HP)" % [run.data.node.label, run.data.hp])
				_check(game.result_banner.visible and game.result_text.text == "VICTORY",
					"A win shows the victory cue.")
				if battles == 0:
					_check(firing_edge_seen and second_loop_seen,
						"The first battle holds the firing-edge highlight and resets the playhead for the second loop.")
					var resumed := FrontierRun.new()
					_check(resumed.load_save(save_path) and resumed.profile.timeline_intro_seen,
						"The opening lesson completion survives a reload before the first reward.")
				battles += 1
				if game.sim.outcome != "victory":
					break
				game._complete_result_animation()
			"reward":
				_pick_elite_relic(run)
				var id: String = run.data.offers[0]
				if run.data.node.type != "boss":
					for preferred in ["hook_bash", "shield_ram", "bash", "shot", "slam"]:
						if preferred in run.data.offers:
							id = preferred
							break
				if not _claim_tile_for_build(game, id):
					_check(game.run_claim_reward("skip"), "Skip a reward if its tile cannot fit.")
			"map":
				var next: Array = run.available_nodes()
				_check(not next.is_empty(), "Route has a reachable node.")
				if next.is_empty():
					break
				var node: Dictionary = next[0]
				for option: Dictionary in next:
					if option.type == "battle":
						node = option
						break
				_check(run.choose_node(node.id), "Travel to a reachable node.")
				game.run_return()
			"shop":
				run.shop_heal()
				run.leave_node()
			"event":
				_check(run.event_choice(0), "Resolve event.")
			"rest":
				_check(run.rest("heal"), "Heal before the boss.")
			"result":
				break
			_:
				_check(false, "Unexpected run phase: " + str(run.data.phase))
				break
	_check(battles >= 3, "Run should include multiple combat nodes.")
	_check(run.data.get("result") == "victory" and run.data.phase == "result", "Fresh run should defeat the Tollkeeper.")
	_check(run.profile.medium_unlocked and int(run.profile.marks) >= 19, "Boss should bank the first clear and unlock Medium.")
	_write_legacy_easy_save(run)
	var restored := FrontierRun.new()
	_check(restored.load_save(save_path) and restored.data.get("result") == "victory", "Victory must survive reload.")
	_check(restored.data.difficulty == "easy" and restored.data.heroes.size() == 1 and restored.profile.medium_unlocked,
		"An existing Easy save should restore one hero and keep its Medium unlock.")
	_check(not restored.finish_combat(true, 100), "Resuming the recap cannot pay the boss twice.")
	_check(not restored.buy_meta("stout_start"), "Meta purchases are blocked until the run is closed.")
	_check(restored.finish_run() and restored.buy_meta("stout_start"), "Spend marks between runs.")
	_check(restored.start_run(42) and int(restored.data.max_hp) == 108, "Bought HP upgrade applies to the next run.")
	var easy_hp: int = run.data.hp
	_check(restored.abandon_run(), "Close the new test run.")
	# These seeded build routes exercise the later campaign with an established roster.
	for id: String in FrontierRun.HEROES:
		var cost := restored.class_unlock_cost(id)
		if cost > 0:
			restored.profile.marks += cost
			_check(restored.buy_class(id), "Unlock %s for the later campaign fixtures." % id)
	var medium: Dictionary = _medium_playthrough(game)
	_check(game.run.finish_run(), "Close the Medium victory recap.")
	var glass_fights := _new_route_playthrough(game, "easy", "glass")
	_check(game.run.finish_run(), "Close the Glass Foundry victory recap.")
	var glass_medium_fights := _new_route_playthrough(game, "medium", "glass")
	_check(game.run.finish_run(), "Close the Glass Foundry Medium victory recap.")
	var crown_fights := _new_route_playthrough(game, "easy", "crown")
	_check(game.run.finish_run(), "Close the Crown Relay victory recap.")
	var crown_medium_fights := _new_route_playthrough(game, "medium", "crown")
	_check(game.run.finish_run(), "Close the Crown Relay Medium victory recap.")
	var moonwreck_fights := _new_route_playthrough(game, "easy", "moonwreck")
	_check(game.run.finish_run(), "Close the Moonwreck Docks victory recap.")
	var moonwreck_medium_fights := _new_route_playthrough(game, "medium", "moonwreck")
	_check(game.run.finish_run(), "Close the Moonwreck Docks Medium victory recap.")
	var moonwreck_hard_fights := _new_route_playthrough(game, "hard", "moonwreck")
	_check(game.run.finish_run(), "Close the Moonwreck Docks Hard victory recap.")
	var crown_hard_fights := _new_route_playthrough(game, "hard", "crown", 1)
	_check(game.run.finish_run(), "Close the Crown Relay Hard victory recap.")
	var glass_hard_fights := _new_route_playthrough(game, "hard", "glass")
	_check(game.run.finish_run(), "Close the Glass Foundry Hard victory recap.")
	var hard_fights := _new_route_playthrough(game, "hard", "brass", 3)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Playthroughs passed: Brass Easy %d fights (%d HP), Medium %d (%d HP combined), Brass Hard %d, Glass Easy %d, Glass Medium %d, Glass Hard %d, Crown Easy %d, Crown Medium %d, Crown Hard %d, Moonwreck Easy %d, Moonwreck Medium %d, Moonwreck Hard %d." % [
			battles, easy_hp, medium.fights, medium.hp, hard_fights, glass_fights, glass_medium_fights, glass_hard_fights, crown_fights, crown_medium_fights, crown_hard_fights, moonwreck_fights, moonwreck_medium_fights, moonwreck_hard_fights])
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _medium_playthrough(game: Control) -> Dictionary:
	var run: RefCounted = game.run
	run.load_save(save_path)
	game.run_start(42, "medium")
	_check(run.data.get("difficulty") == "medium", "Medium starts after an Easy clear.")
	var original_hero := ""
	var middle_reward := ""
	var hp_at_recruit := 0
	var marks_before_medium: int = int(run.profile.marks)
	var recruited := false
	var fought_bosses: Array[String] = []
	var fights := 0
	for step in range(70):
		match run.data.phase:
			"hero":
				original_hero = run.data.offers[0]
				run.choose_hero(original_hero)
			"recruit":
				_check(original_hero not in run.data.offers, "The existing hero must stay out of the second draft.")
				_check(not run.profile.hard_unlocked, "The first boss must not unlock Hard.")
				hp_at_recruit = int(run.data.hp)
				_check(run.choose_hero(run.data.offers[0]), "Recruit a second hero.")
			"boss_relic":
				_check(run.choose_boss_relic("tollkeeper_signet"), "Claim the Tollkeeper relic before recruiting on Medium.")
			"relic":
				run.choose_relic("pocket_bell")
			"starter":
				run.choose_starter("bash")
			"recruit_starter":
				_check(run.choose_starter("shot"), "Equip the recruited hero.")
				recruited = true
				_check(run.loadout.lanes.size() == 2, "Recruitment adds a second lane.")
				_check(int(run.data.heroes[0].hp) == hp_at_recruit and run.data.heroes[1].hp == run.data.heroes[1].max_hp,
					"First hero carries their health and recruit starts at full health.")
				var found_reward := false
				for items: Array in run.loadout.lanes + run.loadout.storage:
					found_reward = found_reward or items.any(func(tile: Dictionary): return tile.id == middle_reward)
				_check(found_reward, "The intermediate Legendary remains in inventory after recruiting.")
				var saved := FrontierRun.new()
				_check(saved.load_save(save_path) and saved.loadout.lanes.size() == 2, "The recruited hero and lane survive reload.")
			"combat":
				game.run_show_arena()
				if recruited and game.lanes[1].size() == 1:
					var transferred := false
					for row in range(game.storage_rows.size()):
						for tile: Dictionary in game.storage_rows[row].duplicate():
							if tile.id == middle_reward:
								game._place({"id": tile.id, "lane": -1, "row": row, "start": tile.start}, 1, 2)
								transferred = true
								break
						if transferred:
							break
				if run.data.node.type == "boss":
					fought_bosses.append(run.data.node.label)
					_check(game.lanes.size() == (2 if recruited else 1), "Each leg loads the correct number of heroes.")
				game._action()
				game.speed = 2
				for tick in range(3000):
					game._physics_process(1.0 / 60)
					if game.state == "finished":
						break
				fights += 1
				if game.sim.outcome != "victory":
					_check(false, "Medium defeat at %s." % run.data.node.label)
					break
				if run.is_final_boss():
					_check(game.sim.trace.any(func(event: Dictionary): return event.tile == "marshal_shattered"),
						"The two timelines should open and shatter the Marshal's armor during the test clear.")
				game._complete_result_animation()
			"reward":
				_pick_elite_relic(run)
				while run.data.phase == "reward":
					var id: String = _preferred_offer(run.data.offers,
						["dawn_bastion", "shield_ram", "hook_bash", "bash", "shot", "slam"])
					if _claim_tile_for_build(game, id):
						if run.data.phase == "boss_relic":
							middle_reward = id
					elif not _skip_reward(game):
						break
			"map":
				var available: Array = run.available_nodes()
				if available.is_empty():
					_check(false, "Medium map must have a reachable node.")
					break
				var node: Dictionary = available[0]
				for preferred in ["elite", "battle", "shop"]:
					var matching: Array = available.filter(func(candidate: Dictionary): return candidate.type == preferred)
					if not matching.is_empty():
						node = matching[0]
						break
				run.choose_node(node.id)
			"shop":
				run.shop_heal()
				for id: String in run.data.offers.duplicate():
					if id in ["bash", "shot", "shield_ram", "hook_bash"]:
						game.run_buy_shop(id)
				run.leave_node()
			"event":
				run.event_choice(0)
			"rest":
				run.rest("heal")
			"result":
				break
			_:
				_check(false, "Unexpected Medium phase: " + str(run.data.phase))
				break
	_check(recruited and fought_bosses.size() == 2 and fought_bosses[0] != fought_bosses[1], "Medium must run both distinct bosses with a recruit between them.")
	_check(not middle_reward.is_empty(), "Claim a playable Legendary at the first boss.")
	_check(run.data.get("result") == "victory" and run.profile.hard_unlocked and run.profile.glass_easy_unlocked,
		"Medium victory must unlock both destinations.")
	_check(int(run.profile.marks) - marks_before_medium >= 38, "Medium awards its larger first clear payout.")
	var hp := 0
	for hero: Dictionary in run.data.get("heroes", []):
		hp += int(hero.hp)
	return {"fights": fights, "hp": hp}

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _new_route_playthrough(game: Control, difficulty: String, location: String, run_seed := 42) -> int:
	var run: RefCounted = game.run
	var brass_hard := location == "brass" and difficulty == "hard"
	game.run_start(run_seed, difficulty, location)
	if run.data.is_empty():
		_check(false, "Expected to start " + location + " " + difficulty)
		return 0
	var fights := 0
	var boss_party_sizes: Array[int] = []
	var glass_hard := location == "glass" and difficulty == "hard"
	var crown_medium := location == "crown" and difficulty == "medium"
	var crown_hard := location == "crown" and difficulty == "hard"
	var moonwreck_medium := location == "moonwreck" and difficulty == "medium"
	var moonwreck_hard := location == "moonwreck" and difficulty == "hard"
	var recruit_checkpoints := 0
	var boss_drafts := 0
	for step in range(100):
		match run.data.phase:
			"hero", "recruit":
				var hero: String = run.data.offers[0]
				for preferred in ["warden", "duelist", "apothecary", "cantor", "bulwark"]:
					if preferred in run.data.offers:
						hero = preferred
						break
				run.choose_hero(hero)
			"relic":
				run.choose_relic("pocket_bell")
			"starter":
				run.choose_starter("bash")
			"boss_relic":
				boss_drafts += 1
				_check(run.choose_boss_relic("bastion_medal"), "Claim the Bastion Medal before recruiting on Hard.")
			"recruit_starter":
				var needs_bash: bool = crown_medium or ((crown_hard or moonwreck_hard) and run.data.heroes.size() == 3)
				var recruit_tile := "bash" if needs_bash else "shot"
				_check(run.choose_starter(recruit_tile), "Equip the recruited hero.")
				if glass_hard or crown_medium or crown_hard or moonwreck_medium or moonwreck_hard:
					var saved := FrontierRun.new()
					_check(saved.load_save(save_path) and saved.data.segment == run.data.segment
						and saved.data.heroes == run.data.heroes and saved.loadout.lanes == run.loadout.lanes,
						"The expedition must save the party and timelines after each recruitment.")
					recruit_checkpoints += 1
			"combat":
				game.run_show_arena()
				_equip_stored_rewards(game)
				var final: bool = run.is_final_boss()
				if crown_hard and run.data.node.get("boss_id") == "relay_marshal":
					_arrange_crown_combo(game)
				if final and location == "crown":
					if crown_medium:
						_arrange_crown_combo(game)
					elif crown_hard:
						_arrange_crown_hard_combo(game)
					var saved := FrontierRun.new()
					var boss_id: String = {"easy": "relay_captain", "medium": "relay_marshal", "hard": "crown_regent"}[difficulty]
					_check(saved.load_save(save_path) and saved.encounter().get("boss_id") == boss_id
						and saved.loadout.lanes == run.loadout.lanes, "Crown Relay must resume its saved boss setup.")
				if location == "moonwreck" and run.data.node.get("boss_id") == "wreckmaster":
					_arrange_wreckmaster_bash(game)
				if final and location == "moonwreck":
					if moonwreck_medium:
						_stow_early_hook(game)
					elif moonwreck_hard:
						var pulls := _pull_tiles(game)
						_check(not pulls.is_empty(), "The Admiral playthrough needs a tile that can pull.")
						if not pulls.is_empty():
							var pull := pulls[0]
							_arrange_hard_combo(game, [
								{"id": "bash", "start": 2, "target": "nearest"},
								{"id": pull, "start": 5 - ArenaSim.TILES[pull].width, "target": "nearest"},
								{"id": "bash", "start": 4, "target": "nearest"},
							], 6)
					var saved := FrontierRun.new()
					var boss_id: String = {"easy": "wreckmaster", "medium": "tidekeeper", "hard": "drowned_admiral"}[difficulty]
					_check(saved.load_save(save_path) and saved.encounter().get("boss_id") == boss_id
						and saved.loadout.lanes == run.loadout.lanes, "Moonwreck Docks must resume its saved boss setup.")
				if run.data.node.type == "boss":
					boss_party_sizes.append(game.lanes.size())
				game._action()
				game.speed = 2
				for tick in range(3000):
					game._physics_process(1.0 / 60)
					if game.state == "finished":
						break
				fights += 1
				if game.sim.outcome != "victory":
					_check(false, "%s %s lost to %s after %d fights." % [location, difficulty, run.data.node.label, fights])
					break
				if final and difficulty == "hard" and location == "brass":
					_check(game.sim.trace.any(func(event: Dictionary): return event.tile == "regent_shattered"),
						"Three heroes should break the Iron Regent's seals during the test clear.")
				if final and location == "glass" and difficulty == "medium":
					_check(game.sim.trace.any(func(event: Dictionary): return event.tile == "prism_shattered"),
						"Both heroes should contribute to the Prism Warden's ward break.")
				if final and glass_hard:
					var combo: Array = game.sim.trace.filter(func(event: Dictionary):
						return event.tile in ["colossus_displaced", "colossus_cracked", "colossus_shattered"])
					_check(combo.map(func(event: Dictionary): return event.tile) ==
						["colossus_displaced", "colossus_cracked", "colossus_shattered"],
						"The expedition loadout should complete the Colossus combo in order.")
					var contributors := {}
					for event: Dictionary in combo:
						contributors[event.actor] = true
					_check(contributors.size() == 3, "A different hero must contribute each step of the combo.")
				if final and location == "crown":
					var interruption: String = {
						"easy": "relay_interrupted", "medium": "relay_marshal_interrupted", "hard": "crown_regent_interrupted"
					}[difficulty]
					_check(game.sim.trace.any(func(event: Dictionary):
						return event.tile == interruption and (difficulty == "easy" or event.amount == 1)),
						"The expedition loadout should interrupt the final Crown Relay %s boss." % difficulty)
				if location == "moonwreck" and run.data.node.get("boss_id") == "wreckmaster":
					var opening: Array = game.sim.trace.filter(func(event: Dictionary):
						return event.tick <= 6 * ArenaSim.TICKS_PER_BEAT)
					_check(opening.any(func(event: Dictionary): return event.tile == "wreckmaster_pull")
						and opening.any(func(event: Dictionary): return event.kind == "push" and event.tile == "bash" and event.beat == 5)
						and opening.any(func(event: Dictionary): return event.tile == "wreckmaster_slam_miss"),
						"An earned Bash should knock the Wreckmaster out of its first Deck Slam range.")
				if final and moonwreck_medium:
					_check(game.sim.trace.any(func(event: Dictionary):
						return event.tile == "tidekeeper_interrupted" and event.amount == 1),
						"Two heroes should interrupt the Tidekeeper's Breakwater Slam.")
					var marked: Array = game.sim.trace.filter(func(event: Dictionary):
						return event.tile == "tidekeeper_pull" and event.beat == 3 and event.tick <= ArenaSim.LOOP_TICKS)
					_check(marked.size() == 2 and marked[0].target != marked[1].target,
						"The Tidekeeper should reel in both heroes before its first slam.")
				if final and moonwreck_hard:
					var opening: Array = game.sim.trace.filter(func(event: Dictionary): return event.tick <= ArenaSim.LOOP_TICKS)
					var combo: Array = opening.filter(func(event: Dictionary):
						return event.tile in ["admiral_unanchored", "admiral_reversed", "admiral_interrupted"])
					_check(combo.map(func(event: Dictionary): return event.tile) ==
						["admiral_unanchored", "admiral_reversed", "admiral_interrupted"] and combo[-1].amount == 1,
						"Bash, Pull, and Bash from the three timelines should cancel the first Undertow Sweep.")
				game._complete_result_animation()
			"reward":
				_pick_elite_relic(run)
				var priorities := ["dawn_bastion", "event_horizon", "bulwark_charge", "shield_ram", "hook_bash", "bash", "shot", "slam"]
				if brass_hard:
					priorities = ["dawn_bastion", "event_horizon", "shield_ram", "hook_bash", "scattershot", "finishing_cut", "slam", "guard", "shot", "bash"]
				while run.data.phase == "reward":
					var chosen: String = _preferred_offer(run.data.offers, priorities)
					if (crown_medium or crown_hard) and _pull_tiles(game).count("hook_bash") < (2 if crown_hard else 1):
						chosen = _preferred_offer(run.data.offers, ["hook_bash", "pull", "grapple"], chosen)
					elif moonwreck_hard and _pull_tiles(game).is_empty():
						chosen = _preferred_offer(run.data.offers, ["pull", "grapple", "hook_bash"], chosen)
					if not _claim_tile_for_build(game, chosen) and not _skip_reward(game):
						break
			"map":
				var options: Array = run.available_nodes()
				if options.is_empty():
					break
				var choice: Dictionary = options[0]
				for preferred in ["battle", "shop", "elite"]:
					var matches: Array = options.filter(func(node: Dictionary): return node.type == preferred)
					if not matches.is_empty():
						choice = matches[0]
						break
				run.choose_node(choice.id)
			"shop":
				run.shop_heal()
				if (crown_medium or crown_hard) and "grapple" in run.data.offers:
					game.run_buy_shop("grapple")
				for tile: String in run.data.offers.duplicate():
					if tile in ["shield_ram", "hook_bash", "shot", "bash"]:
						game.run_buy_shop(tile)
				run.leave_node()
			"rest":
				run.rest("heal")
			"event":
				run.event_choice(0)
			"result":
				break
			_:
				_check(false, "Unexpected phase: " + str(run.data.phase))
				break
	_check(run.data.get("result") == "victory", "%s %s must clear the final boss." % [location, difficulty])
	_check(boss_drafts == (1 if brass_hard else 0), "Only the first Brass Hard boss should offer this relic draft.")
	var expected_sizes := {"easy": [1], "medium": [1, 2], "hard": [1, 2, 3]}
	_check(boss_party_sizes == expected_sizes[difficulty], "Each boss must have the expected party size.")
	match difficulty:
		"easy":
			if location == "crown":
				var saved := FrontierRun.new()
				_check(saved.load_save(save_path) and saved.profile.crown_medium_unlocked and saved.data.get("result") == "victory",
					"Crown Easy should save its victory and the Crown Medium unlock.")
			elif location == "moonwreck":
				var saved := FrontierRun.new()
				_check(saved.load_save(save_path) and saved.profile.moonwreck_medium_unlocked and saved.data.get("result") == "victory",
					"Moonwreck Easy should save its victory and the Moonwreck Medium unlock.")
			else:
				_check(run.profile.glass_medium_unlocked, "Glass Easy should unlock Glass Medium.")
		"medium":
			if moonwreck_medium:
				var saved := FrontierRun.new()
				_check(recruit_checkpoints == 1 and saved.load_save(save_path) and saved.profile.moonwreck_hard_unlocked
					and saved.data.get("result") == "victory", "Moonwreck Medium should persist its recruit, victory and Hard unlock.")
			elif crown_medium:
				var saved := FrontierRun.new()
				_check(recruit_checkpoints == 1 and saved.load_save(save_path) and saved.profile.crown_hard_unlocked
					and saved.profile.moonwreck_easy_unlocked and saved.data.get("result") == "victory",
					"Crown Medium should save its victory and both unlocks.")
			else:
				_check(run.profile.glass_hard_unlocked and run.profile.crown_easy_unlocked, "Glass Medium should unlock Glass Hard and Crown Easy.")
		"hard":
			if moonwreck_hard:
				var saved := FrontierRun.new()
				_check(recruit_checkpoints == 2 and saved.load_save(save_path) and saved.profile.moonwreck_hard_cleared
					and saved.data.get("result") == "victory", "Moonwreck Hard should persist both recruits and its first clear.")
			elif crown_hard:
				var saved := FrontierRun.new()
				_check(recruit_checkpoints == 2 and saved.load_save(save_path) and saved.profile.crown_hard_cleared
					and saved.data.get("result") == "victory", "Crown Hard should persist both recruits and its first clear.")
			elif glass_hard:
				var saved := FrontierRun.new()
				_check(recruit_checkpoints == 2 and saved.load_save(save_path) and saved.profile.glass_hard_cleared
					and saved.data.get("result") == "victory", "Glass Hard should persist both recruits and its first clear.")
			else:
				_check(run.profile.brass_hard_cleared, "Brass Hard should record its clear.")
	return fights

func _stow_early_hook(game: Control) -> void:
	var lane: Array = game.lanes[0]
	var index := lane.find_custom(func(tile: Dictionary): return tile.id == "hook_bash" and tile.start == 0)
	if index < 0:
		return
	# Let both harpoons land before the party starts moving the boss.
	for row: Array in game.storage_rows:
		for beat in range(TilePacking.STORAGE_COLUMNS):
			if TilePacking.can_place(row, "hook_bash", beat, TilePacking.STORAGE_COLUMNS):
				var hook: Dictionary = lane.pop_at(index)
				hook.start = beat
				row.append(hook)
				game._save_loadout()
				return
	_check(false, "Moonwreck Medium needs reserve space for the early Hook Bash.")


func _arrange_wreckmaster_bash(game: Control) -> void:
	var lane: Array = game.lanes[0]
	var bash_index := lane.find_custom(func(tile: Dictionary): return tile.id == "bash")
	_check(bash_index >= 0, "The Moonwreck playthrough should retain the starter Bash.")
	if bash_index < 0:
		return
	var bash: Dictionary = lane.pop_at(bash_index)
	var remaining := lane.duplicate()
	lane.assign([bash])
	bash.start = 3
	var next_beat := 5
	for tile: Dictionary in remaining:
		var width: int = ArenaSim.TILES[tile.id].width
		if next_beat + width <= ArenaSim.BEATS:
			tile.start = next_beat
			lane.append(tile)
			next_beat += width
			continue
		var stowed := false
		for row: Array in game.storage_rows:
			for beat in range(TilePacking.STORAGE_COLUMNS):
				if TilePacking.can_place(row, tile.id, beat, TilePacking.STORAGE_COLUMNS):
					tile.start = beat
					row.append(tile)
					stowed = true
					break
			if stowed:
				break
		_check(stowed, "The Moonwreck playthrough should retain all earned tiles.")
	game._save_loadout()


func _arrange_crown_combo(game: Control) -> void:
	var pulls := _pull_tiles(game)
	_check(not pulls.is_empty(), "Crown Medium needs a tile that can pull apart the link.")
	if pulls.is_empty():
		return
	var pull := "hook_bash" if "hook_bash" in pulls else pulls[0]
	_arrange_hard_combo(game, [
		{"id": pull, "start": 3 - ArenaSim.TILES[pull].width, "target": "nearest"},
		{"id": "bash", "start": 2, "target": "highest_hp"},
	], 4)


func _arrange_crown_hard_combo(game: Control) -> void:
	var pulls := _pull_tiles(game)
	_check(pulls.size() >= 2, "Crown Hard needs two tiles that can pull apart the links.")
	if pulls.size() < 2:
		return
	var first := "hook_bash" if "hook_bash" in pulls else pulls[0]
	pulls.erase(first)
	# The center lane needs the stronger pull to break the right guard's link.
	var second := "hook_bash" if "hook_bash" in pulls else pulls[0]
	_arrange_hard_combo(game, [
		{"id": first, "start": 3 - ArenaSim.TILES[first].width, "target": "relay_left"},
		{"id": second, "start": 4 - ArenaSim.TILES[second].width, "target": "relay_right"},
		{"id": "bash", "start": 2, "target": "relay_regent"},
	], 4)


func _pull_tiles(game: Control) -> Array[String]:
	var ids: Array[String] = []
	for row: Array in game.lanes + game.storage_rows:
		for tile: Dictionary in row:
			if tile.id in ["pull", "grapple", "hook_bash"]:
				ids.append(tile.id)
	return ids


func _arrange_hard_combo(game: Control, combo: Array, first_free_beat: int) -> void:
	var remaining: Array = []
	for lane: Array in game.lanes + game.storage_rows:
		remaining.append_array(lane)
	for tile: Dictionary in combo:
		var index := remaining.find_custom(func(item: Dictionary): return item.id == tile.id)
		_check(index >= 0, "The Hard expedition must earn every combo tile before its final boss.")
		if index < 0:
			return
		remaining.remove_at(index)
	for index in range(combo.size()):
		game.lanes[index].assign([combo[index]])
	for row: Array in game.storage_rows:
		row.clear()
	# Reserve the required opening beats and keep the strongest of the remaining tiles.
	remaining.sort_custom(func(left: Dictionary, right: Dictionary):
		return ArenaSim.TILES[left.id].damage > ArenaSim.TILES[right.id].damage)
	for tile: Dictionary in remaining:
		var equipped := false
		for lane_index in range(game.lanes.size()):
			var lane: Array = game.lanes[lane_index]
			for beat in range(first_free_beat, ArenaSim.BEATS):
				if game._can_place(tile, lane_index, beat):
					tile.start = beat
					lane.append(tile)
					equipped = true
					break
			if equipped:
				break
		if equipped:
			continue
		for row: Array in game.storage_rows:
			for beat in range(TilePacking.STORAGE_COLUMNS):
				if TilePacking.can_place(row, tile.id, beat, TilePacking.STORAGE_COLUMNS):
					tile.start = beat
					row.append(tile)
					equipped = true
					break
			if equipped:
				break
	game._save_loadout()


func _equip_stored_rewards(game: Control) -> void:
	for row in range(game.storage_rows.size()):
		for item: Dictionary in game.storage_rows[row].duplicate():
			if ArenaSim.TILES[item.id].damage < 12:
				continue
			var payload := {"id": item.id, "lane": -1, "row": row, "start": item.start}
			var equipped := false
			for lane in range(game.lanes.size() - 1, -1, -1):
				for beat in range(ArenaSim.BEATS):
					if game._can_place(payload, lane, beat):
						game._place(payload, lane, beat)
						equipped = true
						break
				if equipped:
					break

func _pick_elite_relic(run: RefCounted) -> void:
	var draft: Array = run.elite_relic_offers()
	if not draft.is_empty():
		_check(run.choose_elite_relic(draft[0].id), "Choose a first-elite relic before claiming its tile.")

func _preferred_offer(offers: Array, priorities: Array, fallback := "") -> String:
	for id: String in priorities:
		if id in offers:
			return id
	return offers[0] if fallback.is_empty() else fallback

func _claim_tile_for_build(game: Control, id: String) -> bool:
	if not game.run_claim_reward(id):
		return false
	if not game.run.data.has("reward_combine"):
		return true
	game.run_return()
	var run_data: Dictionary = game.run.data
	if id == "bash" and run_data.location == "crown" \
			and (run_data.difficulty == "medium" or int(run_data.segment) >= 2):
		var hooks_needed := 2 if run_data.difficulty == "hard" else 1
		# Forge a strong pull from the opening Bash copies. Hard needs another for the Regent.
		if _pull_tiles(game).count("hook_bash") < hooks_needed:
			game.forge_choose("hook_bash")
			if not game.run.data.has("reward_combine"):
				return true
	# Keep the individual copy so these builds exercise their intended boss timing.
	if game.run_keep_reward_tile():
		return true
	game.forge_close()
	return false


func _skip_reward(game: Control) -> bool:
	var skipped: bool = game.run_claim_reward("skip")
	_check(skipped, "Skip an individual reward that cannot fit and advance to the next pick.")
	return skipped

func _write_legacy_easy_save(run: RefCounted) -> void:
	var legacy_run: Dictionary = run.data.duplicate(true)
	var legacy_profile: Dictionary = run.profile.duplicate(true)
	for field in ["heroes", "difficulty", "segment"]:
		legacy_run.erase(field)
	for field in ["hard_unlocked", "glass_easy_unlocked"]:
		legacy_profile.erase(field)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "profile": legacy_profile, "run": legacy_run, "loadout": run.loadout}))
	file.close()
