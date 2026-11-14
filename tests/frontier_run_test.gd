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
		var glass_medium := run._make_map(seed_value, "medium", "glass")
		_check_map(glass_medium, 2, "prism_warden")
		_check_glass_events(glass_medium)
		var glass_hard := run._make_map(seed_value, "hard", "glass")
		_check_map(glass_hard, 3, "tempered_colossus")
		check(glass_hard.slice(0, 14) == _with_gate_link(glass_medium, glass_hard[14][0].id),
			"Glass Hard should keep the first two Glass legs and connect the Prism Warden to leg three.")
		_check_glass_hard_leg(glass_hard)
		_check_map(run._make_map(seed_value, "hard"), 3, "iron_regent")
		var crown := run._make_map(seed_value, "easy", "crown")
		_check_map(crown, 1, "relay_captain")
		check(crown == run._make_map(seed_value, "easy", "crown"), "Crown Relay maps must be deterministic.")
		_check_crown_nodes(crown)
		var crown_medium := run._make_map(seed_value, "medium", "crown")
		_check_map(crown_medium, 2, "relay_marshal")
		check(crown_medium.slice(0, 7) == _with_gate_link(crown, crown_medium[7][0].id),
			"Crown Medium must keep the first leg and connect the Captain to the second leg.")
		_check_crown_medium_nodes(crown_medium)
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
	_check_glass_hard(path)
	_check_crown_easy(path)
	_check_crown_medium(path)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Frontier model checks passed across 128 seeds for Brass, Glass, and Crown routes.")
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


func _check_glass_events(layers: Array) -> void:
	var seen: Dictionary = {}
	for row in range(layers.size()):
		for node: Dictionary in layers[row]:
			if node.type != "event":
				continue
			check(not seen.has(node.label), "Glass Medium must not repeat an event label.")
			seen[node.label] = true
			if row >= 7:
				check(node.label in FrontierRun.GLASS_UPPER_NODE_LABELS.event, "The upper leg must offer its own events.")


func _with_gate_link(layers: Array, gate_id: String) -> Array:
	var route := layers.duplicate(true)
	route.back()[0].next.append(gate_id)
	return route


func _check_glass_hard_leg(layers: Array) -> void:
	check(layers[14][0].label == "Tempering Causeway", "Glass Hard must open leg three at the Tempering Causeway.")
	for row in range(15, 20):
		for node: Dictionary in layers[row]:
			check(node.label in FrontierRun.GLASS_TEMPERING_NODE_LABELS[node.type], "Glass Hard leg three must use its own Foundry labels.")


func _check_crown_nodes(layers: Array) -> void:
	check(layers[0][0].label == "Skybridge Trial", "Crown Relay must have its own opening encounter.")
	var events: Array[String] = []
	for row in range(1, 6):
		for node: Dictionary in layers[row]:
			check(node.label in FrontierRun.CROWN_NODE_LABELS[node.type], "Crown Relay must use distinct route names.")
			if node.type == "event":
				check(node.label not in events, "Crown events must not repeat on one route.")
				events.append(node.label)


func _check_crown_medium_nodes(layers: Array) -> void:
	check(layers[7][0].label == "High Relay Gate", "Crown Medium must open leg two at High Relay Gate.")
	var events: Array[String] = []
	for row in range(1, 13):
		for node: Dictionary in layers[row]:
			if row > 7:
				check(node.label in FrontierRun.CROWN_HIGH_RELAY_NODE_LABELS[node.type],
					"Crown Medium leg two must use its own route names.")
			if node.type == "event":
				check(node.label not in events, "Crown Medium events must not repeat across its two legs.")
				events.append(node.label)


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
	check(not run.can_start("medium", "glass"), "Glass Medium must require a Glass Easy clear.")

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
	_check_glass_medium(path)
	check(run.load_save(path) and run.finish_run(), "Return to the hub after the saved Glass Medium clear.")

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


