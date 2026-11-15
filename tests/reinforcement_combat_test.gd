extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const ARRIVAL_TICK := 7 * ArenaSim.TICKS_PER_BEAT

var failures: Array[String] = []


func _initialize() -> void:
	_check_early_clear_and_arrival()
	_check_arrival_avoids_occupied_position()
	_check_defeat_stops_wave()
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Reinforcement combat checks passed. Arrival matches the advertised beat, preserves attack timing, and waits before declaring victory.")
	quit(0 if failures.is_empty() else 1)


func _check_early_clear_and_arrival() -> void:
	var sim := ArenaSim.new()
	var options := _encounter()
	var lane := [{"id": "shot", "start": 0, "target": "nearest"}, {"id": "shot", "start": 5, "target": "nearest"}]
	sim.start([lane], "solo", options)
	var warning := sim.pending_reinforcement()
	_check(not warning.is_empty() and warning.beat == 7 and warning.tick == ARRIVAL_TICK,
		"Setup must advertise a beat-seven arrival.")
	_check(sim.units.size() == 2, "The second enemy must not be present at setup.")
	# Editing the caller's arrays cannot change the scheduled arrival.
	options.reinforcements[0].id = "brass_runner"
	for unit: Dictionary in sim.units:
		unit.speed = 0.0
	_step_through(sim, ARRIVAL_TICK - 1)
	_check(sim.units.size() == 2 and sim.units[1].hp == 0 and sim.outcome.is_empty(),
		"An early clear must wait for the advertised wave.")
	var events := sim.step()
	if not _check(sim.units.size() == 3, "The delayed enemy must appear on the advertised tick."):
		return
	var scout: Dictionary = sim.units[2]
	var spec: Dictionary = ArenaSim.CAMPAIGN_ENEMIES.scout
	_check(scout.attack_id == "scout" and scout.max_hp == roundi(spec.hp * 1.12) and scout.attack.damage == roundi(spec.damage * 1.07),
		"The delayed enemy must preserve its identity and encounter scaling.")
	_check(scout.next_attack == ARRIVAL_TICK + int(spec.first) + 10 and scout.intent.is_empty(),
		"Attack timing must start at arrival.")
	var arrivals := events.filter(func(event: Dictionary) -> bool: return event.kind == "reinforcement")
	_check(arrivals.size() == 1 and arrivals[0].tick == ARRIVAL_TICK and arrivals[0].to == scout.pos
		and arrivals[0].to == warning.positions[0], "Arrival must emit a cue at the marked spawn location.")
	_check(scout.hp < scout.max_hp and sim.activations.back().target == scout.id,
		"A tile ending on the arrival beat must be able to target the new enemy.")
	_check(sim.pending_reinforcement().is_empty(), "The arrival warning must clear when the wave appears.")
	_step_through(sim, ARRIVAL_TICK + 1)
	_check(sim.units.size() == 3, "A reinforcement wave must only spawn once.")
	sim.start([], "solo")
	_check(sim.pending_reinforcement().is_empty(), "Ordinary fights must not inherit a wave.")


func _check_arrival_avoids_occupied_position() -> void:
	var sim := ArenaSim.new()
	sim.start([[]], "solo", _encounter())
	var hero: Dictionary = sim.units[0]
	hero.pos = sim.pending_reinforcement().positions[0]
	hero.speed = 0.0
	sim.units[1].speed = 0.0
	_step_through(sim, ARRIVAL_TICK)
	if not _check(sim.units.size() == 3, "An occupied marker must still admit the wave on time."):
		return
	var scout: Dictionary = sim.units[2]
	_check(Vector2(scout.pos).distance_to(hero.pos) >= scout.radius + hero.radius + 5.0,
		"The delayed enemy must spawn clear of heroes standing on the marker.")


func _check_defeat_stops_wave() -> void:
	var sim := ArenaSim.new()
	sim.start([[]], "solo", _encounter())
	sim.units[0].hp = 0
	sim.step()
	_check(sim.outcome == "defeat", "A pending wave must never hold off defeat.")
	_check(sim.pending_reinforcement().is_empty() and sim.units.size() == 2,
		"The wave must disappear from the warning after a defeat.")


func _encounter() -> Dictionary:
	return {"encounter": "battle", "difficulty": "medium", "seed": 32,
		"formation": [_spawn("recruit", 400.0, 0, 0.1)], "reinforcements": [_spawn("scout", 430.0, 10, 1.0)],
		"reinforcement_beat": 7}


func _spawn(id: String, x: float, delay: int, health_scale: float) -> Dictionary:
	return {"id": id, "x": x, "dy": 0.0, "delay": delay, "health_scale": health_scale, "damage_scale": 1.0}


func _step_through(sim: ArenaSim, target_tick: int) -> void:
	while sim.tick < target_tick and sim.outcome.is_empty():
		sim.step()


func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
	return condition
