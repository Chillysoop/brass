extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const BEAT := ArenaSim.TICKS_PER_BEAT

var failures: Array[String] = []


func _initialize() -> void:
	_check_multi_hit_at_loop_edge()
	_check_blink_and_miss()
	_check_afterimage_cue_origin()
	_check_meteor_footprint()
	_check_enemy_ground_target()
	_check_boss_phase_change()
	_check_canceled_windup()
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Combat animation cues passed tile-edge timing, multi-hit, enemy aim, phase changes, and interrupts.")
	quit(0 if failures.is_empty() else 1)


func _check_multi_hit_at_loop_edge() -> void:
	var sim := _fixture("bruiser", [{"id": "slam", "start": 8}], 128.0)
	var hero: Dictionary = sim.units[0]
	var target: Dictionary = sim.units[1]
	sim._add_campaign_enemy("bruiser", Vector2(430, 330))
	var other: Dictionary = sim.units[2]
	other.speed = 0.0
	other.next_attack = 1000
	_advance(sim, ArenaSim.LOOP_TICKS - 1)
	_expect(sim.visual_cues.is_empty() and target.hp == target.max_hp and other.hp == other.max_hp,
		"A tile ending at beat 12 must have no cast cue or damage on the preceding tick.")
	var events := sim.step()
	var hits := events.filter(func(event: Dictionary) -> bool: return event.kind == "hit" and event.tile == "slam")
	var cue := _cue(sim, "hero_cast", "slam")
	_expect(hits.size() == 2 and sim.visual_cues.size() == 1 and cue.get("tick", -1) == ArenaSim.LOOP_TICKS,
		"A Slam must release on its right edge with one visual cue even when two targets are hit.")
	_expect(cue.get("from") == hero.pos and cue.get("radius") == ArenaSim.TILES.slam.radius and cue.get("landed", false),
		"Slam's cue should carry the actual origin, skill radius, and contact result.")
	_expect(cue.get("contact_points", []).size() == 2, "The shared impact cue retains both actual contact points.")
	_expect(events == sim.trace, "Visual cues must stay outside the existing combat event stream on this fixture.")
	sim.step()
	_expect(sim.visual_cues.is_empty(), "Consumers should not receive the same cast cue on the next simulation step.")


func _check_blink_and_miss() -> void:
	var sim := _fixture("bruiser", [{"id": "blink", "start": 0}], 170.0)
	var origin: Vector2 = sim.units[0].pos
	_advance(sim, 3 * BEAT)
	var cue := _cue(sim, "hero_cast", "blink")
	_expect(cue.get("landed", false) and cue.get("from") == origin and cue.get("arrival") == sim.units[0].pos
		and sim.units[0].pos != origin and cue.get("to") == sim.units[1].pos,
		"Blink must publish the distinct departure, landing, and enemy aim points on the same simulation tick.")
	var miss := _fixture("bruiser", [{"id": "bash", "start": 0}], 500.0)
	_advance(miss, 2 * BEAT)
	var whiff := _cue(miss, "hero_cast", "bash")
	_expect(not whiff.is_empty() and not whiff.landed and miss.units[1].hp == miss.units[1].max_hp,
		"A tile can play its attack animation when it misses without reporting a landed hit.")


func _check_afterimage_cue_origin() -> void:
	var sim := _fixture("bruiser", [{"id": "blink", "start": 0}, {"id": "rivet_bolt", "start": 3}], 170.0)
	var hero: Dictionary = sim.units[0]
	hero.relics = ["afterimage"]
	var start: Vector2 = hero.pos
	_advance(sim, 5 * BEAT - 1)
	_expect(hero.get("afterimage", {}).get("position") == start and sim.visual_cues.is_empty(),
		"The Afterimage stays at Blink's departure point until the follow-up is due.")
	sim.step()
	var cue := _cue(sim, "hero_cast", "rivet_bolt")
	_expect(cue.get("tick") == 5 * BEAT and cue.get("from_afterimage", false) and cue.get("strike_from") == start
		and cue.get("from") == hero.pos and start != hero.pos and not hero.has("afterimage"),
		"The follow-up uses the Afterimage without moving the living hero or playing it before its tile finishes.")


