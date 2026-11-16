extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const TilePacking = preload("res://scripts/tile_packing.gd")
const BEAT := ArenaSim.TICKS_PER_BEAT

var failures: Array[String] = []


func _initialize() -> void:
	for tier in [2, 3, 4]:
		_check_warden(TilePacking.forge_tiers("rampart_counter")[tier])
		_check_hexwright(TilePacking.forge_tiers("gravity_spike")[tier])
		_check_starshot(TilePacking.forge_tiers("horizon_round")[tier])
		_check_wayfarer(TilePacking.forge_tiers("ghost_volley")[tier])
		_check_breaker(TilePacking.forge_tiers("collision_hammer")[tier])
		_check_apothecary(TilePacking.forge_tiers("triage_kit")[tier])
		_check_rune_smith(TilePacking.forge_tiers("runic_anvil")[tier])
		_check_duelist(TilePacking.forge_tiers("needle_point")[tier])
		_check_cantor(TilePacking.forge_tiers("chorus_bolt")[tier])
		_check_bulwark(TilePacking.forge_tiers("bastion_oath")[tier])
		_check_lancer(TilePacking.forge_tiers("comet_charge")[tier])
		_check_cinder_mage(TilePacking.forge_tiers("cinder_wave")[tier])
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Rare, Epic, and Legendary signature combat checks passed for all twelve heroes.")
	quit(0 if failures.is_empty() else 1)


func _check_warden(choices: Array) -> void:
	var counter: String = choices[0]
	var counter_spec: Dictionary = ArenaSim.TILES[counter]
	var edge: int = counter_spec.width * BEAT
	var sim := _fixture([[_tile(counter, 0)]], ["warden"])
	var hold := int(counter_spec.get("guard_spend", 0))
	_check(hold >= 3, "%s should spend Guard." % counter)
	sim.units[0].guard = hold + 2
	_advance(sim, edge - 1)
	_check(sim.activations.is_empty() and sim.units[0].guard == hold + 2,
		"%s must hold its Guard until the tile's right edge." % counter)
	sim.step()
	_check(sim.units[0].guard == 2 and _damage_at(sim, counter, edge) ==
		int(counter_spec.damage) + int(counter_spec.get("guard_bonus", 0)) + hold * 2,
		"%s must spend up to its limit and add 2 damage for each Guard spent." % counter)
	_check(sim.trace.any(func(event: Dictionary):
		return event.kind == "guard_spent" and event.amount == hold and event.tick == edge),
		"%s must record the Guard spent on its firing beat." % counter)

	var low := _fixture([[_tile(counter, 0)]], ["warden"])
	low.units[0].guard = 2
	_advance(low, edge)
	_check(low.units[0].guard == 0 and _damage_at(low, counter, edge) ==
		int(counter_spec.damage) + int(counter_spec.get("guard_bonus", 0)) + 4,
		"%s should spend the remaining Guard when it has less than its limit." % counter)
	var miss := _fixture([[_tile(counter, 0)]], ["warden"])
	miss.units[0].guard = hold
	_move(miss.units[1], Vector2(750, 250))
	_advance(miss, edge)
	_check(miss.units[0].guard == hold and _damage_at(miss, counter, edge) == 0,
		"%s must save its Guard when the enemy is out of reach." % counter)

	var support: String = choices[1]
	var support_spec: Dictionary = ArenaSim.TILES[support]
	var support_amount := int(support_spec.get("ally_guard", 0))
	var support_edge: int = support_spec.width * BEAT
	var party := _fixture([[_tile(support, 0)], [], []], ["warden", "duelist", "breaker"])
	party.units[0].hp = 10
	party.units[1].hp = 85
	party.units[2].hp = 40
	party.units[0].guard = 3
	_advance(party, support_edge)
	_check(support_amount > 0 and party.units[0].guard == 3 and party.units[1].guard == 0
		and party.units[2].guard == support_amount,
		"%s should protect the weakest other living hero while keeping the caster's Guard." % support)
	var solo := _fixture([[_tile(support, 0)], []], ["warden", "duelist"])
	solo.units[1].hp = 0
	_advance(solo, support_edge)
	_check(support_amount > 0 and solo.units[0].guard == support_amount and solo.units[1].guard == 0,
		"%s should grant Guard to its caster when no other hero is alive." % support)


func _check_hexwright(choices: Array) -> void:
	var single_id: String = choices[0]
	var cluster_id: String = choices[1]
	var edge: int = ArenaSim.TILES[single_id].width * BEAT
	var single := _pull_fixture(single_id)
	var base := _pull_fixture("gravity_spike")
	var cluster := _pull_fixture(cluster_id)
	_advance(cluster, edge - 1)
	_check(cluster.activations.is_empty() and cluster.units[2].impulse == Vector2.ZERO,
		"%s must leave the group alone before its right edge." % cluster_id)
	cluster.step()
	_advance(single, edge)
	_advance(base, edge)
	_check(single.units[1].impulse.length() > base.units[1].impulse.length()
		and single.units[2].impulse == Vector2.ZERO and single.units[3].impulse == Vector2.ZERO,
		"%s should pull one enemy harder than Gravity Spike and leave nearby foes alone." % single_id)
	var toward_impact: Vector2 = cluster.units[2].pos.direction_to(cluster.units[1].pos)
	var toward_caster: Vector2 = cluster.units[1].pos.direction_to(cluster.units[0].pos)
	_check(cluster.units[1].impulse.dot(toward_caster) > 0.0
		and cluster.units[2].impulse.normalized().dot(toward_impact) > 0.999
		and cluster.units[3].impulse == Vector2.ZERO,
		"%s should pull the target toward the caster and nearby foes toward the impact, within its radius." % cluster_id)
	var lethal := _pull_fixture(cluster_id)
	lethal.units[1].hp = 1
	_advance(lethal, edge)
	_check(lethal.units[1].hp == 0 and lethal.units[2].impulse.length() > 0.0,
		"%s should pull nearby foes even when the primary target dies." % cluster_id)


