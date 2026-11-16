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
	_check_cantor_specialties()
	_check_second_voice()
	_check_rune_specialties()
	_check_wayfarer_specialties()
	_check_wayfarer_landings()
	_check_wayfarer_flank()
	_check_phantom_step()
	_check_cinder_specialties()
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Class masteries and class specialty tiles passed combat checks.")
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


func _check_cantor_specialties() -> void:
	var beat := ArenaSim.TICKS_PER_BEAT
	var harmonized := _campaign_sandbox([[_tile("guard_refrain", 0)], [_tile("shot", 0)], [_tile("shot", 1)]],
		[{"id": "cantor"}, {"id": "warden"}, {"id": "duelist"}])
	_step_to(harmonized, 2 * beat - 1)
	_check(harmonized.units[0].guard == 0 and harmonized.activations.is_empty(), "Guard Refrain waits until its right edge.")
	harmonized.step()
	var base: int = ArenaSim.TILES.guard_refrain.guard
	var extra: int = ArenaSim.TILES.guard_refrain.harmony_guard
	var guards := _tile_events(harmonized, "guard_refrain", "guard", 2 * beat)
	_check(guards.map(func(event: Dictionary): return int(event.amount)) == [base, base, base, extra]
		and guards.back().target == harmonized.units[1].id,
		"Guard Refrain's bonus only protects the ally whose tile ends on the same beat.")

	var chime := _campaign_sandbox([[_tile("echo_chime", 0), _tile("shot", 2)], [_tile("shot", 2), _tile("tap_bolt", 4)]],
		[{"id": "cantor"}, {"id": "warden"}])
	_step_to(chime, 5 * beat)
	var echoed := _tile_events(chime, "echo_chime", "hit", 4 * beat)
	var self_hit := chime.trace.find_custom(func(event: Dictionary):
		return event.kind == "hit" and event.tile == "shot" and event.actor == chime.units[0].id)
	_check(echoed.size() == 1 and echoed[0].actor == chime.units[0].id and echoed[0].target == chime.units[3].id
		and echoed[0].get("chorus_echo", false) and echoed[0].amount == ArenaSim.TILES.echo_chime.chorus_echo_damage
		and self_hit >= 0 and chime.trace.find(echoed[0]) > self_hit,
		"Only a different hero triggers Echo Chime, and the extra hit belongs to the chime on the neighboring enemy.")
	_check(_tile_events(chime, "echo_chime", "hit", 5 * beat).is_empty(), "Echo Chime is spent after its first allied echo.")


func _check_second_voice() -> void:
	var id := "echo_chime_upgrade_uncommon_technique"
	var spec: Dictionary = ArenaSim.TILES[id]
	var beat := ArenaSim.TICKS_PER_BEAT
	var expiry: int = spec.width + spec.chorus_echo_beats
	var party := [{"id": "cantor"}, {"id": "warden"}, {"id": "duelist"}]
	var first_ally := [_tile("snap_shot", 2), _tile("snap_shot", 3)]
	var chime := _campaign_sandbox([[_tile(id, 0)], first_ally,
		[_tile("snap_shot", expiry - 1), _tile("snap_shot", expiry)]], party)
	_step_to(chime, expiry * beat + beat)
	var echoes := chime.trace.filter(func(event: Dictionary): return event.get("chorus_echo", false))
	_check(echoes.map(func(event: Dictionary): return event.tick) == [3 * beat, expiry * beat],
		"Second Voice accepts two different allies and can trigger at the original deadline.")
	_check(echoes.map(func(event: Dictionary): return event.echo_trigger) == [chime.units[1].id, chime.units[2].id],
		"Second Voice cannot use the same ally's repeat hit as a second voice.")
	for event: Dictionary in echoes:
		_check(event.actor == chime.units[0].id and event.tile == id and event.target == chime.units[4].id
			and event.amount == spec.chorus_echo_damage and not event.critical,
			"Each echo credits Second Voice and hits a neighboring enemy for its stated damage.")

	var late := _campaign_sandbox([[_tile(id, 0)], first_ally, [_tile("snap_shot", expiry)]], party)
	_step_to(late, (expiry + 1) * beat)
	_check(_tile_events(late, id, "hit", 3 * beat).size() == 1
		and _tile_events(late, "snap_shot", "hit", (expiry + 1) * beat).size() == 1
		and _tile_events(late, id, "hit", (expiry + 1) * beat).is_empty(),
		"A late ally can land its attack, but the first echo did not refresh Second Voice's deadline.")


