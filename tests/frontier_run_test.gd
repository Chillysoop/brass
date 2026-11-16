extends SceneTree

const FrontierRun = preload("res://scripts/frontier_run.gd")
const ArenaSim = preload("res://scripts/arena_sim.gd")
const ArsenalTiles = preload("res://scripts/arsenal_tiles.gd")
const ClassDecks = preload("res://scripts/class_decks.gd")
var failures: Array[String] = []


func _initialize() -> void:
	var run := FrontierRun.new()
	for seed_value in range(1, 129):
		var layers := run._make_map(seed_value)
		_check_map(layers)
		check(layers == run._make_map(seed_value), "Same seed must generate the same map.")
		var glass_easy := run._make_map(seed_value, "easy", "glass")
		check(glass_easy.back()[0].boss_id in FrontierRun.GLASS_BOSS_SCOUTS, "Glass Easy uses one of the two Act I bosses.")
		_check_map(glass_easy, 1, glass_easy.back()[0].boss_id)
		var glass_medium := run._make_map(seed_value, "medium", "glass")
		_check_map(glass_medium, 2, "prism_warden")
		check(glass_medium.slice(0, 7) == _with_gate_link(glass_easy, glass_medium[7][0].id),
			"Glass Medium keeps the first leg and connects its boss to the second leg.")
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
		var crown_hard := run._make_map(seed_value, "hard", "crown")
		_check_map(crown_hard, 3, "crown_regent")
		check(crown_hard.slice(0, 14) == _with_gate_link(crown_medium, crown_hard[14][0].id),
			"Crown Hard must keep the first two Crown legs and connect the Marshal to leg three.")
		_check_crown_hard_leg(crown_hard)
		var moonwreck := run._make_map(seed_value, "easy", "moonwreck")
		_check_map(moonwreck, 1, "wreckmaster")
		check(moonwreck == run._make_map(seed_value, "easy", "moonwreck"), "Moonwreck routes must be deterministic.")
		_check_moonwreck_nodes(moonwreck)
		var moonwreck_medium := run._make_map(seed_value, "medium", "moonwreck")
		_check_map(moonwreck_medium, 2, "tidekeeper")
		check(moonwreck_medium.slice(0, 7) == _with_gate_link(moonwreck, moonwreck_medium[7][0].id),
			"Moonwreck Medium must keep the first leg and connect the Wreckmaster to leg two.")
		_check_moonwreck_medium_nodes(moonwreck_medium)
		var moonwreck_hard := run._make_map(seed_value, "hard", "moonwreck")
		_check_map(moonwreck_hard, 3, "drowned_admiral")
		check(moonwreck_hard.slice(0, 14) == _with_gate_link(moonwreck_medium, moonwreck_hard[14][0].id),
			"Moonwreck Hard must keep the first two Moonwreck legs and connect the Tidekeeper to leg three.")
		_check_moonwreck_hard_leg(moonwreck_hard)
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
	check(_finish_rewards(run, "skip"), "Opening skip failed.")
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
					var draft := resumed.elite_relic_offers()
					check(draft.size() == 3 and resumed.choose_elite_relic(draft[0].id),
						"The first elite must let the player choose their relic.")
					check(resumed.data.relics.size() > 1, "Elite victory must award a relic.")
					for id: String in resumed.data.offers:
						check(ArenaSim.TILES[id].rarity != "common", "Elite choices must be Uncommon+.")
				if node.type == "boss":
					check(resumed.profile.medium_unlocked and resumed.data.result == "victory", "Boss must grant victory and unlock Medium.")
					check(resumed.data.offers.size() == 3, "Boss must offer three distinct rewards.")
					for id: String in resumed.data.offers:
						check(ArenaSim.TILES[id].rarity == "legendary", "Boss rewards must be Legendary.")
					check(not resumed.finish_combat(true, 100), "Repeated completion must not pay twice.")
				_finish_rewards(resumed, "skip")
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
	_check_crown_hard(path)
	_check_moonwreck_easy(path)
	_check_moonwreck_medium(path)
	_check_moonwreck_hard(path)
	_check_artifice(path)
	_check_specialist_drafts(path)
	_check_navigation(path)
	_check_legacy_medium_unlocks()
	_check_class_progression()
	_check_slam_pool()
	_check_arsenal_rewards()
	_check_acquisition_drafts()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Frontier model checks passed across 128 seeds for Brass, Glass, Crown, and Moonwreck routes.")
	quit(0 if failures.is_empty() else 1)


func _check_map(layers: Array, segments := 1, final_boss := "") -> void:
	check(layers.size() == 7 * segments and layers[0][0].type == "opening", "Each segment must have seven rows.")
	var allowed := ["tollkeeper", "brass_bellmaker"] if final_boss.is_empty() else [final_boss]
	check(layers.back()[0].boss_id in allowed, "The final boss must match the location and difficulty.")
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


func _expect_party_masteries(profile: Dictionary, heroes: Array) -> void:
	for hero: Dictionary in heroes:
		if hero.id not in profile.mastered_classes:
			profile.mastered_classes.append(hero.id)


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


func _check_crown_hard_leg(layers: Array) -> void:
	check(layers[14][0].label == "Crown Causeway", "Crown Hard must open leg three at Crown Causeway.")
	for row in range(15, 20):
		for node: Dictionary in layers[row]:
			check(node.label in FrontierRun.CROWN_REGENT_NODE_LABELS[node.type], "Crown Hard leg three must use its own route names.")


func _check_moonwreck_nodes(layers: Array) -> void:
	check(layers[0][0].label == "Drowned Gate Trial", "Moonwreck must open at the Drowned Gate Trial.")
	var events: Array[String] = []
	for row in range(1, 6):
		for node: Dictionary in layers[row]:
			check(node.label in FrontierRun.MOONWRECK_NODE_LABELS[node.type], "Moonwreck must have its own route names.")
			if node.type == "event":
				check(node.label not in events, "Moonwreck events must not repeat on one route.")
				events.append(node.label)


func _check_moonwreck_medium_nodes(layers: Array) -> void:
	check(layers[7][0].label == "Breakwater Gate", "Moonwreck Medium must open leg two at Breakwater Gate.")
	var events: Array[String] = []
	for row in range(1, 13):
		for node: Dictionary in layers[row]:
			if row > 7:
				check(node.label in FrontierRun.MOONWRECK_BREAKWATER_NODE_LABELS[node.type],
					"Moonwreck Medium leg two must use its own route names.")
			if node.type == "event":
				check(node.label not in events, "Moonwreck Medium events must not repeat across its two legs.")
				events.append(node.label)