func _check_starshot(choices: Array) -> void:
	var range_id: String = choices[0]
	var range_spec: Dictionary = ArenaSim.TILES[range_id]
	var edge: int = range_spec.width * BEAT
	var near := _fixture([[_tile(range_id, 0)]], ["starshot"])
	var far := _fixture([[_tile(range_id, 0)]], ["starshot"])
	_move(near.units[1], near.units[0].pos + Vector2(210, 0))
	_move(far.units[1], far.units[0].pos + Vector2(211, 0))
	_advance(near, edge)
	_advance(far, edge)
	var distance_bonus := int(range_spec.get("distance_bonus", 0))
	_check(distance_bonus > int(ArenaSim.TILES.horizon_round.distance_bonus)
		and _damage_at(far, range_id, edge) - _damage_at(near, range_id, edge) == distance_bonus
		and not far.trace.any(func(event: Dictionary): return event.kind == "mark"),
		"%s should reward firing strictly beyond 210 range and leave no mark." % range_id)

	var setup_id: String = choices[1]
	var setup: Dictionary = ArenaSim.TILES[setup_id]
	var caster_hit: int = setup.width + 1
	var ally_hit: int = setup.width + setup.mark_beats
	var lanes := [[_tile(setup_id, 0), _tile("tap_bolt", caster_hit - 1)],
		[_tile("tap_bolt", ally_hit - 1), _tile("tap_bolt", ally_hit)]]
	var party := _fixture(lanes, ["starshot", "warden"])
	_advance(party, edge - 1)
	_check(party.activations.is_empty(), "%s must wait until its right edge to mark an enemy." % setup_id)
	_advance(party, caster_hit * BEAT)
	_check(_damage_at(party, "tap_bolt", caster_hit * BEAT) == ArenaSim.TILES.tap_bolt.damage,
		"%s's mark should survive hits from the hero who placed it." % setup_id)
	_advance(party, (ally_hit + 1) * BEAT)
	var ally_damage: int = ArenaSim.TILES.tap_bolt.damage + setup.mark_bonus
	var spends := party.trace.filter(func(event: Dictionary): return event.kind == "mark_spent")
	_check(_damage_at(party, "tap_bolt", ally_hit * BEAT) == ally_damage
		and _damage_at(party, "tap_bolt", (ally_hit + 1) * BEAT) == ArenaSim.TILES.tap_bolt.damage
		and spends.size() == 1 and spends[0].actor == party.units[1].id,
		"%s should boost another hero at the expiry beat, then be consumed once." % setup_id)
	var late := _fixture([[_tile(setup_id, 0)], [_tile("tap_bolt", ally_hit)]], ["starshot", "warden"])
	_advance(late, (ally_hit + 1) * BEAT)
	_check(_damage_at(late, "tap_bolt", (ally_hit + 1) * BEAT) == ArenaSim.TILES.tap_bolt.damage,
		"%s should give ordinary damage to a teammate after its mark expires." % setup_id)

	var mixed := _fixture([[_tile(setup_id, 0), _tile("lantern_shot", setup.width)],
		[_tile("tap_bolt", setup.width + 3), _tile("tap_bolt", setup.width + 4)]], ["starshot", "warden"])
	var first_follow_up: int = (setup.width + 4) * BEAT
	_advance(mixed, first_follow_up + BEAT)
	_check(_damage_at(mixed, "tap_bolt", first_follow_up) == ally_damage
		and _damage_at(mixed, "tap_bolt", first_follow_up + BEAT) ==
			ArenaSim.TILES.tap_bolt.damage + ArenaSim.TILES.lantern_shot.mark_bonus,
		"%s should survive a regular mark reapplication without stacking both bonuses on the same hit." % setup_id)


