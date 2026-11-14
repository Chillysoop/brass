extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const FrontierRun = preload("res://scripts/frontier_run.gd")

var failures: Array[String] = []
var save_path := "user://relic-build-test-%d.json" % Time.get_ticks_usec()


func _initialize() -> void:
	_check_towline()
	_check_bridgeplate()
	_check_metronome()
	_check_reward_flow()
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Combat relic timing, seeded drafts, reward slots, and elite previews passed.")
	quit(0 if failures.is_empty() else 1)


func _check_towline() -> void:
	var sim := _sim("towline_knot", [{"id": "pull", "start": 0}, {"id": "shot", "start": 3}])
	_advance(sim, 5 * ArenaSim.TICKS_PER_BEAT - 1)
	_check(_procs(sim, "towline_knot").is_empty(), "Towline must wait for a separate tile's right edge.")
	sim.step()
	var procs := _procs(sim, "towline_knot")
	_check(procs.size() == 1 and procs[0].source_tile == "shot" and procs[0].tick == sim.tick
		and procs[0].amount == 9, "Towline must buff the tile that hits the marked target two beats later.")
	var follow_up: Dictionary = sim.activations[-1]
	_check(follow_up.damage == ArenaSim.TILES.shot.damage + 9 and follow_up.get("relics", [{}])[0].get("source_beat") == 3,
		"The review must link actual bonus damage to the earlier Pull activation.")
	var too_late := _sim("towline_knot", [{"id": "pull", "start": 0}, {"id": "shot", "start": 4}])
	_advance(too_late, 6 * ArenaSim.TICKS_PER_BEAT)
	_check(_procs(too_late, "towline_knot").is_empty(), "Towline must expire outside its two-beat window.")


func _check_bridgeplate() -> void:
	var sim := _sim("bridgeplate", [{"id": "guard", "start": 0}, {"id": "shot", "start": 3}, {"id": "shot", "start": 5}])
	_advance(sim, 3 * ArenaSim.TICKS_PER_BEAT)
	_check(_procs(sim, "bridgeplate").is_empty() and sim.units[0].guard == ArenaSim.TILES.guard.guard,
		"Gaining Guard alone must not trigger Bridgeplate.")
	sim._damage(sim.units[1], sim.units[0], 3, "enemy_attack")
	_advance(sim, 5 * ArenaSim.TICKS_PER_BEAT)
	var procs := _procs(sim, "bridgeplate")
	_check(procs.size() == 1 and procs[0].tick == sim.tick and procs[0].amount == 8
		and sim.activations[-1].damage == ArenaSim.TILES.shot.damage + 8,
		"A hero's next tile hit must convert absorbed Guard into 8 damage at the right edge.")
	sim._damage(sim.units[1], sim.units[0], 3, "enemy_attack")
	_advance(sim, ArenaSim.LOOP_TICKS + 7 * ArenaSim.TICKS_PER_BEAT)
	_check(_procs(sim, "bridgeplate").size() == 1, "Bridgeplate must proc at most once per hero per loop and cannot carry a charge forward.")


func _check_metronome() -> void:
	var sim := _sim("brass_metronome", [{"id": "shot", "start": 1}, {"id": "shot", "start": 4}])
	_advance(sim, ArenaSim.LOOP_TICKS + 6 * ArenaSim.TICKS_PER_BEAT)
	var procs := _procs(sim, "brass_metronome")
	_check(procs.size() == 2 and procs[0].tick == 3 * ArenaSim.TICKS_PER_BEAT
		and procs[1].tick == ArenaSim.LOOP_TICKS + 3 * ArenaSim.TICKS_PER_BEAT,
		"Brass Metronome must reward the first spaced hit per loop at its right edge.")
	var adjacent := _sim("brass_metronome", [{"id": "shot", "start": 0}, {"id": "shot", "start": 2}, {"id": "shot", "start": 10}])
	_advance(adjacent, ArenaSim.LOOP_TICKS + 4 * ArenaSim.TICKS_PER_BEAT)
	_check(_procs(adjacent, "brass_metronome").size() == 1 and _procs(adjacent, "brass_metronome")[0].tick == ArenaSim.LOOP_TICKS,
		"Tiles with a filled preceding beat must not trigger Metronome, including across the loop boundary.")