func _check_moonwreck_hard_leg(layers: Array) -> void:
	check(layers[14][0].label == "Blackwater Gate", "Moonwreck Hard must open leg three at Blackwater Gate.")
	for row in range(15, 20):
		for node: Dictionary in layers[row]:
			check(node.label in FrontierRun.MOONWRECK_BLACKWATER_NODE_LABELS[node.type],
				"Moonwreck Hard leg three must use its own route names.")


func _finish_rewards(run: FrontierRun, id: String) -> bool:
	while run.data.get("phase") == "reward":
		if not run.reward(id):
			return false
		if id != "skip" and run.data.phase == "reward":
			id = run.data.offers[0]
	return true


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
	check(_finish_rewards(run, run.data.offers[0]), "Intermediate Legendary choice must succeed.")
	check(run.data.phase == "boss_relic" and run.choose_boss_relic("guild_ledger"), "The first Brass boss offers the Ledger before recruitment.")
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
	check(restored.reward_count() == 2 and restored.reward_lane() == 0,
		"Both heroes, including a fallen lead, should earn a final Legendary pick.")
	check(restored.reward("skip") and restored.reward_lane() == 1 and restored.data.phase == "reward",
		"The first hero's skip must keep the recruit's final reward pending.")
	var second_trophy: String = restored.data.offers[0]
	var second_hero: String = restored.data.heroes[1].id
	check(restored.reward(second_trophy) and restored.data.phase == "result"
		and restored.data.trophy == "" and restored.data.trophies == {second_hero: second_trophy},
		"Final rewards must record each hero's trophy and lead to the recap.")


func _check_legacy_medium_unlocks() -> void:
	var path := "user://frontier-legacy-medium-test-%d.json" % Time.get_ticks_usec()
	var old_run := FrontierRun.new()
	old_run.load_save(path)
	old_run.profile.medium_unlocked = true
	old_run.start_run(42, "medium")
	old_run.data.phase = "result"
	old_run.data.node = old_run.data.layers[6][0]
	old_run.data.result = "defeat"
	old_run.save()
	var restored := FrontierRun.new()
	check(restored.load_save(path) and not restored.can_start("hard") and not restored.can_start("easy", "glass"),
		"A saved defeat at the first Medium boss must keep both gates locked.")
	old_run.data.node = old_run.data.layers[-1][0]
	old_run.data.result = "victory"
	old_run.data.segment = 2
	old_run.profile.erase("hard_unlocked")
	old_run.profile.erase("glass_easy_unlocked")
	old_run.save()
	check(restored.load_save(path) and restored.can_start("hard") and restored.can_start("easy", "glass"),
		"A saved victory at the final Medium boss must restore both gates without paying Marks again.")
	check(old_run.finish_run(), "An old title save may have archived the completed recap without either unlock.")
	check(restored.load_save(path) and restored.data.is_empty() and restored.can_start("hard") and restored.can_start("easy", "glass"),
		"The backed-up recap must recover a verified final Medium victory on the title screen.")
	check(restored.profile.marks == 0 and restored.start_run(42, "easy", "glass"),
		"Recovering an unlock must leave the recorded Marks unchanged and allow the newly unlocked route.")
	check(old_run.load_save(path) and old_run.can_start("hard") and old_run.can_start("easy", "glass"),
		"Both restored unlocks must persist after starting a new route.")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func _check_slam_pool() -> void:
	var run := FrontierRun.new()
	check(run.forge_family_available("slam"), "Slam's forge should be available on a fresh profile.")
	check("shockwave" not in run._tier_pool(1), "Slam upgrades should leave an unrelated run's pool intact.")
	run.loadout = {"lanes": [[{"id": "slam"}]], "storage": []}
	check("shockwave" in run._tier_pool(1) and "skybreaker" in run._tier_pool(4),
		"Carrying a Slam should add its family to rarity-appropriate rewards.")


