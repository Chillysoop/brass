extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const BEAT := ArenaSim.TICKS_PER_BEAT
const LOOP := ArenaSim.LOOP_TICKS

var failures: Array[String] = []


func _initialize() -> void:
	_check_overflow_chalice()
	_check_stepped_gear()
	_check_mercy_seal()
	_check_twin_bell()
	_check_switchback_lens()
	_check_longshot_prism()
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Six timeline relics passed timing, targeting, and loop budget checks.")
	quit(0 if failures.is_empty() else 1)


func _check_overflow_chalice() -> void:
	var guard_line := [_tile("guard", 0), _tile("guard", 2), _tile("guard", 4)]
	var sim := _sim("overflow_chalice", [guard_line, [], []])
	var lead: Dictionary = sim.units[0]
	var recruit: Dictionary = sim.units[1]
	lead.hp = 80
	lead.guard = 23
	recruit.hp = 60
	sim.units[2].hp = 0
	_advance(sim, 2 * BEAT - 1)
	_check(recruit.hp == 60 and lead.guard == 23, "Overflow should wait for Guard's right edge.")
	sim.step()
	_check(lead.guard == ArenaSim.MAX_GUARD and recruit.hp == 65 and lead.hp == 80,
		"Overflow should heal only the excess Guard on the living hero missing the most HP.")
	_advance(sim, 6 * BEAT)
	var procs := _procs(sim, "overflow_chalice")
	_check(procs.size() == 2 and procs[0].amount == 5 and procs[1].amount == 1 and recruit.hp == 66 and sim.units[2].hp == 0,
		"Overflow needs a shared six-HP loop budget and cannot revive a fallen hero.")
	_advance(sim, LOOP + 2 * BEAT)
	_check(recruit.hp == 72 and _procs(sim, "overflow_chalice").size() == 3,
		"Overflow should refresh on the next loop.")
	var solo := _sim("overflow_chalice", [guard_line])
	solo.units[0].hp = 80
	_advance(solo, 4 * BEAT)
	_check(solo.units[0].hp == 80, "Guard under the cap should provide no Overflow healing.")
	_advance(solo, 6 * BEAT)
	_check(solo.units[0].hp == 82, "Excess Guard from the third tile should heal a solo hero.")
	_check(solo.activations[-1].get("effect_details", []).is_empty() and solo.activations[-1].get("relics", []).size() == 1,
		"Battle Review should list the same heal once, under Overflow Chalice.")


func _check_stepped_gear() -> void:
	var adjacent := _sim("stepped_gear", [[_tile("ward_link", 0), _tile("shot", 3), _tile("ward_link", 5), _tile("shot", 8)]])
	var spaced := _sim("stepped_gear", [[_tile("ward_link", 0), _tile("shot", 4)]])
	_advance(adjacent, 5 * BEAT - 1)
	_check(_procs(adjacent, "stepped_gear").is_empty(), "Stepped Gear must wait for the short hit's right edge.")
	adjacent.step()
	var procs := _procs(adjacent, "stepped_gear")
	_check(procs.size() == 1 and procs[0].tick == 5 * BEAT and adjacent.activations[-1].damage == ArenaSim.TILES.shot.damage + 7,
		"A short hit immediately following a wide utility tile should gain seven damage.")
	_check(adjacent.activations[-1].get("relics", [{}])[0].get("source_beat") == 3,
		"Battle Review should link the short hit to the wide tile's finishing beat.")
	_advance(adjacent, 10 * BEAT)
	_advance(spaced, 6 * BEAT)
	_check(_procs(adjacent, "stepped_gear").size() == 1 and _procs(spaced, "stepped_gear").is_empty(),
		"The second pair of the loop and a pair with a gap should deal normal damage.")
	var wrap := _sim("stepped_gear", [[_tile("shot", 0), _tile("ward_link", 9)]])
	_advance(adjacent, LOOP + 5 * BEAT)
	_advance(wrap, LOOP + 2 * BEAT)
	_check(_procs(adjacent, "stepped_gear").size() == 2 and _procs(wrap, "stepped_gear").is_empty(),
		"Stepped Gear refreshes each loop and requires adjacency within one timeline row.")


func _check_mercy_seal() -> void:
	var shots := [_tile("shot", 0), _tile("shot", 2), _tile("shot", 4)]
	var sim := _sim("mercy_seal", [shots])
	var hero: Dictionary = sim.units[0]
	var enemy: Dictionary = sim.units[1]
	enemy.max_hp = 300
	enemy.hp = 89
	_advance(sim, 2 * BEAT)
	_check(hero.guard == 0 and enemy.hp == 75, "Crossing 25% with a hit should set up the following attack.")
	_advance(sim, 4 * BEAT - 1)
	_check(_procs(sim, "mercy_seal").is_empty(), "Mercy Seal must wait for the next right edge.")
	sim.step()
	var procs := _procs(sim, "mercy_seal")
	_check(procs.size() == 1 and procs[0].tick == 4 * BEAT and procs[0].amount == 6 and hero.guard == 6,
		"The first hit on an enemy at exactly 25% HP should grant six Guard.")
	_advance(sim, LOOP + 2 * BEAT)
	_check(hero.guard == 12 and _procs(sim, "mercy_seal").size() == 2, "Mercy Seal should fire once per loop.")
	var capped := _sim("mercy_seal", [shots])
	capped.units[0].guard = ArenaSim.MAX_GUARD
	capped.units[1].hp = 200
	_advance(capped, 2 * BEAT)
	_check(_procs(capped, "mercy_seal").is_empty(), "An attack at full Guard should leave Mercy Seal available.")
	capped.units[0].guard -= 2
	_advance(capped, 4 * BEAT)
	procs = _procs(capped, "mercy_seal")
	_check(procs.size() == 1 and procs[0].amount == 2 and capped.units[0].guard == ArenaSim.MAX_GUARD,
		"Mercy Seal should record the Guard that fits before the cap.")