func _check_reward_flow() -> void:
	var cases := {
		"towline_knot": {"starter": "bash", "bridge": "shot", "hint": "Follow a push or pull"},
		"bridgeplate": {"starter": "shield_ram", "bridge": "shot", "hint": "Follow absorbed Guard"},
		"brass_metronome": {"starter": "shot", "bridge": "slam", "hint": "Leave one beat empty before it"},
	}
	var seed_value := 1
	var drafts := {}
	var run := FrontierRun.new()
	run.load_save(save_path)
	while not cases.is_empty() and seed_value <= 24:
		_check(run.start_run(seed_value) and run.choose_hero(run.data.offers[0]), "A new Easy run must reach the relic draft.")
		var offers := run.build_relic_offers()
		drafts[str(offers)] = true
		_check(offers.size() == 3 and offers.filter(func(id): return id in FrontierRun.BUILD_RELICS).size() == 2,
			"The seeded starter draft must mix two build relics and one classic combat relic.")
		var restored := FrontierRun.new()
		_check(restored.load_save(save_path) and offers == restored.build_relic_offers(), "Resuming must preserve the exact relic offers.")
		var relic := ""
		for id: String in offers:
			if cases.has(id):
				relic = id
				break
		if not relic.is_empty():
			var kit: Dictionary = cases[relic]
			cases.erase(relic)
			_check(run.choose_relic(relic) and run.choose_starter(kit.starter), "The relic must lead to a compatible starter tile.")
			var sim := ArenaSim.new()
			sim.start(run.loadout.lanes, "solo", run.encounter())
			_advance(sim, 4500)
			_check(sim.outcome == "victory" and run.finish_combat(true, sim.units[0].hp), "%s must survive a real opening battle." % relic)
			_check(run.data.offers.size() == 3 and run.reward_hint(kit.bridge) == kit.hint,
				"The first reward must offer and explain the bridge into the starter relic's build.")
			if relic != "bridgeplate":
				_check(run.reward_hint(kit.starter) == "Owned copy", "The continuation slot must identify an exact owned tile.")
			_check(restored.load_save(save_path) and restored.reward_hint(kit.bridge) == kit.hint,
				"A saved reward must preserve the build rationale.")
			if relic == "towline_knot" and run.data.phase == "reward":
				run.loadout.storage[0] = [{"id": "bash", "start": 0}, {"id": "guard", "start": 2}]
				_check("bash" in run._standard_rewards() and run.reward_hint("bash") == "Third copy",
					"The continuation slot should finish a forge pair before offering copies of other held tiles.")
				_check_elite_preview(run)
		run.abandon_run()
		seed_value += 1
	_check(cases.is_empty() and drafts.size() > 1, "Seeds must vary which build relics can begin a run.")


func _check_elite_preview(run: FrontierRun) -> void:
	_check(run.reward("skip"), "The route must open after resolving the combat reward.")
	while not run.available_nodes().is_empty():
		var options := run.available_nodes()
		var node: Dictionary = options[0]
		for option: Dictionary in options:
			if option.type == "elite":
				node = option
				break
		var preview := run.elite_preview(node)
		_check(run.choose_node(node.id), "An advertised map node must be selectable.")
		if node.type == "elite":
			_check(not preview.is_empty() and preview.get("encounter") == run.encounter(),
				"An elite preview must exactly match the encounter after choosing it.")
			run.loadout.storage[1].append({"id": "shockwave", "start": 0, "target": "nearest"})
			_check(run.finish_combat(true, run.data.hp) and preview.get("tile") in run.data.offers,
				"An elite victory must offer the advertised tile even when the player edits their loadout.")
			return
		match run.data.phase:
			"combat":
				run.finish_combat(true, run.data.hp)
				run.reward("skip")
			"event": run.event_choice(0)
			"shop": run.leave_node()
			"rest": run.rest("heal")
	_check(false, "The fixture should reach an elite before the act boss.")


func _sim(relic: String, lane: Array) -> ArenaSim:
	var sim := ArenaSim.new()
	sim.start([lane], "solo", {"encounter": "boss", "hero": "warden", "relics": [relic]})
	sim.units[0].pos = Vector2(400, 265)
	sim.units[1].pos = Vector2(535, 265)
	for unit in sim.units:
		unit.speed = 0.0
		unit.next_attack = 9999
	return sim


func _advance(sim: ArenaSim, target_tick: int) -> void:
	while sim.tick < target_tick and sim.outcome.is_empty():
		sim.step()


func _procs(sim: ArenaSim, relic: String) -> Array:
	return sim.trace.filter(func(event: Dictionary): return event.kind == "relic_proc" and event.tile == relic)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
