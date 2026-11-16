extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const Repairmaster = preload("res://scripts/brass_repairmaster.gd")
const BEAT := ArenaSim.TICKS_PER_BEAT

var failures: Array[String] = []


func _initialize() -> void:
	_check_spawns()
	_check_dash_and_finite_repairs()
	_check_burst_counter()
	_check_burst_at_tile_edge()
	_check_displacement_and_destroying_drones()
	_check_blocked_dash()
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Repairmaster spawn, dash timing, finite repairs, and three interruption paths passed.")
	quit(0 if failures.is_empty() else 1)


func _check_spawns() -> void:
	var medium := ArenaSim.new()
	medium.start([[], []], "solo", _encounter("medium", Repairmaster.BOSS_ID))
	var hard := ArenaSim.new()
	hard.start([[], []], "solo", _encounter("hard", Repairmaster.BOSS_ID))
	_check(medium.units.size() == 5 and medium.units[2].attack_id == Repairmaster.BOSS_ID
		and medium.units[2].name == "The Repairmaster" and medium.units[2].hp == 680
		and medium.units[2].attack.damage == 27 and medium.units[2].attack.cooldown == 108
		and medium.units[3].attack_id == Repairmaster.DRONE_ID and medium.units[4].attack_id == Repairmaster.DRONE_ID
		and medium.units[3].hp == 58 and medium.units[3].attack.damage == 5
		and hard.units[2].hp == 980 and hard.units[2].max_hp == 980 and hard.units[2].attack.damage == 41
		and hard.units[2].attack.cooldown == 104 and hard.units[3].hp == 72 and hard.units[3].attack.damage == 6,
		"The selected boss must spawn a Repairmaster and two scaled repair drones.")
	_check(medium.units[3].pos.x - medium.units[2].pos.x >= 100.0
		and medium.units[4].pos.x - medium.units[2].pos.x >= 100.0
		and medium.units[3].pos.y < medium.units[2].pos.y and medium.units[4].pos.y > medium.units[2].pos.y,
		"Both drones must read behind the boss without overlapping its spawn silhouette.")
	var marshal := ArenaSim.new()
	marshal.start([[], []], "solo", _encounter("medium", "gilded_marshal"))
	_check(marshal.units.size() == 3 and marshal.units[2].attack_id == "marshal" and marshal.units[2].hp == 860,
		"The original Marshal must remain available with its existing Medium stats.")


func _check_dash_and_finite_repairs() -> void:
	var sim := _fixture()
	var boss: Dictionary = sim.units[2]
	var first: Dictionary = sim.units[3]
	var second: Dictionary = sim.units[4]
	var origin: Vector2 = boss.pos
	_begin_repair_order(sim)
	_check(boss.intent == first.id and boss.intent_attack_id == Repairmaster.DASH and not first.repairmaster_charge
		and second.repairmaster_charge and boss.intent_tick == sim.tick + Repairmaster.DASH_BEATS * BEAT,
		"The 70% threshold telegraphs the closest charged drone and spends only its charge.")
	var dash_tick: int = boss.intent_tick
	var committed_landing: Vector2 = boss.repairmaster_dash_landing
	_advance(sim, dash_tick - 1)
	_check(boss.pos == origin and _events(sim, "charge", Repairmaster.DASH).is_empty(),
		"The Repairmaster must stay at the start until the telegraphed dash resolves.")
	sim.step()
	var dash := _events(sim, "charge", Repairmaster.DASH)
	_check(dash.size() == 1 and dash[0].tick == dash_tick and dash[0].from == origin and dash[0].to == committed_landing
		and dash[0].route == PackedVector2Array([origin, committed_landing]) and boss.pos == committed_landing
		and boss.intent_attack_id == Repairmaster.REPAIR and boss.intent_tick == dash_tick + Repairmaster.REPAIR_BEATS * BEAT,
		"The real swept dash should reach its announced position and start the second windup on the same tick.")
	var repair_tick: int = boss.intent_tick
	var wounded_hp: int = boss.hp
	_advance(sim, repair_tick - 1)
	_check(boss.hp == wounded_hp and _events(sim, "heal", Repairmaster.REPAIR).is_empty(),
		"Repairs must wait until the visibly charged repair tick.")
	sim.step()
	var heals := _events(sim, "heal", Repairmaster.REPAIR)
	_check(heals.size() == 1 and heals[0].tick == repair_tick and heals[0].actor == first.id and heals[0].target == boss.id
		and heals[0].amount == Repairmaster.HEAL_AMOUNT and boss.hp == wounded_hp + Repairmaster.HEAL_AMOUNT,
		"The docked drone supplies the finite repair on the exact release tick.")
	_check(sim.boss_events.any(func(event: Dictionary): return event.tile == Repairmaster.COMPLETED),
		"Battle Review should distinguish a completed repair from the windup.")
	boss.hp = floori(float(boss.max_hp) * 0.35)
	_advance(sim, boss.repairmaster_next_order + Repairmaster.DASH_BEATS * BEAT)
	_check(boss.intent == second.id and boss.intent_attack_id == Repairmaster.REPAIR and not second.repairmaster_charge,
		"The second threshold can use a different charged drone after the cooldown.")
	boss.hp = boss.max_hp - 9
	_advance(sim, boss.intent_tick)
	heals = _events(sim, "heal", Repairmaster.REPAIR)
	_check(heals.size() == 2 and heals[-1].amount == 9 and boss.hp == boss.max_hp,
		"A partial repair must cap at maximum health and can never create a third charge.")
	boss.hp = 1
	_advance(sim, sim.tick + 18 * BEAT)
	_check(_events(sim, "heal", Repairmaster.REPAIR).size() == 2 and boss.repairmaster_orders_used == 2,
		"A surviving boss cannot start another repair after both drones have been spent.")


