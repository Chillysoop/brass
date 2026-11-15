extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const REPAIR := "tollkeeper_repair"

var failures: Array[String] = []


func _initialize() -> void:
	_check_variant_scope()
	_check_repair_completion()
	_check_tile_interrupt()
	_check_separation()
	_check_drone_attack_after_boss_falls()
	if failures.is_empty():
		print("Tollkeeper repair windup, healing, hit interrupt, separation and last drone attack passed.")
	for failure: String in failures:
		printerr(failure)
	quit(0 if failures.is_empty() else 1)


func _check_variant_scope() -> void:
	var classic := ArenaSim.new()
	classic.start([[]], "solo", _encounter("solo"))
	_check(classic.units.size() == 2 and classic.units[1].max_hp == 330,
		"The solo fixture should retain the original Tollkeeper.")
	var medium := ArenaSim.new()
	var options := _encounter("repair_drone")
	options.difficulty = "medium"
	medium.start([[]], "solo", options)
	_check(medium.units.size() == 2 and medium.units[1].max_hp > 330,
		"The repair variant is limited to Easy.")


func _check_repair_completion() -> void:
	var sim := _start([])
	var boss: Dictionary = sim.units[1]
	var drone: Dictionary = sim.units[2]
	var starting_hp: int = boss.hp
	_step_to(sim, int(drone.attack.first))
	_check(drone.intent == boss.id and drone.intent_attack_id == REPAIR and drone.intent_tick > sim.tick,
		"In-range repairs must announce a windup targeting the Tollkeeper.")
	_check(sim.boss_events.any(func(event): return event.tile == REPAIR and event.stage == "start"),
		"The repair windup must appear in Battle Review.")
	_step_to(sim, drone.intent_tick - 1)
	_check(boss.hp == starting_hp, "Windup ticks should leave the Tollkeeper's HP unchanged.")
	sim.step()
	_check(boss.hp == starting_hp + int(drone.attack.repair_amount)
		and sim.visual_cues.any(func(cue): return cue.tile == REPAIR and cue.target == boss.id and cue.landed),
		"An uninterrupted close repair must heal the Tollkeeper at the end of its windup.")


func _check_tile_interrupt() -> void:
	var sim := _start([{"id": "shot", "start": 6, "target": "lowest_hp"}])
	var boss: Dictionary = sim.units[1]
	var drone: Dictionary = sim.units[2]
	var starting_hp: int = boss.hp
	_step_to(sim, int(drone.attack.first) + int(drone.attack.windup))
	_check(boss.hp == starting_hp and drone.hp < drone.max_hp and drone.intent.is_empty()
		and sim.boss_events.any(func(event): return event.tile == "tollkeeper_repair_interrupted" and event.get("source_tile") == "shot"),
		"A Shot that damages the drone during its windup must cancel the repair and identify the counter tile.")


func _check_separation() -> void:
	var sim := _start([{"id": "pull", "start": 5, "target": "highest_hp"}])
	var drone: Dictionary = sim.units[2]
	_step_to(sim, int(drone.attack.first) + int(drone.attack.windup))
	_check(drone.hp == drone.max_hp and drone.intent.is_empty()
		and sim.boss_events.any(func(event): return event.tile == "tollkeeper_repair_separated")
		and not sim.trace.any(func(event): return event.tile == REPAIR and event.kind == "heal"),
		"Pulling the Tollkeeper out of reach must break the active repair without hitting the drone.")


func _check_drone_attack_after_boss_falls() -> void:
	var sim := _start([])
	var hero: Dictionary = sim.units[0]
	var boss: Dictionary = sim.units[1]
	var drone: Dictionary = sim.units[2]
	var starting_hp: int = hero.hp
	_step_to(sim, int(drone.attack.first))
	sim._damage(hero, boss, boss.hp, "shot")
	drone.pos = hero.pos + Vector2(93, 0)
	_step_to(sim, sim.tick + int(drone.attack.cooldown) + int(drone.attack.windup) + 2)
	_check(drone.hp > 0 and hero.hp < starting_hp and not sim.trace.any(func(event): return event.kind == "heal"),
		"The surviving drone must be able to finish a basic attack and cannot revive its partner.")


func _start(lane: Array) -> ArenaSim:
	var sim := ArenaSim.new()
	sim.start([lane], "solo", _encounter("repair_drone"))
	for unit: Dictionary in sim.units:
		unit.speed = 0.0
	var hero: Dictionary = sim.units[0]
	var boss: Dictionary = sim.units[1]
	var drone: Dictionary = sim.units[2]
	hero.pos = Vector2(285, 265)
	boss.pos = Vector2(450, 265)
	drone.pos = Vector2(553, 265)
	boss.hp -= 30
	boss.next_attack = 9999
	return sim


func _encounter(variant: String) -> Dictionary:
	return {"location": "brass", "difficulty": "easy", "encounter": "boss",
		"boss_id": "tollkeeper", "boss_variant": variant, "hero": "warden", "seed": 42}


func _step_to(sim: ArenaSim, end_tick: int) -> void:
	while sim.tick < end_tick and sim.outcome.is_empty():
		sim.step()


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
