extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const ClassMasteries = preload("res://scripts/class_masteries.gd")

var failures: Array[String] = []


func _initialize() -> void:
	var ids := {}
	for hero_id: String in ArenaSim.HERO_CLASSES:
		var options := ClassMasteries.options(hero_id)
		_check(options.size() == 2, "%s has two masteries." % hero_id)
		for option: Dictionary in options:
			_check(not ids.has(option.id) and ClassMasteries.belongs_to(hero_id, option.id),
				"%s has a unique ID belonging to %s." % [option.label, hero_id])
			ids[option.id] = true
	_check_hexwright()
	_check_consistent_reach()
	_check_base_passives()
	_check_tonic_dart()
	_check_catalyst_flask()
	_check_warden_tiles()
	_check_duelist_tiles()
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Class masteries and new Warden, Duelist, and Apothecary tiles passed combat checks.")
	quit(0 if failures.is_empty() else 1)


func _check_hexwright() -> void:
	var tiles := [_tile("pull", 0), _tile("pull", 3)]
	var warded := _fixture("hexwright", "anchor_ward", tiles)
	var splash := _fixture("hexwright", "shrapnel_tether", tiles)
	var baseline := _fixture("hexwright", "", tiles)
	for sim: ArenaSim in [warded, splash, baseline]:
		_step_to(sim, 3 * ArenaSim.TICKS_PER_BEAT - 1)
		_check(sim.units[0].guard == 0 and sim.units[2].hp == 200,
			"Pull masteries wait for the tile's right edge.")
		sim.step()
	_check(warded.units[0].guard == 5 and "Anchor Ward" in warded.activations[0].reason,
		"Anchor Ward adds Guard and names the mastery in Battle Review.")
	_check(splash.units[2].hp == 194 and splash.units[1].hp == baseline.units[1].hp
		and "Shrapnel Tether" in splash.activations[0].reason,
		"Shrapnel Tether adds a separate hit to the neighboring enemy on the pull's activation.")
	var source_push: Vector2 = baseline.units[1].impulse
	_check(source_push.length() > 850.0 and source_push.is_equal_approx(warded.units[1].impulse),
		"Anchor Ward leaves Hexwright's original stronger pull in place.")
	_step_to(warded, 6 * ArenaSim.TICKS_PER_BEAT)
	_check(warded.units[0].guard == 5, "A second pull does not repeat Anchor Ward in the same loop.")
	_step_to(warded, ArenaSim.LOOP_TICKS + 3 * ArenaSim.TICKS_PER_BEAT)
	_check(warded.units[0].guard == 10, "Anchor Ward can fire in the next loop.")


func _check_consistent_reach() -> void:
	var surveyed := _fixture("starshot", "surveyor", [_tile("shot", 0)])
	var wrong_class := _fixture("duelist", "surveyor", [_tile("shot", 0)])
	for sim: ArenaSim in [surveyed, wrong_class]:
		sim.units[0].pos = Vector2(205, 260)
		sim.units[1].pos = Vector2(820, 260)
		sim.units[2].hp = 0
	_check(not surveyed.target_for(0, "shot", "nearest").is_empty()
		and wrong_class.target_for(0, "shot", "nearest").is_empty(),
		"Only Starshot gets Surveyor's extra range, including the preview at its exact limit.")
	_step_to(surveyed, 2 * ArenaSim.TICKS_PER_BEAT)
	_step_to(wrong_class, 2 * ArenaSim.TICKS_PER_BEAT)
	_check(surveyed.activations[0].damage == ArenaSim.TILES.shot.damage + 5
		and wrong_class.activations[0].status == "miss",
		"The simulation uses the preview's reach and retains Starshot's normal long-range damage.")


func _check_base_passives() -> void:
	var warden := _fixture("warden", "brace_and_strike", [_tile("bash", 0)])
	warden.units[0].guard = 1
	warden.units[1].pos = warden.units[0].pos + Vector2(100, 0)
	warden.units[2].hp = 0
	_step_to(warden, 2 * ArenaSim.TICKS_PER_BEAT)
	_check(warden.units[0].guard == 5 and warden.activations[0].damage == ArenaSim.TILES.bash.damage + 5,
		"Brace and Strike adds damage to a guarded Warden and preserves the Bash Guard passive.")

	var wayfarer := _fixture("wayfarer", "blink_strike", [_tile("blink", 0)])
	_step_to(wayfarer, 3 * ArenaSim.TICKS_PER_BEAT)
	_check(wayfarer.activations[0].damage == ArenaSim.TILES.blink.damage + 6
		and wayfarer.units[0].get("haste_until", 0) > wayfarer.tick,
		"Blink Strike adds damage on a successful teleport and preserves Wayfarer's haste.")