func _check_burst_counter() -> void:
	var sim := _fixture()
	var boss: Dictionary = sim.units[2]
	_begin_repair_order(sim)
	var dash_tick: int = boss.intent_tick
	sim._damage(sim.units[0], boss, Repairmaster.BURST_THRESHOLD, "test_strike")
	_check(boss.intent_attack_id == Repairmaster.DASH and boss.repairmaster_damage_taken == 0,
		"Damage during the dash windup can wound the boss but must leave the next phase's burst counter empty.")
	_advance(sim, dash_tick)
	_check(boss.intent_attack_id == Repairmaster.REPAIR and boss.repairmaster_damage_taken == 0,
		"The burst window opens when the Repairmaster docks.")
	sim._damage(sim.units[0], boss, Repairmaster.BURST_THRESHOLD - 1, "test_strike")
	boss.guard = 7
	sim._damage(sim.units[1], boss, 7, "test_strike")
	_check(boss.intent_attack_id == Repairmaster.REPAIR and boss.repairmaster_damage_taken == Repairmaster.BURST_THRESHOLD - 1,
		"Only actual HP damage should count toward the repair interruption.")
	var repair_tick: int = boss.intent_tick
	sim._damage(sim.units[1], boss, 1, "test_strike")
	var interrupted := _events(sim, "interrupt", Repairmaster.INTERRUPTED)
	_check(boss.intent.is_empty() and interrupted.size() == 1 and interrupted[0].counter == "damage"
		and interrupted[0].counter_actor == sim.units[1].id and boss.next_attack == sim.tick + 2 * BEAT,
		"A different hero's last point of burst damage must cancel the channel and open two beats to attack.")
	_advance(sim, repair_tick)
	_check(_events(sim, "heal", Repairmaster.REPAIR).is_empty(), "A canceled repair cannot resolve after the original end tick.")


func _check_burst_at_tile_edge() -> void:
	var sim := _fixture("medium", [[{"id": "shot", "start": 3}], [{"id": "longshot", "start": 3}]])
	var boss: Dictionary = sim.units[2]
	sim.units[0].pos = Vector2(215, 120)
	sim.units[1].pos = Vector2(230, 405)
	_begin_repair_order(sim)
	var edge := 5 * BEAT
	_advance(sim, edge - 1)
	_check(boss.intent_attack_id == Repairmaster.REPAIR and boss.repairmaster_damage_taken == 0
		and _events(sim, "interrupt", Repairmaster.INTERRUPTED).is_empty(),
		"Charging ranged tiles must not affect the repair counter ahead of their right edge.")
	sim.step()
	var interrupts := _events(sim, "interrupt", Repairmaster.INTERRUPTED)
	_check(interrupts.size() == 1 and interrupts[0].tick == edge and interrupts[0].counter == "damage"
		and interrupts[0].counter_actor == sim.units[1].id,
		"Two ordinary ranged attacks on the same tile edge can end the burst window before the heal.")


