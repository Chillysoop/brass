extends SceneTree

const Arena = preload("res://arena.tscn")
const ArenaSim = preload("res://scripts/arena_sim.gd")
const ArenaView = preload("res://scripts/arena_view.gd")
const ClassDecks = preload("res://scripts/class_decks.gd")
const FrontierRun = preload("res://scripts/frontier_run.gd")

const MATCHED_SEEDS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 42, 76]
const DIRECTIONS := {
	"warden": [["iron_arc", "iron_vow"], ["bellows_strike", "shove"]],
	"hexwright": [["shrapnel", "furnace_burst"], ["rake", "line_guard"]],
	"starshot": [["spark_shot", "signal_flare"], ["retreat_shot", "tap_bolt"]],
}
const MARSHAL_BUILDS := {
	"team": {
		"heroes": ["warden", "starshot"],
		"tiles": [["dawn_bastion", "bash", "iron_arc", "shield_tap"],
			["rivet_bolt", "deadeye", "shot", "sundering_bolt"]],
		"break": "marshal_shattered",
	},
	"pressure": {
		"heroes": ["starshot", "warden"],
		"tiles": [["rivet_bolt", "spark_shot", "star_piercer", "deadeye"],
			["iron_arc", "guard", "first_aid", "ward_lantern"]],
		"break": "marshal_pressure_break",
	},
	"defense": {
		"heroes": ["warden", "starshot"],
		"tiles": [["aegis_network", "shield_tap", "first_aid", "guard"],
			["deadeye", "crossfire", "signal_flare", "retreat_shot"]],
		"break": "marshal_defense_break",
	},
}

var failures: Array[String] = []
var save_paths: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Arena.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	for seed_value: int in MATCHED_SEEDS:
		for hero: String in DIRECTIONS:
			_check_pair(game, hero, seed_value)
	_check_marshal()
	game.queue_free()
	await process_frame
	for path: String in save_paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	for failure: String in failures:
		printerr(failure)
	quit(0 if failures.is_empty() else 1)


func _check_pair(game: Control, hero: String, seed_value: int) -> void:
	var builds: Array = []
	var pair: Array = DIRECTIONS[hero]
	for choices: Array in pair:
		var build := _draft_build(game, hero, seed_value, choices)
		if build.is_empty():
			return
		builds.append(build)
	var context := "%s · seed %d" % [hero, seed_value]
	_check(builds[0].visited == builds[1].visited and builds[0].gold == builds[1].gold,
		context + " · same battle route and gold budget")
	_check(builds[0].opening_offers == builds[1].opening_offers and builds[0].opening_hp == builds[1].opening_hp,
		context + " · same opening through the first reward")
	_check(builds[0].timeline != builds[1].timeline and builds[0].timeline.size() == builds[1].timeline.size(),
		context + " · two different timelines from the same number of rewards")
	print("%s · %s (%d HP) vs %s (%d HP)" % [context, builds[0].timeline, builds[0].hp, builds[1].timeline, builds[1].hp])


func _draft_build(game: Control, hero: String, seed_value: int, choices: Array) -> Dictionary:
	var run: FrontierRun = game.run
	var context := "%s · seed %d · %s" % [hero, seed_value, choices[0]]
	var path := "user://brass-depth-test-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	save_paths.append(path)
	run.load_save(path)
	run.profile.medium_unlocked = true
	if not _check(run.start_run(seed_value, "medium") and run.choose_preferred_hero(hero)
			and run.choose_relic("pocket_bell") and run.choose_starter(ClassDecks.starter(hero)),
			context + " · start the class with its usual tile"):
		return {}
	if not _check(_finish_fight(run), context + " · win the opening battle"):
		return {}
	for direction: Array in DIRECTIONS[hero]:
		if not _check(direction[0] in run.data.offers, context + " · offer both early directions"):
			return {}
	var opening_offers: Array = run.data.offers.duplicate()
	var opening_hp: int = run.data.hp
	if not _check(game.run_claim_reward(choices[0]), context + " · claim the first tile in the draft"):
		return {}
	var next: Array = run.available_nodes().filter(func(node: Dictionary) -> bool: return node.type == "battle")
	if not _check(not next.is_empty() and run.choose_node(next[0].id), context + " · take the first reachable normal battle"):
		return {}
	if not _check(_finish_fight(run), context + " · win the next battle with the selected tile"):
		return {}
	if not _check(game.run_claim_reward(choices[1]),
			context + " · claim the corresponding follow-up tile from the normal draft"):
		return {}
	var entries: Array = run.loadout.lanes[0]
	var drafted: Array = entries.map(func(tile: Dictionary): return tile.id)
	if not _check(drafted == [ClassDecks.starter(hero), choices[0], choices[1]],
			context + " · equip both drafted rewards on the opening timeline"):
		return {}
	var timeline := PackedStringArray()
	for entry: Dictionary in entries:
		var spec: Dictionary = ArenaSim.TILES[entry.id]
		timeline.append("%s@%d" % [spec.label, int(entry.start) + int(spec.width)])
	next = run.available_nodes().filter(func(node: Dictionary) -> bool: return node.type == "battle")
	if not _check(not next.is_empty() and run.choose_node(next[0].id) and _finish_fight(run),
			context + " · win a battle with both early direction tiles"):
		return {}
	return {"visited": run.data.visited.duplicate(), "gold": run.data.gold, "hp": run.data.hp, "timeline": timeline,
		"opening_offers": opening_offers, "opening_hp": opening_hp}


