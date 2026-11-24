extends SceneTree

const FrontierRun = preload("res://scripts/frontier_run.gd")
const ArenaSim = preload("res://scripts/arena_sim.gd")
const ArsenalTiles = preload("res://scripts/arsenal_tiles.gd")
const ClassDecks = preload("res://scripts/class_decks.gd")
const ClassRelics = preload("res://scripts/class_relics.gd")
const TilePacking = preload("res://scripts/tile_packing.gd")
var failures: Array[String] = []


func _initialize() -> void:
	var run := FrontierRun.new()
	var brass_act_two_bosses := {}
	var brass_act_three_bosses := {}
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
		var brass_medium := run._make_map(seed_value, "medium")
		var brass_hard := run._make_map(seed_value, "hard")
		var brass_act_two: Dictionary = brass_medium.back()[0]
		brass_act_two_bosses[brass_act_two.boss_id] = true
		check(brass_act_two.boss_id in FrontierRun.BRASS_ACT_TWO_BOSSES
			and brass_act_two.label == FrontierRun.BOSS_LABELS[brass_act_two.boss_id]
			and brass_medium == run._make_map(seed_value, "medium"),
			"Brass Act II must use a valid, deterministic boss and matching name.")
		check(brass_hard.slice(0, 14) == _with_gate_link(brass_medium, brass_hard[14][0].id),
			"Medium and Hard must pick the same Act II boss for a seed.")
		_check_map(brass_medium, 2, brass_act_two.boss_id)
		var brass_final: Dictionary = brass_hard.back()[0]
		brass_act_three_bosses[brass_final.boss_id] = true
		check(brass_final.boss_id in FrontierRun.BRASS_ACT_THREE_BOSSES
			and brass_final.label == FrontierRun.BOSS_LABELS[brass_final.boss_id]
			and brass_hard == run._make_map(seed_value, "hard"),
			"Brass Hard must select a deterministic Act III finale with its matching name.")
		_check_map(brass_hard, 3, brass_final.boss_id)
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
	check(brass_act_two_bosses.size() == FrontierRun.BRASS_ACT_TWO_BOSSES.size(),
		"Brass Act II must rotate through both bosses across new expeditions.")
	check(brass_act_three_bosses.size() == FrontierRun.BRASS_ACT_THREE_BOSSES.size(),
		"Brass Hard must rotate through both Act III finales across new expeditions.")

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
	_check_repairmaster_campaign()
	_check_siege_vanguard_campaign()
	_check_first_party_elite_class_relic()
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
	_check_rotating_lead_starters()
	_check_opening_specialty_rewards()
	_check_hard_followup_rewards()
	_check_hard_intermediate_boss_drafts()
	_check_later_act_specialties()
	_check_acquisition_drafts()
	_check_mobility_acquisition()
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
	check(run.choose_starter(ClassDecks.starter(hero)), "Equip the Medium lead before reaching the bosses.")
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