func _check_class_progression() -> void:
	var path := "user://frontier-class-progression-test-%d.json" % Time.get_ticks_usec()
	var run := FrontierRun.new()
	run.load_save(path)
	var starters := ["warden", "hexwright", "apothecary", "starshot", "duelist"]
	check(run.available_classes().size() == starters.size()
		and starters.all(func(id: String) -> bool: return id in run.available_classes()),
		"A fresh profile must have five classes available.")
	check(not run.buy_class("bulwark") and not run.can_choose_starter(),
		"A fresh profile needs Marks for a class purchase and a Brass clear for direct selection.")
	check(run.start_run(42) and run.data.offers.size() == 3
		and run.data.offers.all(func(id: String) -> bool: return id in starters),
		"Start drafts must draw only from the available roster.")
	check(not run.choose_preferred_hero(run.data.offers[0]) and not run.choose_hero("bulwark"),
		"A first run must use the offered draft and reject locked classes.")
	if run.choose_hero(run.data.offers[0]) and run.choose_relic("pocket_bell") and run.choose_starter("bash"):
		_reach_boss(run)
		check(run.finish_combat(true, 100) and _finish_rewards(run, "skip"), "Clear Brass Easy to unlock direct selection.")
		check(not run.buy_class("bulwark"), "Class purchases must be blocked during the victory recap.")
		check(run.finish_run() and run.can_choose_starter(), "Direct selection must be available after the first clear.")
	else:
		check(false, "The fresh roster must complete the starter draft.")
	var marks := int(run.profile.marks)
	var price := run.class_unlock_cost("bulwark")
	check(price > 0 and run.buy_class("bulwark") and int(run.profile.marks) == marks - price,
		"Buying a class must charge its listed cost exactly once.")
	check(not run.buy_class("bulwark") and int(run.profile.marks) == marks - price,
		"A repeat purchase must be rejected without charging Marks.")
	check(run.load_save(path) and "bulwark" in run.available_classes() and "cinder_mage" not in run.available_classes(),
		"The purchased class must stay unlocked after reloading without unlocking other classes.")
	run.save_path = path + ".missing/file.json"
	check(not run.buy_class("breaker") and "breaker" not in run.available_classes() and int(run.profile.marks) == marks - price,
		"A failed save must restore the Marks and leave the class locked.")
	run.save_path = path
	var saw_purchase_in_draft := false
	var saw_purchase_outside_draft := false
	for seed in range(1, 13):
		if not run.start_run(seed):
			check(false, "A purchased class must leave the default hero draft available.")
			break
		if "bulwark" in run.data.offers:
			saw_purchase_in_draft = true
		else:
			saw_purchase_outside_draft = true
			check(not run.choose_preferred_hero("cinder_mage") and run.choose_preferred_hero("bulwark")
				and run.data.hero == "bulwark" and run.data.phase == "relic",
				"After a clear, direct selection may pick an owned class outside the current draft and must continue to relics.")
		run.abandon_run()
	check(saw_purchase_in_draft and saw_purchase_outside_draft, "The purchased class must join the seeded draft pool.")
	if run.start_run(42):
		# A save from before class unlocks may have already offered a class now locked for new runs.
		run.data.offers[0] = "cinder_mage"
		check(run.save() and run.load_save(path) and run.choose_hero("cinder_mage"),
			"A saved hero draft may still choose a class it already offered before the progression update.")
		check(run.load_save(path) and run.data.get("hero") == "cinder_mage"
			and "cinder_mage" not in run.available_classes(),
			"A saved party keeps its existing hero without unlocking their class on the profile.")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


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
	check(run.is_final_boss() and run.encounter().boss_id == "glass_refraction_engine", "Seed 76 ends Glass Easy at the Refraction Engine.")
	var marks: int = run.profile.marks
	run.finish_combat(true, [70])
	check(run.profile.glass_medium_unlocked and run.profile.marks == marks + 19, "Glass Easy must bank its own first-clear payout.")
	_finish_rewards(run, "skip")
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
		_finish_rewards(run, "skip")
		if boss_id == "tollkeeper":
			check(run.data.phase == "boss_relic" and run.choose_boss_relic("skip"), "Brass Hard recruitment can proceed after skipping the boss relic.")
		if boss_id == "iron_regent":
			check(run.data.phase == "result" and run.profile.brass_hard_cleared and run.profile.marks == marks + 54,
				"The Iron Regent must complete Hard and bank the first-clear payout.")
			break
		for hero: Dictionary in run.data.heroes:
			check(hero.id not in run.data.offers, "Recruitment must exclude every current hero.")
		var available := run.available_classes()
		check(run.data.offers.size() == 3 and run.data.offers.all(func(id: String) -> bool: return id in available),
			"Each Hard recruit draft must offer three choices from the available roster.")
		run.choose_recruit(run.data.offers[0])
		var restored := FrontierRun.new()
		check(restored.load_save(path) and restored.choose_recruit_starter(ClassDecks.starter(restored.data.pending_recruit)), "Hard recruitment must resume from disk.")
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
	check(run.encounter().boss_id == "glass_refraction_engine" and not run.is_final_boss(), "Seed 76 keeps the same first Glass boss on Medium.")
	run.finish_combat(true, [53])
	check(run.profile.marks == marks + 4 and not run.profile.glass_hard_unlocked and not run.profile.crown_easy_unlocked,
		"The first boss must grant its own marks and leave later routes locked.")
	_finish_rewards(run, run.data.offers[0])
	check(run.data.phase == "recruit" and run.data.hero not in run.data.offers, "Glass Medium must draft a different recruit after the Twins.")
	run.choose_recruit(run.data.offers[0])
	var restored := FrontierRun.new()
	check(restored.load_save(path) and restored.choose_recruit_starter(ClassDecks.starter(restored.data.pending_recruit)), "Resume and finish the Glass Medium recruit's draft.")
	check(restored.data.heroes.size() == 2 and restored.data.hp == 53, "Glass Medium must retain lead HP and add a second hero.")
	check(restored.available_nodes()[0].label == "Annealing Hall", "Recruitment must open the Foundry's upper leg.")
	_reach_boss(restored)
	check(restored.encounter().boss_id == "prism_warden" and restored.is_final_boss(), "The Prism Warden must finish Glass Medium.")
	marks = restored.profile.marks
	restored.finish_combat(true, [27, 61])
	check(restored.profile.marks == marks + 34 and restored.profile.glass_hard_unlocked and restored.profile.crown_easy_unlocked,
		"A first Prism Warden clear must grant its payout and unlock both future routes.")
	check(_finish_rewards(restored, "skip") and restored.data.phase == "result", "The final reward must lead to the Glass Medium recap.")


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
	for boss_id: String in ["glass_refraction_engine", "prism_warden", "tempered_colossus"]:
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
			_expect_party_masteries(before, encounter.heroes)
			check(run.profile == before, "First Glass Hard clear must award 54 marks and record mastery without changing unlocks.")
			check(not run.finish_combat(true, remaining), "The Colossus payout must not be applied twice.")
			check(_finish_rewards(run, run.data.offers[0]) and run.data.phase == "result", "The Colossus trophy must open the recap.")
			break
		check(not run.is_final_boss() and not run.profile.glass_hard_cleared and run.profile.marks == marks + 4,
			"Intermediate Glass Hard bosses must grant only the boss payout.")
		check(_finish_rewards(run, run.data.offers[0]) and run.data.phase == "recruit", "Recruit after each intermediate Glass Hard boss.")
		for hero: Dictionary in run.data.heroes:
			check(hero.id not in run.data.offers, "Glass Hard must not draft a current party member.")
		run.choose_recruit(run.data.offers[0])
		var restored := FrontierRun.new()
		check(restored.load_save(path) and restored.choose_recruit_starter(ClassDecks.starter(restored.data.pending_recruit)), "Glass Hard recruitment must resume from disk.")
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
	check(_finish_rewards(restored, restored.data.offers[0]) and restored.finish_run(), "Crown Easy must return to the hub after its trophy.")
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
	_finish_rewards(restored, "skip")
	restored.data.node = restored.data.layers.back()[0]
	restored.data.phase = "combat"
	marks = restored.profile.marks
	check(restored.finish_combat(true, [71]) and restored.profile.marks == marks + 14,
		"A repeat Crown clear must award the repeat payout.")


