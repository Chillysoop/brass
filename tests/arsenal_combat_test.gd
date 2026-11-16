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
	_check_convergence_pulse()
	_check_severing_tether()
	_check_aegis_intercept()
	_check_shieldshock()
	_check_domino_maul()
	_check_impact_driver()
	_check_lancer_specialties()
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


func _check_convergence_pulse() -> void:
	var id := "convergence_pulse"
	var tile: Dictionary = ArenaSim.TILES[id]
	var sim := _sim([[_tile(id, 0)]], "hexwright")
	sim.units[0].pos = Vector2(170, 265)
	var target: Dictionary = sim.units[1]
	var resistant := _add_still_scout(sim, Vector2(375, 180))
	resistant.attack.displacement = 0.0
	var south := _add_still_scout(sim, Vector2(375, 355))
	var east := _add_still_scout(sim, Vector2(475, 265))
	var beyond_cap := _add_still_scout(sim, Vector2(495, 370))
	var outside := _add_still_scout(sim, Vector2(650, 265))
	var edge: int = tile.width * BEAT
	_advance(sim, edge - 1)
	_check(sim.activations.is_empty() and target.hp == target.max_hp and south.impulse == Vector2.ZERO,
		"Convergence Pulse never pulls or deals damage before the tile's right edge.")
	sim.step()
	var hit_damage: int = tile.damage + 2 * int(tile.convergence_damage_per_pull)
	_check(sim.activations[-1].tick == edge and sim.activations[-1].damage == hit_damage \
		and target.hp == target.max_hp - hit_damage and target.impulse == Vector2.ZERO,
		"Convergence Pulse adds damage to the primary hit for each successful additional pull at the right edge.")
	_check(south.impulse.y < 0 and east.impulse.x < 0 and south.hp == south.max_hp and east.hp == east.max_hp,
		"Convergence Pulse gathers surrounding foes toward its target without damaging them.")
	_check(resistant.impulse == Vector2.ZERO and beyond_cap.impulse == Vector2.ZERO and outside.impulse == Vector2.ZERO,
		"Convergence Pulse respects displacement resistance, the target cap, and the radius.")
	var solo := _sim([[_tile(id, 0)]], "hexwright")
	_advance(solo, edge)
	_check(solo.activations[-1].damage == tile.damage, "Convergence Pulse keeps its base damage against a lone enemy.")


func _check_severing_tether() -> void:
	var id := "severing_tether"
	var tile: Dictionary = ArenaSim.TILES[id]
	var edge: int = tile.width * BEAT
	for ally_offset: Vector2 in [Vector2(-90, 0), Vector2.ZERO, Vector2(90, 0), Vector2(-60, 150)]:
		var sim := _sim([[_tile(id, 0, "highest_hp")]], "hexwright")
		sim.units[0].pos = Vector2(170, 265)
		var target: Dictionary = sim.units[1]
		if not ally_offset.is_zero_approx():
			_add_still_scout(sim, target.pos + ally_offset)
		_advance(sim, edge - 1)
		_check(sim.activations.is_empty() and target.impulse == Vector2.ZERO,
			"Severing Tether waits for its right edge.")
		sim.step()
		var expected: int = tile.damage + (int(tile.isolation_damage) if ally_offset.x > 0.0 else 0)
		_check(sim.activations[-1].tick == edge and target.hp == target.max_hp - expected and target.impulse.x < 0,
			"Severing Tether adds damage only if the pull separates the target enough from its nearest living ally.")


func _check_aegis_intercept() -> void:
	var tile: Dictionary = ArenaSim.TILES.aegis_intercept
	var sim := _sim([[_tile("aegis_intercept", 0)], []], "bulwark")
	var defender: Dictionary = sim.units[0]
	var ally: Dictionary = sim.units[1]
	var enemy: Dictionary = sim.units[2]
	defender.pos = Vector2(230, 265)
	ally.pos = Vector2(160, 330)
	ally.hp = 45
	_advance(sim, tile.width * BEAT - 1)
	_check(ally.guard == 0 and not defender.has("intercept_aegis"), "Aegis Intercept waits for its right edge.")
	sim.step()
	_check(enemy.hp == enemy.max_hp - tile.damage and ally.guard == tile.guard and defender.guard == 0,
		"Aegis Intercept attacks and gives Guard to the weakest living hero.")
	var intercept := sim._intercept_target(ally)
	_check(intercept.id == defender.id and defender.guard == tile.intercept_guard and not defender.has("intercept_aegis"),
		"Aegis adds Guard before the actual intercept consumes it.")
	sim._damage(enemy, intercept, 18, "enemy_attack")
	_check(defender.guard == 0 and ally.hp == 45 and ally.guard == tile.guard,
		"The intercept shields its intended ally from the enemy hit.")


