extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const FrontierRun = preload("res://scripts/frontier_run.gd")
const LOCATIONS := ["glass", "moonwreck"]
const RUN_COUNT := 256

var failures: Array[String] = []


func _initialize() -> void:
	for location: String in LOCATIONS:
		_check_locked_formation(location)
		_check_route_variety(location)
	for failure: String in failures:
		printerr(failure)
	quit(0 if failures.is_empty() else 1)


func _check_locked_formation(location: String) -> void:
	var path := "user://pilot-formations-test-%s-%d.json" % [location, Time.get_ticks_usec()]
	var run := FrontierRun.new()
	run.load_save(path)
	run.profile[location + "_medium_unlocked"] = true
	if not _expect(run.start_run(946, "medium", location), "The pilot must start on Medium."):
		return
	run.data.hero = "warden"
	run.data.heroes = [_hero("warden"), _hero("hexwright")]
	run.loadout.lanes = [[], []]
	run.data.phase = "map"
	run.data.node = run.data.layers[6][0]
	run.data.pilot_fights = [{"kind": "battle", "enemies": ["glass_skirmisher" if location == "glass" else "dock_bruiser"]}]
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
		_expect(percentage < 50.0, "%s Hard must meet the pilot target on %s paths." % [location, policy])


func _sample_route(seed_value: int, location: String, prefer_combat: bool) -> Vector2i:
	var run := FrontierRun.new()
	var sim := ArenaSim.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 831623 + seed_value
	var layers := run._make_map(seed_value, "hard", location)
	run.data = {"seed": seed_value, "location": location, "difficulty": "hard", "layers": layers,
		"hero": "warden", "heroes": [], "hp": 100, "max_hp": 100, "relics": [], "pilot_fights": []}
	var current: Dictionary = layers[0][0]
	var totals := Vector2i.ZERO
	var seen := {}
	var recent: Dictionary = {"battle": [], "elite": []}
	for row in range(layers.size()):
		var kind: String = current.type
		if kind in ["opening", "battle", "elite", "boss"]:
			var act := floori(float(current.row) / FrontierRun.NODES_PER_SEGMENT) + 1
			run.data.heroes.resize(act)
			for lane in range(act):
				run.data.heroes[lane] = _hero("warden")
			var options := run._encounter_for(current, act)
			var enemies := _enemy_ids(sim, options)
			if recent.has(kind):
				for enemy: String in enemies:
					totals += Vector2i(int(seen.has(enemy)), 1)
				var lineup := enemies.duplicate()
				lineup.sort()
				if act > 1:
					_expect(options.has("formation") and enemies.size() >= 1,
						"The arena must generate a real pilot formation for each late combat node.")
					_expect(lineup not in recent[kind], "The pilot must skip recently seen %s lineups." % kind)
				recent[kind].append(lineup)
				if recent[kind].size() > (2 if kind == "battle" else 1):
					recent[kind].pop_front()
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