func _check_repairmaster_campaign() -> void:
	for difficulty: String in ["medium", "hard"]:
		var path := "user://frontier-repairmaster-%s-%d.json" % [difficulty, Time.get_ticks_usec()]
		var run := FrontierRun.new()
		run.load_save(path)
		run.profile.medium_unlocked = true
		run.profile.hard_unlocked = difficulty == "hard"
		var recruited := _equip_gate_starter(run, 9, difficulty, "warden") and _recruit_at_next_boss(run)
		check(recruited, "Recruit normally before the Repairmaster route on %s." % difficulty)
		if recruited:
			_reach_boss(run)
			var encounter := run.encounter()
			check(encounter.get("boss_id") == "brass_repairmaster" and encounter.get("segment") == 2
				and encounter.heroes.size() == 2 and run.data.node.label == "The Repairmaster"
				and run.is_final_boss() == (difficulty == "medium"), "Enter the seeded Repairmaster fight with two heroes.")
			var restored := FrontierRun.new()
			check(restored.load_save(path) and restored.encounter() == encounter,
				"Resume the same Repairmaster fight and party from disk.")
			var marks: int = restored.profile.marks
			var won := restored.finish_combat(true, [70, 65])
			check(won and restored.reward_count() == 2, "Both heroes earn a Repairmaster reward.")
			if won:
				for lane in range(2):
					check(restored.reward_lane() == lane and restored.data.offers.size() == 3
						and restored.data.offers.all(func(id: String): return ArenaSim.TILES[id].rarity == "legendary")
						and restored.reward("skip"), "Each Repairmaster reward offers three Legendary tiles.")
				if difficulty == "medium":
					check(restored.data.phase == "result" and restored.can_start("hard")
						and restored.can_start("easy", "glass") and restored.profile.marks == marks + 34,
						"A Repairmaster victory on Medium completes the expedition and pays the normal unlocks.")
					restored.profile.erase("hard_unlocked")
					restored.profile.erase("glass_easy_unlocked")
					check(restored.save() and restored.load_save(path) and restored.can_start("hard")
						and restored.can_start("easy", "glass") and restored.profile.marks == marks + 34,
						"Recover missing Medium unlocks from a completed Repairmaster save without repaying Marks.")
				else:
					check(restored.data.phase == "recruit" and restored.profile.marks == marks + 4,
						"Hard offers a third recruit after the Repairmaster payout.")
					if restored.data.phase == "recruit":
						var third: String = restored.data.offers[0]
						check(restored.choose_recruit(third) and restored.choose_recruit_starter(ClassDecks.starter(third))
							and restored.data.heroes.size() == 3 and restored.available_nodes()[0].row == 14,
							"The Repairmaster route opens the third act with all three heroes.")
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func _check_siege_vanguard_campaign() -> void:
	var path := "user://frontier-siege-vanguard-%d.json" % Time.get_ticks_usec()
	var run := FrontierRun.new()
	run.load_save(path)
	run.profile.medium_unlocked = true
	run.profile.hard_unlocked = true
	var recruited := _equip_gate_starter(run, 3, "hard", "warden") \
		and _recruit_at_next_boss(run) and _recruit_at_next_boss(run)
	check(recruited, "Recruit both heroes through the seeded Siege Vanguard route.")
	if recruited:
		var finale: Dictionary = run.data.layers.back()[0]
		check(finale.boss_id == "brass_vanguard_cannon", "Seed 3 selects the Siege Vanguard in Brass Hard.")
		var restored := FrontierRun.new()
		check(restored.load_save(path), "Reload the Act III map before traveling to the boss.")
		# Existing runs keep their authored finale when their map is restored.
		var legacy_finale: Dictionary = restored.data.layers.back()[0]
		legacy_finale.boss_id = "iron_regent"
		legacy_finale.label = FrontierRun.BOSS_LABELS.iron_regent
		check(restored.save() and restored.load_save(path) and restored.data.layers.back()[0].boss_id == "iron_regent",
			"An in-progress Brass Hard map retains its original Iron Regent after upgrading.")
		_reach_boss(run)
		var encounter := run.encounter()
		check(run.is_final_boss() and encounter.boss_id == "brass_vanguard_cannon" and encounter.heroes.size() == 3,
			"The Siege Vanguard opens through standard travel with three heroes as the final boss.")
		check(restored.load_save(path) and restored.encounter() == encounter and restored.loadout.lanes == run.loadout.lanes,
			"Resuming the Siege Vanguard preserves the encounter and all three timelines.")
		var marks: int = restored.profile.marks
		check(restored.finish_combat(true, [70, 65, 60]) and restored.reward_count() == 3,
			"Defeating the Siege Vanguard offers a final trophy to every hero.")
		for lane in range(3):
			check(restored.reward_lane() == lane and restored.data.offers.size() == 3
				and restored.data.offers.all(func(id: String): return ArenaSim.TILES[id].rarity == "legendary")
				and restored.reward("skip"), "Each final trophy draft has three Legendaries.")
		check(restored.data.phase == "result" and restored.data.result == "victory" and restored.profile.brass_hard_cleared
			and restored.profile.marks == marks + 54, "The alternate finale grants the Brass Hard clear once.")
		check(restored.load_save(path) and restored.profile.brass_hard_cleared and restored.profile.marks == marks + 54,
			"Resuming a completed Siege Vanguard run keeps its Hard clear payout.")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func _check_first_party_elite_class_relic() -> void:
	for hero: String in FrontierRun.HEROES:
		var id := ClassRelics.id_for(hero)
		check(ClassRelics.owner(id) == hero and FrontierRun.RELICS.has(id), "Every class has one named relic.")
	var path := "user://frontier-class-relic-%d.json" % Time.get_ticks_usec()
	var run := FrontierRun.new()
	run.load_save(path)
	run.profile.medium_unlocked = true
	_exercise_first_party_elite_class_relic(run)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func _exercise_first_party_elite_class_relic(run: FrontierRun) -> void:
	var started := _equip_gate_starter(run, 42, "medium", "warden") and run.finish_combat(true, 90) and run.reward("skip")
	check(started, "Join the route with a new lead before its first elite.")
	if not started:
		return
	var first_boss_row := FrontierRun.NODES_PER_SEGMENT - 1
	run.data.node = run.data.layers[first_boss_row - 1][0]
	var recruited := run.choose_node(run.data.layers[first_boss_row][0].id) and _recruit_at_next_boss(run)
	check(recruited and not run.data.elite_relic_drafted, "Enter Act II with a recruit and no previous elite reward.")
	if not recruited:
		return
	var elite_row := FrontierRun.NODES_PER_SEGMENT + 3
	var targets: Array = run.data.layers[elite_row].filter(func(node: Dictionary): return node.type == "elite")
	check(targets.size() == 1, "Find the Act II elite in the seeded map.")
	if targets.is_empty():
		return
	var elite: Dictionary = targets.front()
	for approach: Dictionary in run.data.layers[elite_row - 1]:
		if elite.id in approach.next:
			run.data.node = approach
			break
	var drafted: bool = run.choose_node(elite.id) and run.finish_combat(true, [80, 75]) and run.party_elite_relic_draft()
	var offers := run.elite_relic_offers().duplicate(true)
	check(drafted and offers.size() == 3, "The first Act II elite presents a party draft even without an Act I elite.")
	if not drafted or offers.size() != 3:
		return
	var class_offer: Dictionary = offers.back()
	var owner := ClassRelics.owner(class_offer.id)
	var signature := ClassDecks.signature(run.data.heroes[1].id)
	check(not owner.is_empty() and class_offer.owner == owner and offers.slice(0, 2).all(func(offer: Dictionary):
		return ClassRelics.owner(offer.id).is_empty()) and run.data.reward_remaining[0].offers.has(signature)
		and ClassDecks.signature(run.data.hero) in run.data.offers, "Preserve both signature tiles behind two shared relics and one class relic.")
	var saved_path := run.save_path
	check(run.load_save(saved_path) and run.elite_relic_offers() == offers, "Resume the exact class relic and assigned hero.")
	var chosen := run.choose_elite_relic(class_offer.id) and run.load_save(saved_path) and _finish_rewards(run, "skip")
	check(chosen and class_offer.id in run.data.relics and run.data.party_elite_relic_drafted,
		"Acquire one class relic and advance through both tile drafts.")
	if not chosen:
		return
	var next_battles := run.available_nodes().filter(func(node: Dictionary): return node.type == "battle")
	var advanced := not next_battles.is_empty() and run.choose_node(next_battles.front().id)
	check(advanced and run.encounter().heroes.all(func(hero: Dictionary):
		return hero.get("class_relic", "") == (class_offer.id if hero.id == owner else "")),
		"Pass the saved class relic into combat on its owner only.")


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
	check(run.choose_starter(ClassDecks.starter(run.data.hero)), "Equip the Hard lead before reaching the bosses.")
	for boss_id in FrontierRun.BRASS_BOSSES:
		_reach_boss(run)
		var encounter := run.encounter()
		check(encounter.boss_id == boss_id and encounter.heroes.size() == encounter.segment, "Hard must use the correct boss and party size for each leg.")
		var remaining := [51, 66, 82].slice(0, encounter.heroes.size())
		if encounter.segment == 2:
			remaining[0] = 0
		marks = run.profile.marks
		check(run.finish_combat(true, remaining), "Complete the Hard boss fight.")
		if run.is_final_boss():
			_finish_rewards(run, "skip")
		else:
			_check_pending_intermediate_boss_drafts(run, path)
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