func _check_wayfarer(choices: Array) -> void:
	var ambush: String = choices[0]
	var cover: String = choices[1]
	var ambush_spec: Dictionary = ArenaSim.TILES[ambush]
	var cover_spec: Dictionary = ArenaSim.TILES[cover]
	var edge: int = ambush_spec.width * BEAT
	var sim := _fixture([[_tile(ambush, 0), _tile("tap_bolt", ambush_spec.width)]], ["wayfarer"])
	sim.units[0].relics.assign(["afterimage"])
	_move(sim.units[1], sim.units[0].pos + Vector2(215, 0))
	_advance(sim, edge - 1)
	var departure: Vector2 = sim.units[0].pos
	_check(sim.activations.is_empty(), "%s must wait for its right edge." % ambush)
	sim.step()
	_check(sim.units[0].pos.distance_to(departure) > 10 and _damage_at(sim, ambush, edge) == ambush_spec.damage
		and sim.units[0].get("afterimage", {}).get("position") == departure
		and not ArenaSim.is_ranged_tile(ambush),
		"%s should blink into melee, hit, and leave an Afterimage." % ambush)
	_advance(sim, edge + BEAT)
	_check(sim.trace.any(func(event: Dictionary):
		return event.kind == "relic_proc" and event.tile == "afterimage" and event.tick == edge + BEAT),
		"Afterimage from %s should extend a later attack from the departure point." % ambush)

	var blocked := _fixture([[_tile(ambush, 0)]], ["wayfarer"])
	blocked.units[1].radius = 1000.0
	_advance(blocked, edge)
	_check(_damage_at(blocked, ambush, edge) == 0
		and blocked.trace.any(func(event: Dictionary): return event.kind == "miss" and event.tile == ambush)
		and not blocked.trace.any(func(event: Dictionary): return event.kind == "teleport"),
		"%s should miss without blinking when no landing is open." % ambush)

	var start: int = cover_spec.width
	var bonus: int = cover_spec.ranged_followup_bonus
	var last: int = start + cover_spec.ranged_followup_beats
	var retreat := _fixture([[_tile(cover, 0), _tile("jab", start),
		_tile("tap_bolt", start + 1), _tile("tap_bolt", last - 1), _tile("tap_bolt", last)]], ["wayfarer"])
	_advance(retreat, start * BEAT)
	_check(retreat.trace.any(func(event: Dictionary):
		return event.kind == "ranged_followup_ready" and event.tick == start * BEAT),
		"%s should ready a ranged bonus only after its retreat." % cover)
	_move(retreat.units[1], retreat.units[0].pos + Vector2(95, 0))
	_advance(retreat, (start + 1) * BEAT)
	_check(_damage_at(retreat, "jab", (start + 1) * BEAT) == ArenaSim.TILES.jab.damage,
		"The ranged bonus from %s should survive a melee hit." % cover)
	_move(retreat.units[1], retreat.units[0].pos + Vector2(390, 0))
	_advance(retreat, (start + 2) * BEAT)
	_check(_damage_at(retreat, "tap_bolt", (start + 2) * BEAT) == 0,
		"The first ranged follow-up should miss from outside range.")
	_move(retreat.units[1], retreat.units[0].pos + Vector2(115, 0))
	_advance(retreat, (last + 1) * BEAT)
	_check(_damage_at(retreat, "tap_bolt", last * BEAT) == ArenaSim.TILES.tap_bolt.damage + bonus
		and _damage_at(retreat, "tap_bolt", (last + 1) * BEAT) == ArenaSim.TILES.tap_bolt.damage,
		"%s should wait through a miss, boost the final eligible hit, then consume its bonus." % cover)

	var late := _fixture([[_tile(cover, 0), _tile("tap_bolt", last)]], ["wayfarer"])
	_advance(late, (last + 1) * BEAT)
	_check(_damage_at(late, "tap_bolt", (last + 1) * BEAT) == ArenaSim.TILES.tap_bolt.damage,
		"%s should not boost a ranged hit after the window closes." % cover)


func _check_breaker(choices: Array) -> void:
	var hammer: String = choices[0]
	var sweep: String = choices[1]
	var hammer_spec: Dictionary = ArenaSim.TILES[hammer]
	var sweep_spec: Dictionary = ArenaSim.TILES[sweep]
	var edge: int = hammer_spec.width * BEAT
	for hero: String in ["warden", "breaker"]:
		var sim := _push_fixture(hammer, hero)
		_move(sim.units[2], Vector2(437, 240))
		_advance(sim, edge + 18)
		var collision := sim.trace.filter(func(event: Dictionary): return event.kind == "hammer_collision")
		var impacts := sim.trace.filter(func(event: Dictionary): return event.kind == "hit" and event.tile == "breaker")
		var damage: int = hammer_spec.collision_bonus + (5 if hero == "breaker" else 0)
		_check(collision.size() == 1 and impacts.size() == 2 and impacts[0].amount == damage
			and impacts[1].amount == damage and impacts[0].target != impacts[1].target,
			"%s should damage both enemies on the first collision when equipped by %s." % [hammer, hero])

	var group := _push_fixture(sweep, "breaker")
	_move(group.units[2], Vector2(370, 320))
	var edge_sweep: int = sweep_spec.width * BEAT
	_advance(group, edge_sweep - 1)
	_check(group.units[2].impulse == Vector2.ZERO, "%s must wait for its right edge." % sweep)
	group.units[1].hp = 1
	group.step()
	var direction: Vector2 = group.units[0].pos.direction_to(group.units[2].pos)
	_check(group.units[1].hp == 0 and group.units[2].impulse.dot(direction) > 0.0
		and group.units[3].impulse == Vector2.ZERO,
		"%s should still push nearby enemies away from the caster when it defeats the target." % sweep)


