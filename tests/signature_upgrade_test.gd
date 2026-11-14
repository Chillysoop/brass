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
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Rare, Epic, and Legendary signature combat checks passed for Warden, Hexwright, and Starshot.")
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
	sim.start(lanes, "solo", {"encounter": encounter, "heroes": heroes, "difficulty": "hard", "segment": 3})
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