func _check_pending_intermediate_boss_drafts(run: FrontierRun, path: String) -> void:
	var restored := FrontierRun.new()
	var offers: Array = run.data.offers.duplicate()
	var remaining: Array = run.data.reward_remaining.duplicate(true)
	var party: Array = run.data.heroes.duplicate(true)
	check(run.reward_count() == party.size() and restored.load_save(path) and restored.reward_lane() == 0 \
		and restored.data.heroes == party and restored.data.offers == offers and restored.data.reward_remaining == remaining,
		"Both intermediate bosses save the visible and queued Legendary offers in order.")
	if party.size() == 2 and restored.data.get("phase") == "reward":
		_check_intermediate_boss_rerolls(restored, path, offers, remaining)
		offers = restored.data.offers.duplicate()
		check(run.load_save(path), "Resume the rerolled first draft with the second still queued.")
	for lane in range(party.size()):
		var ordered_offers: Array = offers if lane == 0 else remaining[lane - 1].offers
		var signatures := _legendary_signature_offers(ordered_offers, party[lane].id)
		check(run.reward_lane() == lane and run.data.offers == ordered_offers and signatures.size() == 1,
			"Every current hero, including a fallen lead, receives their own Legendary signature draft.")
		if signatures.is_empty() or not run.reward(signatures[0]):
			check(false, "Claim the currently offered signature and advance the pending Hard boss draft.")
			return
		check(restored.load_save(path) and restored.data.phase == run.data.phase and restored.reward_lane() == run.reward_lane() \
			and restored.data.offers == run.data.offers, "A claimed draft does not regenerate the next cards on reload.")


func _check_intermediate_boss_rerolls(run: FrontierRun, path: String, original: Array, remaining: Array) -> void:
	var hero: String = run.data.heroes[0].id
	var gold: int = run.data.gold
	var before: Array = original
	for price in [5, 10]:
		if not (run.reward_reroll_price() == price and run.reroll_reward()):
			check(false, "Pay the correct price to reroll an intermediate boss draft.")
			return
		gold -= price
		var after: Array = run.data.offers.duplicate()
		var reroll_roots := {}
		for id: String in after:
			reroll_roots[ArenaSim.TILES[id].get("family", id)] = true
		check(after.size() == 3 and after[0] != after[1] and after[0] != before[0] and after[1] != before[1] \
			and after.slice(0, 2).any(func(id: String): return id not in before) \
			and after[2] != before[2] and _legendary_signature_offers(after, hero) == [after[2]] \
			and reroll_roots.size() == 3 \
			and after.all(func(id: String): return ArenaSim.TILES[id].rarity == "legendary"),
			"A paid reroll refreshes three different roots and trades the signature for its sibling.")
		check(run.data.gold == gold and run.data.reward_remaining == remaining and run.load_save(path) \
			and run.reward_reroll_price() == price * 2 and run.data.offers == after and run.data.reward_remaining == remaining,
			"Reroll cost, visible order and the unopened hero's queued draft survive reload.")
		before = after


func _check_hard_intermediate_boss_drafts() -> void:
	var run := FrontierRun.new()
	var classes: Array = FrontierRun.HEROES.keys()
	for index in range(classes.size()):
		var hero: String = classes[index]
		var signature := ClassDecks.signature(hero)
		var legendaries: Array = TilePacking.forge_tiers(signature)[4]
		check(legendaries.size() == 2 and legendaries[0] != legendaries[1],
			"%s has two distinct Legendary signature variants." % hero)
		for act in [1, 2]:
			var seen_signatures := {}
			var seen_other_offers := {}
			for seed in range(1, 17):
				var heroes: Array = [hero] if act == 1 else [classes[(index + 1) % classes.size()], hero]
				_set_boss_draft_context(run, "brass", "hard", seed, act, heroes)
				var lane: int = heroes.size() - 1
				if seed % 2 == 0:
					run.loadout.lanes[lane].append({"id": signature, "start": 0})
				var draft := run._combat_reward_draft("boss", lane)
				var offers: Array = draft.offers
				var signatures := _legendary_signature_offers(offers, hero)
				var other := offers.filter(func(id: String): return id not in legendaries)
				var ordinary_pool := run._class_reward_pool(hero, 4, run._reward_inventory(lane))
				ordinary_pool = ordinary_pool.filter(func(id: String): return id not in legendaries)
				var other_roots := {}
				for id: String in other:
					other_roots[ArenaSim.TILES[id].get("family", id)] = true
				check(offers.size() == 3 and signatures == [offers[2]] and other.size() == 2 and other[0] != other[1] \
					and other.all(func(id: String): return ArenaSim.TILES[id].rarity == "legendary") \
					and other_roots.size() == 2 \
					and other[0] == run._sample(ordinary_pool, 1, seed, run._node_salt(81 + lane * 1069))[0] \
					and draft == run._combat_reward_draft("boss", lane),
					"%s Hard Act %d seed %d reserves one Legendary signature beside two distinct ordinary roots." % [hero, act, seed])
				for id: String in signatures:
					seen_signatures[id] = true
				seen_other_offers[other] = true
			check(seen_signatures.has_all(legendaries) and seen_other_offers.size() > 1,
				"%s Hard Act %d must rotate both Legendary branches and the ordinary pair across seeds." % [hero, act])

	for region: String in ["brass", "glass", "crown", "moonwreck"]:
		for difficulty: String in ["easy", "medium", "hard"]:
			var acts := ["easy", "medium", "hard"].find(difficulty) + 1
			for act in range(1, acts + 1):
				if region == "brass" and difficulty == "hard" and act < acts:
					continue
				for seed in [3, 9, 42]:
					_set_boss_draft_context(run, region, difficulty, seed, act, classes.slice(0, act))
					for lane in range(act):
						var pool := run._class_reward_pool(classes[lane], 4, run._reward_inventory(lane))
						var ordinary := run._sample(pool, 1, seed, run._node_salt(81 + lane * 1069))
						var offers: Array = run._combat_reward_draft("boss", lane).offers
						var eligible_roots := {}
						var offered_roots := {}
						for id: String in pool:
							eligible_roots[ArenaSim.TILES[id].get("family", id)] = true
						for id: String in offers:
							offered_roots[ArenaSim.TILES[id].get("family", id)] = true
						check(offers.size() == 3 and offers[0] == ordinary[0] \
							and offers.all(func(id: String): return id in pool and ArenaSim.TILES[id].rarity == "legendary") \
							and offered_roots.size() == mini(3, eligible_roots.size()) \
							and offers == run._combat_reward_draft("boss", lane).offers,
							"%s %s Act %d should keep its seeded first pick and offer distinct eligible Legendary roots." % [region, difficulty, act])


