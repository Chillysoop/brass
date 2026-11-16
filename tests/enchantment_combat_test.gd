extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const CombatTotals = preload("res://scripts/combat_totals.gd")
const TileEnchantments = preload("res://scripts/tile_enchantments.gd")
const BEAT := ArenaSim.TICKS_PER_BEAT

var failures: Array[String] = []


func _initialize() -> void:
	var guarded := _fixture("blink", "guarded", 9)
	guarded.units[2].pos = Vector2(820, 200)
	guarded.units[3].pos = Vector2(820, 375)
	_step_to(guarded, ArenaSim.LOOP_TICKS - 1)
	_check(guarded.units[0].guard == 0, "Guarded fired before the right edge.")
	guarded.step()
	_check(guarded.activations.size() == 1 and guarded.activations[0].tick == ArenaSim.LOOP_TICKS
		and guarded.activations[0].status == "miss" and guarded.units[0].guard == TileEnchantments.GUARD_AMOUNT
		and "Guarded granted 5 Guard" in guarded.activations[0].reason, "A missed Blink should grant Guarded at beat 12.")
	_step_to(guarded, 2 * ArenaSim.LOOP_TICKS)
	_check(guarded.units[0].guard == 10, "Guarded should fire each loop.")

	var ranged := _fixture("shot", "longshot")
	var plain := _fixture("shot", "")
	for sim in [ranged, plain]:
		sim.units[2].pos = Vector2(825, 200)
		sim.units[3].pos = Vector2(825, 375)
	_check(ranged.target_for(0, "shot", "nearest", "longshot").get("id") == ranged.units[2].id
		and plain.target_for(0, "shot", "nearest").is_empty()
		and ranged.target_for(0, "bash", "nearest", "longshot").is_empty(), "Longshot should extend only the enchanted attack's preview range.")
	_step_to(ranged, 2 * ArenaSim.TICKS_PER_BEAT - 1)
	_check(ranged.activations.is_empty(), "Longshot fired before the tile edge.")
	ranged.step()
	_step_to(plain, 2 * ArenaSim.TICKS_PER_BEAT)
	_check(ranged.activations[0].damage == ArenaSim.TILES.shot.damage and plain.activations[0].status == "miss",
		"Longshot should reach a foe exactly at the extended boundary.")

	var splash := _fixture("shot", "splash")
	var killed: Dictionary = splash.units[2]
	killed.hp = 1
	var nearest: Dictionary = splash.units[3]
	var third := splash._unit("third", "Third", "enemy", -1, Vector2(360, 279), 40, 17.0, 0.0, 130.0)
	splash.units.append(third)
	var previous: int = nearest.hp
	_step_to(splash, 2 * ArenaSim.TICKS_PER_BEAT - 1)
	_check(killed.hp == 1 and nearest.hp == previous and third.hp == 40, "Splash damage fired before the tile edge.")
	splash.step()
	var damage := roundi(ArenaSim.TILES.shot.damage * TileEnchantments.SPLASH_RATIO)
	_check(killed.hp == 0 and nearest.hp == previous - damage and third.hp == 40
		and splash.activations[0].damage == damage + 1, "Lethal trigger should splash one closest neighbor at the same edge.")
	var hits := splash.trace.filter(func(event: Dictionary): return event.kind == "hit")
	_check(hits.size() == 2 and hits.all(func(event: Dictionary): return event.tick == 2 * ArenaSim.TICKS_PER_BEAT)
		and "Splash dealt" in splash.activations[0].reason, "Splash hit should share the main hit tick and appear in review.")

	var capped := _fixture("shot", "splash")
	capped.units[2].guard = 20
	capped.units[3].marshal_plated = true
	capped.units[3].marshal_exposed_until = 0
	capped.units[3].guard = 2
	previous = capped.units[3].hp
	_step_to(capped, 2 * ArenaSim.TICKS_PER_BEAT)
	_check(capped.units[3].hp == previous - 1, "A fully blocked primary hit should splash, subject to neighboring armor and Guard.")
	_check_piercing()
	_check_embered()
	_check_mending()
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("All six enchantments passed exact-edge and combat-result checks.")
	quit(0 if failures.is_empty() else 1)


