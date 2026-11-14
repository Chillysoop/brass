extends SceneTree

const Arena = preload("res://arena.tscn")
const FrontierRun = preload("res://scripts/frontier_run.gd")
const ArenaSim = preload("res://scripts/arena_sim.gd")
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
				game._action()
				game.speed = 2
				for tick in range(3000):
					game._physics_process(1.0 / 60)
					if game.state == "finished":
						break
				_check(game.sim.outcome == "victory", "Win %s (%d HP)" % [run.data.node.label, run.data.hp])
				battles += 1
				if game.sim.outcome != "victory":
					break
				game._action()
			"reward":
				var id: String = run.data.offers[0]
				if run.data.node.type != "boss":
					for preferred in ["hook_bash", "shield_ram", "bash", "shot", "slam"]:
						if preferred in run.data.offers:
							id = preferred
							break
				if not game.run_claim_reward(id):
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
	var medium: Dictionary = _medium_playthrough(game)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Frontier playthrough passed: Easy %d fights (%d HP), Medium %d fights (%d HP combined)." % [
			battles, easy_hp, medium.fights, medium.hp])
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
				game._action()
			"reward":
				var id: String = run.data.offers[0]
				for preferred in ["dawn_bastion", "shield_ram", "hook_bash", "bash", "shot", "slam"]:
					if preferred in run.data.offers:
						id = preferred
						break
				if game.run_claim_reward(id):
					if run.data.phase == "recruit":
						middle_reward = id
				else:
					run.reward("skip")
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