func _set_boss_draft_context(run: FrontierRun, region: String, difficulty: String, seed: int, act: int, heroes: Array) -> void:
	var layers := run._make_map(seed, difficulty, region)
	run.data = {"location": region, "difficulty": difficulty, "seed": seed, "segment": act, "layers": layers,
		"node": layers[act * FrontierRun.NODES_PER_SEGMENT - 1][0],
		"heroes": heroes.map(func(id: String): return {"id": id})}
	run.loadout = {"lanes": heroes.map(func(_id: String): return []), "storage": [[], [], []]}


func _legendary_signature_offers(offers: Array, hero: String) -> Array:
	var variants: Array = TilePacking.forge_tiers(ClassDecks.signature(hero))[4]
	return offers.filter(func(id: String): return id in variants and ArenaSim.TILES[id].rarity == "legendary")


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


func _check_rotating_lead_starters() -> void:
	var path := "user://frontier-alternate-starter-test-%d.json" % Time.get_ticks_usec()
	var run := FrontierRun.new()
	run.load_save(path)
	run.profile.medium_unlocked = true
	run.profile.hard_unlocked = true
	run.profile.glass_medium_unlocked = true
	run.profile.marks = 999
	for hero: String in FrontierRun.HEROES:
		if hero not in run.available_classes():
			check(run.buy_class(hero), "Unlock %s for the lead starter checks." % hero)
	for hero: String in FrontierRun.HEROES:
		var standard := ClassDecks.starter(hero)
		var alternates := ClassDecks.alternate_starters(hero)
		check(alternates.size() == 2 and alternates.all(func(id: String):
			return id in ClassDecks.specialties(hero) and alternates.count(id) == 1 \
				and id not in [standard, "shot", "bash"] and ArenaSim.TILES[id].rarity == "common" \
				and ArenaSim.TILES[id].damage > 0), "%s has two distinct damaging Common starters in its specialties." % hero)
		for difficulty: String in ["medium", "hard"]:
			var seen: Array[String] = []
			var first_draft: Array = []
			for seed in [1, 2, 3, 4, 5, 6, 7, 8, 1]:
				var context := "%s %s seed %d" % [hero, difficulty, seed]
				if not _open_starter_draft(run, seed, difficulty, hero):
					check(false, "%s must start the standard lead draft." % context)
					continue
				var offers: Array = run.data.offers.duplicate()
				var rotating := offers.filter(func(id: String): return id in alternates)
				check(offers.size() == 3 and rotating.size() == 1 and standard in offers and "shot" in offers,
					"%s must offer one alternate beside the class starter and Shot." % context)
				if rotating.size() != 1:
					continue
				if seed == 1:
					check(first_draft.is_empty() or offers == first_draft, "%s must repeat the exact seed order." % context)
					first_draft = offers
					check(run.load_save(path) and run.data.phase == "starter" and run.data.offers == offers,
						"%s must restore the pending three starter choices." % context)
				var alternate: String = rotating[0]
				if alternate not in seen:
					seen.append(alternate)
					_check_alternate_starter_battle(run, alternate, context)
			check(alternates.all(func(id: String): return id in seen),
				"Both alternate starters should appear for %s on %s across fixed seeds." % [hero, difficulty])
	_check_alternate_opening_reward(run, path)
	_check_starter_draft_boundaries(run, path)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func _check_alternate_starter_battle(run: FrontierRun, id: String, context: String) -> void:
	var deployed: bool = run.choose_starter(id) and run.loadout.lanes[0] == [{"id": id, "start": 0,
		"target": ArenaSim.TILES[id].targets[0]}] and run.encounter().kind == "opening"
	check(deployed, "%s must deploy %s alone for the Gate Trial." % [context, id])
	if deployed:
		var sim := ArenaSim.new()
		sim.start(run.loadout.lanes, "solo", run.encounter())
		for tick in range(4500):
			if not sim.outcome.is_empty():
				break
			sim.step()
		check(sim.outcome == "victory", "%s must win the Gate Trial with %s." % [context, id])


func _check_alternate_opening_reward(run: FrontierRun, path: String) -> void:
	var alternates := ClassDecks.alternate_starters("duelist")
	for copies in [1, 2]:
		var drafted := _open_starter_draft(run, 42, "hard", "duelist")
		var candidates: Array = run.data.get("offers", []).filter(func(id: String): return id in alternates)
		var equipped := drafted and candidates.size() == 1 and run.choose_starter(candidates[0])
		check(equipped, "Equip the alternate attack for the Gate Trial.")
		if not equipped:
			return
		var alternate: String = candidates[0]
		if copies == 2:
			run.loadout.storage[0].append(run.loadout.lanes[0][0].duplicate())
		var rewarded: bool = run.save() and run.load_save(path) and run.finish_combat(true, 90) and run.data.phase == "reward"
		check(rewarded, "Resolve the opening reward from a saved alternate starter fight.")
		if not rewarded:
			return
		if copies == 1:
			check(run.data.offers.size() == 3 and alternate not in run.data.offers,
				"Favor new tiles over a routine copy after taking an alternate starter.")
		else:
			check(alternate in run.data.offers and run.reward_hint(alternate) == "Third copy",
				"Keep a real third-copy offer after taking an alternate starter.")


func _check_starter_draft_boundaries(run: FrontierRun, path: String) -> void:
	var standard := ClassDecks.starter("warden")
	var unchanged := ["bash", "shot", standard]
	for relic: String in ["towline_knot", "bridgeplate"]:
		var found := false
		for seed in range(1, 17):
			if _open_starter_draft(run, seed, "medium", "warden", "brass", relic):
				var shared: String = FrontierRun.RELIC_STARTERS[relic]
				check(run.data.offers.size() == 3 and standard in run.data.offers and shared in run.data.offers \
					and run.data.offers.any(func(id: String): return id in ClassDecks.alternate_starters("warden")),
					"Keep the starter linked to %s beside the standard and alternate cards." % relic)
				found = true
				break
		check(found, "Reach a seeded %s starter draft." % relic)
	check(_open_starter_draft(run, 42, "medium", "warden", "glass") and run.data.offers.size() == 3 \
		and unchanged.all(func(id: String): return id in run.data.offers), "The Glass lead keeps the original starter choices.")
	if _open_starter_draft(run, 42, "medium", "warden"):
		run.data.offers = unchanged.duplicate()
		check(run.save() and run.load_save(path) and run.data.offers == unchanged and run.choose_starter("bash"),
			"An existing Medium starter save still resumes and accepts its original Bash.")
		_reach_boss(run)
		var reached := run.finish_combat(true, 85) and _finish_rewards(run, "skip") and run.choose_boss_relic("skip")
		check(reached, "Reach the Brass recruit draft using the original saved starter.")
		if reached:
			var recruit: String = run.data.offers[0]
			var previous_choices := ["bash", "shot", ClassDecks.starter(recruit)]
			check(run.choose_recruit(recruit) and run.data.offers.size() == 3 \
				and previous_choices.all(func(id: String): return id in run.data.offers) \
				and run.recruit_loadout_offers().size() == 2, "Brass recruits keep their original starter choices and kits.")


