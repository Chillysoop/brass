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
		_check_map(run._make_map(seed_value, "easy", "glass"), 1, "crucible_twins")
		_check_map(run._make_map(seed_value, "hard"), 3, "iron_regent")
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
	_check_hard_and_glass(path)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Frontier model checks passed across 128 seeds for Brass Easy, Brass Hard, and Glass Easy.")
	quit(0 if failures.is_empty() else 1)


func _check_map(layers: Array, segments := 1, final_boss := "tollkeeper") -> void:
	check(layers.size() == 7 * segments and layers[0][0].type == "opening", "Each segment must have seven rows.")
	check(layers.back()[0].boss_id == final_boss, "The final boss must match the location and difficulty.")
	var reachable: Array = [layers[0][0].id]
	var types: Dictionary = {}
	for index in range(layers.size()):
		var next_ids: Array = []
		for node: Dictionary in layers[index]:
			check(node.id in reachable, "Every generated node must be reachable.")
			types[node.type] = true
			next_ids.append_array(node.next)
		reachable = next_ids
		if index % 7 == 6:
			for kind in ["battle", "elite", "shop", "rest"]:
				check(types.has(kind), "Required node is missing: " + kind)
			if index < 14:
				check(types.has("event"), "The first two segments must offer an event.")
			for node: Dictionary in layers[index - 1]:
				check(node.type == "rest" and layers[index][0].id in node.next, "Boss approaches need a reachable rest.")
			types.clear()


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


func _check_hard_and_glass(path: String) -> void:
	var run := FrontierRun.new()
	check(not run.can_start("hard") and not run.can_start("easy", "glass"), "A fresh profile must lock both branches.")
	check(run.load_save(path) and run.finish_run(), "Return to the hub after the saved Medium clear.")
	check(run.can_start("hard") and run.can_start("easy", "glass"), "A Medium clear must open both branches.")
	check(not run.can_start("hard", "glass"), "The playable Glass branch must begin at Easy.")

	run.start_run(76, "easy", "glass")
	run.choose_hero(run.data.offers[0])
	run.choose_relic("pocket_bell")
	run.choose_starter("shot")
	check(run.encounter().location == "glass" and run.data.heroes.size() == 1, "Glass Easy must start as a solo Foundry run.")
	_reach_boss(run)
	check(run.is_final_boss() and run.encounter().boss_id == "crucible_twins", "Glass Easy must finish with the Crucible Twins.")
	var marks: int = run.profile.marks
	run.finish_combat(true, [70])
	check(run.profile.glass_medium_unlocked and run.profile.marks == marks + 19, "Glass Easy must bank its own first-clear payout.")
	run.reward("skip")
	run.finish_run()

	run.start_run(42, "hard")
	run.choose_hero(run.data.offers[0])
	run.choose_relic("pocket_bell")
	run.choose_starter("bash")
	for boss_id in FrontierRun.BRASS_BOSSES:
		_reach_boss(run)
		var encounter := run.encounter()
		check(encounter.boss_id == boss_id and encounter.heroes.size() == encounter.segment, "Hard must use the correct boss and party size for each leg.")
		var remaining := [51, 66, 82].slice(0, encounter.heroes.size())
		marks = run.profile.marks
		run.finish_combat(true, remaining)
		run.reward("skip")
		if boss_id == "iron_regent":
			check(run.data.phase == "result" and run.profile.brass_hard_cleared and run.profile.marks == marks + 54,
				"The Iron Regent must complete Hard and bank the first-clear payout.")
			break
		for hero: Dictionary in run.data.heroes:
			check(hero.id not in run.data.offers, "Recruitment must exclude every current hero.")
		run.choose_recruit(run.data.offers[0])
		var restored := FrontierRun.new()
		check(restored.load_save(path) and restored.choose_recruit_starter("slam"), "Hard recruitment must resume from disk.")
		run = restored
		var team_size: int = run.data.heroes.size()
		check(team_size == encounter.segment + 1 and run.loadout.lanes.size() == team_size, "Each recruit must add exactly one lane.")
		check(run.data.heroes[0].hp == remaining[0] and run.data.heroes.back().hp == run.data.heroes.back().max_hp,
			"Recruitment must preserve party HP and add a full-HP hero.")


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
