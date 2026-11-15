extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const BrassVarietyEnemies = preload("res://scripts/brass_variety_enemies.gd")
const ClassDecks = preload("res://scripts/class_decks.gd")
const BEAT := ArenaSim.TICKS_PER_BEAT

var failures: Array[String] = []


func _initialize() -> void:
	_check_openers()
	_check_shieldwright()
	_check_linksmith()
	_check_springjack()
	_check_hound()
	_check_manifold()
	_check_sparkbow()
	_check_magnetar()
	_check_grounder()
	_check_flywheel()
	_check_pressure_sentinel()
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Twelve Brass enemy threats passed starter, telegraph and counter checks.")
	quit(0 if failures.is_empty() else 1)


func _check_openers() -> void:
	for id: String in ["brass_runner", "brass_riveter"]:
		for hero: String in ArenaSim.HERO_CLASSES:
			for tile: String in ["bash", "shot", "slam", ClassDecks.starter(hero)]:
				var sim := ArenaSim.new()
				var spawn := {"id": id, "x": 525.0, "dy": 0.0, "delay": 0, "health_scale": 1.0, "damage_scale": 1.0}
				var options := {"location": "brass", "encounter": "opening", "hero": hero, "formation": [spawn]}
				sim.start([[_tile(tile, 0)]], "solo", options)
				_advance(sim, 1500)
				_expect(sim.outcome == "victory" and sim.units[0].hp >= 80,
					"%s must be a viable opener with %s using %s." % [id, hero, tile])
	var protected := _arena("brass_riveter", [[_tile("guard", 0)]], 170.0)
	var exposed := _arena("brass_riveter", [[]], 170.0)
	_advance(protected, 43)
	_advance(exposed, 43)
	_expect(protected.units[0].hp == 100 and exposed.units[0].hp == 95,
		"A Guard tile that resolves before the Riveter's shot must block the shot.")


func _check_shieldwright() -> void:
	var sim := _arena("brass_shieldwright", [[]], 115.0)
	var enemy: Dictionary = sim.units[1]
	_advance(sim, 39)
	_expect(enemy.intent == enemy.id and enemy.guard == 0, "The Guard plate must be telegraphed before it activates.")
	sim.step()
	_expect(enemy.guard == 10 and sim.units[0].hp == 100, "Shieldwright must spend its first action on Guard.")
	enemy.next_attack = sim.tick + 1
	_advance(sim, 80)
	_expect(sim.units[0].hp == 94, "Shieldwright must alternate its plating with an attack.")


func _check_linksmith() -> void:
	var near := _arena("brass_linksmith", [[]], 135.0)
	var separated := _arena("brass_linksmith", [[]], 135.0)
	for sim in [near, separated]:
		sim._add_campaign_enemy("brass_runner", Vector2(435, 340))
		sim.units[2].speed = 0.0
		sim.units[2].next_attack = 2000
		sim.step()
		_expect(sim.units[1].intent == sim.units[2].id, "Linksmith must mark an ally during its windup.")
	separated.units[2].pos = Vector2(700, 340)
	_advance(near, 39)
	_advance(separated, 39)
	_expect(near.units[2].guard == 11 and separated.units[2].guard == 0,
		"Separating the ally before the Linksmith releases its plate must prevent the Guard grant.")


func _check_springjack() -> void:
	var guarded := _arena("brass_springjack", [[]], 137.0)
	var exposed := _arena("brass_springjack", [[]], 137.0)
	guarded.units[0].guard = 10
	_advance(guarded, 38)
	_advance(exposed, 38)
	_expect(_events(guarded, "push", "brass_springjack").is_empty() and _events(exposed, "push", "brass_springjack").size() == 1,
		"Springjack's piston must knock back only a defender whose HP takes damage.")


func _check_hound() -> void:
	var sim := _arena("brass_rivet_hound", [[], []], 153.0)
	var enemy: Dictionary = sim.units[2]
	var old_position: Vector2 = enemy.pos
	sim.units[1].hp = 70
	sim.step()
	_expect(enemy.intent == sim.units[1].id, "Rivet Hound must target the weakest hero.")
	_advance(sim, 34)
	_expect(old_position.distance_to(enemy.pos) >= 70.0 and sim.units[1].hp == 63 and sim.units[0].hp == 100,
		"Rivet Hound must pounce toward the marked hero and hit only that hero.")


