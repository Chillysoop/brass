extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const ArenaView = preload("res://scripts/arena_view.gd")
const HeroChoreography = preload("res://scripts/hero_attack_choreography.gd")
const CombatSpritePose = preload("res://scripts/combat_sprite_pose.gd")
const TileEnchantments = preload("res://scripts/tile_enchantments.gd")

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
	var skyline := "horizon_round_upgrade_rare_power"
	_expect(ArenaSim.TILES[skyline].label == "Skyline Shot"
		and HeroChoreography.profile(skyline, ArenaSim.TILES[skyline]).signature_effect == "skyline",
		"Starshot's actual rare Power upgrade must use its signature rifle effect.")

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
	_check_fast_windup(view)
	_check_windup_layout(view)
	_check_marshal_weathered_feedback(view, false)
	_check_marshal_weathered_feedback(view, true)
	_check_burn_status(view)
	_check_movement_paths(view)
	_check_fast_mobility(view)
	view.queue_free()
	for failure: String in _failures:
		printerr(failure)
	if _failures.is_empty():
		print("All %d tile animation profiles and exact-edge arena playback passed." % ArenaSim.TILES.size())
	quit(0 if _failures.is_empty() else 1)


func _check_fast_windup(view: ArenaView) -> void:
	var sim := ArenaSim.new()
	var lanes := [[{"id": "bash", "start": 0, "target": "nearest"}]]
	sim.start(lanes, "solo", {"kind": "opening"})
	view.reset_view(sim.units, lanes)
	var hero: Dictionary = sim.units[0]
	var enemy: Dictionary = sim.units[1]
	enemy.intent = hero.id
	enemy.intent_start_tick = 98
	enemy.intent_tick = 99
	enemy.intent_attack_id = "recruit"
	view.present(sim.units, [], 98, [], 3)
	_expect(view._windups.get(enemy.id) == Vector2i(98, 99), "Fast playback must capture a short windup on its actual start tick.")

	enemy.intent = ""
	view.present(sim.units, [], 99, [{"kind": "enemy_cast", "actor": enemy.id, "tile": "recruit",
		"from": enemy.pos, "to": hero.pos, "target": hero.id, "landed": true}], 3)
	_expect(not view._windups.has(enemy.id) and view._actor_casts.has(enemy.id),
		"A windup crossed between renders must end when the release arrives and keep the cast visible.")
	view._process(0.18)
	_expect(view._actor_casts.has(enemy.id) and not view._windups.has(enemy.id),
		"The release should remain readable in real time at 3× without displaying a false windup.")
	view._process(0.07)
	_expect(not view._actor_casts.has(enemy.id), "A fast release must expire after its real-time display window.")

	enemy.intent = hero.id
	enemy.intent_start_tick = 105
	enemy.intent_tick = 120
	view.present(sim.units, [], 105, [], 3)
	enemy.intent = ""
	view.present(sim.units, [], 106, [], 3)
	_expect(not view._windups.has(enemy.id) and not view._actor_casts.has(enemy.id),
		"Canceling a windup must clear the warning without inventing a release.")


func _check_windup_layout(view: ArenaView) -> void:
	var original_size := view.size
	view.size = Vector2(390, 260)
	view.reset_view([])
	var area := Rect2(8, 8, 374, 244)
	var health := Rect2(140, 135, 94, 32)
	var anchor := Vector2(187, 135)
	var extent := Vector2(118, 36)
	var occupied: Array[Rect2] = [health]
	var first := view._windup_callout_bounds(area, anchor, extent, occupied)
	_expect(first.get_center().x == anchor.x and first.end.y < health.position.y,
		"A windup belongs above its unit's HUD when that space is available.")
	occupied.append(first)
	var second := view._windup_callout_bounds(area, anchor + Vector2(5, 2), extent, occupied)
	_expect(area.encloses(second) and not second.intersects(first) and not second.intersects(health),
		"Nearby windups occupy separate readable space at narrow widths.")
	occupied.append(second)
	var third := view._windup_callout_bounds(area, anchor + Vector2(7, 2), Vector2(153, 36), occupied)
	_expect(area.encloses(third) and not occupied.any(func(other: Rect2): return other.intersects(third)),
		"A third enlarged label can reflow around crowded HUDs.")
	var left_edge := view._windup_callout_bounds(area, Vector2(14, 65), extent, [])
	_expect(area.encloses(left_edge), "A windup against the arena edge stays on the board.")

	view.present([], [{"kind": "hit", "tile": "shot", "actor": "hero_1", "target": "enemy",
		"amount": 25, "from": Vector2(600, 260), "to": Vector2(635, 270)}], 21, [], 3)
	view._combat_number_layout_size = view.size
	view._combat_numbers[0]["bounds"] = first
	view._layout_combat_numbers(area, 0.45, [health], [first, second])
	var moved: Rect2 = view._combat_numbers[0].bounds
	_expect(moved.has_area() and not moved.intersects(first) and not moved.intersects(second),
		"An active damage number yields to a newly occupied windup position at 3×.")
	view._layout_combat_numbers(area, 0.45, [health], [first, second])
	_expect(view._combat_numbers[0].bounds == moved, "The damage number remains in place without another collision.")
	view.size = original_size
	view.reset_view([])