func _check_shieldshock() -> void:
	var tile: Dictionary = ArenaSim.TILES.shieldshock
	for blocks in [false, true]:
		var sim := _sim([[_tile("shieldshock", 0)]], "bulwark")
		var hero: Dictionary = sim.units[0]
		var target: Dictionary = sim.units[1]
		hero.pos = Vector2(230, 265)
		hero.guard = 8
		var near := _add_still_scout(sim, Vector2(460, 320))
		var far := _add_still_scout(sim, Vector2(565, 290))
		_advance(sim, tile.width * BEAT - 1)
		if blocks:
			sim._damage(target, hero, 20, "enemy_attack")
		sim.step()
		var extra: int = tile.recent_block_damage if blocks else 0
		var wave: int = tile.block_wave_damage if blocks else 0
		_check(target.hp == target.max_hp - tile.damage - extra and near.hp == near.max_hp - wave
			and far.hp == far.max_hp, "Shieldshock gets its bonus and wave only after Guard blocks actual damage.")


func _check_domino_maul() -> void:
	var tile: Dictionary = ArenaSim.TILES.domino_maul
	var sim := _sim([[_tile("domino_maul", 0)]], "breaker")
	sim.units[0].pos = Vector2(170, 265)
	sim.units[1].pos = Vector2(280, 265)
	var second := _add_still_scout(sim, Vector2(345, 265))
	var third := _add_still_scout(sim, Vector2(420, 265))
	var fourth := _add_still_scout(sim, Vector2(495, 265))
	_advance(sim, tile.width * BEAT)
	_check(sim.activations[-1].damage == tile.damage and second.hp == second.max_hp,
		"Domino Maul hits at its right edge and waits for physical contact to deal collision damage.")
	_advance(sim, tile.width * BEAT + 2 * BEAT)
	var contacts := sim.trace.filter(func(event: Dictionary): return event.kind == "hammer_collision" and event.tile == "domino_maul")
	_check(contacts.size() == 2 and contacts[0].target == second.id and contacts[1].target == third.id
		and third.hp < third.max_hp and fourth.hp == fourth.max_hp,
		"Domino Maul's second enemy can collide with a third enemy without relaying a second time.")


func _check_impact_driver() -> void:
	var tile: Dictionary = ArenaSim.TILES.impact_driver
	var sim := _sim([[_tile("impact_driver", 0)]], "breaker")
	var target: Dictionary = sim.units[1]
	sim.units[0].pos = Vector2(230, 265)
	target.guard = tile.guard_break + 5
	target.intent = sim.units[0].id
	target.intent_tick = (int(tile.width) + 1) * BEAT
	_advance(sim, tile.width * BEAT)
	_check(target.hp == target.max_hp - tile.damage - tile.windup_bonus + 5 and target.guard == 0,
		"Impact Driver strips Guard before landing its heavy bonus against a winding-up target.")


func _check_lancer_specialties() -> void:
	var tile: Dictionary = ArenaSim.TILES.phalanx_charge
	var sim := _sim([[_tile("phalanx_charge", 0, "highest_hp")]], "lancer")
	var origin := Vector2(160, 250)
	sim.units[0].pos = origin
	var target: Dictionary = sim.units[1]
	target.pos = Vector2(480, 250)
	var near := _add_still_scout(sim, Vector2(285, 302))
	var far := _add_still_scout(sim, Vector2(330, 350))
	near["arsenal_mark"] = {"expires": tile.width * BEAT, "order": -1, "bonus": 8}
	_advance(sim, tile.width * BEAT - 1)
	_check(sim.units[0].pos == origin and near.hp == near.max_hp, "Phalanx Charge waits for the tile's right edge.")
	sim.step()
	_check(sim.units[0].pos.x > 400 and target.hp == target.max_hp - tile.damage
		and near.hp == near.max_hp - tile.charge_path_damage and near.has("arsenal_mark") and far.hp == far.max_hp,
		"Phalanx Charge hits foes along the actual dash path without consuming their Marks.")
	var recoil: Dictionary = ArenaSim.TILES.recoil_thrust
	sim = _sim([[_tile("recoil_thrust", 0), _tile("phalanx_charge", recoil.width)]], "lancer")
	sim.units[0].pos = Vector2(170, 265)
	sim.units[1].pos = Vector2(325, 265)
	_advance(sim, recoil.width * BEAT)
	_check(sim.units[0].pos.x < 100 and sim.units[0].has("lance_return"), "Recoil Thrust readies a return charge after a real retreat.")
	var return_edge: int = (recoil.width + tile.width) * BEAT
	_advance(sim, return_edge)
	var followup := sim.trace.filter(func(event: Dictionary): return event.kind == "lance_return_spent")
	_check(followup.size() == 1 and followup[0].tick == return_edge and followup[0].amount == recoil.lance_return_bonus
		and not sim.units[0].has("lance_return"), "Recoil Thrust strengthens the next charge at the exact follow-up boundary.")


func _add_still_scout(sim: ArenaSim, position: Vector2) -> Dictionary:
	sim._add_campaign_enemy("scout", position)
	var scout: Dictionary = sim.units.back()
	scout.speed = 0.0
	scout.next_attack = 99999
	return scout


func _sim(lanes: Array, lead_class := "warden") -> ArenaSim:
	var heroes: Array = []
	for index in range(lanes.size()):
		heroes.append({"hero": lead_class if index == 0 else "warden"})
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
