extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const BrassEnemies = preload("res://scripts/brass_variety_enemies.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_check_attack_cycle()
	_check_shockwave_counters()
	_check_playable_builds()
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Bellmaker attack rotation, timed counters, and two viable builds passed.")
	quit(0 if failures.is_empty() else 1)


func _check_attack_cycle() -> void:
	var sim := _start([])
	var hero: Dictionary = sim.units[0]
	var boss: Dictionary = sim.units[1]
	if boss.get("attack_id") != "brass_bellmaker":
		_check(false, "The Bellmaker must spawn as the Act I alternate.")
		return
	_step_to(sim, int(boss.attack.first))
	_check(boss.intent_attack_id == BrassEnemies.BELLMAKER_RING and boss.has("pilot_ring_radius"),
		"The first windup must warn of a shockwave.")
	_step_to(sim, int(boss.intent_tick) - 1)
	_check(hero.hp == 100, "The shockwave must wait until its windup finishes.")
	sim.step()
	_check(hero.hp == 81 and not boss.has("pilot_ring_radius"), "The shockwave must hit nearby heroes at release.")
	_step_to(sim, boss.next_attack)
	var mark: Vector2 = hero.pos
	_check(boss.get("intent_attack_id") == BrassEnemies.BELLMAKER_SHOT and boss.get("blast_center") == mark,
		"The second move locks its aim to a fixed spot.")
	hero.pos += Vector2(0, 100)
	_step_to(sim, boss.intent_tick)
	_check(hero.hp == 81 and not boss.has("blast_center"), "Moving out of the mark avoids the shot.")
	_check(sim.boss_events.any(func(event: Dictionary) -> bool:
		return event.tile == BrassEnemies.BELLMAKER_SHOT and event.stage == "success"),
		"Avoiding the shot should appear in Battle Review.")
	_step_to(sim, boss.next_attack)
	_check(boss.get("intent_attack_id") == BrassEnemies.BELLMAKER_RING,
		"The Bellmaker returns to the shockwave after a shot.")


func _check_shockwave_counters() -> void:
	var pushed := _start([{"id": "bash", "start": 5}])
	var boss: Dictionary = pushed.units[1]
	if boss.get("attack_id") != "brass_bellmaker":
		return
	_step_to(pushed, int(boss.attack.first) + int(boss.attack.windup))
	_check(pushed.units[0].hp == 100 and boss.hp < boss.max_hp,
		"A Bash during the windup should move the shockwave out of reach.")
	var guarded := _start([{"id": "guard", "start": 6}])
	var hero: Dictionary = guarded.units[0]
	hero.guard = 9
	_step_to(guarded, int(boss.attack.first) + int(boss.attack.windup))
	_check(hero.hp == 100 and hero.guard == 0, "Guard at beat 8 can absorb the shockwave.")


func _check_playable_builds() -> void:
	var melee := _fight("warden", ["bash", "guard", "slam", "shot"])
	var ranged := _fight("starshot", ["rivet_bolt", "retreat_shot", "spark_shot", "guard", "sundering_bolt"])
	_check(melee.outcome == "victory" and ranged.outcome == "victory",
		"Both a melee build and a ranged build can beat the Easy Bellmaker at 80 starting HP.")
	var timed := _fight("warden", ["guard", "slam", "bash", "shot"])
	_check(timed.outcome == "victory" and timed.units[0].hp > melee.units[0].hp,
		"Changing only the Warden's timeline order can prevent damage from the Bellmaker.")


func _fight(hero: String, tiles: Array) -> ArenaSim:
	var lane := []
	var beat := 0
	for tile: String in tiles:
		lane.append({"id": tile, "start": beat})
		beat += int(ArenaSim.TILES[tile].width)
	var sim := ArenaSim.new()
	sim.start([lane], "solo", _encounter(hero))
	_step_to(sim, 3600)
	return sim


func _start(lane: Array) -> ArenaSim:
	var sim := ArenaSim.new()
	sim.start([lane], "solo", _encounter("warden"))
	for unit: Dictionary in sim.units:
		unit.speed = 0.0
	sim.units[0].hp = 100
	sim.units[0].pos = Vector2(285, 265)
	sim.units[1].pos = Vector2(425, 265)
	return sim


func _encounter(hero: String) -> Dictionary:
	return {"location": "brass", "difficulty": "easy", "encounter": "boss", "boss_id": "brass_bellmaker",
		"hero": hero, "hp": 80, "seed": 42}


func _step_to(sim: ArenaSim, end_tick: int) -> void:
	while sim.tick < end_tick and sim.outcome.is_empty():
		sim.step()


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