func _check_marshal_weathered_feedback(view: ArenaView, partial: bool) -> void:
	var sim := ArenaSim.new()
	var difficulty := "hard" if partial else "medium"
	sim.start([[], []], "duo", {"location": "brass", "difficulty": difficulty,
		"segment": 2, "encounter": "boss", "boss_id": "gilded_marshal",
		"heroes": [{"hero": "warden"}, {"hero": "starshot"}]})
	var marshal: Dictionary = sim.units.back()
	marshal.pos = Vector2(800, 265)
	marshal.marshal_plated = true
	marshal.marshal_plate_integrity = marshal.marshal_plate_max_integrity
	marshal["pilot_ring_radius"] = float(marshal.attack.reach) + ArenaSim.MARSHAL_SWEEP_EXTRA_REACH
	var lead: Dictionary = sim.units.front()
	if partial:
		lead.pos = Vector2(725, 265)
		lead.guard = int(marshal.marshal_sweep_damage) - 5
	sim._start_enemy_intent(marshal, sim.units.front().id, sim.tick + 1, "marshal_sweep")
	view.reset_view(sim.units)
	var events := sim.step()
	view.present(sim.units, events, sim.tick, sim.visual_cues, 3)
	var is_weathered := func(effect: Dictionary) -> bool:
		return (effect.kind == "marshal_sweep_weathered" and effect.target == marshal.id
			and effect.get("partial", false) == partial)
	view._process(0.35)
	_expect(view._effects.any(is_weathered), "Successful mitigation of the Marshal's real %s sweep stays visible at 3×." % difficulty)
	view._process(0.42)
	_expect(not view._effects.any(is_weathered), "The weathered-sweep confirmation should fade after the cue.")


func _check_burn_status(view: ArenaView) -> void:
	var sim := ArenaSim.new()
	sim.start([[], []], "duo", {"kind": "opening",
		"heroes": [{"hero": "cinder_mage"}, {"hero": "warden"}]})
	var target: Dictionary = sim.units[2]
	var cinder: Dictionary = sim.units[0]
	var warden: Dictionary = sim.units[1]
	for unit: Dictionary in sim.units:
		unit.next_attack = 99999
	target.hp = 500
	target.max_hp = 500
	sim.step()
	var applied_at := sim.tick
	sim._displace("push", warden, target, "bash", Vector2.RIGHT, 380.0)
	sim._class_attack_damage(cinder, target, "shot", 5)
	_expect(view._burn_beats_left(target) == 2, "The live Cinder passive contributes its remaining Burn beats.")
	sim._ignite_ember(warden, target, "shot", TileEnchantments.EMBER_DAMAGE, TileEnchantments.EMBER_BEATS, "embered")
	_expect(view._burn_beats_left(target) == 2, "Overlapping passive and Embered durations are not added together.")
	var native_id := "cinder_wave_upgrade_legendary_power"
	var native: Dictionary = ArenaSim.TILES[native_id]
	sim._apply_ember_burn(cinder, target, native_id, native, target.pos, true)
	view.reset_view(sim.units)
	var burn_beats: int = native.ember_burn_ticks
	_expect(view._burn_beats_left(target) == burn_beats, "A longer tile Burn provides the current duration.")
	for elapsed in range(1, burn_beats + 1):
		while sim.tick < applied_at + elapsed * ArenaSim.TICKS_PER_BEAT and sim.outcome.is_empty():
			var events := sim.step()
			view.present(sim.units, events, sim.tick, sim.visual_cues, 3)
		_expect(view._burn_beats_left(target) == burn_beats - elapsed,
			"The Burn counter advances at resolved ticks during 3× playback and clears on expiry.")
	var narrow_bar := Rect2(18, 70, 31, 5)
	var near_edge := view._burn_badge_bounds(narrow_bar, 4, 7.0)
	_expect(near_edge.position.x >= 2.0 and near_edge.end.y < narrow_bar.position.y - 16.0,
		"At the arena edge the Burn badge wraps above a narrow bar without covering health or windup.")