func _check_rune_specialties() -> void:
	var beat := ArenaSim.TICKS_PER_BEAT
	var quick: int = ArenaSim.TILES.snap_shot.damage
	var hammer: Dictionary = ArenaSim.TILES.hammer_stamp
	var stamped := _fixture("rune_smith", "", [_tile("hammer_stamp", 0), _tile("snap_shot", 3),
		_tile("snap_shot", 4), _tile("snap_shot", 5)])
	stamped.units[1].pos = stamped.units[0].pos + Vector2(110, 0)
	_step_to(stamped, 3 * beat - 1)
	_check(stamped.activations.is_empty(), "Hammer Stamp can't charge the next tiles early.")
	_step_to(stamped, 6 * beat)
	var target: String = stamped.units[1].id
	_check_direct_hit(stamped, "snap_shot", 4 * beat, target, quick + hammer.rune_quick_bonus + 5,
		"Hammer Stamp's first quick hit includes Rune Smith's passive")
	_check_direct_hit(stamped, "snap_shot", 5 * beat, target, quick + hammer.rune_quick_bonus, "Hammer Stamp charges a second quick hit")
	_check_direct_hit(stamped, "snap_shot", 6 * beat, target, quick, "A third quick hit has no stamp charge")

	var etched := _fixture("rune_smith", "", [_tile("quick_etch", 0), _tile("snap_shot", 1), _tile("iron_arc", 2)])
	etched.units[1].pos = etched.units[0].pos + Vector2(110, 0)
	_step_to(etched, 5 * beat)
	_check_direct_hit(etched, "snap_shot", 2 * beat, etched.units[1].id, quick, "Quick Etch doesn't spend its charge on another quick attack")
	_check_direct_hit(etched, "iron_arc", 5 * beat, etched.units[1].id,
		ArenaSim.TILES.iron_arc.damage + ArenaSim.TILES.quick_etch.rune_heavy_bonus, "Quick Etch boosts the next wide attack")

	var mixed := _fixture("rune_smith", "", [_tile("hammer_stamp", 0), _tile("quick_etch", 3),
		_tile("snap_shot", 4), _tile("iron_arc", 5)])
	mixed.units[1].pos = mixed.units[0].pos + Vector2(110, 0)
	_step_to(mixed, 8 * beat)
	_check_direct_hit(mixed, "snap_shot", 5 * beat, mixed.units[1].id, quick + hammer.rune_quick_bonus,
		"Quick Etch preserves Hammer Stamp's remaining quick charge")
	_check_direct_hit(mixed, "iron_arc", 8 * beat, mixed.units[1].id,
		ArenaSim.TILES.iron_arc.damage + ArenaSim.TILES.quick_etch.rune_heavy_bonus, "The wide charge remains available too")