func _check_tonic_dart() -> void:
	var sim := _fixture("apothecary", "", [_tile("tonic_dart", 0)])
	var fire_tick := 2 * ArenaSim.TICKS_PER_BEAT
	_step_to(sim, fire_tick - 1)
	_check(sim.units[0].guard == 0 and sim.activations.is_empty(), "Tonic Dart waits for its right edge.")
	sim.step()
	_check(_tile_events(sim, "tonic_dart", "heal", fire_tick).is_empty()
		and _tile_events(sim, "tonic_dart", "guard", fire_tick).size() == 1 and sim.units[0].guard == 3,
		"A full-health Tonic Dart grants its base Guard without claiming a heal.")
	var later := ArenaSim.LOOP_TICKS + fire_tick
	_step_to(sim, later - 1)
	sim.units[0].hp = sim.units[0].max_hp - 5
	sim.step()
	var first_heals := _tile_events(sim, "tonic_dart", "heal", later)
	var overflow := _tile_events(sim, "tonic_dart", "guard", later)
	_check(first_heals.size() == 1 and first_heals[0].amount == 3 and sim.units[0].hp == sim.units[0].max_hp
		and overflow.size() == 1 and overflow[0].amount == 2,
		"Tonic Dart heals solo after the first actual wound and converts the leftover into extra Guard.")
	later += ArenaSim.LOOP_TICKS
	_step_to(sim, later - 1)
	sim.units[0].hp = sim.units[0].max_hp - 10
	sim.step()
	_check(_tile_events(sim, "tonic_dart", "heal", later).is_empty() and sim.units[0].hp == sim.units[0].max_hp - 8,
		"Tonic Dart cannot repeat its per-placement healing in the next loop.")

	var party := _campaign_sandbox([[_tile("tonic_dart", 0)], [], []], [
		{"id": "apothecary"}, {"id": "hexwright"}, {"id": "warden"},
	])
	party.units[1].hp = party.units[1].max_hp - 2
	party.units[2].max_hp = 200
	party.units[2].hp = 194
	_step_to(party, fire_tick)
	var heals := _tile_events(party, "tonic_dart", "heal", fire_tick)
	_check(heals.size() == 1 and heals[0].target == party.units[2].id and heals[0].amount == 4
		and party.units[1].hp == party.units[1].max_hp - 2,
		"Tonic Dart prefers the living hero missing the most HP over an ally with lower absolute HP.")

	var out_of_range := _fixture("apothecary", "", [_tile("tonic_dart", 0)])
	out_of_range.units[0].hp -= 7
	out_of_range.units[1].pos = Vector2(900.0, 228.0)
	out_of_range.units[2].pos = Vector2(940.0, 302.0)
	_step_to(out_of_range, fire_tick)
	_check(out_of_range.activations.size() == 1 and out_of_range.activations[0].status == "miss"
		and out_of_range.units[0].hp == out_of_range.units[0].max_hp - 7 and out_of_range.units[0].guard == 0,
		"Tonic Dart needs a hit to deliver its support.")


func _check_catalyst_flask() -> void:
	var tiles := [_tile("first_aid", 0), _tile("catalyst_flask", 2)]
	var full := _fixture("apothecary", "", tiles)
	var hurt := _fixture("apothecary", "", tiles)
	hurt.units[0].hp -= 9
	var fire_tick := 5 * ArenaSim.TICKS_PER_BEAT
	var flask: Dictionary = ArenaSim.TILES.catalyst_flask
	for sim: ArenaSim in [full, hurt]:
		_step_to(sim, fire_tick - 1)
		_check(_tile_events(sim, "catalyst_flask", "hit", fire_tick - 1).is_empty()
			and sim.units[1].hp == 200 and sim.units[2].hp == 200,
			"Catalyst Flask does no damage before its right edge.")
		sim.step()
	_check_flask_hit(full, fire_tick, 0, "Healing attempts at full HP do not prime Catalyst Flask")
	_check_flask_hit(hurt, fire_tick, flask.healing_damage_bonus, "Actual HP restored earlier in the loop primes Catalyst Flask")
	var next_loop := ArenaSim.LOOP_TICKS + fire_tick
	_step_to(hurt, next_loop)
	_check(not _tile_events(hurt, "apothecary", "heal", next_loop).is_empty(),
		"The next flask can trigger the Apothecary passive heal at its own edge.")
	_check_flask_hit(hurt, next_loop, 0, "The flask cannot use its own heal or a heal from a previous loop")

	var party := _campaign_sandbox([[_tile("catalyst_flask", 0)], [_tile("first_aid", 0)]], [
		{"id": "apothecary"}, {"id": "warden"},
	])
	party.units[1].hp -= 6
	_step_to(party, 3 * ArenaSim.TICKS_PER_BEAT)
	_check_flask_hit(party, 3 * ArenaSim.TICKS_PER_BEAT, flask.healing_damage_bonus, "An ally's heal can prime Catalyst Flask")


