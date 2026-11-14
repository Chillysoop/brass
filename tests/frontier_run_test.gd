extends SceneTree

const FrontierRun = preload("res://scripts/frontier_run.gd")
const ArenaSim = preload("res://scripts/arena_sim.gd")
var failures: Array[String] = []


func _initialize() -> void:
	var run := FrontierRun.new()
	for seed_value in range(1, 129):
		var layers := run._make_map(seed_value)
		_check_map(layers)
		check(layers == run._make_map(seed_value), "Same seed must generate the same map.")
	check(run._make_map(1) != run._make_map(2), "Distinct seeds should vary routes.")

	var path := "user://frontier-model-test-%d.json" % Time.get_ticks_usec()
	check(not run.load_save(path), "A new save path should start empty.")
	check(run.start_run(42), "Easy must be available with a fresh profile.")
	check(run.data.offers.size() == 3 and run.data.max_hp == 100, "Starter class draft or baseline HP invalid.")
	check(run.choose_hero(run.data.offers[0]), "Class selection failed.")
	check(run.choose_relic("quartermasters_coin"), "Relic selection failed.")
	check(run.choose_starter("bash"), "Starter tile selection failed.")
	check(run.loadout.lanes[0][0].id == "bash", "Starter tile must be equipped before opening battle.")
	check(run.finish_combat(true, 90), "Opening resolution failed.")
	check(run.data.offers.size() == 3 and "bash" in run.data.offers, "Normal reward must include three tiles and an owned duplicate.")
	check(run.reward("skip"), "Opening skip failed.")
	check(run.data.gold == 33, "Combat and Quartermaster skip payouts were incorrect.")

	var resumed := FrontierRun.new()
	check(resumed.load_save(path), "Persisted run was not reloadable.")
	check(resumed.data.seed is int and resumed.data.hp == 90, "Save must restore integer seed and carried HP.")
	check(resumed.data.layers == run.data.layers and resumed.loadout == run.loadout, "Save must restore map and equipped tiles.")
	var preferred := ["battle", "shop", "elite", "battle", "rest", "boss"]
	for kind: String in preferred:
		var options := resumed.available_nodes()
		var node: Dictionary = options[0]
		for option: Dictionary in options:
			if option.type == kind:
				node = option
		check(resumed.choose_node(node.id), "Reachable node selection failed.")
		match resumed.data.phase:
			"combat":
				check(resumed.encounter().hp == resumed.data.hp, "Next fight must keep HP.")
				check(resumed.finish_combat(true, resumed.data.hp), "Battle resolution failed.")
				if node.type == "elite":
					check(resumed.data.relics.size() > 1, "Elite victory must award a relic.")
					for id: String in resumed.data.offers:
						check(ArenaSim.TILES[id].rarity != "common", "Elite choices must be Uncommon+.")
				if node.type == "boss":
					check(resumed.profile.medium_unlocked and resumed.data.result == "victory", "Boss must grant victory and unlock Medium.")
					check(resumed.data.offers.size() == 3, "Boss must offer three distinct rewards.")
					for id: String in resumed.data.offers:
						check(ArenaSim.TILES[id].rarity == "legendary", "Boss rewards must be Legendary.")
					check(not resumed.finish_combat(true, 100), "Repeated completion must not pay twice.")
				resumed.reward("skip")
			"event": resumed.event_choice(0)
			"shop":
				var tile: String = resumed.data.offers[0]
				var cost := resumed.shop_price(tile)
				var gold: int = resumed.data.gold
				check(resumed.shop_buy(tile) and resumed.data.gold == gold - cost, "Shop purchase must deduct price once.")
				check(not resumed.shop_buy(tile), "An already purchased shop offer must be exhausted.")
				resumed.leave_node()
			"rest":
				resumed.rest("heal")
				check(resumed.data.hp == 100, "Rest must heal run HP.")
	check(not resumed.buy_meta("stout_start"), "Meta upgrades must be restricted to between runs.")
	check(resumed.finish_run(), "Boss recap must return to the hub.")
	check(resumed.profile.marks >= 20 and resumed.buy_meta("stout_start"), "Boss and midpoint payout must fund a meta node.")
	check(resumed.buy_meta("curated_cache"), "Prerequisite must unlock the next Aether Chart node.")
	check(resumed.start_run(42) and resumed.data.max_hp == 108, "Stout Start must raise the next run's starting HP.")
	check("gravity_hook" in resumed._normal_pool(), "Gravity Hook must stay eligible for future drafts.")
	_check_medium(path)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Frontier model checks passed across 128 generated maps.")
	quit(0 if failures.is_empty() else 1)