func _check_opening_specialty_rewards() -> void:
	var path := "user://frontier-gate-specialty-test-%d.json" % Time.get_ticks_usec()
	var run := FrontierRun.new()
	run.load_save(path)
	run.profile.medium_unlocked = true
	run.profile.hard_unlocked = true
	run.profile.glass_medium_unlocked = true
	run.profile.glass_hard_unlocked = true
	run.profile.marks = 999
	for hero_id: String in FrontierRun.HEROES:
		if hero_id not in run.available_classes():
			check(run.buy_class(hero_id), "%s should be unlockable for the Gate Trial test." % hero_id)

	for difficulty: String in ["medium", "hard"]:
		for hero_id: String in run.available_classes():
			var specialty_mixes := {}
			var directions: Array = FrontierRun.EARLY_BUILD_DIRECTIONS.get(hero_id, []) if difficulty == "medium" else []
			for seed in range(1, 9):
				if not _equip_gate_starter(run, seed, difficulty, hero_id):
					check(false, "%s must reach the %s Gate Trial through the opening draft." % [hero_id, difficulty])
					continue
				var context := "%s %s seed %d" % [hero_id, difficulty, seed]
				check(run.encounter().kind == "opening" and run.data.node.label == "Gate Trial",
					"%s must test the actual opening encounter." % context)
				if not run.finish_combat(true, 100):
					check(false, "%s must have an opening victory reward." % context)
					continue
				var offers: Array = run.data.offers.duplicate()
				var specialties := _offered_gate_specialties(offers, hero_id)
				check(offers.size() == 3 and offers.all(func(id: String): return offers.count(id) == 1) \
					and not specialties.is_empty(), "%s must offer three distinct choices with a class specialty." % context)
				var families := specialties.map(_reward_tile_family)
				families.sort()
				specialty_mixes[str(families)] = true
				check(directions.all(func(direction: Dictionary): return direction.opening in offers),
					"%s must retain both authored opening directions when applicable." % context)
				if seed == 1:
					check(run.load_save(path) and run.data.phase == "reward" and run.data.offers == offers,
						"%s must reload the exact Gate Trial reward." % context)
			check(specialty_mixes.size() > 1,
				"%s must see different class specialty choices across %s Gate Trial seeds." % [hero_id, difficulty])

	for difficulty: String in ["medium", "hard"]:
		if _equip_gate_starter(run, 1, difficulty, "warden"):
			run.loadout.lanes[0] = _acquisition_pair(ClassDecks.starter("warden"))
			check(run.finish_combat(true, 100) and run.reward_hint("shield_tap") == "Third copy" \
				and not _offered_gate_specialties(run.data.offers, "warden").is_empty(),
				"The %s Gate Trial keeps a third-copy opportunity beside a Warden specialty." % difficulty)
		else:
			check(false, "Equip Warden for the %s third-copy Gate Trial fixture." % difficulty)

	var saw_non_specialty_draft := false
	for seed in range(1, 9):
		if _equip_gate_starter(run, seed, "medium", "warden", "glass") and run.finish_combat(true, 100):
			saw_non_specialty_draft = saw_non_specialty_draft or _offered_gate_specialties(run.data.offers, "warden").is_empty()
	check(saw_non_specialty_draft, "The Brass opening guarantee should not apply to Glass Foundry.")
	_check_gate_specialty_rarities(run, path)

	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func _equip_gate_starter(run: FrontierRun, seed: int, difficulty: String, hero_id: String, region := "brass",
		relic := "pocket_bell") -> bool:
	return _open_starter_draft(run, seed, difficulty, hero_id, region, relic) \
		and run.choose_starter(ClassDecks.starter(hero_id))


func _open_starter_draft(run: FrontierRun, seed: int, difficulty: String, hero_id: String, region := "brass",
		relic := "pocket_bell") -> bool:
	if not run.data.is_empty() and not run.abandon_run():
		return false
	return run.start_run(seed, difficulty, region) and run.choose_preferred_hero(hero_id) and run.choose_relic(relic)


func _offered_gate_specialties(offers: Array, hero_id: String) -> Array:
	var specialties := ClassDecks.specialties(hero_id)
	return offers.filter(func(id: String): return _reward_tile_family(id) in specialties)


func _reward_tile_family(id: String) -> String:
	var tile: Dictionary = ArenaSim.TILES[id]
	return tile.get("base_tile", tile.get("family", id))


func _check_gate_specialty_rarities(run: FrontierRun, path: String) -> void:
	# The same Duelist setup in Glass has the same normal reward roll without the Brass specialty.
	var fixtures := [
		{"seed": 4, "difficulty": "medium", "rarity": "common", "relic": "pocket_bell"},
		{"seed": 267, "difficulty": "hard", "rarity": "uncommon", "relic": "pocket_bell"},
		{"seed": 798, "difficulty": "hard", "rarity": "rare", "relic": "pocket_bell"},
		{"seed": 4, "difficulty": "medium", "rarity": "rare", "relic": "brass_metronome"},
	]
	for fixture: Dictionary in fixtures:
		var before := _gate_pair_draft(run, fixture, "glass")
		var after := _gate_pair_draft(run, fixture, "brass")
		var context := "%s seed %d with %s" % [fixture.difficulty, fixture.seed, fixture.relic]
		check(before.size() == 3 and _offered_gate_specialties(before, "duelist").is_empty() and after.size() == 3,
			"%s must compare a normal draft with its Brass specialty version." % context)
		var removed := before.filter(func(id: String): return id not in after)
		var added := after.filter(func(id: String): return id not in before)
		check(removed.size() == 1 and added.size() == 1 and ArenaSim.TILES[removed[0]].rarity == fixture.rarity \
			and ArenaSim.TILES[added[0]].rarity == fixture.rarity and added == _offered_gate_specialties(after, "duelist"),
			"%s must replace the least-rare eligible rolled card with a specialty of its original rarity." % context)
		check("jab" in after and run.reward_hint("jab") == "Third copy",
			"%s must keep the existing third-copy reward." % context)
		if fixture.relic == "brass_metronome":
			check("slam" in after and run.reward_hint("slam") == "Leave one beat empty before it",
				"The relic's Common bridge stays even when the only available specialty replacement is Rare.")
		check(run.load_save(path) and run.data.offers == after, "%s must preserve the rarity-protected reward on resume." % context)