func _check_flask_hit(sim: ArenaSim, tick: int, bonus: int, premise: String) -> void:
	var hits := _tile_events(sim, "catalyst_flask", "hit", tick)
	if hits.size() != 2:
		_check(false, premise + ". Expect one direct hit and one splash.")
		return
	var flask: Dictionary = ArenaSim.TILES.catalyst_flask
	var main_damage := _critical_damage(hits[0], flask.damage + bonus)
	_check(hits[0].amount == main_damage and hits[1].amount == flask.splash_damage + bonus, premise + ".")


func _check_warden_tiles() -> void:
	var edge := 6 * ArenaSim.TICKS_PER_BEAT
	var plate: Dictionary = ArenaSim.TILES.reversal_plate
	var last_block := edge - int(plate.recent_block_beats) * ArenaSim.TICKS_PER_BEAT
	for trial: Dictionary in [
		{"guard": 5, "attack_tick": last_block, "boosted": true},
		{"guard": 5, "attack_tick": last_block - 1, "boosted": false},
		{"guard": 0, "attack_tick": last_block, "boosted": false},
	]:
		var sim := _fixture("warden", "", [_tile("reversal_plate", 4)])
		var hero := sim.units[0]
		var enemy := sim.units[1]
		hero.guard = trial.guard
		enemy.pos = hero.pos + Vector2(100, 0)
		enemy.attack = {"reach": 150.0, "damage": 5, "cooldown": 99999, "push": 0.0}
		sim._start_enemy_intent(enemy, hero.id, trial.attack_tick, "reversal_block_fixture")
		_step_to(sim, edge - 1)
		var attacks := _tile_events(sim, "enemy_attack", "hit", trial.attack_tick)
		_check(attacks.size() == 1 and attacks[0].blocked == trial.guard,
			"Reversal Plate setup resolves the scheduled enemy strike against real Guard.")
		if trial.guard == 0:
			hero.guard = 1
		sim.step()
		var damage: int = plate.damage + (plate.recent_block_damage if trial.boosted else 0)
		_check_direct_hit(sim, "reversal_plate", edge, enemy.id, damage, "Reversal Plate requires an actual block inside its window")
		var guarded := _tile_events(sim, "reversal_plate", "guard", edge)
		_check(guarded.size() == 1 and guarded[0].amount == plate.guard, "Reversal Plate grants Guard on its hit.")

	var rush := _fixture("warden", "", [_tile("rampart_rush", 0)])
	var origin: Vector2 = rush.units[0].pos
	rush.units[1].pos = origin + Vector2(245, 0)
	rush.units[2].pos = rush.units[1].pos + Vector2(25, 66)
	edge = 3 * ArenaSim.TICKS_PER_BEAT
	_step_to(rush, edge - 1)
	_check(rush.units[0].pos.is_equal_approx(origin) and rush.units[0].guard == 0 and rush.activations.is_empty(),
		"Rampart Rush waits to charge, strike, and guard until its right edge.")
	rush.step()
	var push_hits := _tile_events(rush, "rampart_rush", "push", edge)
	_check(_tile_events(rush, "rampart_rush", "charge", edge).size() == 1
		and origin.distance_to(rush.units[0].pos) > 100 and rush.units[0].guard == ArenaSim.TILES.rampart_rush.guard
		and push_hits.map(func(hit: Dictionary): return hit.target) == [rush.units[1].id, rush.units[2].id],
		"Rampart Rush moves the Warden, pushes the main target and its neighbor, and grants Guard on the same edge.")