func _check_apothecary(choices: Array) -> void:
	var dose: String = choices[0]
	var mist: String = choices[1]
	var dose_spec: Dictionary = ArenaSim.TILES[dose]
	var mist_spec: Dictionary = ArenaSim.TILES[mist]
	var allies := ["apothecary", "warden", "duelist"]
	var edge: int = dose_spec.width * BEAT
	var focused := _fixture([[_tile(dose, 0)], [], []], allies)
	focused.units[0].hp = 70
	focused.units[1].hp = 20
	focused.units[2].hp = 60
	_advance(focused, edge - 1)
	_check(focused.units[1].hp == 20 and focused.units[1].guard == 0, "%s must wait for its right edge." % dose)
	focused.step()
	_check(focused.units[0].hp == 70 and focused.units[1].hp == 20 + dose_spec.heal
		and focused.units[1].guard == dose_spec.guard and focused.units[2].hp == 60,
		"%s should concentrate healing and Guard on the lowest-HP hero." % dose)
	focused.units[1].guard = 0
	_advance(focused, edge + ArenaSim.LOOP_TICKS)
	_check(focused.units[1].hp == 20 + dose_spec.heal and focused.units[1].guard == dose_spec.guard,
		"%s should still grant Guard on the second loop without repeating the heal." % dose)

	var overflow := _fixture([[_tile(dose, 0)], [], []], allies)
	overflow.units[0].hp = 100
	overflow.units[1].hp = 98
	overflow.units[2].hp = 100
	_advance(overflow, edge)
	var overflow_bonus := mini(dose_spec.heal - 2, int(dose_spec.get("heal_overflow_guard", 0)))
	_check(overflow_bonus > 0 and overflow.units[1].hp == 100 and overflow.units[1].guard == dose_spec.guard + overflow_bonus
		and overflow.units[0].guard == 0 and overflow.units[2].guard == 0,
		"%s should turn limited unused healing into Guard on the recipient." % dose)
	overflow.units[1].hp = 98
	overflow.units[1].guard = 0
	_advance(overflow, edge + ArenaSim.LOOP_TICKS)
	_check(overflow.units[1].hp == 98 and overflow.units[1].guard == dose_spec.guard,
		"%s should only convert healing to Guard when the tile actually restores HP." % dose)

	var shared := _fixture([[_tile(mist, 0)], [], []], allies)
	shared.units[0].hp = 50
	shared.units[1].hp = 100
	shared.units[2].hp = 0
	_advance(shared, edge)
	var guard_after_heal: int = mist_spec.guard + int(mist_spec.get("heal_party_guard", 0))
	_check(shared.units[0].hp == 50 + mist_spec.heal and shared.units[1].hp == 100
		and shared.units[1].guard == guard_after_heal and shared.units[2].hp == 0 and shared.units[2].guard == 0,
		"%s should heal injured living heroes, guard the living party, and leave fallen heroes down." % mist)
	shared.units[0].hp = 45
	shared.units[1].hp = 55
	shared.units[0].guard = 0
	_advance(shared, edge + ArenaSim.LOOP_TICKS)
	_check(shared.units[0].hp == 45 and shared.units[0].guard == guard_after_heal
		and shared.units[1].hp == 55 + mist_spec.heal and shared.units[2].hp == 0,
		"%s should heal a previously full hero on a later loop without healing the same hero twice." % mist)


func _check_rune_smith(choices: Array) -> void:
	var heavy: String = choices[0]
	var quick: String = choices[1]
	var edge: int = ArenaSim.TILES[quick].width
	var tap_damage: int = ArenaSim.TILES.tap_bolt.damage
	var spread := _fixture([[_tile(quick, 0), _tile("tap_bolt", edge),
		_tile("jab", edge + 1), _tile("tap_bolt", edge + 2), _tile("tap_bolt", edge + 3),
		_tile("tap_bolt", edge + 4)]], ["rune_smith"])
	_advance(spread, edge * BEAT - 1)
	_check(spread.activations.is_empty(), "%s must wait until its right edge." % quick)
	spread.step()
	_check(_damage_at(spread, quick, edge * BEAT) == ArenaSim.TILES[quick].damage
		and not spread.trace.any(func(event: Dictionary): return event.kind == "rune_charge_spent"),
		"%s must prime after its own hit." % quick)
	_advance(spread, (edge + 1) * BEAT)
	var bonus: int = ArenaSim.TILES[quick].rune_quick_bonus
	_check(_damage_at(spread, "tap_bolt", (edge + 1) * BEAT) == tap_damage + bonus + 5,
		"%s must stack with the Rune Smith's ordinary passive." % quick)
	_move(spread.units[1], spread.units[0].pos + Vector2(240, 0))
	_advance(spread, (edge + 2) * BEAT)
	_check(_damage_at(spread, "jab", (edge + 2) * BEAT) == 0,
		"An out-of-range melee attack should leave the remaining quick rune charges alone.")
	_advance(spread, (edge + 5) * BEAT)
	var charges: Array = spread.trace.filter(func(event: Dictionary): return event.kind == "rune_charge_spent")
	_check(charges.size() == ArenaSim.TILES[quick].rune_quick_hits
		and _damage_at(spread, "tap_bolt", (edge + 3) * BEAT) == tap_damage + bonus
		and _damage_at(spread, "tap_bolt", (edge + 5) * BEAT) == tap_damage,
		"%s must boost multiple quick attacks and stop after the advertised count." % quick)

	var concentrated := _fixture([[_tile(heavy, 0), _tile("tap_bolt", edge),
		_tile("sweep", edge + 1), _tile("sweep", edge + 4)]], ["rune_smith"], "elite")
	_layout_two_targets(concentrated, 1, 100, Vector2(112, 70))
	_advance(concentrated, (edge + 7) * BEAT)
	charges = concentrated.trace.filter(func(event: Dictionary): return event.kind == "rune_charge_spent")
	var hits := concentrated.trace.filter(func(event: Dictionary):
		return event.kind == "hit" and event.tile == "sweep" and event.tick == (edge + 4) * BEAT)
	_check(_damage_at(concentrated, "tap_bolt", (edge + 1) * BEAT) == tap_damage + 5
		and charges.size() == 1 and charges[0].tick == (edge + 4) * BEAT
		and charges[0].amount == ArenaSim.TILES[heavy].rune_heavy_bonus and hits.size() >= 2,
		"%s should boost the first target of a single wide attack, not each target in its splash." % heavy)

	var expired := _fixture([[_tile(quick, 0), _tile("tap_bolt", edge + 1)]], ["rune_smith"])
	_advance(expired, edge * BEAT)
	_move(expired.units[1], Vector2(790, 240))
	_advance(expired, edge * BEAT + ArenaSim.LOOP_TICKS)
	_move(expired.units[1], expired.units[0].pos + Vector2(100, 0))
	var late_hit := (edge + 2) * BEAT + ArenaSim.LOOP_TICKS
	_advance(expired, late_hit)
	_check(_damage_at(expired, "tap_bolt", late_hit) == tap_damage + 5
		and not expired.trace.any(func(event: Dictionary): return event.kind == "rune_charge_spent"),
		"%s should boost no attacks after its rune expires." % quick)