func _gate_pair_draft(run: FrontierRun, fixture: Dictionary, region: String) -> Array:
	if not _equip_gate_starter(run, fixture.seed, fixture.difficulty, "duelist", region, fixture.relic):
		return []
	run.loadout.lanes[0] = _acquisition_pair("jab")
	return run.data.offers.duplicate() if run.finish_combat(true, 100) else []


func _check_hard_followup_rewards() -> void:
	var path := "user://hard-followup-test-%d.json" % Time.get_ticks_usec()
	var run := FrontierRun.new()
	run.load_save(path)
	run.profile.medium_unlocked = true
	run.profile.hard_unlocked = true
	run.profile.glass_hard_unlocked = true
	_check_hard_followup_route(run, false)
	_check_hard_followup_route(run, true)
	_check_hard_followup_single_copy(run)
	_check_hard_followup_epic_copy(run)
	_check_hard_followup_scope(run)
	for base: String in [path, path + ".control", path + ".reroll"]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(base + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(base + suffix))


func _check_hard_followup_route(run: FrontierRun, protected_first: bool) -> void:
	if not (_equip_gate_starter(run, 7, "hard", "duelist") and run.finish_combat(true, 100) and run.reward("skip")):
		check(false, "Reach the matched Hard route through the Gate Trial.")
		return
	run.loadout.lanes[0] = _acquisition_pair("jab")
	var signature := ClassDecks.signature("duelist")
	if protected_first:
		run.loadout.storage[0] = [{"id": signature, "start": 0, "target": "nearest"}]
		run.data.relics.append("siege_fuse")
	var route := ["1-2", "3-1", "4-0"]
	for index in range(route.size()):
		if index == 1 and not (run.choose_node("2-2") and run.data.phase == "shop" and run.leave_node()):
			check(false, "A real shop visit separates the two ordinary battle wins.")
			return
		if not run.choose_node(route[index]):
			check(false, "Reach ordinary battle %d on the matched Hard route." % (index + 1))
			return
		var standard := _matched_followup_control(run)
		if not run.finish_combat(true, 100):
			check(false, "Win the ordinary Hard battle and open its reward.")
			return
		var offers: Array = run.data.offers.duplicate()
		var pick := "skip"
		if index == 0:
			check(run.reward_hint("jab") == "Third copy", "The early reward preserves the available third Jab.")
			_check_followup_combine(run)
			if protected_first:
				check(offers == standard and "slam" in offers and "Siege Fuse" in run.reward_hint("slam") \
					and offers.any(func(id: String): return _reward_tile_family(id) == signature and ArenaSim.TILES[id].rarity == "rare"),
					"A protected third copy, relic companion, and signature leave no room for a different offer.")
				run.loadout.storage[0] = []
				run.data.relics.erase("siege_fuse")
			else:
				pick = _check_followup_replacement(run, standard)
				_check_followup_round_trip(run)
		elif index == 1:
			_check_followup_replacement(run, standard)
		else:
			check(offers == standard, "The third ordinary win keeps its original reward even if the first had no open slot.")
		if pick != "skip":
			check(TilePacking.can_place(run.loadout.lanes[0], pick, 2, ArenaSim.BEATS), "Equip the first new choice for the second fight.")
			run.loadout.lanes[0].append({"id": pick, "start": 2, "target": ArenaSim.TILES[pick].targets[0]})
		if not run.reward(pick):
			check(false, "Resolve each early reward before traveling onward.")
			return


func _matched_followup_control(run: FrontierRun) -> Array:
	# Duelist has no separate Medium build directions, so this changes only the Hard rule.
	var control := FrontierRun.new()
	var path := run.save_path
	if not control.load_save(path):
		check(false, "Load the same lead, inventory, and encounter for the matched draft.")
		return []
	control.save_path = path + ".control"
	control.data.difficulty = "medium"
	return control.data.offers.duplicate() if control.finish_combat(true, 100) else []


func _check_followup_replacement(run: FrontierRun, standard: Array) -> String:
	var offers: Array = run.data.offers
	var added := offers.filter(func(id: String): return id not in standard)
	var removed := standard.filter(func(id: String): return id not in offers)
	var tier := func(id: String): return ArenaSim.TILES[id].rarity
	check(offers.size() == 3 and added.size() <= 1 and added.size() == removed.size() and offers.map(tier) == standard.map(tier),
		"The Hard follow-up changes at most one choice while keeping each card's rarity slot.")
	var held: Array = run.loadout.lanes[0] + run.loadout.storage[0] + run.loadout.storage[1] + run.loadout.storage[2]
	for id: String in (added if not added.is_empty() else offers):
		var family := _reward_tile_family(id)
		var traits := run._tile_reward_traits(id)
		if id in ClassDecks.common("duelist") and ArenaSim.TILES[id].damage > 0 and run.reward_hint(id).is_empty() \
				and held.all(func(item: Dictionary): return _reward_tile_family(item.id) != family) \
				and offers.filter(func(offer: String): return _reward_tile_family(offer) == family).size() == 1 \
				and run.loadout.lanes[0].all(func(item: Dictionary): return traits != run._tile_reward_traits(item.id)):
			return id
	check(false, "The draft has a fresh class choice with a different combat role and no instruction on its card.")
	return "skip"


func _check_followup_combine(run: FrontierRun) -> void:
	var copies := TilePacking.find_copies(run.loadout.lanes, run.loadout.storage, "jab", [0])
	var upgrade: String = TilePacking.next_options("jab")[0]
	var plan := TilePacking.combine_plan(run.loadout.lanes, run.loadout.storage, copies, 2, upgrade, [0])
	var inventory := run.loadout.duplicate(true)
	check("jab" in run.data.offers and copies.size() == 2 and not plan.is_empty() \
		and TilePacking.apply_combination(inventory.lanes, inventory.storage, plan.copies, plan.destination, upgrade, "nearest") \
		and inventory.lanes[0].size() == 1 and inventory.lanes[0][0].id == upgrade,
		"The protected card supplies a real third copy and its two owned inputs can combine immediately.")


