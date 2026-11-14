extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const BEAT := ArenaSim.TICKS_PER_BEAT

var failures: Array[String] = []


func _initialize() -> void:
	_check_mark()
	_check_retreat()
	_check_support()
	_check_windup()
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Combat tile timing, cross-hero marks, retreat, and support checks passed.")
	quit(0 if failures.is_empty() else 1)


func _check_mark() -> void:
	var sim := _sim([[_tile("signal_flare", 0)], [_tile("jab", 4), _tile("jab", 5)]])
	var foe: Dictionary = sim.units[2]
	_advance(sim, 2 * BEAT - 1)
	_check(not foe.has("arsenal_mark") and sim.activations.is_empty(),
		"Signal Flare must wait for its right edge before hitting or marking.")
	sim.step()
	_check(foe.arsenal_mark.expires == 5 * BEAT, "A mark should last through the third beat after it lands.")
	_advance(sim, 6 * BEAT)
	var spent := sim.trace.filter(func(event: Dictionary): return event.kind == "mark_spent")
	_check(spent.size() == 1 and spent[0].tick == 5 * BEAT and spent[0].actor == sim.units[1].id
		and sim.activations[1].damage == ArenaSim.TILES.jab.damage + 7
		and sim.activations[2].damage == ArenaSim.TILES.jab.damage,
		"Another hero's one-beat Jab can spend the mark at the boundary, once.")
	var late := _sim([[_tile("signal_flare", 0)], [_tile("jab", 5)]])
	_advance(late, 6 * BEAT)
	_check(late.activations[-1].damage == ArenaSim.TILES.jab.damage,
		"A hit a beat after the mark expires gets ordinary damage.")


func _check_retreat() -> void:
	var sim := _sim([[_tile("retreat_shot", 0)]])
	var hero: Dictionary = sim.units[0]
	var foe: Dictionary = sim.units[1]
	var origin: Vector2 = hero.pos
	var target: Vector2 = foe.pos
	_advance(sim, 2 * BEAT)
	var events := sim.trace.filter(func(event: Dictionary): return event.tile == "retreat_shot")
	_check(events.size() == 2 and events[0].kind == "hit" and events[1].kind == "retreat"
		and events[1].from == origin and events[1].to == hero.pos
		and origin.distance_to(target) + 71.0 < target.distance_to(hero.pos),
		"Retreat Shot must deal damage from the original point, then create distance.")


func _check_support() -> void:
	var sim := _sim([[_tile("field_dressing", 0, "self")], [_tile("bulwark_bell", 0, "self")]])
	var first: Dictionary = sim.units[0]
	var second: Dictionary = sim.units[1]
	second.hp = 48
	_advance(sim, 3 * BEAT)
	_check(second.hp == 58 and first.hp == first.max_hp and first.guard == 9 and second.guard == 15,
		"Field Dressing must heal and protect the weakest living ally, and Bulwark Bell protects the party.")
	second.hp = 45
	_advance(sim, ArenaSim.LOOP_TICKS + 3 * BEAT)
	_check(second.hp == 45 and sim.trace.filter(func(event: Dictionary): return event.kind == "heal").size() == 1,
		"Field Dressing keeps granting Guard without healing again every loop.")


func _check_windup() -> void:
	var sim := _sim([[_tile("rivet_bolt", 0)]])
	var foe: Dictionary = sim.units[1]
	foe.intent = sim.units[0].id
	foe.intent_tick = 3 * BEAT
	_advance(sim, 2 * BEAT)
	_check(sim.activations[-1].damage == ArenaSim.TILES.rivet_bolt.damage + 9,
		"Rivet Bolt should use the actual active windup at its right edge.")
	var idle := _sim([[_tile("rivet_bolt", 0)]])
	_advance(idle, 2 * BEAT)
	_check(idle.activations[-1].damage == ArenaSim.TILES.rivet_bolt.damage,
		"Rivet Bolt's bonus should require an active windup.")


func _sim(lanes: Array) -> ArenaSim:
	var heroes: Array = []
	for index in range(lanes.size()):
		heroes.append({"hero": "warden"})
	var sim := ArenaSim.new()
	sim.start(lanes, "solo", {"encounter": "opening", "heroes": heroes})
	for unit: Dictionary in sim.units:
		unit.speed = 0.0
		unit.next_attack = 99999
		if unit.side == "enemy":
			unit.pos = Vector2(375, 265)
			unit.prev_pos = unit.pos
			unit.hp = 220
			unit.max_hp = 220
	return sim


func _tile(id: String, start: int, target := "nearest") -> Dictionary:
	return {"id": id, "start": start, "target": target}


func _advance(sim: ArenaSim, target_tick: int) -> void:
	while sim.tick < target_tick and sim.outcome.is_empty():
		sim.step()


func _check(passed: bool, message: String) -> void:
	if not passed:
		failures.append(message)