func _check_crown_medium(path: String) -> void:
	var run := FrontierRun.new()
	check(not run.can_start("easy", "moonwreck"), "Moonwreck Easy must require a Crown Medium clear.")
	check(not run.can_start("hard", "crown"), "Crown Hard must require a Crown Medium clear.")
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
	check(_finish_rewards(run, run.data.offers[0]) and run.data.phase == "recruit" and run.data.hero not in run.data.offers,
		"Taking the Captain's Legendary must offer a distinct second hero.")
	check(run.choose_recruit(run.data.offers[0]), "Choose a Crown recruit.")
	var restored := FrontierRun.new()
	check(restored.load_save(path) and restored.data.phase == "recruit_starter" and restored.choose_recruit_starter(ClassDecks.starter(restored.data.pending_recruit)),
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
	check(restored.can_start("hard", "crown") and restored.can_start("easy", "moonwreck"),
		"Crown Hard and Moonwreck Easy must both be playable after their unlock.")
	check(not restored.finish_combat(true, [42, 71]) and _finish_rewards(restored, restored.data.offers[0]) and restored.finish_run(),
		"The final payout must be recorded once and the trophy must lead to a recap.")
	check(restored.start_run(983, "medium", "crown"), "Crown Medium must be replayable.")
	restored.choose_hero(restored.data.offers[0])
	restored.choose_relic("pocket_bell")
	restored.choose_starter("shot")
	restored.data.node = restored.data.layers.back()[0]
	marks = restored.profile.marks
	check(restored.finish_combat(true, [71]) and restored.profile.marks == marks + 24,
		"A repeated Marshal clear must omit the first-clear bonus.")


func _check_crown_hard(path: String) -> void:
	var run := FrontierRun.new()
	check(run.load_save(path), "Crown Hard must read its Medium clear unlock from disk.")
	run.abandon_run()
	check(run.start_run(983, "hard", "crown"), "The Relay Marshal's Medium clear must open Crown Hard.")
	run.choose_hero(run.data.offers[0])
	run.choose_relic("pocket_bell")
	run.choose_starter("shot")
	for boss_id: String in FrontierRun.CROWN_BOSSES:
		_reach_boss(run)
		var encounter := run.encounter()
		check(encounter.boss_id == boss_id and encounter.location == "crown" and encounter.difficulty == "hard",
			"Every Crown Hard leg must select its intended boss.")
		check(encounter.heroes.size() == encounter.segment, "Crown Hard must add one hero per leg.")
		var remaining := [52, 63, 75].slice(0, encounter.heroes.size())
		var before: Dictionary = run.profile.duplicate(true)
		check(run.finish_combat(true, remaining), "Resolve the Crown Hard boss.")
		if boss_id == "crown_regent":
			check(run.is_final_boss() and run.data.result == "victory" and run.data.offers.size() == 3,
				"The Crown Regent must begin the final Legendary recap.")
			before.marks += 54
			before.crown_hard_cleared = true
			_expect_party_masteries(before, encounter.heroes)
			check(run.profile == before, "The first Crown Hard clear must grant 54 marks and record mastery without opening new gates.")
			check(not run.finish_combat(true, remaining), "The Regent's payout must not be applied twice.")
			check(_finish_rewards(run, run.data.offers[0]) and run.data.phase == "result", "The Regent's trophy must open the recap.")
			break
		check(not run.is_final_boss() and not run.profile.crown_hard_cleared and run.profile.marks == before.marks + 4,
			"Intermediate Crown Hard bosses must grant only the boss payout.")
		check(run.data.offers.size() == 3 and _finish_rewards(run, run.data.offers[0]) and run.data.phase == "recruit",
			"An intermediate Legendary reward must open recruitment.")
		for hero: Dictionary in run.data.heroes:
			check(hero.id not in run.data.offers, "Crown Hard must not draft a current party member.")
		run.choose_recruit(run.data.offers[0])
		var restored := FrontierRun.new()
		check(restored.load_save(path) and restored.data.phase == "recruit_starter" and restored.choose_recruit_starter(ClassDecks.starter(restored.data.pending_recruit)),
			"Both Crown Hard recruitment stages must resume from disk.")
		run = restored
		check(run.loadout.lanes.size() == encounter.segment + 1 and run.data.heroes[0].hp == remaining[0],
			"Resumed Crown Hard recruitment must preserve carried HP and add exactly one timeline.")
	check(run.finish_run() and run.start_run(983, "hard", "crown"), "A completed Crown Hard route must be replayable.")
	run.choose_hero(run.data.offers[0])
	run.choose_relic("pocket_bell")
	run.choose_starter("shot")
	run.data.node = run.data.layers.back()[0]
	var marks: int = run.profile.marks
	check(run.finish_combat(true, [75]) and run.profile.marks == marks + 39,
		"A repeated Regent clear must omit the first-clear bonus.")


func _check_moonwreck_easy(path: String) -> void:
	var run := FrontierRun.new()
	check(not run.can_start("easy", "moonwreck"), "Moonwreck Easy must be locked on a fresh profile.")
	check(not run.can_start("medium", "moonwreck"), "Moonwreck Medium must require a Moonwreck Easy clear.")
	check(run.load_save(path), "Read Moonwreck's Crown Medium unlock from disk.")
	run.abandon_run()
	check(run.can_start("easy", "moonwreck") and run.start_run(9142, "easy", "moonwreck"),
		"The Relay Marshal's Medium clear must open Moonwreck Easy.")
	run.choose_hero(run.data.offers[0])
	run.choose_relic("pocket_bell")
	run.choose_starter("shot")
	check(run.encounter().location == "moonwreck" and run.encounter().kind == "opening" and run.data.heroes.size() == 1,
		"Moonwreck Easy must start with a solo Drowned Gate Trial.")
	var restored := FrontierRun.new()
	check(restored.load_save(path) and restored.data.layers == run.data.layers and restored.data.location == "moonwreck",
		"Moonwreck Easy must resume with the same route and location.")
	_reach_boss(restored)
	check(restored.is_final_boss() and restored.encounter().boss_id == "wreckmaster", "The Wreckmaster must finish Moonwreck Easy.")
	var marks: int = restored.profile.marks
	check(restored.finish_combat(true, [67]), "Resolve the Moonwreck boss.")
	check(restored.profile.moonwreck_medium_unlocked and restored.can_start("medium", "moonwreck") and restored.profile.marks == marks + 19,
		"The first Moonwreck clear must bank its boss payout and unlock Medium.")
	check(not restored.can_start("hard", "moonwreck"), "Moonwreck Hard must remain unavailable.")
	check(restored.data.offers.size() == 3, "The Wreckmaster's final reward must offer three choices.")
	for id: String in restored.data.offers:
		check(ArenaSim.TILES[id].rarity == "legendary", "The Wreckmaster's final reward must be Legendary.")
	check(not restored.finish_combat(true, [67]), "Moonwreck's first-clear payout must not be applied twice.")
	check(_finish_rewards(restored, restored.data.offers[0]) and restored.finish_run(), "Moonwreck Easy must return to the hub after its trophy.")
	check(restored.start_run(9142, "easy", "moonwreck"), "Moonwreck Easy must be replayable.")
	restored.choose_hero(restored.data.offers[0])
	restored.choose_relic("pocket_bell")
	restored.choose_starter("shot")
	restored.data.phase = "event"
	restored.data.node = restored._node("event", "Tethered Barge", 1, 0)
	var gold: int = restored.data.gold
	check(restored.event_choice(0) and restored.data.gold == gold + 12 and restored.data.phase == "map",
		"The Tethered Barge must pay the promised share of salvage.")
	restored.data.phase = "event"
	restored.data.heroes[0].hp = 50
	check(restored.event_choice(1) and restored.data.hp == 74 and restored.data.gold == gold + 12,
		"Resting aboard the Tethered Barge must heal without granting additional gold.")
	restored.data.node = restored.data.layers.back()[0]
	restored.data.phase = "combat"
	marks = restored.profile.marks
	check(restored.finish_combat(true, [67]) and restored.profile.marks == marks + 14,
		"A repeated Wreckmaster clear must omit the first-clear bonus.")


func _check_moonwreck_medium(path: String) -> void:
	var run := FrontierRun.new()
	check(run.load_save(path), "Moonwreck Medium must read its unlock from a saved profile.")
	run.abandon_run()
	check(run.start_run(9142, "medium", "moonwreck"), "The Wreckmaster's Easy clear must open Moonwreck Medium.")
	run.choose_hero(run.data.offers[0])
	run.choose_relic("pocket_bell")
	run.choose_starter("shot")
	_reach_boss(run)
	check(run.encounter().boss_id == "wreckmaster" and run.encounter().segment == 1 and not run.is_final_boss(),
		"The Wreckmaster must end leg one without ending Moonwreck Medium.")
	var marks: int = run.profile.marks
	check(run.finish_combat(true, [61]) and run.profile.marks == marks + 4 and not run.profile.moonwreck_hard_unlocked,
		"The Wreckmaster's intermediate defeat must pay only the boss payout.")
	check(run.data.offers.size() == 3, "The Wreckmaster must offer three intermediate rewards.")
	for id: String in run.data.offers:
		check(ArenaSim.TILES[id].rarity == "legendary", "The Wreckmaster's intermediate rewards must be Legendary.")
	check(_finish_rewards(run, run.data.offers[0]) and run.data.phase == "recruit" and run.data.hero not in run.data.offers,
		"Taking the Wreckmaster's Legendary must offer a distinct second hero.")
	check(run.choose_recruit(run.data.offers[0]), "Choose a Moonwreck recruit.")
	var restored := FrontierRun.new()
	check(restored.load_save(path) and restored.data.phase == "recruit_starter" and restored.choose_recruit_starter(ClassDecks.starter(restored.data.pending_recruit)),
		"The Moonwreck recruit's starter draft must resume from disk.")
	check(restored.data.heroes.size() == 2 and restored.loadout.lanes.size() == 2 and restored.data.hp == 61,
		"Moonwreck recruitment must carry HP and add a second hero and timeline.")
	check(restored.available_nodes()[0].label == "Breakwater Gate", "Recruiting a second hero must open Breakwater Gate.")
	_reach_boss(restored)
	check(restored.is_final_boss() and restored.encounter().boss_id == "tidekeeper" and restored.encounter().heroes.size() == 2,
		"The Tidekeeper must end the two-hero second leg.")
	var before: Dictionary = restored.profile.duplicate(true)
	check(restored.finish_combat(true, [42, 71]), "Resolve the Tidekeeper's first clear.")
	before.marks += 34
	before.moonwreck_hard_unlocked = true
	_expect_party_masteries(before, restored.data.heroes)
	check(restored.profile == before and restored.can_start("hard", "moonwreck"),
		"The first Tidekeeper clear must pay 34 marks and open only the Hard route.")
	check(not restored.finish_combat(true, [42, 71]) and _finish_rewards(restored, restored.data.offers[0]) and restored.finish_run(),
		"The final payout must be recorded once and the trophy must lead to a recap.")
	var finished := FrontierRun.new()
	check(finished.load_save(path) and finished.can_start("hard", "moonwreck"),
		"The Hard unlock must survive a reload.")
	check(finished.start_run(9142, "medium", "moonwreck"), "Moonwreck Medium must be replayable.")
	finished.choose_hero(finished.data.offers[0])
	finished.choose_relic("pocket_bell")
	finished.choose_starter("shot")
	finished.data.node = finished.data.layers.back()[0]
	marks = finished.profile.marks
	check(finished.finish_combat(true, [71]) and finished.profile.marks == marks + 24,
		"A repeated Tidekeeper clear must omit the first-clear bonus.")


func _check_moonwreck_hard(path: String) -> void:
	var run := FrontierRun.new()
	check(not run.can_start("hard", "moonwreck"), "Moonwreck Hard must require a Moonwreck Medium clear.")
	check(run.load_save(path), "Moonwreck Hard must read its Medium clear unlock from disk.")
	run.abandon_run()
	check(run.start_run(9142, "hard", "moonwreck"), "The Tidekeeper's Medium clear must open Moonwreck Hard.")
	run.choose_hero(run.data.offers[0])
	run.choose_relic("pocket_bell")
	run.choose_starter("shot")
	for boss_id: String in FrontierRun.MOONWRECK_BOSSES:
		_reach_boss(run)
		var encounter := run.encounter()
		check(encounter.boss_id == boss_id and encounter.location == "moonwreck" and encounter.difficulty == "hard",
			"Every Moonwreck Hard leg must select its intended boss.")
		check(encounter.heroes.size() == encounter.segment, "Moonwreck Hard must add one hero per leg.")
		var remaining := [52, 63, 75].slice(0, encounter.heroes.size())
		var before: Dictionary = run.profile.duplicate(true)
		check(run.finish_combat(true, remaining), "Resolve the Moonwreck Hard boss.")
		check(run.data.offers.size() == 3, "Each Moonwreck Hard boss must offer three choices.")
		for id: String in run.data.offers:
			check(ArenaSim.TILES[id].rarity == "legendary", "Moonwreck Hard boss rewards must be Legendary.")
		if boss_id == "drowned_admiral":
			check(run.is_final_boss() and run.data.result == "victory", "The Drowned Admiral must begin the final recap.")
			before.marks += 54
			before.moonwreck_hard_cleared = true
			_expect_party_masteries(before, encounter.heroes)
			check(run.profile == before, "The first Moonwreck Hard clear must grant 54 marks and record mastery.")
			check(not run.finish_combat(true, remaining), "The Drowned Admiral's payout must not be applied twice.")
			check(_finish_rewards(run, run.data.offers[0]) and run.data.phase == "result", "The Drowned Admiral's trophy must open the recap.")
			break
		check(not run.is_final_boss() and not run.profile.moonwreck_hard_cleared and run.profile.marks == before.marks + 4,
			"Intermediate Moonwreck Hard bosses must grant only the boss payout.")
		check(_finish_rewards(run, run.data.offers[0]) and run.data.phase == "recruit", "An intermediate Legendary reward must open recruitment.")
		for hero: Dictionary in run.data.heroes:
			check(hero.id not in run.data.offers, "Moonwreck Hard must not draft a current party member.")
		run.choose_recruit(run.data.offers[0])
		var restored := FrontierRun.new()
		check(restored.load_save(path) and restored.data.phase == "recruit_starter" and restored.choose_recruit_starter(ClassDecks.starter(restored.data.pending_recruit)),
			"Both Moonwreck Hard recruitment stages must resume from disk.")
		run = restored
		check(run.loadout.lanes.size() == encounter.segment + 1 and run.data.heroes[0].hp == remaining[0],
			"Resumed Moonwreck Hard recruitment must preserve carried HP and add exactly one timeline.")
		if encounter.segment == 2:
			check(run.available_nodes()[0].label == "Blackwater Gate", "The third recruit must open Blackwater Gate.")
	var finished := FrontierRun.new()
	check(finished.load_save(path) and finished.profile.moonwreck_hard_cleared and finished.finish_run(),
		"Moonwreck Hard mastery and the recap must survive a reload.")
	check(finished.start_run(9142, "hard", "moonwreck"), "A completed Moonwreck Hard route must be replayable.")
	finished.choose_hero(finished.data.offers[0])
	finished.choose_relic("pocket_bell")
	finished.choose_starter("shot")
	finished.data.node = finished.data.layers.back()[0]
	var marks: int = finished.profile.marks
	check(finished.finish_combat(true, [75]) and finished.profile.marks == marks + 39,
		"A repeated Drowned Admiral clear must omit the first-clear bonus.")


func _check_artifice(path: String) -> void:
	var run := FrontierRun.new()
	check(run.load_save(path) and _finish_rewards(run, "skip") and run.finish_run(),
		"Return from the Moonwreck Hard recap before purchasing Artifice.")
	check(not run.buy_meta("wayfarers_pin"), "Wayfarer's Pin must require Blink Artifice.")
	var marks: int = run.profile.marks
	check(run.buy_meta("blink_artifice") and run.profile.marks == marks - 18,
		"Buying Blink Artifice must spend 18 Marks once its prerequisite is met.")
	check(not run.buy_meta("blink_artifice") and run.buy_meta("wayfarers_pin") and run.profile.marks == marks - 32,
		"Buying Wayfarer's Pin must spend another 14 Marks. Artifice cannot be bought twice.")
	var restored := FrontierRun.new()
	check(restored.load_save(path) and restored.profile.meta == run.profile.meta,
		"Both new Chart purchases must persist.")
	check(restored.start_run(42), "A new expedition can use unlocked Artifice.")
	check(restored.choose_hero(restored.data.offers[0]), "A new expedition still begins with the hero draft.")
	check(restored.data.offers.size() == 4 and "wayfarers_pin" in restored.data.offers
		and "wayfarers_pin" in restored._available_relics(),
		"The new relic joins the starter draft, elite and shop pools as an additional choice.")
	check(restored.choose_relic(restored.data.offers[0]) and restored.choose_starter("bash"),
		"The expanded draft must still leave an eligible relic and starter tile.")
	check(restored.finish_combat(true, 90), "The first battle still awards a combat draft.")
	check(restored.data.offers.size() == 3 and "bash" in restored.data.offers,
		"An expanded reward pool must still offer an exact copy of the starting tile.")

	var fresh := FrontierRun.new()
	for tier in range(1, ArenaSim.BLINK_TIERS.size()):
		for id: String in ArenaSim.BLINK_TIERS[tier]:
			check(id not in fresh._tier_pool(tier) and id in restored._tier_pool(tier),
				"Blink upgrades must enter their matching pool only after unlocking Artifice.")
	check("blink" in fresh._normal_pool(), "The common Blink remains available on a fresh profile.")
	check("wayfarers_pin" not in fresh._available_relics(), "A fresh profile cannot receive the locked relic.")

	var offered_normal := {}
	var offered_elite := {}
	var offered_boss := {}
	for seed_value in range(1, 129):
		restored.data.seed = seed_value
		restored.loadout.lanes = [[{"id": "bash"}, {"id": "phase_cut"}, {"id": "phase_cut"}]]
		var rewards := restored._standard_rewards()
		check(rewards.size() == 3 and "phase_cut" in rewards and rewards == restored._standard_rewards(),
			"A held pair takes priority in the deterministic normal draft.")
		for id: String in rewards:
			offered_normal[id] = true
		var elite_pool := restored._tier_pool(1) + restored._tier_pool(2) + restored._tier_pool(3)
		var elites := restored._tier_rewards(elite_pool, 3, 81)
		check(elites.size() == 3 and "phase_cut" in elites and not elites.any(func(id: String): return id not in elite_pool),
			"Elites should retain one useful owned tile within their Uncommon through Epic pool.")
		for id: String in elites:
			offered_elite[id] = true
		for id: String in restored._tier_rewards(restored._tier_pool(4), 3, 81):
			offered_boss[id] = true
		for leg in range(1, 4):
			restored.data.segment = leg
			var stock := restored._shop_tiles()
			check(stock.size() == 4 and stock[3] in ArenaSim.BLINK_TIERS[leg]
				and stock[2] in ArsenalTiles.UNCOMMON_IDS
				and stock.slice(0, 2).all(func(id: String): return id in restored._normal_pool()),
				"Artifice adds one Blink upgrade to the shop's regular stock.")
			if leg == 1:
				check(stock[3] == "phase_cut", "A matching shop upgrade should favor completing a pair.")
	check(offered_normal.has_all(ArenaSim.BLINK_TIERS[1] + ArenaSim.BLINK_TIERS[2]),
		"Personal drafts can offer both Uncommon and both Rare upgrades from an owned, unlocked family.")
	check(offered_elite.has_all(ArenaSim.BLINK_TIERS[1] + ArenaSim.BLINK_TIERS[2] + ArenaSim.BLINK_TIERS[3]),
		"Elites can offer all Uncommon through Epic Blink upgrades.")
	check(offered_boss.has_all(ArenaSim.BLINK_TIERS[4]) and offered_boss.size() == 5,
		"The two Blink Legendaries join the existing boss choices.")
	var next_blink := restored._owned_reward(restored._tier_pool(2), 92)
	check(next_blink in ArenaSim.BLINK_TIERS[2], "With no eligible duplicate, a reward can offer another tile from an owned family.")


func _check_specialist_drafts(path: String) -> void:
	var run := FrontierRun.new()
	check(run.load_save(path) and run.abandon_run(), "Leave the test expedition before purchasing new Chart nodes.")
	check(not run.buy_meta("shot_artifice") and not run.buy_meta("navigation"), "Supplies is a prerequisite for Marksman and Navigation.")
	check(run.buy_meta("purse") and run.buy_meta("shot_artifice") and run.buy_meta("guard_artifice"), "The new forge families can unlock independently.")
	check(run.start_run(42) and run.choose_hero(run.data.offers[0]) and run.choose_relic("pocket_bell")
		and run.choose_starter("shot"), "An upgraded account can start with a Common Shot.")
	var fresh := FrontierRun.new()
	check(not fresh.forge_family_available("shot") and not fresh.forge_family_available("guard")
		and "shot" in fresh._normal_pool() and "guard" in fresh._normal_pool(), "Common Shot and Guard remain draftable before their trees unlock.")
	for family in ["shot", "guard"]:
		check(run.forge_family_available(family), "An unlocked family can use the forge.")
		for tier in range(1, 5):
			var tiles: Array = ArenaSim.FORGE_FAMILIES[family][tier]
			check(tiles.all(func(id: String): return id in run._tier_pool(tier) and id not in fresh._tier_pool(tier)),
				"Each specialist upgrade joins its rarity pool only after its unlock.")
	var stocked := {}
	var legendary := {}
	var normal := {}
	var shot: String = ArenaSim.FORGE_FAMILIES.shot[1][0]
	run.loadout.storage[0] = [{"id": shot, "start": 0}, {"id": shot, "start": 3}]
	check(shot in run._standard_rewards(), "An owned pair keeps its slot in the expanded combat draft.")
	run.loadout.storage[0] = []
	for seed_value in range(1, 513):
		run.data.seed = seed_value
		var shop := run._shop_tiles()
		check(shop.size() == 4 and shop[2] in ArsenalTiles.UNCOMMON_IDS
			and shop.slice(0, 2).all(func(id: String): return id in run._normal_pool()),
			"Multiple unlocks share one shop slot and preserve three regular offers.")
		stocked[shop[3]] = true
		var offers := run._tier_rewards(run._tier_pool(4), 3, 81)
		check(offers.size() == 3 and offers.any(func(id: String): return id in fresh._tier_pool(4)),
			"Expanded boss drafts preserve a baseline Legendary choice.")
		for id: String in offers:
			legendary[id] = true
		for id: String in run._standard_rewards():
			normal[id] = true
	var active_families: Array = ClassDecks.forge_families(run.data.hero) + ["shot"]
	for family in ["shot", "guard"]:
		check(stocked.has_all(ArenaSim.FORGE_FAMILIES[family][1]),
			"Each unlocked family can enter shops.")
		check(normal.has_all(ArenaSim.FORGE_FAMILIES[family][1]) == active_families.has(family),
			"An unlocked family enters combat rewards when the hero uses it or has it in their class deck.")
		check(legendary.has_all(ArenaSim.FORGE_FAMILIES[family][4]), "Each new Legendary can appear as a boss reward.")


func _check_arsenal_rewards() -> void:
	var path := "user://frontier-arsenal-test-%d.json" % Time.get_ticks_usec()
	var run := FrontierRun.new()
	run.load_save(path)
	check(run.start_run(42) and run.choose_hero(run.data.offers[0]) and run.choose_relic("pocket_bell")
		and run.choose_starter("bash"), "Start an expedition with no Aether Chart unlocks.")
	run.loadout.storage[0].append({"id": "bash", "start": 0, "target": "nearest"})
	var battle_tiles := {}
	var shop_tiles := {}
	for seed_value in range(1, 1025):
		run.data.seed = seed_value
		var rewards := run._standard_rewards()
		var stock := run._shop_tiles()
		check(rewards.size() == 3 and "bash" in rewards and rewards == run._standard_rewards(),
			"The expanded seeded draft keeps the third copy of an owned pair.")
		check(stock.size() == 3 and stock[2] in ArsenalTiles.UNCOMMON_IDS,
			"A fresh shop carries an Uncommon among its three tiles.")
		for id: String in rewards:
			battle_tiles[id] = true
		for id: String in stock:
			shop_tiles[id] = true
	var added_tiles := ArsenalTiles.COMMON_IDS + ArsenalTiles.UNCOMMON_IDS
	var class_tiles: Array = ClassDecks.common(run.data.hero) + ClassDecks.uncommon(run.data.hero)
	check(battle_tiles.has_all(class_tiles) and shop_tiles.has_all(added_tiles),
		"Fresh runs can find their class deck in battle rewards and all 24 arsenal tiles in shops.")
	check(run.finish_combat(true, 90), "The expanded pool is active at the opening fight.")
	var restored := FrontierRun.new()
	check(restored.load_save(path) and restored.data.offers == run.data.offers and restored.reward_hint("bash") == "Third copy",
		"Resuming keeps all three offers and identifies the copy needed for the forge.")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func _check_acquisition_drafts() -> void:
	var path := "user://frontier-acquisition-test-%d.json" % Time.get_ticks_usec()
	var run := FrontierRun.new()
	run.load_save(path)
	run.profile.medium_unlocked = true
	_check_rotating_shop(run)
	run.abandon_run()
	_check_first_paid_copy(run)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func _start_acquisition_run(run: FrontierRun, difficulty: String) -> bool:
	return run.start_run(1, difficulty) and run.choose_preferred_hero("warden") \
		and run.choose_relic("pocket_bell") and run.choose_starter("shield_tap")


func _check_rotating_shop(run: FrontierRun) -> void:
	if not _start_acquisition_run(run, "medium"):
		check(false, "Start the two-hero shop fixture.")
		return
	_reach_boss(run)
	if not (run.finish_combat(true, 100) and _finish_rewards(run, "skip") and run.choose_boss_relic("skip")):
		check(false, "The first boss should open recruit selection for the shop fixture.")
		return
	var recruit: String = run.data.offers[0]
	if not (run.choose_recruit(recruit) and run.choose_recruit_starter(ClassDecks.starter(recruit))):
		check(false, "The shop fixture needs a second hero.")
		return
	var deck_tiles := {"warden": "shield_ram", recruit: ClassDecks.specialties(recruit).back()}
	for lane in range(run.data.heroes.size()):
		run.loadout.lanes[lane] = _acquisition_pair(deck_tiles[run.data.heroes[lane].id])
	if not (run.choose_node("7-1") and run.finish_combat(true, [100, 100]) and _finish_rewards(run, "skip") \
		and run.choose_node("8-0") and run.leave_node() and run.choose_node("9-1")):
		check(false, "The seeded route must reach the first Act II shop.")
		return
	var stock := run.shop_stock().duplicate()
	var ordinary := run._shop_tiles()
	var offer := run.shop_deck_offer_id()
	var owner := run.shop_class_offer_owner(offer)
	var lane := run.shop_class_offer_lane(offer)
	check(stock == ordinary + [offer] and offer == deck_tiles.get(owner) and lane >= 0,
		"The added class slot leaves ordinary stock intact and can stock an exact pair completion from its hero's deck.")
	var gold: int = run.data.gold
	var price := run.shop_price(offer)
	check(run.shop_buy(offer) and run.load_save(run.save_path) and run.data.gold == gold - price \
		and run.shop_deck_offer_id() == offer and run.shop_stock() == stock \
		and run.shop_class_offer_owner(offer) == owner and run.shop_tile_purchased(offer) and not run.shop_buy(offer),
		"A bought class offer keeps its label, owner, stock position, and purchased state after reload.")
	if not (run.leave_node() and run.choose_node("10-0") and run.finish_combat(true, [100, 100]) \
		and _finish_rewards(run, "skip") and run.choose_node("11-1")):
		check(false, "The seeded route must reach a second Act II shop.")
		return
	var next := run.shop_deck_offer_id()
	var next_owner := run.shop_class_offer_owner(next)
	check(not next.is_empty() and next_owner != owner and next == deck_tiles.get(next_owner),
		"Visiting another shop rotates the regular class slot to the other hero.")


func _check_first_paid_copy(run: FrontierRun) -> void:
	if not _start_acquisition_run(run, "easy"):
		check(false, "Start the first-reroll fixture.")
		return
	var lane := _acquisition_pair("reversal_plate")
	lane.append_array(_acquisition_pair("rampart_rush", 4))
	run.loadout.lanes[0] = lane
	if not run.finish_combat(true, 100):
		check(false, "A combat victory must open a rerollable reward.")
		return
	var initial := ["reversal_plate", "shoulder_check", "shield_tap"]
	run.data.offers = initial
	var tiers := initial.map(func(id: String): return ArenaSim.TILES[id].rarity)
	var gold: int = run.data.gold
	check(run.reward_reroll_price() == 5 and run.reward_reroll_prefers_copy() and run.reroll_reward(),
		"The first paid reroll can prioritize an eligible copy for five gold.")
	var first: Array = run.data.offers.duplicate()
	check(first.size() == 3 and first.all(func(id: String): return id not in initial and first.count(id) == 1) \
		and first.map(func(id: String): return ArenaSim.TILES[id].rarity) == tiers \
		and "rampart_rush" in first and run.reward_hint("rampart_rush") == "Third copy",
		"The reroll favors a different owned exact copy alongside fresh, distinct options at the same rarities.")
	check(run.load_save(run.save_path) and run.data.gold == gold - 5 and run.data.offers == first \
		and run.reward_reroll_price() == 10 and not run.reward_reroll_prefers_copy(),
		"The first reroll and doubled next cost survive reload.")
	check(run.reroll_reward() and run.data.gold == gold - 15 and run.reward_reroll_price() == 20 \
		and run.data.offers.all(func(id: String): return id not in first),
		"A later reroll continues to refresh the draft and double the cost.")
	run.abandon_run()

	if not _start_acquisition_run(run, "easy"):
		check(false, "Start the retained-copy reroll fixture.")
		return
	lane = _acquisition_pair("guard") + _acquisition_pair("riposte", 4)
	run.loadout.lanes[0] = lane
	var locked_pool := run._forge_copy_pool("warden", run._reward_inventory(0))
	check("guard" in locked_pool and "riposte" not in locked_pool,
		"Common copies are eligible for merging before Artifice, while higher locked tiers are ineligible.")
	if not run.finish_combat(true, 100):
		check(false, "The retained-copy fixture must reach a combat draft.")
		return
	run.data.offers = ["bash", "guard", "shield_tap"]
	check(run.reroll_reward() and run.data.offers[1] == "guard" and run.reward_hint("guard") == "Third copy" \
		and "bash" not in run.data.offers and "shield_tap" not in run.data.offers,
		"The first reroll can keep an existing useful Common in its slot while refreshing the other two.")


func _acquisition_pair(id: String, start := 0) -> Array:
	var tile: Dictionary = ArenaSim.TILES[id]
	return [{"id": id, "start": start, "target": tile.targets[0]},
		{"id": id, "start": start + tile.width, "target": tile.targets[0]}]


func _check_navigation(path: String) -> void:
	var run := FrontierRun.new()
	check(run.load_save(path) and run.abandon_run() and run.buy_meta("navigation"), "Navigation can be bought between runs.")
	var fresh := FrontierRun.new()
	var labels := {}
	for seed_value in range(1, 33):
		var normal := fresh._make_map(seed_value, "hard", "brass")
		var charts := run._make_map(seed_value, "hard", "brass")
		check(charts == run._make_map(seed_value, "hard", "brass"), "Navigation variations are deterministic.")
		var seen: Array[String] = []
		for row in range(charts.size()):
			for column in range(charts[row].size()):
				var node: Dictionary = charts[row][column]
				if node.label not in FrontierRun.NAVIGATION_EVENTS:
					check(node == normal[row][column], "Navigation preserves unrelated nodes and connectivity.")
					continue
				check(node.type == "event" and node.next == normal[row][column].next and node.label not in seen,
					"Navigation mystery nodes never repeat or alter connections.")
				seen.append(node.label)
				labels[node.label] = true
		check(not seen.is_empty(), "A Charted expedition finds at least one new mystery event.")
	check(labels.has_all(FrontierRun.NAVIGATION_EVENTS), "All Navigation events appear across seeds.")
	check(run.start_run(18) and run.choose_hero(run.data.offers[0]) and run.choose_relic("pocket_bell")
		and run.choose_starter(run.data.offers[0]), "Open a test expedition with Navigation.")
	var restored := FrontierRun.new()
	check(restored.load_save(path) and restored.data.layers == run.data.layers, "Saved Navigation nodes survive a reload.")
	run.data.node = run._node("event", "Broker's Table", 1, 0)
	run.data.phase = "event"
	run.data.gold = 9
	check(not run.event_choice(1) and run.event_choice(0) and run.data.gold == 13,
		"An unaffordable wager leaves gold untouched and the safe choice available.")
	run.data.node = run._node("event", "Salvage Permit", 2, 0)
	run.data.phase = "event"
	run.data.gold = 30
	check(run.event_choice(1) and run.data.relics.size() == 2 and run.data.relics[0] != run.data.relics[1]
		and run.data.gold == 6, "The permit charges gold and grants an unowned relic.")
	run.data.node = run._node("event", "Bounty Board", 3, 0)
	run.data.phase = "event"
	var marks: int = run.profile.marks
	check(run.event_choice(1) and run.encounter().encounter == "elite" and run.finish_combat(true, 83)
		and run.data.gold == 26 and run.profile.marks == marks + 2 and run.data.offers.size() == 3,
		"Taking a bounty starts an Elite fight and awards Elite loot when won.")


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
			"reward":
				var draft: Array = run.elite_relic_offers()
				if not draft.is_empty():
					check(run.choose_elite_relic(draft[0].id), "Choose the elite relic before traveling on.")
				_finish_rewards(run, "skip")
			"shop": run.leave_node()
			"event": run.event_choice(0)
			"rest": run.rest("heal")
			_:
				check(false, "Unexpected phase while traveling to a boss: " + str(run.data.phase))
				return


func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
