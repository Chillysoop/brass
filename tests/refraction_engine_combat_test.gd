extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const GlassEnemies = preload("res://scripts/glass_pilot_enemies.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_check_telegraphs()
	_check_displacement_and_guard()
	_check_distinct_builds()
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Refraction Engine beam, discharge, counters, and two Easy builds passed.")
	quit(0 if failures.is_empty() else 1)


func _check_telegraphs() -> void:
	var sim := _stationary([])
	var hero: Dictionary = sim.units[0]
	var engine: Dictionary = sim.units[1]
	_check(engine.get("attack_id") == GlassEnemies.REFRACTION_ENGINE, "Spawn the selected Glass boss.")
	_advance(sim, engine.attack.first)
	_check(engine.get("intent_attack_id") == GlassEnemies.REFRACTION_BEAM and engine.has("pilot_aim_point"),
		"The Engine must mark the beam during windup.")
	var aim: Vector2 = engine.pilot_aim_point
	hero.pos += Vector2(0, 50)
	_advance(sim, engine.intent_tick - 1)
	_check(engine.pilot_aim_point == aim and hero.hp == 100, "The beam must stay on the marked line and wait for release.")
	sim.step()
	_check(hero.hp == 100 and not engine.has("pilot_aim_point") and _review_success(sim, GlassEnemies.REFRACTION_BEAM),
		"Leaving the marked line avoids the shot and adds feedback to Battle Review.")
	_advance(sim, engine.next_attack)
	_check(engine.intent_attack_id == GlassEnemies.REFRACTION_DISCHARGE and engine.has("pilot_ring_radius"),
		"A nearby hero gets a telegraph for the follow-up discharge.")
	_advance(sim, engine.intent_tick - 1)
	_check(hero.hp == 100, "The discharge must also wait for release.")
	sim.step()
	_check(hero.hp < 100 and not engine.has("pilot_ring_radius"), "The discharge must hit heroes still inside its ring.")


func _check_displacement_and_guard() -> void:
	var pushed := _stationary([{"id": "bash", "start": 4}])
	var engine: Dictionary = pushed.units[1]
	_advance(pushed, int(engine.attack.first) + int(engine.attack.windup))
	_check(pushed.units[0].hp == 100 and _review_success(pushed, GlassEnemies.REFRACTION_BROKEN),
		"Bash during windup knocks the lens out of alignment and prevents the beam.")
	var guarded := _stationary([{"id": "guard", "start": 6}])
	guarded.units[0].guard = 7
	_advance(guarded, int(engine.attack.first) + int(engine.attack.windup))
	_check(guarded.units[0].hp == 100 and guarded.units[0].guard == 0,
		"A Guard tile resolving on the beam's release beat can absorb the attack.")


func _check_distinct_builds() -> void:
	var melee := _fight("warden", ["bash", "guard", "slam", "shot"])
	var timed := _fight("warden", ["guard", "slam", "bash", "shot"])
	var ranged := _fight("starshot", ["rivet_bolt", "retreat_shot", "spark_shot", "guard", "sundering_bolt"])
	_check(timed.outcome == "victory" and timed.units[0].hp > melee.units[0].hp,
		"Changing the same Warden tiles can preserve health by countering the Engine.")
	_check(ranged.outcome == "victory", "A separate ranged build must also be viable.")


func _fight(hero: String, tiles: Array) -> ArenaSim:
	var entries := []
	var beat := 0
	for id: String in tiles:
		entries.append({"id": id, "start": beat})
		beat += int(ArenaSim.TILES[id].width)
	var sim := _start(entries, hero)
	_advance(sim, 3600)
	return sim


func _stationary(entries: Array) -> ArenaSim:
	var sim := _start(entries, "warden")
	for unit: Dictionary in sim.units:
		unit.speed = 0.0
	sim.units[0].hp = 100
	sim.units[0].pos = Vector2(285, 265)
	sim.units[1].pos = Vector2(425, 265)
	return sim


func _start(entries: Array, hero: String) -> ArenaSim:
	var sim := ArenaSim.new()
	sim.start([entries], "solo", {"location": "glass", "difficulty": "easy", "encounter": "boss",
		"boss_id": GlassEnemies.REFRACTION_ENGINE, "hero": hero, "hp": 80, "seed": 42})
	return sim


func _advance(sim: ArenaSim, end_tick: int) -> void:
	while sim.tick < end_tick and sim.outcome.is_empty():
		sim.step()


func _review_success(sim: ArenaSim, id: String) -> bool:
	return sim.boss_events.any(func(event: Dictionary) -> bool: return event.tile == id and event.stage == "success")


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
