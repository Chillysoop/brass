extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const BEAT := ArenaSim.TICKS_PER_BEAT

var failures: Array[String] = []


func _initialize() -> void:
	_check_afterimage()
	_check_barrage()
	_check_siege()
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Afterimage, Barrage Rack, and Siege Fuse combat checks passed.")
	quit(0 if failures.is_empty() else 1)


func _check_afterimage() -> void:
	var sim := _sim("afterimage", [[_tile("ward_step", 0), _tile("guard", 3), _tile("bash", 5), _tile("bash", 7)]])
	var hero: Dictionary = sim.units[0]
	var foe: Dictionary = sim.units[1]
	_park(foe, Vector2(400, 265))
	var departure: Vector2 = hero.pos
	_advance(sim, BEAT * 5)
	var landing: Vector2 = hero.pos
	_check(landing.distance_to(foe.pos) > ArenaSim.TILES.bash.range and not landing.is_equal_approx(departure),
		"The first Blink should put the enemy out of the hero's normal Bash range.")
	_check(_procs(sim, "afterimage").is_empty() and hero.has("afterimage"),
		"Guard must leave Afterimage waiting for a damaging tile.")
	_advance(sim, BEAT * 7 - 1)
	_check(_procs(sim, "afterimage").is_empty(), "Afterimage must wait for the Bash right edge.")
	sim.step()
	var procs := _procs(sim, "afterimage")
	var activation: Dictionary = sim.activations[-1]
	_check(procs.size() == 1 and procs[0].tick == BEAT * 7 and procs[0].from == departure and procs[0].to == foe.pos,
		"Afterimage must fire from the Blink departure on the following Bash's right edge.")
	_check(activation.damage == ArenaSim.TILES.bash.damage and activation.get("relics", [{}])[0].get("source_beat") == 3,
		"Battle Review must link the landed Bash to the preceding Blink.")
	_check(hero.pos == landing and foe.impulse.x > 0.0, "Bash should push away from the echo while the hero stays in place.")
	_advance(sim, BEAT * 9)
	_check(_procs(sim, "afterimage").size() == 1 and sim.activations[-1].status == "miss",
		"Only the next attack can use that departure point.")

	var fallback := _sim("afterimage", [[_tile("blink", 0), _tile("bash", 3)]])
	_park(fallback.units[1], Vector2(600, 265))
	_advance(fallback, BEAT * 5)
	_check(_procs(fallback, "afterimage").is_empty() and fallback.activations[-1].damage == ArenaSim.TILES.bash.damage,
		"A normal hit should still land if only the post-Blink position is in range.")

	var refreshed := _sim("afterimage", [[_tile("blink", 0), _tile("ward_step", 3), _tile("bash", 6)]])
	_park(refreshed.units[1], Vector2(600, 265))
	_advance(refreshed, BEAT * 3)
	var second_departure: Vector2 = refreshed.units[0].pos
	_advance(refreshed, BEAT * 8)
	procs = _procs(refreshed, "afterimage")
	_check(procs.size() == 1 and procs[0].from == second_departure,
		"A second Blink bypasses the first echo and records its own departure.")


func _check_barrage() -> void:
	var sim := _sim("barrage_rack", [[_tile("shot", 0), _tile("shot", 2), _tile("shot", 4)]])
	var foe: Dictionary = sim.units[1]
	foe.guard = 28
	_advance(sim, BEAT * 4 - 1)
	_check(foe.guard == 14 and _procs(sim, "barrage_rack").is_empty(), "The first hit spends Guard normally.")
	sim.step()
	var procs := _procs(sim, "barrage_rack")
	_check(procs.size() == 1 and procs[0].amount == 8 and procs[0].tick == BEAT * 4,
		"The second hit must strip up to 8 Guard at its right edge.")
	_check(sim.activations[-1].damage == 8 and sim.activations[-1].relics[0].source_beat == 2,
		"Guard strip must precede damage and identify the first attack in Battle Review.")
	_advance(sim, BEAT * 6)
	_check(_procs(sim, "barrage_rack").size() == 1, "A hit spent in a pair cannot set up another pair.")

	var late := _sim("barrage_rack", [[_tile("shot", 0), _tile("shot", 3)]])
	late.units[1].guard = 28
	_advance(late, BEAT * 5)
	_check(_procs(late, "barrage_rack").is_empty() and late.units[1].hp == late.units[1].max_hp,
		"A gap of more than two beats must break the pair.")

	var duo := _sim("barrage_rack", [[_tile("shot", 0)], [_tile("shot", 0)]])
	duo.units[2].guard = 28
	_advance(duo, BEAT * 2)
	procs = _procs(duo, "barrage_rack")
	_check(procs.size() == 1 and procs[0].lane == 1 and procs[0].tick == BEAT * 2,
		"Separate heroes can pair their hits on the same target on the same beat.")

	var split := _sim("barrage_rack", [[_tile("shot", 0), _tile("shot", 2, "farthest")]], "elite")
	_park(split.units[1], Vector2(425, 265))
	_park(split.units[2], Vector2(545, 265))
	split.units[1].guard = 28
	split.units[2].guard = 28
	_advance(split, BEAT * 4)
	_check(_procs(split, "barrage_rack").is_empty(), "Hits on two different enemies cannot form a pair.")