func _check_wayfarer_specialties() -> void:
	var beat := ArenaSim.TICKS_PER_BEAT
	var sim := _fixture("wayfarer", "", [_tile("veil_step", 0), _tile("mirror_dart", 3), _tile("mirror_dart", 5)])
	var hero: Dictionary = sim.units[0]
	hero.relics = ["wayfarers_pin", "afterimage"]
	var origin: Vector2 = hero.pos
	_step_to(sim, 2 * beat - 1)
	_check(hero.pos.is_equal_approx(origin) and sim.activations.is_empty(), "Veil Step does not move or attack ahead of its right edge.")
	sim.step()
	var shot := _tile_events(sim, "veil_step", "hit", 2 * beat)
	var blink := _tile_events(sim, "veil_step", "teleport", 2 * beat)
	var target: Vector2 = sim.units[1].pos
	_check(shot.size() == 1 and shot[0].from.is_equal_approx(origin) and blink.size() == 1
		and sim.trace.find(shot[0]) < sim.trace.find(blink[0]) and hero.pos.is_equal_approx(blink[0].to)
		and is_equal_approx(blink[0].to.distance_to(target), origin.distance_to(target))
		and is_equal_approx(blink[0].to.distance_to(origin), ArenaSim.TILES.veil_step.blink_on_hit_retreat),
		"Veil Step attacks from the starting point before circling the target at the same distance.")
	_check(hero.get("last_teleport_tick", -1) == 2 * beat and hero.get("haste_until", -1) == 5 * beat
		and hero.get("afterimage", {}).get("position") == origin
		and _tile_events(sim, "wayfarers_pin", "guard", 2 * beat).size() == 1,
		"A sideways blink still grants Wayfarer haste and triggers both teleport relics at the departure edge.")
	_check(_tile_events(sim, "veil_step", "veil_echo", 2 * beat).is_empty(), "Common Veil Step has no afterimage shot.")
	_step_to(sim, 7 * beat)
	var dart: Dictionary = ArenaSim.TILES.mirror_dart
	_check_direct_hit(sim, "mirror_dart", 5 * beat, sim.units[1].id, dart.damage + dart.teleport_followup_damage,
		"Mirror Dart uses a real teleport within its window")
	_check_direct_hit(sim, "mirror_dart", 7 * beat, sim.units[1].id, dart.damage,
		"Mirror Dart loses the teleport bonus after the window")


func _check_wayfarer_landings() -> void:
	var tile := _tile("veil_step", 0)
	tile.target = "highest_hp"
	var edge: int = ArenaSim.TILES.veil_step.width * ArenaSim.TICKS_PER_BEAT
	var near_wall := _fixture("wayfarer", "", [tile])
	var hero: Dictionary = near_wall.units[0]
	var enemy: Dictionary = near_wall.units[1]
	var origin := Vector2(325, ArenaSim.WALL_MARGIN + float(hero.radius) + 5.0)
	hero.pos = origin
	enemy.pos = origin + Vector2(175, 0)
	enemy.hp = 500
	_step_to(near_wall, edge)
	var track := _tile_events(near_wall, tile.id, "teleport", edge)
	_check(track.size() == 1 and hero.pos.y > origin.y + 60.0
		and is_equal_approx(hero.pos.distance_to(enemy.pos), origin.distance_to(enemy.pos)),
		"When the wall blocks the preferred orbit, Veil Step uses the clear side.")

	var crowded := _fixture("wayfarer", "", [tile])
	hero = crowded.units[0]
	enemy = crowded.units[1]
	origin = Vector2(325, 260)
	hero.pos = origin
	enemy.pos = origin + Vector2(175, 0)
	enemy.hp = 500
	crowded.units[2].pos = Vector2(780, 400)
	for offset: Vector2 in [Vector2(-154, -79), Vector2(-154, 79)]:
		crowded._add_campaign_enemy("recruit", enemy.pos + offset)
		crowded.units.back().speed = 0.0
		crowded.units.back().next_attack = 99999
	_step_to(crowded, edge)
	track = _tile_events(crowded, tile.id, "teleport", edge)
	var retreat: float = ArenaSim.TILES.veil_step.blink_on_hit_retreat
	_check(track.size() == 1 and hero.pos.is_equal_approx(origin - Vector2(retreat, 0)),
		"When bodies block every sideways landing, Veil Step retreats into the open space.")


func _check_wayfarer_flank() -> void:
	var sim := _campaign_sandbox([[_tile("veil_step", 0), _tile("mirror_dart", 2)], [_tile("snap_shot", 2)]],
		[{"id": "wayfarer"}, {"id": "warden"}])
	var hero: Dictionary = sim.units[0]
	var partner: Dictionary = sim.units[1]
	var target: Dictionary = sim.units[2]
	var center := Vector2(500, 260)
	target.pos = center
	hero.pos = center - Vector2(60, 0)
	partner.pos = center - Vector2(165, 0)
	sim.units[3].pos = center + Vector2(130, 0)
	hero.relics = ["flanking_standard"]
	partner.relics = ["flanking_standard"]
	var beat := ArenaSim.TICKS_PER_BEAT
	_step_to(sim, 4 * beat)
	var flank := _tile_events(sim, "flanking_standard", "relic_proc", 4 * beat)
	_check(flank.size() == 1 and flank[0].actor == hero.id and flank[0].target == target.id
		and hero.pos.x > center.x and flank[0].source_tile == "mirror_dart",
		"A close sideways blink opens a real opposite-side hit for Wayfarer's next shot.")


