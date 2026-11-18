extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const ArenaView = preload("res://scripts/arena_view.gd")
const BEAT := ArenaSim.TICKS_PER_BEAT

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var view := ArenaView.new()
	view.size = Vector2(850, 357)
	root.add_child(view)
	view.set_process(false)
	var long_tiles := 0
	for id: String in ArenaSim.TILES:
		_check_tile(view, id)
		long_tiles += int(ArenaSim.TILES[id].width >= 4)
	for id: String in ["jab", "bash", "blink", "slam", "meteor_seal", "event_horizon"]:
		for speed in [2, 3]:
			_check_tile(view, id, speed, true)
	view.queue_free()
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("All %d tile IDs release exactly at their right edge; %d wide tiles prepare through their full width. Loop-edge releases also passed at 2x/3x." % [ArenaSim.TILES.size(), long_tiles])
	quit(0 if failures.is_empty() else 1)


func _check_tile(view: ArenaView, id: String, speed := 1, loop_edge := false) -> void:
	var tile: Dictionary = ArenaSim.TILES[id]
	var width := int(tile.width)
	var start := ArenaSim.BEATS - width if loop_edge else 2
	var ready := start * BEAT
	var release := (start + width) * BEAT
	var target := "self" if tile.targets == ["self"] else "nearest"
	var lanes := [[{"id": id, "start": start, "target": target}]]
	var sim := ArenaSim.new()
	sim.start(lanes, "solo", {"seed": 42, "encounter": "battle",
		"heroes": [{"hero": "warden", "hp": 5000, "max_hp": 10000}]})
	for unit: Dictionary in sim.units:
		unit.speed = 0.0
		unit.next_attack = 999999
		if unit.side == "enemy":
			unit.hp = 10000
			unit.max_hp = 10000
			unit.pos = Vector2(460 + (sim.units.find(unit) - 1) * 75, 265)
	sim.units[0].pos = Vector2(400, 265)
	view.reset_view(sim.units, lanes)
	var hero: Dictionary = sim.units[0]
	var preparation_ticks: Array[int] = [ready, ready + width * BEAT / 4, ready + width * BEAT / 2, release - 1]
	var last_charge := -1.0
	var early := false
	var phases := 0
	while sim.tick < release:
		var events := sim.step()
		view.present(sim.units, events, sim.tick, sim.visual_cues, speed)
		if sim.tick < release:
			early = early or sim.visual_cues.any(func(cue: Dictionary): return cue.kind == "hero_cast" and cue.tile == id)
			early = early or view._actor_casts.has(hero.id)
		if sim.tick in preparation_ticks and sim.tick > 0 and sim.tick < release:
			var windup: Dictionary = view._windup_details(hero)
			_check(not windup.is_empty() and is_equal_approx(float(windup.get("beats", -1)), width),
				"%s: preparation covers its actual %d-beat width at tick %d." % [id, width, sim.tick])
			if not windup.is_empty():
				_check(float(windup.charge) >= last_charge and float(windup.charge) < 1.0,
					"%s: its visible preparation progresses without reaching contact early." % id)
				last_charge = float(windup.charge)
				phases += 1
	_check(not early, "%s: no release is rendered before tick %d at %dx." % [id, release, speed])
	var cues: Array = sim.visual_cues.filter(func(cue: Dictionary): return cue.kind == "hero_cast" and cue.tile == id)
	var cast: Dictionary = view._actor_casts.get(hero.id, {})
	_check(cues.size() == 1 and cues[0].tick == release and cast.get("tile") == id
		and view._windup_details(hero).is_empty(),
		"%s: one real sim cue starts playback exactly at tick %d, ending preparation at %dx." % [id, release, speed])
	if width >= 4:
		_check(phases >= 3 and last_charge > 0.98, "%s: a wide tile visibly prepares through early, middle and final phases." % id)
	sim.step()
	_check(not sim.visual_cues.any(func(cue: Dictionary): return cue.kind == "hero_cast" and cue.tile == id),
		"%s: the release cue is consumed once." % id)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
