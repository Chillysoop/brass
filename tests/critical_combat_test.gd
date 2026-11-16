extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_check(ArenaSim.critical_chance("warden", "shot", 400.0) == 0.05, "A normal attack has 5% critical chance.")
	_check(ArenaSim.critical_chance("starshot", "shot", 210.0) == 0.15
		and ArenaSim.critical_chance("starshot", "shot", 210.01) == 0.30, "Starshot's ranged chance increases beyond 210.")
	_check(ArenaSim.critical_chance("starshot", "bash", 0.0) == 0.05
		and ArenaSim.critical_chance("starshot", "guard", 0.0) == 0.0, "Close attacks use base chance and support never crits.")
	_check_defenses_and_seed()
	_check_secondary_targets()
	_check_starshot()
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Critical hits preserve firing beats, defense order, deterministic rolls and Starshot's bounded movement.")
	quit(0 if failures.is_empty() else 1)


func _check_defenses_and_seed() -> void:
	var sim := _fight("warden", [{"id": "shot", "start": 0}], 2, 200.0)
	sim.units[1].guard = 8
	_to_beat(sim, 2, -1)
	_check(_hits(sim).is_empty(), "A critical does not fire early.")
	sim.step()
	var hit := _first_hit(sim)
	_check(hit.get("critical", false) and hit.get("tick") == 2 * ArenaSim.TICKS_PER_BEAT, "The seeded critical fires at the right edge.")
	_check(hit.get("amount") == 13 and hit.get("blocked") == 8 and sim.units[1].hp == 207, "Critical damage is modified before Guard.")
	var replay := _fight("warden", [{"id": "shot", "start": 0}], 2, 200.0)
	replay.units[1].guard = 8
	_to_beat(replay, 2)
	_check(_first_hit(replay) == hit, "The same seed replays the same hit event.")
	var ordinary := _fight("warden", [{"id": "shot", "start": 0}], 0, 200.0)
	_to_beat(ordinary, 2)
	var normal_hit := _first_hit(ordinary)
	_check(not normal_hit.get("critical", false) and normal_hit.get("amount") == ArenaSim.TILES.shot.damage,
		"An ordinary hit still deals its base damage.")


func _check_secondary_targets() -> void:
	var sim := _fight("warden", [{"id": "shrapnel", "start": 0}], 2, 230.0)
	sim._add_campaign_enemy("recruit", sim.units[1].pos + Vector2(0, 95))
	sim.units[2].speed = 0.0
	sim.units[2].next_attack = 99999
	_to_beat(sim, 3)
	var hits := _hits(sim)
	_check(hits.size() == 2 and hits[0].critical and not hits[1].critical
		and hits[1].amount == ArenaSim.TILES.shrapnel.splash_damage, "A critical affects the chosen enemy only.")


func _check_starshot() -> void:
	var near_shot := _fight("starshot", [{"id": "shot", "start": 0}], 4, 210.0)
	var far_shot := _fight("starshot", [{"id": "shot", "start": 0}], 4, 260.0)
	_to_beat(near_shot, 2)
	_to_beat(far_shot, 2)
	_check(not _first_hit(near_shot).get("critical", false) and _first_hit(far_shot).get("critical", false),
		"Extra ranged chance changes the same seeded roll beyond 210.")
	_check(far_shot.units[0].pos.distance_to(far_shot.units[1].pos) == 324.0, "Starshot backs up 64 units on the ranged critical.")
	var two_shots := _fight("starshot", [{"id": "shot", "start": 0}, {"id": "shot", "start": 2}], 3, 260.0)
	_to_beat(two_shots, 4)
	var both := _hits(two_shots)
	_check(both.size() == 2 and both.all(func(hit: Dictionary): return hit.critical), "Both shots can critically hit in the same loop.")
	_check(two_shots.trace.filter(func(event: Dictionary): return event.kind == "retreat").size() == 1
		and two_shots.units[0].pos.distance_to(two_shots.units[1].pos) == 324.0,
		"The backstep only happens once per loop.")
	var near_limit := _fight("starshot", [{"id": "shot", "start": 0}], 2, ArenaSim.TILES.shot.range - 8.0)
	_to_beat(near_limit, 2)
	_check(_first_hit(near_limit).get("critical", false) and near_limit.units[0].pos == Vector2(250, 250),
		"Critting near maximum shot range does not move Starshot out of reach.")


func _fight(hero: String, tiles: Array, seed_value: int, distance: float) -> ArenaSim:
	var sim := ArenaSim.new()
	sim.start([tiles], "solo", {"hero": hero, "seed": seed_value, "encounter": "opening"})
	sim.units[0].pos = Vector2(250, 250)
	sim.units[1].pos = Vector2(250 + distance, 250)
	sim.units[1].max_hp = 220
	sim.units[1].hp = 220
	for unit in sim.units:
		unit.speed = 0.0
		unit.next_attack = 99999
	return sim


func _to_beat(sim: ArenaSim, beat: int, offset := 0) -> void:
	while sim.tick < beat * ArenaSim.TICKS_PER_BEAT + offset and sim.outcome.is_empty():
		sim.step()


func _hits(sim: ArenaSim) -> Array[Dictionary]:
	return sim.trace.filter(func(event: Dictionary): return event.kind == "hit")


func _first_hit(sim: ArenaSim) -> Dictionary:
	var hits := _hits(sim)
	return {} if hits.is_empty() else hits.front()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