func _finish_fight(run: FrontierRun) -> bool:
	var sim := ArenaSim.new()
	sim.start(run.loadout.lanes, "solo", run.encounter())
	_play(sim)
	if sim.outcome != "victory":
		return false
	return run.finish_combat(true, int(sim.units[0].hp))


func _check_marshal() -> void:
	var view := ArenaView.new()
	for approach: String in MARSHAL_BUILDS:
		var build: Dictionary = MARSHAL_BUILDS[approach]
		var lanes: Array = []
		var rarities := {}
		for index in range(build.tiles.size()):
			var lane: Array = []
			var beat := 0
			var hero: String = build.heroes[index]
			var deck := ClassDecks.common(hero) + ClassDecks.uncommon(hero)
			for id: String in build.tiles[index]:
				var spec: Dictionary = ArenaSim.TILES[id]
				_check(id in deck or spec.get("family", "") in ClassDecks.forge_families(hero),
					approach + " · each tile belongs to its hero's deck or forge")
				lane.append({"id": id, "start": beat, "target": spec.targets[0]})
				beat += int(spec.width)
				rarities[spec.rarity] = int(rarities.get(spec.rarity, 0)) + 1
			_check(beat <= ArenaSim.BEATS, approach + " · fit each hero's timeline")
			lanes.append(lane)
		_check(rarities == {"common": 5, "uncommon": 1, "rare": 1, "legendary": 1},
			approach + " · match the other approaches' tile count and rarities")
		var sim := ArenaSim.new()
		sim.start(lanes, "duo", {
			"location": "brass", "difficulty": "medium", "encounter": "boss",
			"segment": 2, "boss_id": "gilded_marshal", "seed": 13303, "relic": "pocket_bell",
			"heroes": [
				{"id": build.heroes[0], "hp": 80, "max_hp": 100},
				{"id": build.heroes[1], "hp": 80, "max_hp": 100},
			],
		})
		_play(sim)
		var broken_by: String = sim.units.back().get("marshal_last_break", "")
		_check(sim.outcome == "victory", approach + " · defeat the Marshal on the matched fixture")
		_check(broken_by == approach, approach + " · break the plate using the intended mechanic")
		var break_events := sim.trace.filter(func(event: Dictionary) -> bool: return event.tile == build.break)
		_check(break_events.size() == 1, approach + " · record the intended plate break once in combat")
		view.reset_view(sim.units, lanes)
		view.present(sim.units, break_events, sim.tick)
		_check(view._effects.size() == 1 and view._effects[0].kind == "marshal_plate_broken",
			approach + " · show the plate break in the arena")
		var weathered_sweep := sim.trace.any(func(event: Dictionary) -> bool: return event.tile == "marshal_sweep_weathered")
		_check(weathered_sweep == (approach == "defense"),
			approach + " · only the defensive fixture relies on weathering sweeps")
		print("Marshal · %s · %s · %d/%d HP" % [approach, sim.outcome, int(sim.units[0].hp), int(sim.units[1].hp)])
	view.free()


func _play(sim: ArenaSim) -> void:
	for tick in range(4400):
		if not sim.outcome.is_empty():
			break
		sim.step()


func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
	return condition
