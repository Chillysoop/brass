extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const Duo = preload("res://scripts/brass_vanguard_cannon.gd")
const BEAT := ArenaSim.TICKS_PER_BEAT

var failures: Array[String] = []


func _initialize() -> void:
	_check_formation_and_replay()
	_check_charge_timing_and_contact()
	_check_charge_obstruction()
	_check_shell_timing_and_splash()
	_check_disrupted_aim()
	_check_surviving_boss()
	for message in failures:
		printerr(message)
	if failures.is_empty():
		print("Vanguard and Cannon pass seeded replay, swept dash, fixed shell aim, and independent defeat checks.")
	quit(0 if failures.is_empty() else 1)


func _check_formation_and_replay() -> void:
	var forward := ArenaSim.new()
	var flank := ArenaSim.new()
	var flipped := ArenaSim.new()
	var replay := ArenaSim.new()
	forward.start([[], [], []], "solo", _encounter(0))
	flank.start([[], [], []], "solo", _encounter(1))
	flipped.start([[], [], []], "solo", _encounter(3))
	replay.start([[], [], []], "solo", _encounter(1))
	_check(forward.units.size() == 5 and forward.units[3].attack_id == Duo.VANGUARD and forward.units[4].attack_id == Duo.CANNON
		and forward.units[3].pos.x < forward.units[4].pos.x and flank.units[3].pos.x > flank.units[4].pos.x
		and flank.units[3].pos.y < flank.units[4].pos.y and flipped.units[3].pos.y > flipped.units[4].pos.y
		and flank.units[3].next_attack > forward.units[3].next_attack,
		"The boss ID must spawn two independent targets and a saved seed must choose the forward body and flank.")
	_advance(flank, 5 * BEAT)
	_advance(replay, 5 * BEAT)
	_check(flank.trace == replay.trace and flank.units[3].pos == replay.units[3].pos and flank.units[4].intent == replay.units[4].intent,
		"Starting the same encounter again must reproduce movement and the committed intent from the checkpoint seed.")
	var original := ArenaSim.new()
	original.start([[], [], []], "solo", _encounter(0, "iron_regent"))
	_check(original.units.size() == 4 and original.units[3].attack_id == "regent" and original.units[3].max_hp == 1140,
		"The legacy Iron Regent must still load with its own single-body encounter.")


func _check_charge_timing_and_contact() -> void:
	var sim := _fixture()
	var leader: Dictionary = sim.units[3]
	leader.next_attack = 5
	_advance(sim, leader.next_attack)
	var origin: Vector2 = leader.pos
	var fixed_end: Vector2 = leader.pilot_aim_point
	var release: int = leader.intent_tick
	_check(leader.intent == sim.units[0].id and leader.intent_attack_id == Duo.CHARGE
		and release == sim.tick + int(leader.attack.windup), "The Vanguard selects its nearest hero and visibly winds up.")
	sim.units[0].pos = Vector2(400, 110)
	sim.units[1].pos = Vector2(468, 260)
	_advance(sim, release - 1)
	_check(leader.pos == origin and leader.pilot_aim_point == fixed_end and _events(sim, "charge", Duo.CHARGE).is_empty(),
		"A dodging hero must not move the locked lane or release an early dash.")
	sim.step()
	var charges := _events(sim, "charge", Duo.CHARGE)
	var contacts := _attack_hits(sim, Duo.CHARGE)
	var intercepted: Dictionary = sim.units[1]
	var body_clearance: float = leader.radius + intercepted.radius + 2.98
	_check(charges.size() == 1 and charges[0].tick == release and charges[0].route == PackedVector2Array([origin, leader.pos])
		and leader.pos.distance_to(intercepted.pos) >= body_clearance and leader.pos != fixed_end,
		"The actual charge must collide with a body and report the clipped route without overlap.")
	_check(contacts.size() == 1 and contacts[0].target == intercepted.id and intercepted.hp == 100 - leader.attack.damage
		and intercepted.impulse.length() > 0.0 and sim.units[0].hp == 100 and _enemy_cast(sim, Duo.CHARGE).landed,
		"The first hero standing on the route takes the real knockback strike in place of the evading mark.")


func _check_charge_obstruction() -> void:
	var sim := _fixture()
	var leader: Dictionary = sim.units[3]
	var cannon: Dictionary = sim.units[4]
	leader.next_attack = 4
	_advance(sim, leader.next_attack)
	var planned: Vector2 = leader.pilot_aim_point
	cannon.pos = Vector2(535, 260)
	_advance(sim, leader.intent_tick)
	var charge := _events(sim, "charge", Duo.CHARGE)
	var clearance: float = leader.radius + cannon.radius + 2.98
	_check(charge.size() == 1 and leader.pos != planned and leader.pos.distance_to(cannon.pos) >= clearance
		and _events(sim, "miss", Duo.CHARGE).size() == 1 and not _enemy_cast(sim, Duo.CHARGE).landed
		and _attack_hits(sim, Duo.CHARGE).is_empty(),
		"The Cannon's body can clip its partner's dash without damage reaching a hero beyond it.")


