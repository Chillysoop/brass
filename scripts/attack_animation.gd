extends RefCounted

const SpriteFusionVfx = preload("res://scripts/sprite_fusion_vfx.gd")
const TileAnimationEffects = preload("res://scripts/tile_animation_effects.gd")
const SIGNATURE_SECONDS := {"meteor": 0.64, "skyline": 0.49, "marshal_sweep": 0.49, "hammer": 0.46}


static func lifetime(profile: Dictionary) -> float:
	if not SpriteFusionVfx.release_key(profile).is_empty():
		return SpriteFusionVfx.release_seconds(profile)
	if SIGNATURE_SECONDS.has(profile.get("signature_effect", "")):
		return SIGNATURE_SECONDS[profile.signature_effect]
	match profile.style:
		"shot", "slash", "thrust": return 0.22 + 0.025 * float(profile.weight)
		"dash", "bolt", "pull": return 0.29 + 0.025 * float(profile.weight)
		_: return 0.33 + 0.055 * float(profile.weight)


static func release_duration(profile: Dictionary) -> float:
	return 0.26 if profile.get("signature_effect", "") in ["skyline", "hammer", "marshal_sweep"] else 0.18


# x/y move the portrait around its feet. z is lean and w is squash.
static func pose(profile: Dictionary, weight: float, facing: float, released: bool) -> Vector4:
	var force := weight * float(profile.weight)
	var motion := Vector4(0.16, -0.035, 0.17, 0.04)
	match profile.style:
		"slash": motion = Vector4(0.18, -0.03, 0.26, -0.04)
		"thrust": motion = Vector4(0.24, -0.02, 0.12, -0.04)
		"heavy": motion = Vector4(0.08, 0.045, 0.26, -0.13)
		"shot": motion = Vector4(-0.13, -0.025, -0.19, -0.08)
		"pull": motion = Vector4(-0.20, 0.025, -0.22, -0.08)
		"ward", "heal": motion = Vector4(0.0, -0.075, 0.0, 0.065)
		"guard": motion = Vector4(0.055, 0.035, 0.06, -0.11)
		"dash": motion = Vector4(0.23, -0.04, 0.27, -0.08)
		"spin": motion = Vector4(0.09, -0.03, 0.27, 0.045)
		"blink": motion = Vector4(0.015, -0.07, 0.03, 0.16)
		"burst", "mine": motion = Vector4(0.05, 0.055, 0.16, -0.08)
		"mark": motion = Vector4(0.045, -0.03, 0.06, 0.035)
	match profile.get("signature_effect", ""):
		"skyline": motion = Vector4(-0.20, -0.055, -0.24, -0.06)
		"hammer": motion = Vector4(0.14, 0.035, 0.28, -0.06)
	if not released:
		motion *= -0.62
		if profile.style in ["guard", "dash", "mine"]:
			motion.y = 0.035
			motion.w = -0.08
		elif profile.style == "heavy":
			motion.y = -0.065
			motion.w = 0.055
	motion.z *= 0.85 + float(profile.variant) * 0.10
	return motion * Vector4(facing, 1.0, facing, 1.0) * force


static func hero_anticipation(start_tick: int, end_tick: int, tick: int, beats: float) -> Dictionary:
	if tick < start_tick or tick >= end_tick or end_tick <= start_tick:
		return {}
	return {"charge": inverse_lerp(float(start_tick), float(end_tick), float(tick)), "beats": beats}


static func windup(canvas: CanvasItem, at: Vector2, facing: float, size: float, charge: float,
		profile: Dictionary, duration_beats := 2.0) -> void:
	draw_hero_anticipation(canvas, at, facing, size, charge, profile, duration_beats)


static func draw_hero_anticipation(canvas: CanvasItem, at: Vector2, facing: float, size: float,
		charge: float, profile: Dictionary, duration_beats: float) -> void:
	var recipe: Dictionary = profile.get("tile_animation", {})
	if not recipe.is_empty():
		TileAnimationEffects.draw_anticipation(canvas, recipe, at, facing, size, charge, profile.color, duration_beats)
	else:
		SpriteFusionVfx.draw_anticipation(canvas, at, facing, size, charge, profile, duration_beats)