func _check_piercing() -> void:
	var pierced := _fixture("shot", "piercing")
	var control := _fixture("shot", "")
	for sim in [pierced, control]:
		sim.units[2].guard = ArenaSim.MAX_GUARD
		_step_to(sim, 2 * BEAT - 1)
		_check(sim.units[2].hp == sim.units[2].max_hp and sim.units[2].guard == ArenaSim.MAX_GUARD,
			"Piercing and its ordinary attack must wait for the tile edge.")
		sim.step()
	var target: Dictionary = pierced.units[2]
	var raw: int = ArenaSim.MAX_GUARD - control.units[2].guard
	var bypass := ceili(raw * TileEnchantments.PIERCING_RATIO)
	var procs := _enchantment_events(pierced, "piercing", "enchant_pierce")
	_check(target.max_hp - target.hp == bypass and target.guard == control.units[2].guard
		and control.units[2].hp == control.units[2].max_hp,
		"Piercing should leak a rounded-up quarter of the blocked damage through Guard and still spend the normal Guard.")
	_check(procs.size() == 1 and procs[0].amount == bypass and procs[0].tick == 2 * BEAT and procs[0].source_tile == "shot"
		and pierced.activations[0].damage == bypass and "Piercing dealt" in pierced.activations[0].reason,
		"Review and trace must report the actual damage that reached HP because of Piercing.")
	var weak_guard := _fixture("shot", "piercing")
	weak_guard.units[2].guard = 2
	_step_to(weak_guard, 2 * BEAT)
	procs = _enchantment_events(weak_guard, "piercing", "enchant_pierce")
	_check(weak_guard.units[2].max_hp - weak_guard.units[2].hp == raw - 2 + ceili(2 * TileEnchantments.PIERCING_RATIO)
		and weak_guard.units[2].guard == 0 and procs.size() == 1 and procs[0].amount == 1,
		"Even a small Guard pool should leak one damage without saving any Guard for the enemy.")
	var unguarded := _fixture("shot", "piercing")
	_step_to(unguarded, 2 * BEAT)
	_check(unguarded.units[2].max_hp - unguarded.units[2].hp == raw
		and _enchantment_events(unguarded, "piercing", "enchant_pierce").is_empty(),
		"Piercing should add no damage when there is no Guard to block damage.")
	var armored := _fixture("shot", "piercing")
	var armored_control := _fixture("shot", "")
	for sim in [armored, armored_control]:
		sim._critical_seed = 2
		sim.units[2].marshal_plated = true
		sim.units[2].marshal_exposed_until = 0
		sim.units[2].guard = ArenaSim.MAX_GUARD
		_step_to(sim, 2 * BEAT)
	var armored_hit: Dictionary = armored.trace.back()
	var armored_raw: int = ArenaSim.MAX_GUARD - armored_control.units[2].guard
	_check(armored.activations[0].critical and armored_control.activations[0].critical and armored_hit.kind == "enchant_pierce"
		and armored.units[2].max_hp - armored.units[2].hp == ceili(armored_raw * TileEnchantments.PIERCING_RATIO)
		and armored.units[2].guard == armored_control.units[2].guard,
		"Piercing should use the normal critical damage after the boss's armor, while still spending the normal Guard.")

	var area := _fixture("slam", "piercing")
	_place_area_targets(area)
	area.units[2].guard = ArenaSim.MAX_GUARD
	area.units[3].guard = ArenaSim.MAX_GUARD
	_step_to(area, 4 * BEAT)
	procs = _enchantment_events(area, "piercing", "enchant_pierce")
	_check(procs.size() == 1 and procs[0].target == area.units[2].id and area.units[3].hp == area.units[3].max_hp
		and area.units[3].guard < ArenaSim.MAX_GUARD,
		"Only the selected hit of an area tile can bypass Guard, while collateral keeps its usual damage.")


