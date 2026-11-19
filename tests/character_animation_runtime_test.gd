extends SceneTree

const Sheet = preload("res://scripts/combat_sprite_sheet.gd")
const Pose = preload("res://scripts/combat_sprite_pose.gd")
const ArenaSim = preload("res://scripts/arena_sim.gd")
const ArenaView = preload("res://scripts/arena_view.gd")
const HeroChoreography = preload("res://scripts/hero_attack_choreography.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _fixture_sheet() -> RefCounted:
	var path := "res://assets/sprite_fusion/characters/hero_warden.png"
	var animations := {}
	for state: String in Sheet.STATES:
		var count := 1 if state == "idle" else (8 if state == "attack_heavy" else 6)
		var frames := []
		for index in range(count):
			frames.append({"rect": [0, 0, 80, 80], "pivot": [40, 76],
				"sockets": {"hand": [54 + index, 38], "muzzle": [62 + index * 2, 30],
					"blade": [68 + index, 26], "cast": [52, 24 - index], "feet": [40, 76]}})
		animations[state] = {"texture": path, "frames": frames, "contact_frame": 3,
			"fps": 12, "loop": state in ["run", "backpedal", "strafe"], "stride_length": 48,
			"reference_height": 100 if state == "attack_heavy" else 80}
	return Sheet.new({"height": 80, "facing": 1, "animations": animations})


func _run() -> void:
	var sheet := _fixture_sheet()
	for action: String in ["attack_quick", "attack_heavy", "attack_ranged", "attack_cast", "attack_guard", "attack_mobility"]:
		_check(sheet.attack_frame(0.999, false, action) < 3 and sheet.attack_frame(0.0, true, action) == 3,
			"%s separates preparation from the exact contact frame." % action)
	var choices := {
		"warden": ["guard", 2, "attack_guard"], "bulwark": ["heavy", 4, "attack_heavy"],
		"breaker": ["heavy", 4, "attack_heavy"], "hexwright": ["ward", 3, "attack_guard"],
		"wayfarer": ["blink", 3, "attack_mobility"], "lancer": ["thrust", 4, "attack_heavy"],
		"cantor": ["ward", 3, "attack_guard"], "apothecary": ["burst", 4, "attack_ranged"],
		"rune_smith": ["mark", 2, "attack_cast"], "starshot": ["bolt", 5, "attack_heavy"],
		"cinder_mage": ["burst", 4, "attack_heavy"], "duelist": ["spin", 3, "attack_heavy"],
	}
	for identity: String in choices:
		var spec: Array = choices[identity]
		_check(sheet.action_for({"style": spec[0], "tile_animation": {"beats": spec[1]}}, identity) == spec[2],
			"%s selects the appropriate authored class action." % identity)
	_check(sheet.action_for({"style": "shot"}, "starshot") == "attack_ranged", "A quick rifle shot keeps its ranged action.")
	_check(sheet.action_for({"style": "bolt"}, "cinder_mage") == "attack_cast", "A quick spell keeps its caster action.")
	_check(sheet.action_for(HeroChoreography.profile("quick_etch", ArenaSim.TILES.quick_etch), "rune_smith") == "attack_cast",
		"The Rune Smith's actual quick rune uses the new casting action.")
	var right: Vector2 = sheet.socket_offset("attack_ranged", 3, "muzzle", 80, 1)
	var left: Vector2 = sheet.socket_offset("attack_ranged", 3, "muzzle", 80, -1)
	_check(right.is_equal_approx(Vector2(28, -46)) and left.is_equal_approx(Vector2(-28, -46)),
		"Authored muzzle anchors mirror around the actual feet pivot.")
	_check(sheet.socket_offset("attack_heavy", 3, "muzzle", 100, 1).is_equal_approx(right),
		"A padded clip uses its explicit body reference height for anchors.")
	_check(sheet.stride_frame("run", 8, 40) == 1 and sheet.stride_frame("run", 8, 40, true) == 5,
		"Native strides follow distance and reverse correctly for an unspecialized backstep.")
	_check(sheet.stride_frame("run", 56, 40) == sheet.stride_frame("run", 8, 40), "A full authored stride wraps exactly.")
	_check(is_equal_approx(sheet.release_seconds("attack_heavy"), 5.0 / 12.0), "Body recovery follows the actual authored recovery frames.")
	_check(Pose.CLASS_STANCES.size() == 12, "Every hero class has an authored body emphasis.")
	var old_sheets: Dictionary = Sheet._sheets
	var old_loaded: bool = Sheet._catalog_loaded
	var old_catalog: Dictionary = Sheet._catalog
	Sheet._catalog_loaded = true
	Sheet._sheets = {"heroes/warden": sheet}
	Sheet._catalog = {"heroes": {}, "enemies": {}}
	var view := ArenaView.new()
	view.size = Vector2(1280, 620)
	root.add_child(view)
	view.set_process(false)
	var sim := ArenaSim.new()
	sim.start([[{"id": "slam", "start": 0, "target": "nearest"}]], "solo")
	var hero: Dictionary = sim.units.front()
	var enemy: Dictionary = sim.units.back()
	view.reset_view(sim.units)
	hero.drive_velocity = Vector2(80, 0)
	view._update_gait(hero, Vector2(5, 0), 0.05)
	view._update_gait(hero, Vector2(5, 0), 0.3)
	_check(is_equal_approx(view._gait_distances[hero.id], 10), "Stride distance ignores real-time frame duration.")
	view._update_gait(hero, Vector2(-5, 0), 0.05)
	_check(is_equal_approx(view._gait_distances[hero.id], 10), "Forced displacement does not generate walking steps.")
	hero.drive_velocity = Vector2(-80, 0)
	hero.facing = 1.0
	_check(view._sheet_frame(sheet, hero, {}, {}, 1.0).state == "backpedal" and hero.facing == 1.0,
		"Kiting chooses real backward locomotion while the hero faces the enemy.")
	hero.drive_velocity = Vector2.ZERO
	var profile := HeroChoreography.profile("slam", ArenaSim.TILES.slam)
	var cast := {"profile": profile, "from": hero.pos, "to": enemy.pos, "arrival": hero.pos,
		"actor": hero.id, "target": enemy.id, "tile": "slam", "age": 0.0, "lifetime": 0.5, "tick": 10}
	view._actor_casts[hero.id] = cast
	var body_before: Dictionary = view._body_pose(hero, 80, 0, 0, cast, {}, sheet)
	view.present(sim.units, [{"kind": "hit", "actor": enemy.id, "target": hero.id, "tile": "enemy_attack",
		"amount": 8, "blocked": 0, "from": enemy.pos, "to": hero.pos}], 10)
	var body_after: Dictionary = view._body_pose(hero, 80, 0, 0, cast, {}, sheet)
	_check(body_after.frame.state == "attack_heavy" and body_after.frame.frame == 3,
		"Taking damage does not hide the real heavy strike contact frame.")
	_check(not body_before.bounce.is_equal_approx(body_after.bounce), "A hit adds visible recoil over an active native action.")
	var next_preparation := {"profile": HeroChoreography.profile("guard", ArenaSim.TILES.guard),
		"charge": 0.35, "start_tick": 10, "beats": 2}
	var prior_cast := cast.duplicate()
	prior_cast.age = 0.20
	hero.facing = -1.0
	var next_body: Dictionary = view._body_pose(hero, 80, 0, 0, prior_cast, next_preparation, sheet)
	_check(next_body.frame.state == "attack_guard" and not next_body.acting and next_body.facing == -1.0,
		"Next preparation, body pose and facing take over together when the old recovery yields.")
	var contact_body: Dictionary = view._body_pose(hero, 80, 0, 0, cast, next_preparation, sheet)
	_check(contact_body.frame.state == "attack_heavy" and contact_body.frame.frame == 3
		and contact_body.acting and contact_body.facing == 1.0,
		"The exact first contact keeps its original action and target-facing before preparation takes over.")
	view._movement_recoveries[hero.id] = {"kind": "retreat", "age": 0.04}
	var kiting_body: Dictionary = view._body_pose(hero, 80, 1.0, 0, prior_cast, next_preparation, sheet)
	_check(kiting_body.frame.state == "attack_mobility" and not kiting_body.acting and kiting_body.facing == -1.0,
		"A real critical retreat selects the new mobility recovery with matching body pose and facing.")
	_check(view._sheet_frame(sheet, hero, next_preparation, cast, 1.0).state == "attack_heavy",
		"A retreat recovery cannot replace the exact ability contact frame.")
	var final_preparation := next_preparation.duplicate()
	final_preparation.charge = 0.85
	_check(view._sheet_frame(sheet, hero, final_preparation, prior_cast, 1.0).state == "attack_guard",
		"Final next-tile preparation takes over from a lingering retreat recovery.")
	view._movement_recoveries.clear()
	hero.facing = 1.0
	var long_effect := cast.duplicate()
	long_effect.age = 0.70
	long_effect.lifetime = 1.50
	view._sprite_hits.clear()
	_check(view._sheet_frame(sheet, hero, {}, long_effect, 0.0).get("state", "idle") == "idle",
		"A long-lived spell effect does not keep the weapon/body locked in recovery.")
	view._sprite_reactions.clear()
	var state_before := JSON.stringify(sim.units)
	view._update_actor_sockets(Rect2(0, 0, 700, 320), 0.5)
	var emitted: Dictionary = view._profile_for_cast(cast, Rect2(0, 0, 700, 320), 0.5)
	_check(emitted.has("emission_sockets") and emitted.emission_sockets.size() == 5,
		"A cast receives current hand, blade, muzzle, casting and feet anchors before drawing.")
	_check(not cast.profile.has("emission_sockets") and not cast.profile.tile_animation.has("emission_sockets"),
		"Rendering never writes transient coordinates into shared choreography or tile recipes.")
	var first: Vector2 = emitted.emission_sockets.muzzle
	view._update_actor_sockets(Rect2(0, 0, 1400, 640), 1.0)
	var resized: Dictionary = view._profile_for_cast(cast, Rect2(0, 0, 1400, 640), 1.0)
	_check(resized.emission_sockets.muzzle.is_equal_approx(first * 2.0), "Weapon anchors follow the same frame and resize transform as the sprite.")
	_check(state_before == JSON.stringify(sim.units), "Animation sampling cannot change combat state or deadlines.")
	# A still-sheet fallback has the same reaction/recovery compression in its mesh and anchors.
	var fallback := Sheet.new({"height": 80, "facing": 1, "animations": {
		"idle": {"texture": "res://assets/sprite_fusion/characters/hero_warden.png", "frames": [
			{"rect": [0, 0, 80, 80], "pivot": [40, 76], "sockets": {"muzzle": [66, 30]}}]}}})
	Sheet._sheets["heroes/warden"] = fallback
	view._actor_casts.clear()
	view._animation_time = 0.30
	view._sprite_reactions[hero.id] = {"age": 0.0, "direction": Vector2.LEFT, "guard": false, "strength": 1.0}
	view._movement_recoveries[hero.id] = {"age": 0.04, "kind": "retreat"}
	var fallback_height := 66.0
	var fallback_body: Dictionary = view._body_pose(hero, fallback_height, 0, 0, {}, {}, fallback)
	_check(not fallback_body.native and not is_equal_approx(fallback_body.body_pose.w, fallback_body.pose.w),
		"The regression fixture exercises a non-native frame with layered compression.")
	var fallback_point := Vector2(100, 200)
	var rendered: Transform2D = view._body_transform(fallback_body, fallback_point, 1.0, true)
	_check(is_equal_approx(rendered.y.length(), 1.0 + float(fallback_body.body_pose.w)),
		"The fallback sprite uses the layered body compression, including recoil and recovery.")
	view._update_actor_sockets(Rect2(0, 0, 700, 320), 0.5)
	var anchor_body: Dictionary = view._body_pose(hero, fallback_height, 0, 0, {}, {}, fallback)
	var body_point: Vector2 = view._actor_screen_origins[hero.id]
	var expected_transform := Transform2D(anchor_body.lean,
		Vector2(1.0 - anchor_body.body_pose.w * 0.67, 1.0 + anchor_body.body_pose.w), 0.0, body_point + anchor_body.bounce)
	var layout: Dictionary = fallback.fallback_layout(fallback_height)
	expected_transform.origin += expected_transform.basis_xform(layout.offset)
	var mesh = view._combat_sprites[hero.id]
	var uv: Vector2 = fallback.socket_pixel("idle", 0, "muzzle") / fallback.frame_size("idle", 0)
	var expected_anchor: Vector2 = expected_transform * mesh.anchor_offset(uv, layout.height, Pose.leg_pose(0, 0, 0), anchor_body.arms)
	_check(view._emission_sockets[hero.id].muzzle.is_equal_approx(expected_anchor),
		"Fallback muzzle sockets and rendered mesh use exactly the same compressed transform.")
	view._register_movement_effect("teleport", {"actor": hero.id, "from": hero.pos, "to": hero.pos + Vector2(20, 0)})
	view.playback_paused = true
	view._process(0.1)
	_check(view._movement_recoveries[hero.id].age == -0.08, "Pause freezes recovery and action clocks.")
	view.reset_view(sim.units)
	_check(view._sprite_reactions.is_empty() and view._gait_distances.is_empty() and view._emission_sockets.is_empty(),
		"Retry clears reactions, locomotion and transient weapon anchors.")
	view.queue_free()
	Sheet._sheets = old_sheets
	Sheet._catalog_loaded = old_loaded
	Sheet._catalog = old_catalog
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("All 12 class action selections, distance strides, exact contacts, mirrored frame sockets, layered recoil, resize and pause passed.")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
