extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const FrontierRun = preload("res://scripts/frontier_run.gd")
const PilotFormations = preload("res://scripts/pilot_formations.gd")
const CampaignFormations = preload("res://scripts/campaign_formations.gd")
const ClassDecks = preload("res://scripts/class_decks.gd")
const LOCATIONS := ["brass", "glass", "crown", "moonwreck"]
const RUN_COUNT := 256

var failures: Array[String] = []


func _initialize() -> void:
	for location: String in LOCATIONS:
		_check_locked_formation(location)
		_check_openers(location)
		_check_route_variety(location)
	for failure: String in failures:
		printerr(failure)
	quit(0 if failures.is_empty() else 1)


func _check_locked_formation(location: String) -> void:
	var path := "user://pilot-formations-test-%s-%d.json" % [location, Time.get_ticks_usec()]
	var run := FrontierRun.new()
	run.load_save(path)
	var unlock := "medium_unlocked" if location == "brass" else location + "_medium_unlocked"
	run.profile[unlock] = true
	if not _expect(run.start_run(946, "medium", location), "The pilot must start on Medium."):
		return
	var lead: String = run.data.offers[0]
	_expect(run.choose_hero(lead) and run.choose_relic("pocket_bell") and run.choose_starter("bash"),
		"A fresh expedition must enter its opening combat from the regular starter draft.")
	var opening := run.encounter()
	var resumed_opening := FrontierRun.new()
	_expect(opening.has("formation") and run.data.node.has("pilot_formation")
		and resumed_opening.load_save(path) and opening == resumed_opening.encounter(),
		"A rotated opener must keep its exact formation after save and resume.")
	run.data.hero = "warden"
	run.data.heroes = [_hero("warden"), _hero("hexwright")]
	run.loadout.lanes = [[], []]
	run.data.phase = "map"
	run.data.node = run.data.layers[6][0]
	run.data.pilot_fights = [{"kind": "opening", "enemies": _formation_ids(opening.get("formation", []))}]
	var before: Dictionary = run.data.duplicate(true)
	var gate: Dictionary = run.available_nodes()[0]
	var preview := run._encounter_for(gate, 2)
	_expect(run.data == before and preview.has("formation"), "A pilot gate preview must choose a formation without mutating the run.")
	if _expect(run.choose_node(gate.id), "The previewed pilot gate must be reachable."):
		var entered := run.encounter()
		_expect(entered == preview, "Selecting the node must lock the formation shown in its preview.")
		var resume := FrontierRun.new()
		_expect(resume.load_save(path) and entered == resume.encounter(), "An entered pilot fight must keep its exact spawn after a save and resume.")
		var sim := ArenaSim.new()
		var enemies := _enemy_ids(sim, entered)
		_expect(enemies == _formation_ids(entered.formation), "The arena must spawn the enemy types selected by the pilot formation.")
		if _expect(run.finish_combat(true, [92, 94]), "The pilot gate should accept the fight result."):
			_expect(run.data.pilot_fights.back().enemies == enemies, "Victory must record the actual lineup for later novelty checks.")
		run.data.phase = "event"
		run.data.node = {"type": "event", "row": 8, "column": 1, "id": "r8c1", "label": "Bounty Board"}
		if _expect(run.event_choice(1), "A late-act Bounty Board must be playable."):
			var bounty := run.encounter()
			_expect(bounty.kind == "elite" and bounty.has("formation"), "A late-act event override must choose from the pilot elite pool.")
			run.data.erase("encounter_roster_version")
			_expect(run.save() and resume.load_save(path) and resume.encounter() == bounty,
				"A locked encounter must resume with its persisted lineup across roster versions.")
			run.data.erase("pilot_fights")
			run.data.node.erase("pilot_formation")
			_expect(run.save() and resume.load_save(path) and not resume.encounter().has("formation"),
				"An already entered legacy fight must retain its original generation.")
	for suffix: String in ["", ".bak", ".tmp"]:
		var file := path + suffix
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))


func _hero(id: String) -> Dictionary:
	return {"id": id, "hp": 100, "max_hp": 100}


func _formation_ids(formation: Array) -> Array[String]:
	var enemies: Array[String] = []
	for spawn: Dictionary in formation:
		enemies.append(spawn.id)
	return enemies


func _enemy_ids(sim: ArenaSim, options: Dictionary) -> Array[String]:
	sim.start([], "solo", options)
	var enemies: Array[String] = []
	for unit: Dictionary in sim.units:
		if unit.side == "enemy":
			enemies.append(unit.id.rsplit("_", true, 1)[0])
	return enemies