static func draw_cast_back(canvas: CanvasItem, profile: Dictionary, start: Vector2, target: Vector2,
		arrival: Vector2, progress: float, visual_scale: float, hit: bool, footprint := Vector2.ZERO) -> void:
	var recipe: Dictionary = profile.get("tile_animation", {})
	if not recipe.is_empty():
		TileAnimationEffects.draw_release(canvas, recipe, start, target, arrival, progress,
			visual_scale * float(profile.scale), hit, footprint, "back")
	else:
		SpriteFusionVfx.draw_release(canvas, profile, start, target, arrival, progress,
			visual_scale * float(profile.scale), hit, footprint, "back")


static func draw_status(canvas: CanvasItem, kind: String, at: Vector2, progress: float,
		visual_scale: float, footprint := Vector2.ZERO) -> bool:
	if SpriteFusionVfx.draw_status(canvas, kind, at, progress, visual_scale, footprint):
		return true
	return _draw_particle_status(canvas, kind, at, progress, visual_scale, footprint)


static func draw_cast(canvas: CanvasItem, profile: Dictionary, start: Vector2, target: Vector2, arrival: Vector2,
		progress: float, visual_scale: float, hit: bool, footprint := Vector2.ZERO) -> void:
	var size := visual_scale * float(profile.scale)
	var recipe: Dictionary = profile.get("tile_animation", {})
	if not recipe.is_empty():
		TileAnimationEffects.draw_release(canvas, recipe, start, target, arrival, progress, size, hit, footprint, "front")
	else:
		SpriteFusionVfx.draw_release(canvas, profile, start, target, arrival, progress, size, hit, footprint, "front")
	_draw_signature(canvas, profile, start, target, arrival, progress, size, hit, footprint)


static func _draw_signature(canvas: CanvasItem, profile: Dictionary, start: Vector2, target: Vector2,
		arrival: Vector2, progress: float, size: float, hit: bool, footprint: Vector2) -> void:
	var signature: String = profile.get("signature_effect", "")
	var duration: float = SIGNATURE_SECONDS.get(signature, 0.0)
	var age := progress * lifetime(profile)
	if duration <= 0.0 or age >= duration:
		return
	var p := age / duration
	var direction := start.direction_to(target) if start.distance_squared_to(target) > 0.01 else Vector2.RIGHT
	var source := start - Vector2(0, size * 0.85)
	var contact := target - Vector2(0, size * 0.7) if hit else source + direction * size * 0.8
	var particles = TileAnimationEffects.Particles
	var color: Color = profile.get("color", Color.WHITE)
	match signature:
		"meteor":
			# Molten ejecta extend upward from an already-landed blast, never arrive late.
			for index in range(11):
				var t := float(index) / 10.0
				var pos := contact + Vector2(-0.35, -1.0) * size * (t * 2.1 + p * 0.5)
				pos.x += sin(index * 2.4 + p * 2.0) * size * 0.12
				particles.stamp(canvas, "ember" if index % 3 != 2 else "smoke", pos, p,
					size * (0.9 - t * 0.46), -1.9, particles.tint(color, (1.0 - p) * (1.0 - t * 0.65), "ember"))
		"skyline":
			for index in range(8):
				var t := float(index) / 7.0
				var pos := source.lerp(contact, t) + direction.orthogonal() * sin(t * PI) * size * p * 0.18
				particles.stamp(canvas, "arc", pos, p, size * (0.78 - t * 0.25), direction.angle(),
					particles.tint(Color("#a1efff"), (1.0 - p) * (0.85 - t * 0.35), "arc"), Vector2(1.6, 0.65))
		"hammer":
			var shoulder := arrival - Vector2(0, size * 0.75) if profile.style == "dash" else source
			var center := shoulder.lerp(contact, 0.6)
			for index in range(9):
				var angle := direction.angle() - 1.8 + float(index) * 0.27 + p * 0.8
				var pos := center + Vector2.RIGHT.rotated(angle) * Vector2(1, 0.65) * size * (0.4 + p * 0.45)
				particles.stamp(canvas, "slash" if index % 3 == 0 else "brass", pos, p, size * 0.62,
					angle + PI * 0.5, particles.tint(color, 1.0 - p, "brass"))
		"marshal_sweep":
			var extent := footprint if footprint.x > 0.0 else Vector2(size * 2.0, size)
			for index in range(13):
				var angle := float(index) * TAU / 13.0
				var pos := start + Vector2.RIGHT.rotated(angle) * extent * (0.35 + p * 0.75)
				particles.stamp(canvas, "dust", pos, p, size * (0.8 + p * 0.4), angle,
					particles.tint(color, (1.0 - p) * 0.8, "dust"))