func _check_embered() -> void:
	var sim := _fixture("shot", "embered")
	var target: Dictionary = sim.units[2]
	target.guard = ArenaSim.MAX_GUARD
	_step_to(sim, 2 * BEAT - 1)
	_check(_enchantment_events(sim, "embered", "ember_ignite").is_empty(), "Embered should wait for contact at the tile edge.")
	sim.step()
	var procs := _enchantment_events(sim, "embered", "ember_ignite")
	_check(procs.size() == 1 and procs[0].tick == 2 * BEAT and target.hp == target.max_hp
		and procs[0].amount == TileEnchantments.EMBER_DAMAGE and "Embered ignites" in sim.activations[0].reason,
		"An otherwise blocked direct hit can ignite its surviving target and record the Burn in review.")
	var guard_after_hit: int = target.guard
	_step_to(sim, 3 * BEAT - 1)
	_check(target.guard == guard_after_hit and _enchantment_events(sim, "embered", "ember_tick").is_empty(),
		"Embered's first Burn must wait one beat after ignition.")
	sim.step()
	_check(target.hp == target.max_hp and target.guard == guard_after_hit - TileEnchantments.EMBER_DAMAGE,
		"Ordinary Guard should absorb an Embered tick at its scheduled beat.")
	target.guard = 0
	_step_to(sim, 5 * BEAT)
	var ticks := _enchantment_events(sim, "embered", "ember_tick")
	_check(ticks.size() == TileEnchantments.EMBER_BEATS and ticks[0].tick == 3 * BEAT and ticks[0].amount == 0
		and ticks[-1].tick == 4 * BEAT and ticks[-1].amount == TileEnchantments.EMBER_DAMAGE
		and target.hp == target.max_hp - TileEnchantments.EMBER_DAMAGE,
		"Burn should apply its two scheduled ticks, expire, and expose actual damage dealt.")
	var totals := CombatTotals.new()
	totals.record(sim.trace, sim.units)
	var damage := totals.ranked("damage")
	_check(damage.size() == 1 and damage[0].tile == "shot" and damage[0].damage == TileEnchantments.EMBER_DAMAGE,
		"Combat totals should credit only actual Embered damage to the enchanting tile.")

	var area := _fixture("slam", "embered")
	_place_area_targets(area)
	_step_to(area, 4 * BEAT)
	procs = _enchantment_events(area, "embered", "ember_ignite")
	_check(procs.size() == 1 and procs[0].target == area.units[2].id and not area.units[3].has("ember_burns"),
		"Only the surviving primary enemy of an area activation should begin burning.")
	var lethal := _fixture("shot", "embered")
	lethal.units[2].hp = 1
	_step_to(lethal, 2 * BEAT)
	_check(lethal.units[2].hp == 0 and _enchantment_events(lethal, "embered", "ember_ignite").is_empty(),
		"A killing hit should not ignite a fallen enemy.")