func _check_duelist(choices: Array) -> void:
	var lock: String = choices[0]
	var passing: String = choices[1]
	var lock_spec: Dictionary = ArenaSim.TILES[lock]
	var switch := {"id": "tap_bolt", "start": 5, "target": "farthest"}
	var focused := _fixture([[_tile(lock, 0), _tile(lock, 1), _tile(lock, 2),
		_tile(lock, 3), _tile(lock, 4), switch, _tile(lock, 6)]], ["duelist"], "elite")
	_layout_two_targets(focused, 1, 94, Vector2(180, 60))
	focused.units[1].max_hp = 500
	focused.units[1].hp = 500
	_advance(focused, 7 * BEAT)
	var bonuses := focused.trace.filter(func(event: Dictionary): return event.kind == "duel_stack")
	_check(_damage_at(focused, lock, BEAT) == lock_spec.damage and bonuses.size() == 4
		and bonuses[0].amount == lock_spec.duel_stack_gain
		and bonuses[3].amount == lock_spec.duel_stack_cap
		and _damage_at(focused, lock, 7 * BEAT) == lock_spec.damage,
		"%s must build repeat-hit damage, respect its cap, and reset after switching targets." % lock)

	var cut_spec: Dictionary = ArenaSim.TILES[passing]
	var finisher := _fixture([[_tile(passing, 0), _tile("tap_bolt", 1), _tile("tap_bolt", 2)]], ["duelist"], "elite")
	_layout_two_targets(finisher, 1, 97, Vector2(168, 55))
	finisher.units[1].hp = 1
	_advance(finisher, 3 * BEAT)
	var spent := finisher.trace.filter(func(event: Dictionary): return event.kind == "duel_kill_spent")
	_check(spent.size() == 1 and spent[0].target == finisher.units[2].id and spent[0].amount == cut_spec.duel_kill_bonus
		and _damage_at(finisher, "tap_bolt", 2 * BEAT) == ArenaSim.TILES.tap_bolt.damage + cut_spec.duel_kill_bonus
		and _damage_at(finisher, "tap_bolt", 3 * BEAT) == ArenaSim.TILES.tap_bolt.damage + 2,
		"%s must carry bonus damage from its kill to exactly one hit against another enemy." % passing)