func _check_phantom_step() -> void:
	var id := "veil_step_upgrade_uncommon_technique"
	var spec: Dictionary = ArenaSim.TILES[id]
	var edge: int = spec.width * ArenaSim.TICKS_PER_BEAT
	var sim := _fixture("wayfarer", "", [_tile(id, 0)])
	var origin: Vector2 = sim.units[0].pos
	_step_to(sim, edge - 1)
	_check(sim.activations.is_empty() and sim.units[0].pos.is_equal_approx(origin),
		"Phantom Step cannot attack, blink, or fire its afterimage before its right edge.")
	sim.step()
	var hits := _tile_events(sim, id, "hit", edge)
	var blinks := _tile_events(sim, id, "teleport", edge)
	var echoes := _tile_events(sim, id, "veil_echo", edge)
	_check(hits.size() == 2 and blinks.size() == 1 and echoes.size() == 1
		and sim.trace.find(hits[0]) < sim.trace.find(blinks[0]) and sim.trace.find(blinks[0]) < sim.trace.find(echoes[0])
		and sim.trace.find(echoes[0]) < sim.trace.find(hits[1]),
		"Phantom Step's shot, blink, and damaging afterimage happen in order at the same tile boundary.")
	if hits.size() == 2 and echoes.size() == 1:
		_check(hits[0].from.is_equal_approx(origin) and hits[0].amount == _critical_damage(hits[0], spec.damage)
			and echoes[0].from.is_equal_approx(origin) and hits[1].from.is_equal_approx(origin)
			and hits[1].target == hits[0].target and hits[1].get("veil_echo", false)
			and not hits[1].critical and hits[1].amount == spec.blink_echo_damage,
			"Phantom Step credits its extra shot from the departure point for its stated damage.")


func _check_cinder_specialties() -> void:
	var beat := ArenaSim.TICKS_PER_BEAT
	var spread := _campaign_sandbox([[_tile("wildfire_globe", 2)], [_tile("bellows_strike", 0), _tile("cinder_brand", 2)]],
		[{"id": "cinder_mage"}, {"id": "warden"}])
	spread.units[2].pos = spread.units[1].pos + Vector2(145, -48)
	spread.units[3].pos = spread.units[2].pos + Vector2(70, 40)
	_step_to(spread, 7 * beat)
	var branded := _tile_events(spread, "cinder_brand", "ember_ignite", 4 * beat)
	_check(branded.size() == 1 and branded[0].target == spread.units[2].id
		and not _tile_events(spread, "bellows_strike", "push", 2 * beat).is_empty(),
		"Cinder Brand ignites a target actually pushed earlier.")
	var ignited := _tile_events(spread, "wildfire_globe", "ember_ignite", 5 * beat)
	var delayed := _tile_events(spread, "wildfire_globe", "ember_tick", 6 * beat)
	_check(ignited.size() == 2 and delayed.size() == 2 and delayed[0].amount == ArenaSim.TILES.wildfire_globe.ember_burn_damage,
		"Wildfire Globe spreads an existing burn to the cluster and credits its delayed damage.")

	var cold := _fixture("cinder_mage", "", [_tile("wildfire_globe", 0)])
	_step_to(cold, 3 * beat - 1)
	cold.units[1].impulse = Vector2(150, 0)
	cold.step()
	_check(cold.units[1].get("burn_left", 0) > 0 and _tile_events(cold, "wildfire_globe", "ember_ignite", 3 * beat).is_empty(),
		"Wildfire Globe can't use a burn that its own hit started through Cinder Mage's passive.")


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