func _check_movement_paths(view: ArenaView) -> void:
	var field := Rect2(40, 65, 800, 260)
	var departure := Vector2(310, 270)
	var shoulder := Vector2(432, 211)
	var landing := Vector2(514, 278)
	var route := PackedVector2Array([departure, shoulder, landing])
	var path := view._project_charge_path({"from": departure, "to": landing, "route": route}, field)
	_expect(path.size() == 3 and path[0].is_equal_approx(Vector2(288, 200))
		and path[1].is_equal_approx(Vector2(385.6, 170.5)) and path[2].is_equal_approx(Vector2(451.2, 204)),
		"A curved charge cue keeps the actual bend and landing on a scaled battlefield.")
	_expect(view._project_charge_path({"from": departure, "to": departure}, field).size() == 1,
		"A charge with no movement cannot invent a path.")

	var flank := {"kind": "relic_proc", "tile": "flanking_standard", "actor": "hero_2", "target": "rival",
		"from": departure, "to": landing, "previous_direction": Vector2(0.36, -0.93).normalized()}
	var approaches := view._flanking_approaches(flank, field)
	var scale := field.size / ArenaView.WORLD_SIZE
	_expect(approaches[0].is_equal_approx(((departure - landing) * scale).normalized())
		and approaches[1].is_equal_approx((flank.previous_direction * scale).normalized())
		and not approaches[0].is_equal_approx(-approaches[1]), "The flank draws the two recorded angles, including a non-mirrored attack.")
	view.reset_view([])
	view.present([], [flank], 63, [], 3)
	view._process(0.33)
	_expect(view._effects.size() == 1 and view._effects[0].kind == "flanking_standard",
		"The flank has a legible lifetime even at 3× speed.")
	view._process(0.31)
	_expect(view._effects.is_empty(), "A flank cue expires on its presentation clock.")


func _check_fast_mobility(view: ArenaView) -> void:
	var movement_types := {"blink": "teleport", "veil_step": "teleport", "backdraft_bolt": "retreat", "pinpoint_lunge": "charge"}
	for multiplier in [2, 3]:
		for id: String in movement_types:
			var lanes := [[{"id": id, "start": 0}]]
			var sim := _range_fixture("duelist" if id == "pinpoint_lunge" else "wayfarer", lanes[0])
			var hero: Dictionary = sim.units[0]
			hero.speed = 0.0
			var origin: Vector2 = hero.pos
			var kind: String = movement_types[id]
			view.reset_view(sim.units, lanes)
			var edge: int = ArenaSim.TILES[id].width * ArenaSim.TICKS_PER_BEAT
			while sim.tick < edge - 1:
				var events := sim.step()
				view.present(sim.units, events, sim.tick, sim.visual_cues, multiplier)
			_expect(view._effects.is_empty() and view._attack_casts.is_empty(),
				"%s cannot show its movement or attack before the firing edge at %d×." % [id, multiplier])
			var events := sim.step()
			view.present(sim.units, events, sim.tick, sim.visual_cues, multiplier)
			var motion := view._effects.filter(func(effect: Dictionary): return effect.kind == kind)
			_expect(motion.size() == 1 and motion[0].from == origin and motion[0].to == hero.pos and hero.pos != origin,
				"%s shows exactly one resolved movement between its real endpoints at %d×." % [id, multiplier])
			if id == "veil_step":
				var cast: Dictionary = view._actor_casts.get(hero.id, {})
				_expect(not cast.is_empty() and cast.profile.style == "shot" and cast.strike_from == origin
					and cast.arrival == hero.pos, "Veil Step shows a shot from before the blink alongside its portal cue.")
			if id == "pinpoint_lunge" and motion.size() == 1:
				_check_curved_charge_sprite(view, sim, motion[0], multiplier)
			view._process(0.30)
			_expect(view._effects.any(func(effect: Dictionary): return effect.kind == kind),
				"%s's movement survives the same real-time display window at %d×." % [id, multiplier])


func _check_curved_charge_sprite(view: ArenaView, sim: ArenaSim, motion: Dictionary, multiplier: int) -> void:
	var hero: Dictionary = sim.units[0]
	_expect(view._positions[hero.id] == motion.from and sim.activations[0].tick == motion.tick
		and sim.activations[0].damage > 0, "The curved sprite starts at departure while the hit records at the tile edge.")
	var cast: Dictionary = view._actor_casts[hero.id]
	_expect(view._sprite_facing(hero, cast) == signf(cast.to.x - motion.from.x),
		"A charging hero faces its target from the visible part of the route.")
	view._process(ArenaView.CURVED_CHARGE_SECONDS * 0.5)
	var midpoint: Vector2 = view._positions[hero.id]
	var straight := Geometry2D.get_closest_point_to_segment(midpoint, motion.from, motion.to)
	_expect(midpoint.distance_to(straight) > 8.0, "The sprite follows the curved route around the target at %d×." % multiplier)
	if multiplier == 3:
		hero.pos += Vector2(30.0, 26.0)
		var blink := {"kind": "teleport", "tile": "blink", "actor": hero.id, "target": sim.units[1].id,
			"from": motion.to, "to": hero.pos}
		view.present(sim.units, [blink], sim.tick + 1, [], multiplier)
	else:
		hero.pos += Vector2(3.0, 1.0)
		view.present(sim.units, [], sim.tick + 1, [], multiplier)
		view._process(ArenaView.CURVED_CHARGE_SECONDS * 0.56)
	_expect(not view._curved_charges.has(hero.id) and view._positions[hero.id] == hero.pos,
		"The curved sprite reconciles with the latest position after ongoing movement or a new blink.")


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