func _check_glass_medium(path: String) -> void:
	var run := FrontierRun.new()
	check(run.load_save(path) and run.start_run(76, "medium", "glass"), "Glass Medium must open after Glass Easy.")
	run.choose_hero(run.data.offers[0])
	run.choose_relic("pocket_bell")
	run.choose_starter("shot")
	_reach_boss(run)
	var marks: int = run.profile.marks
	check(run.encounter().boss_id == "crucible_twins" and not run.is_final_boss(), "The Crucible Twins must be the first Glass Medium boss.")
	run.finish_combat(true, [53])
	check(run.profile.marks == marks + 4 and not run.profile.glass_hard_unlocked and not run.profile.crown_easy_unlocked,
		"The first boss must grant its own marks and leave later routes locked.")
	run.reward(run.data.offers[0])
	check(run.data.phase == "recruit" and run.data.hero not in run.data.offers, "Glass Medium must draft a different recruit after the Twins.")
	run.choose_recruit(run.data.offers[0])
	var restored := FrontierRun.new()
	check(restored.load_save(path) and restored.choose_recruit_starter("slam"), "Resume and finish the Glass Medium recruit's draft.")
	check(restored.data.heroes.size() == 2 and restored.data.hp == 53, "Glass Medium must retain lead HP and add a second hero.")
	check(restored.available_nodes()[0].label == "Annealing Hall", "Recruitment must open the Foundry's upper leg.")
	_reach_boss(restored)
	check(restored.encounter().boss_id == "prism_warden" and restored.is_final_boss(), "The Prism Warden must finish Glass Medium.")
	marks = restored.profile.marks
	restored.finish_combat(true, [27, 61])
	check(restored.profile.marks == marks + 34 and restored.profile.glass_hard_unlocked and restored.profile.crown_easy_unlocked,
		"A first Prism Warden clear must grant its payout and unlock both future routes.")
	check(restored.reward("skip") and restored.data.phase == "result", "The final reward must lead to the Glass Medium recap.")


func _check_glass_hard(path: String) -> void:
	var run := FrontierRun.new()
	run.load_save(path)
	run.abandon_run()
	var unlocked: bool = run.profile.glass_hard_unlocked
	run.profile.glass_hard_unlocked = false
	check(not run.start_run(76, "hard", "glass"), "Glass Hard must require a Glass Medium clear.")
	run.profile.glass_hard_unlocked = unlocked
	check(run.start_run(76, "hard", "glass"), "Glass Hard must be playable after the Prism Warden clear.")
	run.choose_hero(run.data.offers[0])
	run.choose_relic("pocket_bell")
	run.choose_starter("shot")
	for boss_id: String in FrontierRun.GLASS_BOSSES:
		_reach_boss(run)
		var encounter := run.encounter()
		check(encounter.boss_id == boss_id and encounter.location == "glass" and encounter.difficulty == "hard",
			"Every Glass Hard leg must select its intended Foundry boss.")
		check(encounter.heroes.size() == encounter.segment, "Glass Hard must add one hero per leg.")
		var remaining := [41, 65, 74].slice(0, encounter.heroes.size())
		var marks: int = run.profile.marks
		var before: Dictionary = run.profile.duplicate(true)
		check(run.finish_combat(true, remaining), "Resolve the Glass Hard boss.")
		if boss_id == "tempered_colossus":
			check(run.is_final_boss() and run.data.result == "victory" and run.data.offers.size() == 3,
				"Defeating the Tempered Colossus must begin the final Legendary recap.")
			before.marks += 54
			before.glass_hard_cleared = true
			check(run.profile == before, "First Glass Hard clear must award 54 marks and record mastery without changing unlocks.")
			check(not run.finish_combat(true, remaining), "The Colossus payout must not be applied twice.")
			check(run.reward(run.data.offers[0]) and run.data.phase == "result", "The Colossus trophy must open the recap.")
			break
		check(not run.is_final_boss() and not run.profile.glass_hard_cleared and run.profile.marks == marks + 4,
			"Intermediate Glass Hard bosses must grant only the boss payout.")
		check(run.reward(run.data.offers[0]) and run.data.phase == "recruit", "Recruit after each intermediate Glass Hard boss.")
		for hero: Dictionary in run.data.heroes:
			check(hero.id not in run.data.offers, "Glass Hard must not draft a current party member.")
		run.choose_recruit(run.data.offers[0])
		var restored := FrontierRun.new()
		check(restored.load_save(path) and restored.choose_recruit_starter("slam"), "Glass Hard recruitment must resume from disk.")
		run = restored
		check(run.loadout.lanes.size() == encounter.segment + 1 and run.data.heroes[0].hp == remaining[0],
			"Resumed Glass Hard recruitment must preserve carried HP and add exactly one timeline.")
	check(run.finish_run() and run.start_run(76, "hard", "glass"), "A completed Glass Hard route must be replayable.")
	run.choose_hero(run.data.offers[0])
	run.choose_relic("pocket_bell")
	run.choose_starter("shot")
	run.data.node = run.data.layers.back()[0]
	var repeat_marks: int = run.profile.marks
	check(run.finish_combat(true, [74]) and run.profile.marks == repeat_marks + 39,
		"A repeated Glass Hard clear must grant the repeat payout without a first-clear bonus.")


