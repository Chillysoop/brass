extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const ArenaView = preload("res://scripts/arena_view.gd")
const HeroChoreography = preload("res://scripts/hero_attack_choreography.gd")
const CombatSpritePose = preload("res://scripts/combat_sprite_pose.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var styles := {}
	var profiles := {}
	for id: String in ArenaSim.TILES:
		var profile := HeroChoreography.profile(id, ArenaSim.TILES[id])
		profiles[JSON.stringify(profile)] = true
		styles[profile.style] = true
	_expect(profiles.size() == ArenaSim.TILES.size(), "Every tile must have its own profile, including forge upgrades.")
	_expect(styles.size() >= 12, "Tiles should vary in shape and pose as well as color.")
	_expect(HeroChoreography.profile("bash", ArenaSim.TILES.bash).style == "thrust"
		and HeroChoreography.profile("slam", ArenaSim.TILES.slam).style == "heavy"
		and HeroChoreography.profile("rail_shot", ArenaSim.TILES.rail_shot).style == "bolt", "Core attacks need distinct animation families.")

	var view := ArenaView.new()
	root.add_child(view)
	view.set_process(false)
	view.size = Vector2(850, 357)
	var sim := ArenaSim.new()
	var lanes := [[{"id": "shot", "start": 1, "target": "nearest"}]]
	sim.start(lanes, "solo", {"kind": "opening"})
	view.reset_view(sim.units, lanes)
	var hero: Dictionary = sim.units[0]
	var fire_tick := ArenaSim.TICKS_PER_BEAT * 3
	for _i in range(fire_tick - 1):
		var events := sim.step()
		view.present(sim.units, events, sim.tick, sim.visual_cues)
	_expect(not view._windup_details(hero).is_empty() and not view._actor_casts.has(hero.id),
		"At the tick before the tile's right edge the hero is still preparing.")
	var events := sim.step()
	view.present(sim.units, events, sim.tick, sim.visual_cues)
	_expect(view._actor_casts.has(hero.id) and view._actor_casts[hero.id].tile == "shot"
		and view._actor_casts[hero.id].profile.style == "shot" and view._windup_details(hero).is_empty(),
		"The shot's animation must reach the view on the exact right edge.")
	view._process(1.0)
	_expect(view._attack_casts.is_empty() and view._actor_casts.is_empty(), "Expired effects must release every sprite pose.")

	var queued: Array = sim.visual_cues.duplicate()
	view.present(sim.units, [], sim.tick, queued)
	view.reset_view(sim.units, lanes)
	_expect(view._attack_casts.is_empty() and view._actor_casts.is_empty() and view._windups.is_empty(),
		"Reset must clear the old attack effects and windups.")
	_check_ranged_standoff(view)
	_check_limb_pose(view)
	view.queue_free()
	for failure: String in _failures:
		printerr(failure)
	if _failures.is_empty():
		print("All %d tile animation profiles and exact-edge arena playback passed." % ArenaSim.TILES.size())
	quit(0 if _failures.is_empty() else 1)


func _check_ranged_standoff(view: ArenaView) -> void:
	var starshot := _range_fixture("starshot", [{"id": "rivet_bolt", "start": 0}, {"id": "guard", "start": 2}])
	var hero: Dictionary = starshot.units[0]
	var enemy: Dictionary = starshot.units[1]
	starshot.step()
	view.present(starshot.units, [], starshot.tick)
	_expect(hero.velocity.x < 0.0 and view._sprite_facing(hero, {}) > 0.0,
		"A ranged hero backs away while facing a threat on the right.")
	for tick in range(2 * ArenaSim.TICKS_PER_BEAT - 1):
		starshot.step()
	_expect(starshot.activations.size() == 1 and starshot.activations[0].damage == 16
		and hero.pos.distance_to(enemy.pos) > 200.0,
		"Starshot fires an ordinary Rivet Bolt from far enough away for the class passive.")
	enemy.pos = hero.pos - Vector2(175.0, 0.0)
	starshot.step()
	view.present(starshot.units, [], starshot.tick)
	_expect(hero.velocity.x > 0.0 and view._sprite_facing(hero, {}) < 0.0,
		"A ranged hero also backs away while facing a threat on the left.")

	var short_ranged := _range_fixture("warden", [{"id": "snap_shot", "start": 0}])
	for tick in range(ArenaSim.TICKS_PER_BEAT):
		short_ranged.step()
	_expect(short_ranged.activations.size() == 1 and short_ranged.activations[0].damage == 6
		and short_ranged.units[0].pos.distance_to(short_ranged.units[1].pos) > 185.0,
		"A shorter ranged build from another class does not charge into melee.")

	var mixed := _range_fixture("starshot", [{"id": "bash", "start": 0}, {"id": "shot", "start": 2}])
	for tick in range(4 * ArenaSim.TICKS_PER_BEAT):
		mixed.step()
	_expect(mixed.activations.size() == 2 and mixed.activations[0].damage > 0 and mixed.activations[1].damage > 0,
		"A mixed lane still closes far enough to use its melee attack and then lands its shot.")


func _range_fixture(hero_id: String, lane: Array) -> ArenaSim:
	var sim := ArenaSim.new()
	sim.start([lane], "solo", {"encounter": "opening", "hero": hero_id})
	sim.units[1].pos = sim.units[0].pos + Vector2(175.0, 0.0)
	sim.units[1].speed = 0.0
	sim.units[1].next_attack = 99999
	return sim


func _check_limb_pose(view: ArenaView) -> void:
	var geometry := CombatSpritePose.geometry(preload("res://assets/warden.png"), 1.0)
	var sprite := CombatSpritePose.new(geometry)
	var neutral: PackedVector2Array = geometry.points
	sprite._update_vertices(CombatSpritePose.leg_pose(PI / 3.0, 1.0, 0.0), Vector3.ZERO)
	var stride: PackedVector2Array = sprite._vertices.duplicate()
	var front_leg_moved := false
	var back_leg_moved := false
	for i in range(stride.size()):
		var shift := stride[i] - neutral[i]
		front_leg_moved = front_leg_moved or shift.x > 0.05
		back_leg_moved = back_leg_moved or shift.x < -0.05
	_expect(front_leg_moved and back_leg_moved and stride[0].is_equal_approx(neutral[0]),
		"The legs stride in opposite directions under a stable head.")

	var strike := HeroChoreography.profile("slam", ArenaSim.TILES.slam)
	sprite._update_vertices(Vector4.ZERO, CombatSpritePose.arm_pose(strike, 1.0, false))
	var windup: PackedVector2Array = sprite._vertices.duplicate()
	sprite._update_vertices(Vector4.ZERO, CombatSpritePose.arm_pose(strike, 1.0, true))
	_expect(windup != sprite._vertices and sprite._vertices[-1].is_equal_approx(neutral[-1]),
		"The leading arm moves between the windup and strike while the feet stay planted.")

	var unit := {"id": "limb_test", "side": "hero", "radius": 24.0, "facing": 1.0,
		"drive_velocity": Vector2(70.0, 0.0)}
	view._gait_phases[unit.id] = PI
	view._update_gait(unit, Vector2(2.0, 0.0), 1.0 / 60.0)
	_expect(view._gait_phases[unit.id] > PI, "Forward movement advances the gait.")
	unit.drive_velocity = Vector2(-70.0, 0.0)
	view._update_gait(unit, Vector2(-2.0, 0.0), 1.0 / 60.0)
	_expect(is_equal_approx(float(view._gait_phases[unit.id]), PI), "Backing away reverses the gait while facing forward.")
	unit.drive_velocity = Vector2.ZERO
	view._update_gait(unit, Vector2(13.0, 0.0), 1.0 / 60.0)
	_expect(is_zero_approx(float(view._gait_strengths[unit.id]))
		and is_equal_approx(float(view._gait_phases[unit.id]), PI), "Forced movement does not generate footsteps.")
	view.playback_paused = true
	view._process(0.25)
	_expect(is_equal_approx(float(view._gait_phases[unit.id]), PI), "Pause freezes the gait.")
	view.playback_paused = false


func _expect(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