func _check_siege() -> void:
	var tiles := [_tile("slam", 0), _tile("slam", 4)]
	var sim := _siege_fixture("siege_fuse", tiles)
	var plain := _siege_fixture("", tiles)
	_advance(sim, BEAT * 4 - 1)
	var neighbor: Dictionary = sim.units[2]
	var original_hp: int = neighbor.hp
	_check(neighbor.pos == Vector2(440, 418) and _procs(sim, "siege_fuse").is_empty(),
		"Siege Fuse should wait for the heavy tile's exact right edge.")
	sim.step()
	_advance(plain, BEAT * 4)
	var procs := _procs(sim, "siege_fuse")
	_check(procs.size() == 1 and procs[0].source_tile == "slam" and procs[0].amount == 1 and procs[0].tick == BEAT * 4,
		"Siege Fuse should report the extra enemy it pulls into the first Slam.")
	_check(neighbor.hp == original_hp - ArenaSim.TILES.slam.damage and plain.units[2].hp == original_hp,
		"The inward pull must happen before checking the Slam's damage radius.")
	_park(sim.units[1], Vector2(440, 265))
	_park(neighbor, Vector2(440, 418))
	_advance(sim, BEAT * 8)
	_check(_procs(sim, "siege_fuse").size() == 1 and neighbor.hp == original_hp - ArenaSim.TILES.slam.damage,
		"The second Slam in the same loop must leave the distant enemy outside its area.")
	_park(sim.units[1], Vector2(440, 265))
	_park(neighbor, Vector2(440, 418))
	_advance(sim, ArenaSim.LOOP_TICKS + BEAT * 4)
	_check(_procs(sim, "siege_fuse").size() == 2, "Siege Fuse must refresh in the next loop.")

	var ranged := _siege_fixture("siege_fuse", [_tile("rail_shot", 0)])
	_advance(ranged, BEAT * 4)
	_check(ranged.units[2].hp == ranged.units[2].max_hp and ranged.units[2].pos.y < 418.0,
		"A heavy single-target shot should group neighbors without dealing them splash damage.")


func _siege_fixture(relic: String, tiles: Array) -> ArenaSim:
	var sim := _sim(relic, [tiles], "elite")
	_park(sim.units[1], Vector2(440, 265))
	_park(sim.units[2], Vector2(440, 418))
	return sim


func _sim(relic: String, lanes: Array, encounter := "opening") -> ArenaSim:
	var heroes: Array = []
	for lane in range(lanes.size()):
		heroes.append({"hero": "warden"})
	var sim := ArenaSim.new()
	sim.start(lanes, "solo", {"encounter": encounter, "heroes": heroes, "relics": [] if relic.is_empty() else [relic]})
	for unit: Dictionary in sim.units:
		_park(unit, unit.pos)
		if unit.side == "enemy":
			unit.hp = 220
			unit.max_hp = 220
	return sim


func _park(unit: Dictionary, point: Vector2) -> void:
	unit.pos = point
	unit.speed = 0.0
	unit.impulse = Vector2.ZERO
	unit.next_attack = 99999


func _tile(id: String, start: int, rule := "nearest") -> Dictionary:
	return {"id": id, "start": start, "target": rule}


func _advance(sim: ArenaSim, target_tick: int) -> void:
	while sim.tick < target_tick and sim.outcome.is_empty():
		sim.step()


func _procs(sim: ArenaSim, id: String) -> Array:
	return sim.trace.filter(func(event: Dictionary): return event.kind == "relic_proc" and event.tile == id)


func _check(passed: bool, message: String) -> void:
	if not passed:
		failures.append(message)