func _check_crown_easy(path: String) -> void:
	var run := FrontierRun.new()
	check(not run.can_start("easy", "crown"), "Crown Easy must require a Glass Medium clear.")
	check(not run.can_start("medium", "crown"), "Crown Medium must require a Crown Easy clear.")
	check(run.load_save(path), "Load a profile that cleared Glass Medium.")
	run.abandon_run()
	check(run.can_start("easy", "crown") and run.start_run(983, "easy", "crown"), "The Prism Warden clear must open Crown Easy.")
	run.choose_hero(run.data.offers[0])
	run.choose_relic("pocket_bell")
	run.choose_starter("shot")
	check(run.encounter().location == "crown" and run.encounter().kind == "opening" and run.data.heroes.size() == 1,
		"Crown Easy must start with a solo Skybridge Trial.")
	var restored := FrontierRun.new()
	check(restored.load_save(path) and restored.data.layers == run.data.layers and restored.data.location == "crown",
		"Crown Easy must resume with the same route and location.")
	_reach_boss(restored)
	check(restored.is_final_boss() and restored.encounter().boss_id == "relay_captain", "The Relay Captain must finish Crown Easy.")
	var marks: int = restored.profile.marks
	check(restored.finish_combat(true, [71]), "Resolve the Crown boss.")
	check(restored.profile.crown_medium_unlocked and restored.can_start("medium", "crown") and restored.profile.marks == marks + 19,
		"The first Crown clear must bank its boss payout and unlock Medium.")
	check(restored.data.offers.size() == 3, "Crown's final reward must offer three choices.")
	for id: String in restored.data.offers:
		check(ArenaSim.TILES[id].rarity == "legendary", "Crown's final reward must be Legendary.")
	check(not restored.finish_combat(true, [71]), "Crown's first-clear payout must not be applied twice.")
	check(restored.reward(restored.data.offers[0]) and restored.finish_run(), "Crown Easy must return to the hub after its trophy.")
	check(restored.start_run(983, "easy", "crown"), "Crown Easy must be replayable.")
	restored.choose_hero(restored.data.offers[0])
	restored.choose_relic("pocket_bell")
	restored.choose_starter("shot")
	restored.data.phase = "event"
	restored.data.node = restored._node("event", "Signal Cache", 1, 0)
	var gold: int = restored.data.gold
	check(restored.event_choice(0) and restored.data.gold == gold + 14 and restored.data.phase == "map",
		"The Signal Cache's safe choice must pay gold.")
	restored.data.phase = "event"
	var expected_hp: int = int(restored.data.hp) - ceili(float(restored.data.max_hp) * 0.12)
	check(restored.event_choice(1) and restored.data.hp == expected_hp and restored.data.phase == "reward" and restored.data.offers.size() == 2,
		"Opening the Signal Cache must cost 12% max HP and offer two choices.")
	restored.reward("skip")
	restored.data.node = restored.data.layers.back()[0]
	restored.data.phase = "combat"
	marks = restored.profile.marks
	check(restored.finish_combat(true, [71]) and restored.profile.marks == marks + 14,
		"A repeat Crown clear must award the repeat payout.")


