extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const BEAT := ArenaSim.TICKS_PER_BEAT

var failures: Array[String] = []


func _initialize() -> void:
	_check_mark()
	_check_retreat()
	_check_travel_tiles()
	_check_support()
	_check_windup()
	_check_class_attack_bonuses()
	_check_class_support()
	_check_displacement_window()
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Combat tile timing, marks, retreat, support, and class damage bonus checks passed.")
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
		and origin.distance_to(target) + 124.0 < target.distance_to(hero.pos),
		"Retreat Shot must deal damage from the original point, then create distance.")


func _check_travel_tiles() -> void:
	var dash := _sim([[_tile("shoulder_check", 0)], []])
	dash.units[0].pos = Vector2(200, 265)
	dash.units[1].pos = Vector2(446, 265)
	dash.units[2].pos = Vector2(520, 265)
	_advance(dash, 3 * BEAT - 1)
	_check(dash.units[0].pos == Vector2(200, 265), "Shoulder Check holds position before its firing beat.")
	dash.step()
	var charges := dash.trace.filter(func(event: Dictionary): return event.kind == "charge")
	_check(charges.size() == 1 and charges[0].tick == 3 * BEAT
		and absf(dash.units[0].pos.y - 265.0) > 40.0 and dash.units[0].pos.x > 450.0
		and dash.activations[-1].damage == ArenaSim.TILES.shoulder_check.damage,
		"Shoulder Check finds a clear angle around the blocking ally and hits on the tile edge.")
	var blink := _sim([[_tile("blink", 0)]])
	blink.units[0].pos = Vector2(190, 265)
	blink.units[1].pos = Vector2(705, 265)
	_advance(blink, 3 * BEAT)
	var teleports := blink.trace.filter(func(event: Dictionary): return event.kind == "teleport")
	_check(teleports.size() == 1 and teleports[0].tick == 3 * BEAT
		and blink.units[0].pos.x > blink.units[1].pos.x and blink.units[0].pos.x > 750.0,
		"Blink crosses more than half the arena and lands behind its target on the tile edge.")


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


func _check_class_attack_bonuses() -> void:
	var counter: Dictionary = ArenaSim.TILES.iron_arc
	var edge: int = counter.width * BEAT
	var protected := _sim([[_tile("iron_arc", 0)]])
	_advance(protected, edge - 1)
	_check(protected.activations.is_empty(), "Iron Arc must wait until the tile's right edge.")
	protected.units[0].guard = 1
	protected.step()
	var exposed := _sim([[_tile("iron_arc", 0)]])
	_advance(exposed, edge)
	_check(protected.activations[-1].damage == counter.damage + counter.guard_bonus
		and exposed.activations[-1].damage == counter.damage,
		"Iron Arc checks the caster's Guard when it lands.")
	var shot: Dictionary = ArenaSim.TILES.horizon_round
	for distance in [210.0, 211.0]:
		var sim := _sim([[_tile("horizon_round", 0)]])
		sim.units[1].pos = sim.units[0].pos + Vector2(distance, 0)
		_advance(sim, shot.width * BEAT)
		var expected: int = shot.damage + (shot.distance_bonus if distance > 210.0 else 0)
		_check(sim.activations[-1].damage == expected, "Horizon Round gains distance damage strictly beyond 210 px.")


func _check_class_support() -> void:
	var triage: Dictionary = ArenaSim.TILES.triage_kit
	var lantern: Dictionary = ArenaSim.TILES.ward_lantern
	var sim := _sim([[_tile("triage_kit", 0, "self")], [_tile("ward_lantern", 0, "self")]])
	var second: Dictionary = sim.units[1]
	second.hp = 45
	_check(sim.target_for(0, "triage_kit", "self").get("id") == second.id,
		"Triage Kit previews the weakest ally as its target.")
	var edge := maxi(triage.width, lantern.width) * BEAT
	_advance(sim, edge)
	var expected_hp: int = 45 + triage.heal + lantern.heal
	_check(second.hp == expected_hp and second.guard == mini(28, triage.guard + lantern.guard)
		and sim.units[0].guard == lantern.guard,
		"Triage Kit heals and shields the weakest ally while Ward Lantern shields both heroes and heals its caster.")
	_advance(sim, ArenaSim.LOOP_TICKS + edge)
	_check(second.hp == expected_hp, "Triage Kit and Ward Lantern each heal only once per fight.")


func _check_displacement_window() -> void:
	var rake: Dictionary = ArenaSim.TILES.rake
	var push_beat: int = ArenaSim.TILES.bash.width
	for gap in [0, 3, 4]:
		var rake_beat: int = push_beat + gap
		var sim := _sim([[_tile("bash", 0)], [_tile("rake", rake_beat - rake.width)]])
		_advance(sim, push_beat * BEAT)
		var foe: Dictionary = sim.units[2]
		_check(foe.get("displaced_until", -1) == (push_beat + 3) * BEAT,
			"A hostile push starts a three-beat displacement window.")
		foe.impulse = Vector2.ZERO
		_advance(sim, rake_beat * BEAT)
		var expected: int = rake.damage + (rake.displaced_bonus if gap <= 3 else 0)
		_check(sim.activations[-1].damage == expected,
			"Rake gets its displacement bonus through the third beat, then it expires.")


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