func _check_openers(location: String) -> void:
	var sim := ArenaSim.new()
	var rosters: Array = CampaignFormations.ROSTERS[location][1].opening
	var minimum_hp := 100
	for roster: Array in rosters:
		var formation := CampaignFormations.deploy(roster, "opening", 1, 12)
		for hero: String in ArenaSim.HERO_CLASSES:
			for tile: String in ["bash", "shot", "slam", ClassDecks.starter(hero)]:
				var lanes := [[{"id": tile, "start": 0, "target": "nearest"}]]
				sim.start(lanes, "solo", {"location": location, "encounter": "opening", "formation": formation,
					"hero": hero, "hp": 100, "max_hp": 100})
				while sim.tick < 3600 and sim.outcome.is_empty():
					sim.step()
				_expect(sim.outcome == "victory" and sim.units[0].hp >= 75,
					"%s must be a viable opener for %s using %s." % [roster[0], hero, tile])
				minimum_hp = mini(minimum_hp, sim.units[0].hp)
	print("  %s · %d opener lineups across all classes and four starter tiles · minimum %d HP" % [location, rosters.size(), minimum_hp])


func _check_route_variety(location: String) -> void:
	var seed_rng := RandomNumberGenerator.new()
	seed_rng.seed = 912488620
	var sample: Array[int] = []
	for index in range(RUN_COUNT):
		var seed_value := maxi(1, int(seed_rng.randi()))
		while seed_value in sample:
			seed_value = maxi(1, int(seed_rng.randi()))
		sample.append(seed_value)
	for prefer_combat: bool in [false, true]:
		var repeats := 0
		var spawns := 0
		for seed_value: int in sample:
			var result := _sample_route(seed_value, location, prefer_combat)
			repeats += result.x
			spawns += result.y
		var percentage := 100.0 * float(repeats) / spawns
		var policy := "combat-first" if prefer_combat else "mixed"
		print("  %s Hard · %s · %d seeds · %.1f%% familiar (%d / %d spawns)" % [location, policy, sample.size(), percentage, repeats, spawns])
		_expect(percentage <= 25.0, "%s Hard must meet the encounter variety target on %s paths." % [location, policy])


func _sample_route(seed_value: int, location: String, prefer_combat: bool) -> Vector2i:
	var run := FrontierRun.new()
	var sim := ArenaSim.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 831623 + seed_value
	var layers := run._make_map(seed_value, "hard", location)
	run.data = {"seed": seed_value, "location": location, "difficulty": "hard", "layers": layers,
		"hero": "warden", "heroes": [], "hp": 100, "max_hp": 100, "relics": [], "pilot_fights": [],
		"encounter_roster_version": PilotFormations.CURRENT_VERSION}
	var current: Dictionary = layers[0][0]
	var totals := Vector2i.ZERO
	var seen := {}
	var fought_lineups := {}
	for row in range(layers.size()):
		var kind: String = current.type
		if kind in ["opening", "battle", "elite", "boss"]:
			var act := floori(float(current.row) / FrontierRun.NODES_PER_SEGMENT) + 1
			run.data.heroes.resize(act)
			for lane in range(act):
				run.data.heroes[lane] = _hero("warden")
			var options := run._encounter_for(current, act)
			var enemies := _enemy_ids(sim, options)
			if kind != "boss":
				_expect(options.has("formation") and enemies == _formation_ids(options.get("formation", [])),
					"Every regular or elite node and opener must spawn its seeded lineup.")
			if kind in ["battle", "elite"]:
				for enemy: String in enemies:
					totals += Vector2i(int(seen.has(enemy)), 1)
			var lineup := enemies.duplicate()
			lineup.sort()
			var key := "+".join(lineup)
			if kind in ["battle", "elite"]:
				_expect(not fought_lineups.has(key), "An audited Hard route must avoid exact lineup repeats when alternatives exist.")
			fought_lineups[key] = true
			for enemy: String in enemies:
				seen[enemy] = true
			run.data.pilot_fights.append({"kind": kind, "enemies": enemies})
		if row + 1 == layers.size():
			break
		var candidates: Array = layers[row + 1].filter(func(node: Dictionary): return node.id in current.next)
		if prefer_combat:
			var combat := candidates.filter(func(node: Dictionary): return node.type in ["battle", "elite", "boss"])
			if not combat.is_empty():
				candidates = combat
		current = candidates[rng.randi_range(0, candidates.size() - 1)]
	return totals


func _expect(condition: bool, error: String) -> bool:
	if not condition and error not in failures:
		failures.append(error)
	return condition