func _check_crown_medium(path: String) -> void:
	var run := FrontierRun.new()
	check(run.load_save(path), "Crown Medium must read its unlock from a saved profile.")
	run.abandon_run()
	check(run.start_run(983, "medium", "crown"), "The Captain's Easy clear must open Crown Medium.")
	run.choose_hero(run.data.offers[0])
	run.choose_relic("pocket_bell")
	run.choose_starter("shot")
	_reach_boss(run)
	check(run.encounter().boss_id == "relay_captain" and run.encounter().segment == 1 and not run.is_final_boss(),
		"The Relay Captain must end leg one without ending Crown Medium.")
	var marks: int = run.profile.marks
	check(run.finish_combat(true, [61]) and run.profile.marks == marks + 4,
		"The Captain's intermediate defeat must pay only the boss payout.")
	check(not run.profile.crown_hard_unlocked and not run.profile.moonwreck_easy_unlocked,
		"The Captain must not open the Medium clear gates.")
	check(run.reward(run.data.offers[0]) and run.data.phase == "recruit" and run.data.hero not in run.data.offers,
		"Taking the Captain's Legendary must offer a distinct second hero.")
	check(run.choose_recruit(run.data.offers[0]), "Choose a Crown recruit.")
	var restored := FrontierRun.new()
	check(restored.load_save(path) and restored.data.phase == "recruit_starter" and restored.choose_recruit_starter("slam"),
		"The Crown Medium recruit's starter draft must resume from disk.")
	check(restored.data.heroes.size() == 2 and restored.loadout.lanes.size() == 2 and restored.data.hp == 61,
		"Crown Medium recruitment must carry HP and add a second hero and timeline.")
	check(restored.available_nodes()[0].label == "High Relay Gate", "Recruiting a second hero must open High Relay Gate.")
	_reach_boss(restored)
	check(restored.is_final_boss() and restored.encounter().boss_id == "relay_marshal" and restored.encounter().heroes.size() == 2,
		"The Relay Marshal must end the two-hero second leg.")
	marks = restored.profile.marks
	check(restored.finish_combat(true, [42, 71]) and restored.profile.marks == marks + 34,
		"The first Marshal clear must grant the first-clear payout.")
	check(restored.profile.crown_hard_unlocked and restored.profile.moonwreck_easy_unlocked,
		"The Marshal must unlock Crown Hard and Moonwreck Docks Easy.")
	check(not restored.can_start("hard", "crown") and not restored.can_start("easy", "moonwreck"),
		"Future routes must remain unavailable in this build.")
	check(not restored.finish_combat(true, [42, 71]) and restored.reward(restored.data.offers[0]) and restored.finish_run(),
		"The final payout must be recorded once and the trophy must lead to a recap.")
	check(restored.start_run(983, "medium", "crown"), "Crown Medium must be replayable.")
	restored.choose_hero(restored.data.offers[0])
	restored.choose_relic("pocket_bell")
	restored.choose_starter("shot")
	restored.data.node = restored.data.layers.back()[0]
	marks = restored.profile.marks
	check(restored.finish_combat(true, [71]) and restored.profile.marks == marks + 24,
		"A repeated Marshal clear must omit the first-clear bonus.")


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