static func draw_blink_transition(canvas: CanvasItem, start: Vector2, arrival: Vector2, progress: float) -> void:
	if start.distance_squared_to(arrival) < 1.0:
		return
	SpriteFusionVfx.draw_blink(canvas, start, arrival, progress)


static func draw_motion_path(canvas: CanvasItem, points: PackedVector2Array, progress: float,
		tone: Color, size := 26.0) -> void:
	SpriteFusionVfx.draw_motion_path(canvas, points, progress, tone, size)


static func draw_secondary_contact(canvas: CanvasItem, profile: Dictionary, start: Vector2, target: Vector2,
		progress: float, size: float) -> void:
	var lift := Vector2(0.0, -size * 0.45)
	TileAnimationEffects.draw_secondary_contact(canvas, profile, target + lift, progress, size)


static func draw_support_link(canvas: CanvasItem, start: Vector2, target: Vector2,
		color: Color, icon: String, phase: float) -> void:
	TileAnimationEffects.draw_support_link(canvas, start, target, color, icon, phase)


static func _draw_particle_status(canvas: CanvasItem, kind: String, at: Vector2,
		progress: float, size: float, footprint: Vector2) -> bool:
	var material := ""
	var gesture := "pulse"
	var clip := ""
	match kind:
		"chorus_guard", "bastion_ready", "guard_relay", "relay_interrupted", "relay_link_broken", "marshal_plate_broken":
			material = "shield"
			gesture = "dome" if kind in ["chorus_guard", "bastion_ready", "guard_relay"] else "scatter"
		"chorus_mark", "chorus_mark_spent", "ranged_followup_ready", "lance_return_ready", "rune_charge_ready":
			material = "aether"
			gesture = "collapse" if kind == "chorus_mark" else "orbit"
		"duel_stack", "duel_kill_ready", "duel_kill_spent", "counter", "arc", "barrage_rack", "lance_travel_spent":
			material = "spark"
			gesture = "cleave"
		"ranged_followup_spent", "lance_return_spent", "longshot_prism", "charge_impact":
			material = "arc"
			gesture = "lance"
		"siege_fuse", "cluster_pull", "pull":
			material = "phase"
			gesture = "collapse"
		"afterimage", "veil_echo", "switchback_lens", "haste", "fuse_disarmed", "admiral_reversed":
			material = "phase"
			gesture = "spiral"
		"class_relic", "class_relic_ready", "stepped_gear", "twin_bell", "bell_ring", "reinforcement", "flanking_standard":
			material = "aether"
			gesture = "fountain"
		"push", "sweep_push", "class_relic_wave", "hazard_burst", "brass_cannon_impact", "wreckmaster_slam":
			material = "dust"
			gesture = "scatter"
			clip = "explosion" if kind in ["hazard_burst", "brass_cannon_impact"] else "impact"
		"repair_interrupted", "repair_separated", "relay_marshal_separated", "tidekeeper_unanchored", "spring_jam", "marshal_sweep_weathered":
			material = "brass"
			gesture = "scatter"
		"tar_slow":
			material = "smoke"
			gesture = "pulse"
		"defeat_unit":
			material = "dust"
			gesture = "fountain"
		_:
			return false
	var tone := Color.WHITE
	var unit := clampf(size, 13.0, 42.0)
	var profile := {"style": "heavy", "sprite_fusion": clip, "color": tone}
	if not clip.is_empty():
		for layer: String in ["back", "front"]:
			SpriteFusionVfx.draw_release(canvas, profile, at, at, at, progress, unit * 0.7, true, footprint, layer)
	var spec := {"material": material, "secondary": "aether" if material == "shield" else "spark",
		"gesture": gesture, "streams": 2, "pulses": 1, "scatter": "radial", "finish": "rise"}
	var recipe := {"particles": spec, "family": "heal" if material == "heal" else "mark", "rank": 0,
		"branch": "base", "color": tone, "sprite_fusion": "", "motif": {}, "particle_layers": []}
	for layer: String in ["back", "front"]:
		TileAnimationEffects.draw_release(canvas, recipe, at, at, at, progress, unit * 0.72, true, Vector2.ZERO, layer)
	return true