func _check_mending() -> void:
	var sim := _fixture("field_dressing", "mending")
	var caster: Dictionary = sim.units[0]
	var ally: Dictionary = sim.units[1]
	caster.hp = caster.max_hp - 2
	ally.hp = 30
	var base: int = ArenaSim.TILES.field_dressing.heal
	_step_to(sim, 3 * BEAT - 1)
	_check(caster.hp == caster.max_hp - 2 and ally.hp == 30, "Mending must wait for the tile to actually restore HP.")
	sim.step()
	var procs := _enchantment_events(sim, "mending", "heal")
	_check(procs.size() == 1 and procs[0].amount == 2 and procs[0].target == caster.id and procs[0].tick == 3 * BEAT
		and ally.hp == 30 + base and caster.hp == caster.max_hp and "Mending restores 2 HP" in sim.activations[0].reason,
		"Mending chooses a different injured hero and caps its bonus at their missing HP.")
	var totals := CombatTotals.new()
	totals.record(sim.trace, sim.units)
	var healing := totals.ranked("healing")
	_check(healing.size() == 1 and healing[0].tile == "field_dressing" and healing[0].healing == base + 2,
		"Mending's actual bonus should be credited to the enchanted tile in combat totals.")
	caster.hp -= 12
	_step_to(sim, ArenaSim.LOOP_TICKS + 3 * BEAT)
	_check(_enchantment_events(sim, "mending", "heal").size() == 1 and caster.hp == caster.max_hp - 12,
		"The same enchanted placement cannot heal again in a later loop of this fight.")

	var not_healed := _fixture("first_aid", "mending")
	not_healed.units[1].hp = 40
	_step_to(not_healed, 2 * BEAT)
	_check(_enchantment_events(not_healed, "mending", "heal").is_empty() and not_healed.units[1].hp == 40,
		"Healing a full-health primary must not trigger Mending on an injured teammate.")
	not_healed.units[0].hp -= 12
	_step_to(not_healed, ArenaSim.LOOP_TICKS + 2 * BEAT)
	_check(not_healed.units[1].hp == 40 + TileEnchantments.MENDING_AMOUNT
		and _enchantment_events(not_healed, "mending", "heal").size() == 1,
		"A successful later self-heal can still trigger Mending on another hero.")
	var lone := _fixture("first_aid", "mending")
	lone.units[0].hp -= 20
	lone.units[1].hp = 0
	_step_to(lone, 2 * BEAT)
	_check(_enchantment_events(lone, "mending", "heal").is_empty() and lone.units[1].hp == 0,
		"Mending cannot heal a knocked-out teammate or duplicate the tile's self-heal.")
	var triage_id := "triage_kit_upgrade_rare_technique"
	var triage := ArenaSim.new()
	triage.start([[{"id": triage_id, "start": 0, "enchantment": "mending"}], [], []], "solo",
		{"heroes": [{"hero": "apothecary", "hp": 50}, {"hero": "warden", "hp": 60}, {"hero": "lancer"}]})
	for unit: Dictionary in triage.units:
		unit.speed = 0.0
		unit.next_attack = 99999
	var triage_edge: int = ArenaSim.TILES[triage_id].width * BEAT
	_step_to(triage, triage_edge)
	_check(_enchantment_events(triage, "mending", "heal").size() == 1, "Party healing can trigger one additional heal on another ally.")
	triage.units[2].hp = 50
	_step_to(triage, ArenaSim.LOOP_TICKS + triage_edge)
	_check(triage.units[2].hp > 50 and _enchantment_events(triage, "mending", "heal").size() == 1,
		"A later intrinsic party heal on a newly wounded ally must not refresh the enchanted tile's once-per-fight bonus.")


func _place_area_targets(sim: ArenaSim) -> void:
	sim.units[2].pos = Vector2(340, 200)
	sim.units[3].pos = Vector2(388, 228)


func _enchantment_events(sim: ArenaSim, enchantment: String, kind: String) -> Array:
	return sim.trace.filter(func(event: Dictionary): return event.kind == kind and event.get("enchantment") == enchantment)


func _fixture(id: String, enchantment: String, start := 0) -> ArenaSim:
	var sim := ArenaSim.new()
	sim.start([[{"id": id, "enchantment": enchantment, "start": start, "target": "nearest"}], []], "duo")
	var positions := [Vector2(190, 200), Vector2(190, 375), Vector2(360, 200), Vector2(411, 200)]
	for index in range(sim.units.size()):
		var unit: Dictionary = sim.units[index]
		unit.pos = positions[index]
		unit.prev_pos = unit.pos
		unit.speed = 0.0
		unit.next_attack = 99999
	return sim


func _step_to(sim: ArenaSim, tick: int) -> void:
	while sim.tick < tick and sim.outcome.is_empty():
		sim.step()


func _check(passed: bool, failure: String) -> void:
	if not passed:
		failures.append(failure)