func _check_manifold() -> void:
	var sim := _arena("brass_manifold", [[], []], 115.0)
	sim.units[1].pos = Vector2(300, 440)
	sim.step()
	_expect(sim.units[2].has("pilot_ring_radius"), "Manifold must preview its pressure ring.")
	_advance(sim, 44)
	_expect(sim.units[0].hp == 92 and sim.units[1].hp == 100,
		"Manifold's pressure burst must hit only heroes within the ring.")


func _check_sparkbow() -> void:
	var sim := _arena("brass_sparkbow", [[], []], 200.0)
	sim.units[1].pos = Vector2(380, 260)
	sim.step()
	_expect(sim.units[2].pilot_aim_point == sim.units[0].pos, "Sparkbow must lock its shot to the initial point.")
	sim.units[0].pos.y += 100.0
	_advance(sim, 45)
	_expect(sim.units[0].hp == 100 and sim.units[1].hp == 92,
		"A hero who moves off the Sparkbow line must evade it and the hero left in the line must be hit.")


func _check_magnetar() -> void:
	var guarded := _arena("brass_magnetar", [[]], 220.0)
	var exposed := _arena("brass_magnetar", [[]], 220.0)
	guarded.units[0].guard = 10
	_advance(guarded, 43)
	_advance(exposed, 43)
	_expect(_events(guarded, "pull", "brass_magnetar").size() == 1 and _events(exposed, "pull", "brass_magnetar").is_empty(),
		"The Magnetar must pull a guarded hero from beyond its normal reach.")


func _check_grounder() -> void:
	var guarded := _arena("brass_grounder", [[]], 130.0)
	var exposed := _arena("brass_grounder", [[]], 130.0)
	guarded.units[0].guard = 10
	_advance(guarded, 34)
	_advance(exposed, 34)
	_expect(guarded.units[1].guard == 0 and exposed.units[1].guard == 8,
		"Grounder's hit must reach HP to charge its Guard.")


func _check_flywheel() -> void:
	var sim := _arena("brass_flywheel", [[_tile("shot", 0)]], 110.0, 22)
	sim.units[1]["flywheel_momentum"] = 2
	_advance(sim, 60)
	_expect(_events(sim, "interrupt", "brass_flywheel_canceled").size() == 1 and sim.units[1].flywheel_momentum == 0 and sim.units[0].hp == 100,
		"A heavy hit during the Flywheel's windup must interrupt it and reset momentum.")
	var rolling := _arena("brass_flywheel", [[]], 110.0)
	_advance(rolling, 39)
	_expect(rolling.units[1].flywheel_momentum == 1, "An unblocked Flywheel hit must build momentum.")


func _check_pressure_sentinel() -> void:
	var sim := _arena("brass_pressure_sentinel", [[_tile("shot", 0), _tile("shot", 2)]], 130.0, 26)
	_advance(sim, 2 * BEAT)
	var enemy: Dictionary = sim.units[1]
	BrassVarietyEnemies.on_tile_hit(sim, sim.units[0], enemy, 7, "shot", 0)
	_expect(enemy.pressure_vents == 1, "A second hit from one tile activation must not vent pressure again.")
	_advance(sim, 4 * BEAT)
	_expect(_events(sim, "interrupt", "brass_pressure_vented").size() == 2 and sim.units[0].hp == 95,
		"Two shots in the windup, including one on the last tick, must weaken the Sentinel's strike by eight.")


func _arena(id: String, lanes: Array, distance: float, first := 1) -> ArenaSim:
	var heroes: Array[Dictionary] = []
	for _lane in lanes:
		heroes.append({"hero": "warden", "hp": 100, "max_hp": 100})
	var sim := ArenaSim.new()
	sim.start(lanes, "solo", {"location": "brass", "encounter": "opening", "heroes": heroes})
	sim.units.resize(heroes.size())
	for lane in range(heroes.size()):
		sim.units[lane].pos = Vector2(300.0, 260.0 + 93.0 * lane)
		sim.units[lane].speed = 0.0
	sim._add_campaign_enemy(id, Vector2(300.0 + distance, 260.0))
	sim.units[-1].speed = 0.0
	sim.units[-1].next_attack = first
	return sim


func _tile(id: String, start: int) -> Dictionary:
	return {"id": id, "start": start}


func _advance(sim: ArenaSim, target_tick: int) -> void:
	while sim.tick < target_tick and sim.outcome.is_empty():
		sim.step()


func _events(sim: ArenaSim, kind: String, tile: String) -> Array:
	return sim.trace.filter(func(event: Dictionary) -> bool: return event.kind == kind and event.tile == tile)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