func _check_cantor(choices: Array) -> void:
	var chorus: String = choices[0]
	var ward: String = choices[1]
	var chorus_spec: Dictionary = ArenaSim.TILES[chorus]
	var edge: int = chorus_spec.width
	var last: int = edge + chorus_spec.chorus_mark_beats
	var tap_damage: int = ArenaSim.TILES.tap_bolt.damage
	var party := _fixture([[_tile(chorus, 0), _tile("tap_bolt", edge)],
		[_tile("tap_bolt", edge + 1), _tile("tap_bolt", edge + 2)],
		[_tile("tap_bolt", last - 1), _tile("tap_bolt", last)]], ["cantor", "warden", "hexwright"])
	_layout_cantor_party(party)
	_advance(party, edge * BEAT - 1)
	_check(party.activations.is_empty(), "%s must wait for its right edge." % chorus)
	_advance(party, (last + 1) * BEAT)
	var assists := party.trace.filter(func(event: Dictionary): return event.kind == "chorus_mark_spent")
	_check(_damage_at(party, "tap_bolt", (edge + 1) * BEAT) == tap_damage
		and _damage_at(party, "tap_bolt", (edge + 3) * BEAT) == tap_damage
		and _damage_at(party, "tap_bolt", (last + 1) * BEAT) == tap_damage
		and assists.size() == 2 and assists[0].actor != assists[1].actor
		and assists[0].amount == chorus_spec.chorus_mark_bonus and assists[1].tick == last * BEAT,
		"%s should help two different allies, exclude the caster, and include the expiry beat." % chorus)

	var ward_spec: Dictionary = ArenaSim.TILES[ward]
	var pulses: int = ward_spec.chorus_guard
	var defense := _fixture([[_tile(ward, 0), _tile("tap_bolt", edge)],
		[_tile("tap_bolt", edge + 1), _tile("tap_bolt", edge + 2)], []], ["cantor", "warden", "hexwright"])
	_layout_cantor_party(defense)
	defense.units[2].hp = 0
	_advance(defense, (edge + 1) * BEAT)
	var baseline := [int(defense.units[0].guard), int(defense.units[1].guard)]
	_advance(defense, (edge + 3) * BEAT)
	var wards := defense.trace.filter(func(event: Dictionary): return event.kind == "chorus_guard")
	_check(wards.size() == 1 and wards[0].tick == (edge + 2) * BEAT and wards[0].actor == defense.units[1].id
		and _damage_at(defense, "tap_bolt", (edge + 2) * BEAT) == tap_damage
		and defense.units[0].guard == baseline[0] + pulses and defense.units[1].guard == baseline[1] + pulses
		and defense.units[2].guard == 0, "%s should grant Guard once to the living party after another hero hits." % ward)
	var too_late: int = edge + ward_spec.chorus_guard_beats + 1
	var expired := _fixture([[_tile(ward, 0)], [_tile("tap_bolt", too_late - 1)]], ["cantor", "warden"])
	_layout_cantor_party(expired)
	_advance(expired, too_late * BEAT)
	_check(_damage_at(expired, "tap_bolt", too_late * BEAT) == tap_damage
		and not expired.trace.any(func(event: Dictionary): return event.kind == "chorus_guard"),
		"%s should grant no party Guard after its mark expires." % ward)


func _check_bulwark(choices: Array) -> void:
	var rescue: String = choices[0]
	var ward: String = choices[1]
	var impact_tick: int = ArenaSim.TILES[ward].width * BEAT
	var rescue_sim := _fixture([[_tile(rescue, 0)], [], []], ["bulwark", "warden", "hexwright"])
	_layout_cantor_party(rescue_sim)
	rescue_sim.units[0].hp = 70
	rescue_sim.units[1].hp = 45
	rescue_sim.units[2].hp = 0
	_advance(rescue_sim, impact_tick - 1)
	_check(rescue_sim.units[1].guard == 0, "%s should wait until its right edge." % rescue)
	rescue_sim.step()
	_check(rescue_sim.units[1].guard == ArenaSim.TILES[rescue].guard and rescue_sim.units[0].guard == 0
		and rescue_sim.units[2].guard == 0 and _damage_at(rescue_sim, rescue, impact_tick) > 0,
		"%s should guard the lowest-HP living ally on a hit." % rescue)

	var ward_spec: Dictionary = ArenaSim.TILES[ward]
	var defend := _fixture([[_tile(ward, 0)], [], []], ["bulwark", "warden", "hexwright"])
	_layout_cantor_party(defend)
	defend.units[2].hp = 0
	_advance(defend, impact_tick - 1)
	_check(_events_of(defend, "bastion_ready").is_empty(), "%s should arm only at its right edge." % ward)
	defend.step()
	var caster: Dictionary = defend.units[0]
	var foe: Dictionary = defend.units[3]
	var threshold: int = ward_spec.bastion_block_threshold
	_check(_events_of(defend, "bastion_ready").size() == 1 and caster.guard == ward_spec.guard,
		"%s should grant its own Guard and arm the release on a hit." % ward)
	# The innate first-hit reduction leaves one less than the threshold for Guard to absorb.
	defend._damage(foe, caster, threshold + 5, "enemy_attack")
	_check(_events_of(defend, "bastion_release").is_empty() and defend.units[1].guard == 0,
		"%s should ignore a hit below its actual absorption threshold." % ward)
	var last_tick: int = impact_tick + ward_spec.bastion_beats * BEAT
	_advance(defend, last_tick)
	caster.guard = threshold
	var hp_before: int = caster.hp
	defend._damage(foe, caster, threshold + 3, "enemy_attack")
	_check(caster.hp == hp_before - 3 and caster.guard == ward_spec.bastion_party_guard
		and defend.units[1].guard == ward_spec.bastion_party_guard and defend.units[2].guard == 0,
		"%s should still release at the expiry beat, after incoming damage, for living heroes only." % ward)
	caster.guard = threshold
	defend._damage(foe, caster, threshold, "enemy_attack")
	_check(_events_of(defend, "bastion_release").size() == 1,
		"%s should release only once even if another hit meets the threshold." % ward)

	var expired := _fixture([[_tile(ward, 0)], []], ["bulwark", "warden"])
	_layout_cantor_party(expired)
	_advance(expired, last_tick + 1)
	expired._damage(expired.units[2], expired.units[0], threshold + 6, "enemy_attack")
	_check(_events_of(expired, "bastion_release").is_empty() and expired.units[1].guard == 0,
		"%s should not release after its window ends." % ward)