func _check_shell_timing_and_splash() -> void:
	var sim := _fixture()
	var cannon: Dictionary = sim.units[4]
	cannon.pos = Vector2(805, 340)
	sim.units[0].pos = Vector2(570, 175)
	sim.units[1].pos = Vector2(525, 426)
	sim.units[2].pos = Vector2(245, 340)
	cannon.next_attack = 3
	_advance(sim, cannon.next_attack)
	var origin: Vector2 = cannon.pilot_aim_origin
	var fixed_end: Vector2 = cannon.pilot_aim_point
	var release: int = cannon.intent_tick
	_check(cannon.intent == sim.units[2].id and cannon.intent_attack_id == Duo.SHOT
		and release == sim.tick + int(cannon.attack.windup), "The Cannon must show its own longer charge aimed at the farthest hero.")
	sim.units[0].pos = Vector2(580, 348)
	sim.units[1].pos = Vector2(535, 416)
	sim.units[2].pos = Vector2(245, 155)
	sim.units[0].guard = 10
	_advance(sim, release - 1)
	_check(cannon.pilot_aim_point == fixed_end and _attack_hits(sim, Duo.SHOT).is_empty(), "The shell fires only on its own fixed-lane endpoint.")
	sim.step()
	var hits := _attack_hits(sim, Duo.SHOT)
	var impact := _events(sim, Duo.IMPACT, Duo.SHOT)
	var cue := _enemy_cast(sim, Duo.SHOT)
	_check(hits.size() == 2 and hits[0].target == sim.units[0].id and hits[0].attack_component == "contact"
		and hits[0].amount == cannon.attack.damage - 10 and hits[1].target == sim.units[1].id
		and hits[1].attack_component == "splash" and hits[1].amount == cannon.attack.splash_damage and sim.units[2].hp == 100,
		"The first hero on the locked ray takes the blockable shell while only the nearby hero takes splash.")
	_check(impact.size() == 1 and impact[0].from == Vector2(580, 340) and impact[0].radius == cannon.attack.splash_radius
		and cue.from == origin and cue.to == impact[0].from and cue.landed,
		"The regular projectile cue and burst circle must share the actual impact point on the original lane.")


func _check_disrupted_aim() -> void:
	var sim := _fixture()
	var captain: Dictionary = sim.units[3]
	var cannon: Dictionary = sim.units[4]
	captain.next_attack = 5
	cannon.next_attack = 5
	_advance(sim, 5)
	var pending: int = captain.intent_tick
	var firing: int = cannon.intent_tick
	var origin: Vector2 = cannon.pilot_aim_origin
	sim._displace("pull", sim.units[0], cannon, "pull", Vector2.UP, 1050.0)
	while not cannon.intent.is_empty() and sim.tick < firing:
		sim.step()
	var counter := _events(sim, "interrupt", Duo.DISRUPTED)
	_check(counter.size() == 1 and counter[0].actor == cannon.id and counter[0].target == cannon.id
		and counter[0].attack_id == Duo.SHOT and origin.distance_to(cannon.pos) >= cannon.attack.alignment
		and captain.intent_tick == pending and captain.intent_attack_id == Duo.CHARGE,
		"A real pull can break the Cannon's alignment without canceling the Captain's attack.")
	cannon.next_attack = 99999
	_advance(sim, firing)
	_check(_events(sim, Duo.IMPACT, Duo.SHOT).is_empty() and _events(sim, "charge", Duo.CHARGE).size() == 1,
		"A canceled shell cannot release, while the other boss remains fully active.")


func _check_surviving_boss() -> void:
	for victim_index in [3, 4]:
		var sim := _fixture()
		var victim: Dictionary = sim.units[victim_index]
		var survivor: Dictionary = sim.units[7 - victim_index]
		victim.next_attack = 5
		survivor.next_attack = 5
		_advance(sim, 5)
		sim._damage(sim.units[0], victim, victim.hp, "test_strike")
		var surviving_cue: String = survivor.intent_attack_id
		var dead_cue: String = victim.intent_attack_id
		var survivor_tick: int = survivor.intent_tick
		_advance(sim, 5 + maxi(int(victim.attack.windup), int(survivor.attack.windup)))
		_check(sim.outcome.is_empty() and victim.hp == 0 and survivor.hp == survivor.max_hp
			and _attack_hits(sim, dead_cue).is_empty() and not _attack_hits(sim, surviving_cue).is_empty()
			and _attack_hits(sim, surviving_cue)[0].tick == survivor_tick,
			"Either boss can die first; only the survivor's existing windup may release.")
		sim._damage(sim.units[1], survivor, survivor.hp, "test_strike")
		sim.step()
		_check(sim.outcome == "victory", "Defeating both bodies by ordinary damage must end the fight.")


func _fixture() -> ArenaSim:
	var sim := ArenaSim.new()
	sim.start([[], [], []], "solo", _encounter(0))
	var positions := [Vector2(420, 260), Vector2(335, 145), Vector2(295, 426), Vector2(625, 260), Vector2(785, 363)]
	for index in range(sim.units.size()):
		var unit: Dictionary = sim.units[index]
		unit.pos = positions[index]
		unit.next_attack = 99999
		unit.speed = 0.0
	return sim


func _encounter(seed: int, boss := Duo.BOSS_ID) -> Dictionary:
	return {"encounter": "boss", "location": "brass", "segment": 3, "boss_id": boss, "difficulty": "hard", "seed": seed,
		"heroes": [{"hero": "warden"}, {"hero": "duelist"}, {"hero": "starshot"}]}


func _advance(sim: ArenaSim, until: int) -> void:
	while sim.tick < until and sim.outcome.is_empty():
		sim.step()


func _events(sim: ArenaSim, kind: String, tile: String) -> Array:
	return sim.trace.filter(func(event: Dictionary): return event.kind == kind and event.tile == tile)


func _attack_hits(sim: ArenaSim, cue: String) -> Array:
	return sim.trace.filter(func(event: Dictionary): return event.kind == "hit" and event.get("attack_id") == cue)


func _enemy_cast(sim: ArenaSim, cue: String) -> Dictionary:
	for event: Dictionary in sim.visual_cues:
		if event.kind == "enemy_cast" and event.tile == cue:
			return event
	return {"landed": false, "from": Vector2.INF, "to": Vector2.INF}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