func _check_duelist_tiles() -> void:
	var tiles := []
	for start in [0, 2, 4, 6]:
		tiles.append(_tile("pinpoint_lunge", start).merged({"target": "highest_hp" if start == 4 else "lowest_hp"}, true))
	var lunge := _fixture("duelist", "", tiles)
	lunge.units[1].hp = 125
	lunge.units[2].pos += Vector2(0, 65)
	var spec: Dictionary = ArenaSim.TILES.pinpoint_lunge
	var edge := 2 * ArenaSim.TICKS_PER_BEAT
	var first: String = lunge.units[1].id
	var other: String = lunge.units[2].id
	for trial: Dictionary in [
		{"target": first, "damage": spec.damage}, {"target": first, "damage": spec.damage + spec.repeat_target_damage + 2},
		{"target": other, "damage": spec.damage}, {"target": first, "damage": spec.damage},
	]:
		_step_to(lunge, edge)
		_check_direct_hit(lunge, "pinpoint_lunge", edge, trial.target, trial.damage,
			"Pinpoint Lunge only adds its repeat bonus on the last landed target, alongside Duelist's passive")
		edge += 2 * ArenaSim.TICKS_PER_BEAT

	var cut := _fixture("duelist", "", [_tile("vanishing_cut", 0), _tile("shot", 3), _tile("shot", 5)])
	var start_position: Vector2 = cut.units[0].pos
	cut.units[1].hp = 16
	edge = 3 * ArenaSim.TICKS_PER_BEAT
	_step_to(cut, edge - 1)
	_check(cut.units[0].pos.is_equal_approx(start_position) and cut.units[1].hp == 16,
		"Vanishing Cut waits until its edge to blink and strike.")
	cut.step()
	_check(_tile_events(cut, "vanishing_cut", "teleport", edge).size() == 1 and cut.units[1].hp == 0
		and _tile_events(cut, "vanishing_cut", "duel_kill_ready", edge).size() == 1,
		"A lethal Vanishing Cut blinks and readies the extra damage.")
	_step_to(cut, 7 * ArenaSim.TICKS_PER_BEAT)
	_check_direct_hit(cut, "shot", 5 * ArenaSim.TICKS_PER_BEAT, cut.units[2].id,
		ArenaSim.TILES.shot.damage + ArenaSim.TILES.vanishing_cut.duel_kill_bonus,
		"The next hit on a different target spends Vanishing Cut's kill bonus")
	_check_direct_hit(cut, "shot", 7 * ArenaSim.TICKS_PER_BEAT, cut.units[2].id, ArenaSim.TILES.shot.damage + 2,
		"Later attacks keep Duelist's normal streak but no longer receive the kill bonus")


func _check_direct_hit(sim: ArenaSim, id: String, tick: int, target: String, damage: int, premise: String) -> void:
	var hits := _tile_events(sim, id, "hit", tick)
	_check(hits.size() == 1 and hits[0].target == target and hits[0].amount == _critical_damage(hits[0], damage),
		premise + ".")


func _critical_damage(hit: Dictionary, amount: int) -> int:
	return roundi(amount * ArenaSim.CRITICAL_DAMAGE_MULTIPLIER) if hit.get("critical", false) else amount


func _tile_events(sim: ArenaSim, id: String, kind: String, at_tick: int) -> Array[Dictionary]:
	return sim.trace.filter(func(event: Dictionary): return event.tile == id and event.kind == kind and event.tick == at_tick)


func _fixture(hero: String, mastery: String, tiles: Array) -> ArenaSim:
	return _campaign_sandbox([tiles], [{"id": hero, "mastery": mastery}])


func _campaign_sandbox(lanes: Array, heroes: Array) -> ArenaSim:
	var sim := ArenaSim.new()
	sim.start(lanes, "solo", {"encounter": "battle", "heroes": heroes, "formation": [
		{"id": "recruit", "x": 450.0, "dy": 0.0, "delay": 0, "health_scale": 1.0, "damage_scale": 1.0},
		{"id": "scout", "x": 490.0, "dy": 55.0, "delay": 0, "health_scale": 1.0, "damage_scale": 1.0},
	]})
	for unit: Dictionary in sim.units:
		unit.speed = 0.0
		unit.next_attack = 99999
		if unit.side == "enemy":
			unit.hp = 200
			unit.max_hp = 200
	return sim


func _tile(id: String, start: int) -> Dictionary:
	return {"id": id, "start": start, "target": "nearest"}


func _step_to(sim: ArenaSim, tick: int) -> void:
	while sim.tick < tick and sim.outcome.is_empty():
		sim.step()


func _check(passed: bool, failure: String) -> void:
	if not passed:
		failures.append(failure)