func _check_lancer(choices: Array) -> void:
	var stride: String = choices[0]
	var return_charge: String = choices[1]
	var stride_spec: Dictionary = ArenaSim.TILES[stride]
	var impact_tick: int = stride_spec.width * BEAT
	for walks in [false, true]:
		var stride_sim := _fixture([[_tile(stride, 0)]], ["lancer"])
		_move(stride_sim.units[0], Vector2(200, 240))
		_move(stride_sim.units[1], Vector2(500, 240))
		if walks:
			stride_sim.units[0].speed = 150.0
		_advance(stride_sim, impact_tick - 1)
		_check(stride_sim.activations.is_empty(), "%s should wait until its right edge." % stride)
		stride_sim.step()
		var bonuses := _events_of(stride_sim, "lance_travel_spent")
		var expected: int = stride_spec.damage + (stride_spec.lance_travel_bonus + 6 if walks else 0)
		_check(_damage_at(stride_sim, stride, impact_tick) == expected
			and (bonuses.size() == 1 and bonuses[0].amount == stride_spec.lance_travel_bonus if walks else bonuses.is_empty()),
			"%s should reward distance walked and stack with the passive, without counting the lunge itself." % stride)

	var charge_spec: Dictionary = ArenaSim.TILES[return_charge]
	var base: int = ArenaSim.TILES.spur.damage
	var followups := _fixture([[_tile(return_charge, 0), _tile("spur", 3), _tile("spur", 5), _tile("spur", 7)], []],
		["lancer", "warden"])
	var actor: Dictionary = followups.units[0]
	var blocker: Dictionary = followups.units[1]
	var target: Dictionary = followups.units[2]
	var origin := Vector2(200, 240)
	_move(actor, origin)
	_move(target, Vector2(380, 240))
	_move(blocker, Vector2(275, 410))
	_advance(followups, impact_tick)
	var prepared := _events_of(followups, "lance_return_ready")
	_check(prepared.size() == 1 and prepared[0].tick == impact_tick
		and _damage_at(followups, return_charge, impact_tick) == charge_spec.damage,
		"%s should prime after pushing a surviving enemy without boosting the same hit." % return_charge)
	target.impulse = Vector2.ZERO
	_move(actor, origin)
	_move(target, Vector2(380, 240))
	_move(blocker, Vector2(275, 240))
	_advance(followups, 5 * BEAT)
	_check(_damage_at(followups, "spur", 5 * BEAT) == 0 and _events_of(followups, "lance_return_spent").is_empty(),
		"%s should retain its bonus through a blocked charge." % return_charge)
	_move(blocker, Vector2(275, 410))
	_advance(followups, 9 * BEAT)
	var spent := _events_of(followups, "lance_return_spent")
	_check(spent.size() == 1 and spent[0].tick == 7 * BEAT and spent[0].amount == charge_spec.lance_return_bonus
		and _damage_at(followups, "spur", 7 * BEAT) == base + charge_spec.lance_return_bonus
		and _damage_at(followups, "spur", 9 * BEAT) == base,
		"%s should boost one landed follow-up charge and leave later hits alone." % return_charge)

	var expired := _fixture([[_tile(return_charge, 0), _tile("spur", 10)]], ["lancer"])
	_move(expired.units[0], origin)
	_move(expired.units[1], Vector2(380, 240))
	_advance(expired, impact_tick)
	expired.units[1].impulse = Vector2.ZERO
	_advance(expired, 12 * BEAT)
	_check(_events_of(expired, "lance_return_ready").size() == 1
		and _events_of(expired, "lance_return_spent").is_empty()
		and _damage_at(expired, "spur", 12 * BEAT) == base,
		"%s should leave a successful charge unboosted after the follow-up window ends." % return_charge)


func _check_cinder_mage(choices: Array) -> void:
	var long_burn: String = choices[0]
	var spread: String = choices[1]
	var long_spec: Dictionary = ArenaSim.TILES[long_burn]
	var impact_tick: int = long_spec.width * BEAT
	var single := _fixture([[_tile(long_burn, 0)]], ["cinder_mage"], "elite")
	_layout_two_targets(single, 1, 110, Vector2(120, 80))
	single.units[1]["displaced_until"] = impact_tick
	_advance(single, impact_tick - 1)
	_check(_events_of(single, "ember_ignite").is_empty(), "%s should wait for its right edge." % long_burn)
	_advance(single, impact_tick + (long_spec.ember_burn_ticks + 1) * BEAT)
	var ignitions := _events_of(single, "ember_ignite")
	var burns := _events_of(single, "ember_tick")
	var main_id: String = single.units[1].id
	_check(ignitions.size() == 1 and ignitions[0].tick == impact_tick and ignitions[0].target == main_id
		and burns.size() == long_spec.ember_burn_ticks and burns.all(func(event: Dictionary):
			return event.target == main_id and event.amount == long_spec.ember_burn_damage)
		and burns[0].tick == impact_tick + BEAT and burns.back().tick == impact_tick + long_spec.ember_burn_ticks * BEAT,
		"%s should burn only its displaced primary at one tick per beat for the full duration." % long_burn)

	var group := _fixture([[_tile(spread, 0)]], ["cinder_mage"], "elite")
	_layout_two_targets(group, 1, 110, Vector2(120, 80))
	group.units[1].hp = 1
	group.units[1]["displaced_until"] = impact_tick
	var spread_spec: Dictionary = ArenaSim.TILES[spread]
	_advance(group, impact_tick + (spread_spec.ember_burn_ticks + 1) * BEAT)
	ignitions = _events_of(group, "ember_ignite")
	burns = _events_of(group, "ember_tick")
	var neighbor_id: String = group.units[2].id
	_check(group.units[1].hp == 0 and ignitions.size() == 1 and ignitions[0].target == neighbor_id
		and burns.size() == spread_spec.ember_burn_ticks and burns.all(func(event: Dictionary):
			return event.target == neighbor_id and event.amount == spread_spec.ember_burn_damage),
		"%s should still light nearby foes on a lethal primary hit and exclude foes outside the radius." % spread)

	var stale := _fixture([[_tile(spread, 0)]], ["cinder_mage"], "elite")
	_layout_two_targets(stale, 1, 110, Vector2(120, 80))
	stale.units[1]["displaced_until"] = impact_tick - 1
	_advance(stale, impact_tick + BEAT)
	_check(_damage_at(stale, spread, impact_tick) > 0 and _events_of(stale, "ember_ignite").is_empty(),
		"%s should still hit after displacement expires without applying burn." % spread)
	if long_spec.rarity == "legendary":
		_check_reapplied_ember_burn(long_burn, spread)