func _check_displacement_and_destroying_drones() -> void:
	var pushed := _fixture()
	var boss: Dictionary = pushed.units[2]
	_begin_repair_order(pushed)
	pushed._displace("push", pushed.units[0], boss, "bash", Vector2.LEFT, 600.0)
	var interrupts := _events(pushed, "interrupt", Repairmaster.INTERRUPTED)
	_check(boss.intent.is_empty() and interrupts.size() == 1 and interrupts[0].counter == "displacement",
		"A real push to the Repairmaster must stop the approach.")

	var pulled := _fixture()
	var pull_boss: Dictionary = pulled.units[2]
	_begin_repair_order(pulled)
	_advance(pulled, pull_boss.intent_tick)
	var selected_id: String = pull_boss.intent
	pulled._displace("pull", pulled.units[1], pulled.units[4], "pull", Vector2.LEFT, 600.0)
	_check(pull_boss.intent == selected_id, "Moving the idle drone must leave the active repair link alone.")
	pulled._displace("pull", pulled.units[1], pulled.units[3], "pull", Vector2.LEFT, 600.0)
	interrupts = _events(pulled, "interrupt", Repairmaster.INTERRUPTED)
	_check(pull_boss.intent.is_empty() and interrupts.size() == 1 and interrupts[0].counter == "displacement",
		"Pulling the selected drone far enough must stop the channel.")

	var destroyed := _fixture("medium", [[{"id": "shot", "start": 0}], [{"id": "shot", "start": 0}]])
	var exposed: Dictionary = destroyed.units[2]
	_begin_repair_order(destroyed)
	destroyed._damage(destroyed.units[0], destroyed.units[3], 100, "test_strike")
	interrupts = _events(destroyed, "interrupt", Repairmaster.INTERRUPTED)
	_check(exposed.intent.is_empty() and interrupts.size() == 1 and interrupts[0].counter == "drone_destroyed",
		"Defeating the selected drone should stop repairs immediately.")
	destroyed._damage(destroyed.units[1], destroyed.units[4], 100, "test_strike")
	destroyed.units[0].pos = Vector2(240, 210)
	destroyed.units[1].pos = Vector2(240, 310)
	exposed.hp = 20
	_advance(destroyed, 2 * BEAT)
	_check(destroyed.outcome == "victory" and exposed.repairmaster_orders_used == 1,
		"With both drones gone, ordinary shots must be able to finish the Repairmaster without a special counter.")


func _check_blocked_dash() -> void:
	var sim := _fixture()
	var boss: Dictionary = sim.units[2]
	_begin_repair_order(sim)
	var departure: Vector2 = boss.pos
	var destination: Vector2 = boss.repairmaster_dash_landing
	sim.units[0].pos = departure.lerp(destination, 0.55)
	_advance(sim, boss.intent_tick)
	var interrupts := _events(sim, "interrupt", Repairmaster.INTERRUPTED)
	_check(boss.pos != destination and boss.intent.is_empty() and interrupts.size() == 1
		and interrupts[0].counter == "dash_blocked"
		and _events(sim, "intent", Repairmaster.REPAIR).is_empty(),
		"A body entering the committed route may clip the dash but must prevent the distant repair.")
	var blocker: Vector2 = sim.units[0].pos
	var route_point := Geometry2D.get_closest_point_to_segment(blocker, departure, boss.pos)
	_check(blocker.distance_to(route_point) >= boss.radius + sim.units[0].radius + 2.95,
		"The clipped dash must not pass through the blocker.")


func _fixture(difficulty := "medium", lanes: Array = [[], []]) -> ArenaSim:
	var sim := ArenaSim.new()
	sim.start(lanes, "solo", _encounter(difficulty, Repairmaster.BOSS_ID))
	var positions := [Vector2(105, 120), Vector2(105, 405), Vector2(410, 260), Vector2(670, 150), Vector2(785, 395)]
	for index in range(sim.units.size()):
		sim.units[index].pos = positions[index]
		sim.units[index].speed = 0.0
		sim.units[index].next_attack = 99999
	return sim


func _encounter(difficulty: String, boss: String) -> Dictionary:
	return {"encounter": "boss", "location": "brass", "segment": 2, "boss_id": boss, "difficulty": difficulty,
		"heroes": [{"hero": "warden"}, {"hero": "lancer"}]}


func _begin_repair_order(sim: ArenaSim) -> void:
	var boss: Dictionary = sim.units[2]
	boss.hp = floori(float(boss.max_hp) * 0.7)
	sim.step()


func _advance(sim: ArenaSim, target_tick: int) -> void:
	while sim.tick < target_tick and sim.outcome.is_empty():
		sim.step()


func _events(sim: ArenaSim, kind: String, tile: String) -> Array:
	return sim.trace.filter(func(event: Dictionary): return event.kind == kind and event.tile == tile)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