func _check_meteor_footprint() -> void:
	var sim := _fixture("bruiser", [{"id": "meteor_seal", "start": 0}], 220.0)
	var primary: Dictionary = sim.units[1]
	var landing: Vector2 = primary.pos
	sim._add_campaign_enemy("bruiser", landing + Vector2(20.0, 120.0))
	var secondary: Dictionary = sim.units[2]
	secondary.speed = 0.0
	secondary.next_attack = 1000
	_advance(sim, 5 * BEAT - 1)
	_expect(sim.visual_cues.is_empty() and primary.hp == primary.max_hp and secondary.hp == secondary.max_hp,
		"Meteor Seal must not land before the tile ends.")
	sim.step()
	var cue := _cue(sim, "hero_cast", "meteor_seal")
	_expect(cue.get("tick") == 5 * BEAT and cue.get("to") == landing
		and cue.get("radius") == ArenaSim.TILES.meteor_seal.radius and cue.get("contact_points", []).size() == 2,
		"Meteor Seal draws one impact at the actual area center and knows both contacts.")


func _check_enemy_ground_target() -> void:
	var sim := _fixture("dock_bilge_sapper", [], 180.0, 1)
	var hero: Dictionary = sim.units[0]
	var sapper: Dictionary = sim.units[1]
	sim.step()
	var marked: Vector2 = hero.pos
	var release: int = sapper.intent_tick
	_expect(sapper.intent_start_tick == 1 and sapper.intent_attack_id == "dock_bilge_sapper" and sim.visual_cues.is_empty(),
		"Enemy windup must expose its timing and attack ID before it produces a cast cue.")
	hero.pos += Vector2(0, 105)
	_advance(sim, release - 1)
	_expect(sim.visual_cues.is_empty(), "A ground attack should not release its cast animation early.")
	var events := sim.step()
	var cue := _cue(sim, "enemy_cast", "dock_bilge_sapper")
	_expect(cue.get("to") == marked and cue.get("radius") == sapper.attack.blast_radius and cue.get("tick") == release,
		"An enemy ground attack should animate at its committed aim point and on its exact resolution tick.")
	_expect(hero.hp == hero.max_hp and events.any(func(event: Dictionary) -> bool: return event.kind == "hazard_burst"),
		"Dodging the ground attack keeps its burst but avoids damage.")


func _check_boss_phase_change() -> void:
	var sim := ArenaSim.new()
	sim.start([[]], "solo", {"location": "moonwreck", "encounter": "boss", "boss_id": "wreckmaster"})
	var hero: Dictionary = sim.units[0]
	var boss: Dictionary = sim.units[1]
	hero.speed = 0.0
	boss.speed = 0.0
	_advance(sim, 3 * BEAT)
	var harpoon := _cue(sim, "enemy_cast", "wreckmaster_harpoon")
	_expect(harpoon.get("tick") == 3 * BEAT and boss.intent_start_tick == 3 * BEAT
		and boss.intent_attack_id == "wreckmaster_slam_windup" and sim.visual_cues.size() == 1,
		"The harpoon release should animate once while the follow-up starts a new windup on the same tick.")
	_advance(sim, 6 * BEAT)
	var slam := _cue(sim, "enemy_cast", "wreckmaster_slam_windup")
	_expect(slam.get("tick") == 6 * BEAT and slam.get("to") == boss.pos
		and slam.get("radius") == boss.wreckmaster_slam_radius,
		"The follow-up Deck Slam should animate on beat 6 around the boss's own location.")


func _check_canceled_windup() -> void:
	var sim := _fixture("dock_shellback", [{"id": "slam", "start": 0}], 106.0, 60)
	_advance(sim, 60)
	var shellback: Dictionary = sim.units[1]
	var release: int = shellback.intent_tick
	_advance(sim, 4 * BEAT)
	_expect(shellback.intent.is_empty() and shellback.get("cracked_shell", false),
		"The fixture must interrupt Shellback with a heavy hit while the shell is still closing.")
	_advance(sim, release)
	_expect(_cue(sim, "enemy_cast", "dock_shellback").is_empty() and shellback.guard == 0,
		"Interrupting an enemy must prevent its cast cue as well as its action.")


func _fixture(enemy_id: String, lane: Array, distance: float, first_attack := 1000) -> ArenaSim:
	var sim := ArenaSim.new()
	sim.start([lane], "solo", {"encounter": "opening", "hero": "warden"})
	sim.units.resize(1)
	var hero: Dictionary = sim.units[0]
	hero.pos = Vector2(300, 260)
	hero.speed = 0.0
	sim._add_campaign_enemy(enemy_id, hero.pos + Vector2(distance, 0))
	sim.units[1].speed = 0.0
	sim.units[1].next_attack = first_attack
	return sim


func _advance(sim: ArenaSim, target_tick: int) -> void:
	while sim.tick < target_tick and sim.outcome.is_empty():
		sim.step()


func _cue(sim: ArenaSim, kind: String, tile: String) -> Dictionary:
	for cue: Dictionary in sim.visual_cues:
		if cue.kind == kind and cue.tile == tile:
			return cue
	return {}


func _expect(condition: bool, failure: String) -> void:
	if not condition:
		failures.append(failure)