func _check_followup_round_trip(run: FrontierRun) -> void:
	var path := run.save_path
	var offers: Array = run.data.offers.duplicate()
	var hints: Dictionary = run.data.reward_hints.duplicate()
	var visited: Array = run.data.visited.duplicate()
	check(run.load_save(path) and run.data.offers == offers and run.data.reward_hints == hints \
		and run.data.visited == visited and not run.finish_combat(true, 100), "Resume the exact draft without recording another win.")
	var rerolled := FrontierRun.new()
	if rerolled.load_save(path):
		rerolled.save_path = path + ".reroll"
		check(rerolled.reroll_reward() and rerolled.load_save(rerolled.save_path) and rerolled.data.visited == visited,
			"A paid reroll and subsequent reload do not count as another battle visit.")


func _check_hard_followup_single_copy(run: FrontierRun) -> void:
	if not (_equip_gate_starter(run, 7, "hard", "duelist") and run.finish_combat(true, 100) \
			and run.reward("skip") and run.choose_node("1-2")):
		check(false, "Reach the matched Hard reward with only one Jab owned.")
		return
	var standard := _matched_followup_control(run)
	if not run.finish_combat(true, 100):
		check(false, "Resolve the first ordinary fight with a one-tile inventory.")
		return
	var pick := _check_followup_replacement(run, standard)
	check("jab" in standard and "jab" not in run.data.offers and pick != "skip" \
		and run.data.offers[standard.find("jab")] == pick and run.reward_hint("jab").is_empty(),
		"Replace the routine second Jab in its own slot before touching the two rolled cards.")


func _check_hard_followup_epic_copy(run: FrontierRun) -> void:
	if not (_equip_gate_starter(run, 7, "hard", "duelist") and run.finish_combat(true, 100) and run.reward("skip")):
		check(false, "Reach the Hard opening route before testing an Epic copy.")
		return
	run.loadout.lanes[0] = [{"id": "rail_shot", "start": 0, "target": "nearest"}]
	var won := run.choose_node("1-2") and run.finish_combat(true, 100)
	check(won and run.data.offers.size() == 3 and "rail_shot" in run.data.offers \
		and run.reward_hint("rail_shot") == "Owned copy", "A same-rarity replacement cannot erase an Epic copy outside the normal roll tiers.")


func _check_hard_followup_scope(run: FrontierRun) -> void:
	if _equip_gate_starter(run, 1, "hard", "duelist") and run.finish_combat(true, 100) and run.reward("skip"):
		var beacon: Array = run.available_nodes().filter(func(node: Dictionary): return node.label == "Loaded Beacon")
		if not beacon.is_empty() and run.choose_node(beacon[0].id) and run.event_choice(1):
			var standard := _matched_followup_control(run)
			check(run.finish_combat(true, 100) and run.data.offers == standard,
				"The Loaded Beacon ambush does not modify the normal event reward.")
		else:
			check(false, "Reach the real Loaded Beacon ambush in the scope fixture.")
	if _equip_gate_starter(run, 7, "hard", "duelist", "glass") and run.finish_combat(true, 100) and run.reward("skip"):
		var battles: Array = run.available_nodes().filter(func(node: Dictionary): return node.type == "battle")
		if not battles.is_empty() and run.choose_node(battles[0].id):
			var standard := _matched_followup_control(run)
			check(run.finish_combat(true, 100) and run.data.offers == standard,
				"A Glass Foundry Hard regular battle keeps its original draft.")


func _check_later_act_specialties() -> void:
	for region: String in ["brass", "glass"]:
		var path := "user://frontier-act-specialty-%s-%d.json" % [region, Time.get_ticks_usec()]
		var run := FrontierRun.new()
		run.load_save(path)
		run.profile.medium_unlocked = true
		run.profile.hard_unlocked = true
		run.profile.glass_hard_unlocked = true
		_check_party_specialty_route(run, region, path)
		for base: String in [path, path + ".control"]:
			for suffix in ["", ".bak", ".tmp"]:
				if FileAccess.file_exists(base + suffix):
					DirAccess.remove_absolute(ProjectSettings.globalize_path(base + suffix))