func _check_map(layers: Array) -> void:
	check(layers.size() == 7 and layers[0][0].type == "opening" and layers[6][0].type == "boss", "Easy must reach one boss on the seventh node.")
	var reachable: Array = [layers[0][0].id]
	var types: Dictionary = {}
	for index in range(layers.size()):
		var next_ids: Array = []
		for node: Dictionary in layers[index]:
			check(node.id in reachable, "Every generated node must be reachable.")
			types[node.type] = true
			next_ids.append_array(node.next)
		reachable = next_ids
	for kind in ["battle", "elite", "shop", "event", "rest"]:
		check(types.has(kind), "Required node is missing: " + kind)
	for node: Dictionary in layers[5]:
		check(node.type == "rest" and layers[6][0].id in node.next, "Boss approaches need a reachable rest.")


func _check_medium(path: String) -> void:
	var run := FrontierRun.new()
	run.load_save(path)
	run.abandon_run()
	run.profile.medium_unlocked = false
	check(not run.start_run(42, "medium"), "Medium must require an Easy clear.")
	run.profile.medium_unlocked = true
	check(run.start_run(42, "medium"), "Unlocked Medium must start.")
	check(run.data.layers.size() == 14, "Medium must have two segments of six nodes and one boss each.")
	var hero: String = run.data.offers[0]
	run.choose_hero(hero)
	run.choose_relic("pocket_bell")
	run.choose_starter("bash")
	_reach_boss(run)
	check(run.data.node.label == "The Tollkeeper" and not run.is_final_boss(), "First Medium boss must be intermediate.")
	var marks: int = run.profile.marks
	check(run.finish_combat(true, [68]), "Medium boss must read per-hero HP.")
	check(run.profile.marks == marks + 4 and not run.profile.hard_unlocked, "First boss must bank only its boss payout.")
	check(run.reward(run.data.offers[0]), "Intermediate Legendary choice must succeed.")
	check(run.data.phase == "recruit" and run.data.offers.size() == 3 and hero not in run.data.offers,
		"Second draft must offer three different choices from the lead hero.")
	check(run.choose_recruit(run.data.offers[0]), "Choose a recruit.")
	var restored := FrontierRun.new()
	check(restored.load_save(path) and restored.data.phase == "recruit_starter", "Recruitment must resume from the saved starter draft.")
	check(restored.choose_recruit_starter("shot"), "Recruit must be able to choose a starter tile.")
	check(restored.data.heroes.size() == 2 and restored.data.heroes[0].hp == 68 and restored.data.heroes[1].hp == 108,
		"Recruitment must preserve the lead hero's HP and add a full-HP recruit.")
	check(restored.loadout.lanes.size() == 2 and restored.loadout.lanes[1][0].id == "shot", "The recruit's lane must include its starter.")
	check(restored.data.segment == 2 and int(restored.available_nodes()[0].row) == 7, "Recruitment must open the first node in segment two.")
	_reach_boss(restored)
	check(restored.data.node.label == "The Gilded Marshal" and restored.is_final_boss(), "Second Medium boss must be the Gilded Marshal.")
	marks = restored.profile.marks
	check(restored.finish_combat(true, [0, 50]), "Final fight must persist both heroes' remaining HP.")
	check(restored.data.hp == 0 and restored.data.heroes[1].hp == 50, "Legacy HP alias must follow the lead hero.")
	check(restored.profile.marks == marks + 34 and restored.profile.hard_unlocked and restored.profile.glass_easy_unlocked,
		"First Medium clear must grant boss, completion and first-clear marks and open both gates.")
	check(not restored.finish_combat(true, [0, 50]), "Resuming the final reward must not pay again.")
	check(restored.reward("skip") and restored.data.phase == "result", "Final Legendary choice must lead to the recap.")


func _reach_boss(run: RefCounted) -> void:
	while run.data.node.type != "boss" or run.data.phase != "combat":
		match run.data.phase:
			"map":
				var options: Array = run.available_nodes()
				var node: Dictionary = options[0]
				for option: Dictionary in options:
					if option.type in ["battle", "shop", "rest", "boss"]:
						node = option
						break
				run.choose_node(node.id)
			"combat":
				var hp: Array = []
				for hero: Dictionary in run.data.heroes:
					hp.append(hero.hp)
				run.finish_combat(true, hp)
			"reward": run.reward("skip")
			"shop": run.leave_node()
			"event": run.event_choice(0)
			"rest": run.rest("heal")
			_:
				check(false, "Unexpected phase while traveling to a boss: " + str(run.data.phase))
				return


func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
