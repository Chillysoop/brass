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
	_check_guard_relay()
	_check_flanking_standard()
	_check_switchback_lens()
	_check_longshot_prism()
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Eight timeline relics passed timing, targeting, positioning, and loop budget checks.")
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


func _check_guard_relay() -> void:
	var pair := _sim("guard_relay", [[_tile("rally_guard", 0)], [_tile("rally_guard", 2)], []])
	var base: int = ArenaSim.TILES.rally_guard.guard
	var bonus := ArenaSim.GUARD_RELAY_GUARD
	pair.units[2].hp = 0
	_advance(pair, 2 * BEAT - 1)
	_check(_procs(pair, "guard_relay").is_empty() and pair.units[1].guard == 0,
		"Guard Relay should wait for the tile's right edge.")
	pair.step()
	var procs := _procs(pair, "guard_relay")
	_check(procs.size() == 1 and procs[0].source_tile == "rally_guard" and procs[0].tick == 2 * BEAT
		and procs[0].amount == 2 * bonus and pair.units[0].guard == base + bonus
		and pair.units[1].guard == base + bonus and pair.units[2].guard == 0,
		"An allied Guard grant should give both living heroes four extra and identify its tile in Battle Review.")
	for hero_index in [0, 1]:
		pair.units[hero_index].guard = 0
	_advance(pair, 4 * BEAT)
	_check(_procs(pair, "guard_relay").size() == 1 and pair.units[0].guard == base and pair.units[1].guard == base,
		"Guard Relay's once-per-loop limit should be shared across the party.")
	_advance(pair, LOOP + 2 * BEAT)
	_check(_procs(pair, "guard_relay").size() == 2, "Guard Relay should refresh in the next loop.")

	var capped := _sim("guard_relay", [[], [_tile("shield_chorus", 0)]])
	var chorus: int = ArenaSim.TILES.shield_chorus.guard
	capped.units[0].guard = ArenaSim.MAX_GUARD - chorus - 2
	capped.units[1].guard = ArenaSim.MAX_GUARD - chorus + 1
	_advance(capped, 4 * BEAT)
	procs = _procs(capped, "guard_relay")
	_check(procs.size() == 1 and procs[0].amount == 2 and capped.units[0].guard == ArenaSim.MAX_GUARD
		and capped.units[1].guard == ArenaSim.MAX_GUARD,
		"Calculate the extra Guard after all of the tile's own party grants have reached their recipients.")
	var solo := _sim("guard_relay", [[_tile("guard", 0), _tile("rally_guard", 2)], []])
	solo.units[1].hp = 0
	_advance(solo, 4 * BEAT)
	_check(_procs(solo, "guard_relay").is_empty() and solo.units[1].guard == 0,
		"Self Guard and fallback on a fallen ally must leave Guard Relay unused.")


func _check_flanking_standard() -> void:
	var staggered := [[_tile("shot", 0), _tile("shot", 4)], [_tile("shot", 2), _tile("shot", 6)]]
	var sim := _flank_fixture(staggered)
	var control := _sim("", staggered)
	control.units[0].pos = sim.units[0].pos
	control.units[1].pos = sim.units[1].pos
	_advance(sim, 4 * BEAT - 1)
	_check(_procs(sim, "flanking_standard").is_empty(), "The second attack must finish before the flank pays out.")
	sim.step()
	_advance(control, 4 * BEAT)
	var procs := _procs(sim, "flanking_standard")
	_check(procs.size() == 1 and procs[0].amount == ArenaSim.FLANKING_STANDARD_DAMAGE and procs[0].tick == 4 * BEAT
		and procs[0].lane == 1 and procs[0].source_tile == "shot" and procs[0].from == sim.units[1].pos
		and sim.activations[-1].relics[0].source_beat == 2 and sim.units[2].hp < control.units[2].hp,
		"Opposite-side strikes within exactly two beats should add damage to the second hit and identify both tiles.")
	_advance(sim, 8 * BEAT)
	_check(_procs(sim, "flanking_standard").size() == 1, "Only one flank can pay out per loop.")
	_advance(sim, LOOP + 4 * BEAT)
	_check(_procs(sim, "flanking_standard").size() == 2, "The next loop can trigger a new flank.")

	var late := _flank_fixture([[_tile("shot", 0)], [_tile("shot", 3)]])
	var same_side := _flank_fixture([[_tile("shot", 0)], [_tile("shot", 1)]])
	same_side.units[1].pos = Vector2(375, 330)
	var late_death := _flank_fixture([[_tile("shot", 0)], [_tile("shot", 1)]])
	_advance(late_death, 2 * BEAT)
	late_death.units[0].hp = 0
	for pair in [late, same_side, late_death]:
		_advance(pair, 5 * BEAT)
		_check(_procs(pair, "flanking_standard").is_empty(),
			"A late shot, a same-side shot, or losing the first hero before the follow-up must leave the bonus unused.")
	var split := _sim("flanking_standard", [[_tile("shot", 0)], [_tile("shot", 1)]], "elite")
	split.units[1].pos = Vector2(800, 265)
	_advance(split, 3 * BEAT)
	_check(split.activations[0].target != split.activations[1].target and _procs(split, "flanking_standard").is_empty(),
		"A separate target cannot complete another hero's flank.")
	var wrap := _flank_fixture([[_tile("shot", 10)], [_tile("shot", 0)]])
	_advance(wrap, LOOP + 2 * BEAT)
	procs = _procs(wrap, "flanking_standard")
	_check(procs.size() == 1 and procs[0].tick == LOOP + 2 * BEAT,
		"Count the two-beat window across the loop boundary and spend the follow-up loop's budget.")
	var blink := _flank_fixture([[_tile("shot", 0)], [_tile("blink", 0)]])
	blink.units[1].pos = Vector2(350, 325)
	_advance(blink, 3 * BEAT)
	procs = _procs(blink, "flanking_standard")
	_check(procs.size() == 1 and procs[0].source_tile == "blink" and procs[0].from == blink.units[1].pos,
		"Blink can complete a flank from its landing position when both heroes started in front.")


func _flank_fixture(lanes: Array) -> ArenaSim:
	var sim := _sim("flanking_standard", lanes)
	sim.units[0].pos = Vector2(330, 265)
	sim.units[1].pos = Vector2(630, 265)
	return sim


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