func _check_party_specialty_route(run: FrontierRun, region: String, path: String) -> void:
	if not _equip_gate_starter(run, 6, "hard", "warden", region) or not _recruit_at_next_boss(run):
		check(false, "%s Hard must reach Act II with a recruit." % region)
		return
	var starter := ClassDecks.starter("warden")
	run.loadout.lanes[0] = _acquisition_pair(starter)
	run.loadout.lanes[0].append({"id": "iron_vow", "start": 4, "target": "nearest"})
	var lead_tiles: Array = run.loadout.lanes[0].duplicate(true)
	run.loadout.storage[0] = [{"id": "bellows_strike_upgrade_uncommon_technique", "start": 0, "target": "nearest"}]
	run.data.relics.assign(["pocket_bell", "siege_fuse"])
	var recruit: String = run.data.heroes[1].id
	var act_two_gate: Dictionary = run.available_nodes()[0]
	if not (run.choose_node(act_two_gate.id) and run.finish_combat(true, [100, 100])):
		check(false, "%s Act II must resolve its first ordinary fight." % region)
		return
	var lead_signature := ClassDecks.signature("warden")
	var first_history: Dictionary = run.data.get("act_specialty_offers", {})
	check(run.reward_hint(starter) == "Third copy" and run.data.offers.any(func(id: String):
		return _reward_tile_family(id) == lead_signature and ArenaSim.TILES[id].rarity == "rare") \
		and run.data.offers.any(func(id: String): return "Siege Fuse" in run.reward_hint(id)) \
		and not first_history.has("warden") and int(first_history.get(recruit, 0)) == 2,
		"%s keeps three protected lead picks while the new recruit can get their own first specialty." % region)
	var queued: Array = run.data.reward_remaining.duplicate(true)
	check(run.load_save(path) and run.data.reward_remaining == queued and run.reward("skip") \
		and not _offered_gate_specialties(run.data.offers, recruit).is_empty(),
		"%s Act II retains the recruit's separate specialty draft after reloading." % region)
	if not _finish_rewards(run, "skip"):
		return
	# The right-hand Brass branch rolls only Commons on the second fight.
	var second := "8-2" if region == "brass" else "8-0"
	if not (run.choose_node(second) and run.finish_combat(true, [100, 100])):
		check(false, "%s Act II must reach a second ordinary fight." % region)
		return
	var eligible := ["reversal_plate", "rampart_rush"]
	if region == "brass":
		check(not run.data.get("act_specialty_offers", {}).has("warden") \
			and run.data.offers.all(func(id: String): return ArenaSim.TILES[id].rarity == "common"),
			"An established hero's Act II specialty stays pending after a Common-only second reward.")
		if not _finish_rewards(run, "skip"):
			check(false, "Brass Act II must resolve its second ordinary draft.")
			return
		run.loadout.lanes[0] = [{"id": "shield_ram", "start": 0, "target": "nearest"}]
		run.loadout.storage[1] = [{"id": "iron_vow", "start": 0, "target": "nearest"}]
		if not (run.choose_node("9-2") and run.finish_combat(true, [100, 100])):
			check(false, "Brass Act II must reach a third ordinary fight.")
			return
		check(int(run.data.get("act_specialty_offers", {}).get("warden", 0)) == 2 and "shield_ram" not in run.data.offers \
			and run.reward_hint("shield_ram").is_empty() and run.data.offers.any(func(id: String):
				return _reward_tile_family(id) in eligible and ArenaSim.TILES[id].rarity == "uncommon"),
			"The later win uses an eligible single owned Uncommon slot and prefers a family absent from the party.")
		run.loadout.lanes[0] = lead_tiles
		run.loadout.storage[1] = []
	else:
		check(int(run.data.get("act_specialty_offers", {}).get("warden", 0)) == 2 and run.data.offers.any(func(id: String):
			return _reward_tile_family(id) in eligible and ArenaSim.TILES[id].rarity == "rare") \
			and run.reward_hint(starter) == "Third copy",
			"Glass retries a fully protected offer and uses a later Rare roll without taking the third copy.")
	if not _finish_rewards(run, "skip") or not _recruit_at_next_boss(run):
		check(false, "%s Hard must reach Act III with three heroes." % region)
		return
	run.data.relics.assign(["pocket_bell"])
	run.loadout.lanes[1] = [{"id": "shield_ram", "start": 0, "target": "nearest"}]
	var act_three_gate: Dictionary = run.available_nodes()[0]
	if not run.choose_node(act_three_gate.id):
		check(false, "%s Act III must reach its opening battle." % region)
		return
	var normal := FrontierRun.new()
	if not normal.load_save(path):
		check(false, "%s Act III must save its opening battle for the matched control." % region)
		return
	normal.save_path = path + ".control"
	var control_history: Dictionary = normal.data.get_or_add("act_specialty_offers", {})
	control_history.warden = 3
	if not (normal.finish_combat(true, [100, 100, 100]) and run.finish_combat(true, [100, 100, 100])):
		check(false, "%s Act III must open both matched combat drafts." % region)
		return
	var removed: Array = normal.data.offers.filter(func(id: String): return id not in run.data.offers)
	var added: Array = run.data.offers.filter(func(id: String): return id not in normal.data.offers)
	check(removed.size() == 1 and added.size() == 1 and ArenaSim.TILES[removed[0]].rarity == "uncommon" \
		and ArenaSim.TILES[added[0]].rarity == "uncommon" and _reward_tile_family(added[0]) in eligible \
		and run.reward_hint(starter) == "Third copy",
		"%s chooses the Uncommon roll over a Common for the fresh family and keeps the exact third copy." % region)
	var history: Dictionary = run.data.get("act_specialty_offers", {}).duplicate()
	queued = run.data.reward_remaining.duplicate(true)
	check(run.load_save(path) and run.data.reward_remaining == queued and history.keys().all(func(id: String):
		return int(run.data.get("act_specialty_offers", {}).get(id, 0)) == int(history[id])),
		"%s Act III preserves the consumed act and queued drafts for all three heroes on reload." % region)
	for hero: Dictionary in run.data.heroes:
		check(int(history.get(hero.id, 0)) == 3 and not _offered_gate_specialties(run.data.offers, hero.id).is_empty(),
			"%s Act III offers a separate class specialty to %s." % [region, hero.id])
		if not run.reward("skip"):
			break


func _recruit_at_next_boss(run: FrontierRun) -> bool:
	_reach_boss(run)
	var hp: Array = run.data.heroes.map(func(hero: Dictionary): return hero.hp)
	if not (run.finish_combat(true, hp) and _finish_rewards(run, "skip")):
		return false
	if run.data.phase == "boss_relic" and not run.choose_boss_relic("skip"):
		return false
	if run.data.phase != "recruit":
		return false
	var recruit: String = run.data.offers[0]
	return run.choose_recruit(recruit) and run.choose_recruit_starter(ClassDecks.starter(recruit))


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


func _check_mobility_acquisition() -> void:
	var run := FrontierRun.new()
	run.loadout = {"lanes": [[], []], "storage": [[], [], []]}
	for pair: Array in [["lancer", "phalanx_charge"], ["wayfarer", "veil_step"]]:
		var hero: String = pair[0]
		var family: String = pair[1]
		var tiers: Array = ArenaSim.FORGE_FAMILIES[family]
		check(family in run._class_reward_pool(hero, 0, []), "%s remains in the Common class deck." % family)
		for tier in [1, 2]:
			var pool := run._class_reward_pool(hero, tier, [])
			check(tiers[tier].all(func(id: String): return id in pool and id not in run._class_reward_pool("warden", tier, [])),
				"Both %s variants at tier %d can drop for %s before the family is owned." % [family, tier, hero])
			var node := run._node("shop", "Relay Market", 1, 0)
			run.data = {"phase": "shop", "segment": tier, "node": node, "layers": [[]], "visited": [],
				"heroes": [{"id": hero}, {"id": "warden"}]}
			var stocked := false
			for seed in range(1, 129):
				run.data.seed = seed
				run.data.offers = run._shop_tiles()
				var ordinary: Array = run.data.offers.duplicate()
				run._add_shop_deck_offer()
				var offer := run.shop_deck_offer_id()
				if offer in tiers[tier]:
					stocked = run.shop_class_offer_owner(offer) == hero and run.shop_stock() == ordinary + [offer]
					break
			check(stocked, "A party shop at tier %d can stock an unowned %s variant in %s's class slot." % [tier, family, hero])
		check(tiers[4].all(func(id: String): return id not in run._class_reward_pool(hero, 4, [])),
			"Direct %s offers are limited to the Common, Uncommon, and Rare pools." % family)


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