func _check_reapplied_ember_burn(long_burn: String, spread: String) -> void:
	var long_spec: Dictionary = ArenaSim.TILES[long_burn]
	var spread_spec: Dictionary = ArenaSim.TILES[spread]
	var impact_tick: int = long_spec.width * BEAT
	var reapplied := _fixture([[_tile(long_burn, 0), _tile(spread, long_spec.width)]], ["cinder_mage"], "elite")
	_layout_two_targets(reapplied, 1, 110, Vector2(120, 80))
	reapplied.units[1]["displaced_until"] = impact_tick + spread_spec.width * BEAT
	_advance(reapplied, impact_tick + long_spec.ember_burn_ticks * BEAT)
	var main_id: String = reapplied.units[1].id
	var burns := _events_of(reapplied, "ember_tick").filter(func(event: Dictionary): return event.target == main_id)
	_check(burns.size() == long_spec.ember_burn_ticks
		and burns.all(func(event: Dictionary): return event.tile == long_burn)
		and burns.back().tick == impact_tick + long_spec.ember_burn_ticks * BEAT,
		"A weaker burn from the same hero should neither stack nor shorten a stronger burn already ticking.")


func _events_of(sim: ArenaSim, kind: String) -> Array:
	return sim.trace.filter(func(event: Dictionary): return event.kind == kind)


func _layout_two_targets(sim: ArenaSim, first: int, reach: float, near_neighbor: Vector2) -> void:
	var origin := Vector2(200, 240)
	_move(sim.units[0], origin)
	_move(sim.units[first], origin + Vector2(reach, 0))
	_move(sim.units[first + 1], origin + near_neighbor)
	_move(sim.units[first + 2], Vector2(755, 400))


func _layout_cantor_party(sim: ArenaSim) -> void:
	for lane in range(sim.units.size() - 1):
		_move(sim.units[lane], Vector2(230, 130 + lane * 92))
	_move(sim.units[-1], Vector2(355, 240))


func _push_fixture(id: String, hero: String) -> ArenaSim:
	var sim := _fixture([[_tile(id, 0)]], [hero], "elite")
	_move(sim.units[0], Vector2(250, 240))
	_move(sim.units[1], Vector2(370, 240))
	_move(sim.units[2], Vector2(510, 240))
	_move(sim.units[3], Vector2(750, 395))
	return sim


func _pull_fixture(id: String) -> ArenaSim:
	var sim := _fixture([[_tile(id, 0)]], ["hexwright"], "elite")
	_move(sim.units[0], Vector2(255, 240))
	_move(sim.units[1], Vector2(500, 240))
	_move(sim.units[2], Vector2(530, 324))
	_move(sim.units[3], Vector2(700, 392))
	return sim


func _fixture(lanes: Array, hero_ids: Array, encounter := "opening") -> ArenaSim:
	var heroes := hero_ids.map(func(id: String): return {"hero": id})
	var sim := ArenaSim.new()
	# Isolate the signature's base damage and follow-ups from critical rolls.
	sim.start(lanes, "solo", {"encounter": encounter, "heroes": heroes, "difficulty": "hard", "segment": 3, "seed": 17})
	for unit: Dictionary in sim.units:
		unit.speed = 0.0
		unit.next_attack = 99999
		unit.guard = 0
		if unit.side == "enemy":
			_move(unit, sim.units[0].pos + Vector2(120, 0))
			unit.hp = 220
			unit.max_hp = 220
	return sim


func _move(unit: Dictionary, position: Vector2) -> void:
	unit.pos = position
	unit.prev_pos = position


func _tile(id: String, start: int) -> Dictionary:
	return {"id": id, "start": start, "target": "nearest"}


func _advance(sim: ArenaSim, tick: int) -> void:
	while sim.tick < tick and sim.outcome.is_empty():
		sim.step()


func _damage_at(sim: ArenaSim, tile_id: String, tick: int) -> int:
	for activation: Dictionary in sim.activations:
		if activation.tile == tile_id and activation.tick == tick:
			return activation.damage
	return 0


func _check(passed: bool, message: String) -> void:
	if not passed:
		failures.append(message)