func _check_twin_bell() -> void:
	var shots := [_tile("shot", 0), _tile("shot", 2)]
	var trio := _sim("twin_bell", [shots, shots, shots])
	_advance(trio, 2 * BEAT - 1)
	_check(_procs(trio, "twin_bell").is_empty(), "Twin Bell should wait for the simultaneous right edges.")
	trio.step()
	var procs := _procs(trio, "twin_bell")
	_check(procs.size() == 1 and procs[0].tick == 2 * BEAT and procs[0].lane == 1 and procs[0].amount == 12,
		"Twin Bell should put the twelve-damage bonus on only the second of three simultaneous hits.")
	_check(trio.activations[1].damage == ArenaSim.TILES.shot.damage + 12 and trio.activations[2].damage == ArenaSim.TILES.shot.damage,
		"Twin Bell should affect damage at impact without claiming the third hero's hit.")
	_advance(trio, LOOP + 2 * BEAT)
	_check(_procs(trio, "twin_bell").size() == 2, "Twin Bell should refresh only when the next loop starts.")
	var offset := _sim("twin_bell", [[_tile("shot", 0)], [_tile("shot", 1)]])
	var split := _sim("twin_bell", [[_tile("shot", 0)], [_tile("shot", 0, "farthest")]], "elite")
	_advance(offset, 3 * BEAT)
	_advance(split, 2 * BEAT)
	_check(_procs(offset, "twin_bell").is_empty() and _procs(split, "twin_bell").is_empty(),
		"A one-beat offset or attacks on different enemies should not trigger Twin Bell.")


func _check_switchback_lens() -> void:
	var sim := _sim("switchback_lens", [[_tile("shot", 0), _tile("bash", 2), _tile("guard", 4),
		_tile("shot", 6, "farthest"), _tile("shot", 8)]], "elite")
	_advance(sim, 8 * BEAT - 1)
	_check(sim.activations[1].status == "miss" and _procs(sim, "switchback_lens").is_empty(),
		"An out-of-range attack or a support tile should not replace the previous damaging hit.")
	sim.step()
	var procs := _procs(sim, "switchback_lens")
	_check(procs.size() == 1 and procs[0].tick == 8 * BEAT and procs[0].target == sim.units[2].id
		and sim.activations[-1].damage == ArenaSim.TILES.shot.damage + 10,
		"Changing the selected target should add ten damage to the second primary hit.")
	_advance(sim, 10 * BEAT)
	_check(_procs(sim, "switchback_lens").size() == 1, "A second target switch in one loop should not proc.")
	var splash := _sim("switchback_lens", [[_tile("split_shot", 0), _tile("split_shot", 2)]], "elite")
	splash.units[2].pos = Vector2(600, 265)
	_advance(splash, 4 * BEAT)
	_check(splash.units[2].hp < splash.units[2].max_hp and _procs(splash, "switchback_lens").is_empty(),
		"Splash hits should not count as changing targets when two direct attacks aimed at the same enemy.")


func _check_longshot_prism() -> void:
	var shots := [_tile("shot", 0), _tile("shot", 2)]
	var far := _sim("longshot_prism", [shots])
	far.units[1].pos = Vector2(285 + ArenaSim.LONGSHOT_PRISM_RANGE, 265)
	_advance(far, 2 * BEAT - 1)
	_check(_procs(far, "longshot_prism").is_empty(), "Longshot Prism must wait for its right edge.")
	far.step()
	_check(_procs(far, "longshot_prism").size() == 1 and far.activations[-1].damage == ArenaSim.TILES.shot.damage + 11,
		"A direct shot at the minimum Prism range should gain eleven damage.")
	_advance(far, LOOP + 2 * BEAT)
	_check(_procs(far, "longshot_prism").size() == 2, "Longshot Prism should grant damage only once in each loop.")
	var close := _sim("longshot_prism", [shots])
	close.units[1].pos = Vector2(285 + ArenaSim.LONGSHOT_PRISM_RANGE - 1.0, 265)
	_advance(close, 4 * BEAT)
	_check(_procs(close, "longshot_prism").is_empty() and close.activations[-1].damage == ArenaSim.TILES.shot.damage,
		"A hit just inside the minimum Prism range should deal normal damage.")


func _sim(relic: String, lanes: Array, encounter := "opening") -> ArenaSim:
	var heroes: Array = []
	for lane in lanes:
		heroes.append({"hero": "warden"})
	var sim := ArenaSim.new()
	sim.start(lanes, "solo", {"encounter": encounter, "heroes": heroes, "relics": [relic]})
	var enemy_index := 0
	for unit: Dictionary in sim.units:
		unit.speed = 0.0
		unit.next_attack = 99999
		if unit.side == "enemy":
			unit.pos = Vector2(480 + 170 * enemy_index, 265)
			unit.max_hp = 1000
			unit.hp = unit.max_hp
			enemy_index += 1
	return sim


func _tile(id: String, start: int, rule := "nearest") -> Dictionary:
	return {"id": id, "start": start, "target": rule}


func _advance(sim: ArenaSim, target_tick: int) -> void:
	while sim.tick < target_tick and sim.outcome.is_empty():
		sim.step()


func _procs(sim: ArenaSim, relic: String) -> Array:
	return sim.trace.filter(func(event: Dictionary): return event.kind == "relic_proc" and event.tile == relic)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
