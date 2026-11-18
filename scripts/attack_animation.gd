extends RefCounted

const SpriteFusionVfx = preload("res://scripts/sprite_fusion_vfx.gd")
const INK := Color("#292130")
const LIGHT := Color("#fff5de")
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
	SpriteFusionVfx.draw_anticipation(canvas, at, facing, size, charge, profile, duration_beats)


static func draw_cast_back(canvas: CanvasItem, profile: Dictionary, start: Vector2, target: Vector2,
		arrival: Vector2, progress: float, visual_scale: float, hit: bool, footprint := Vector2.ZERO) -> void:
	SpriteFusionVfx.draw_release(canvas, profile, start, target, arrival, progress,
		visual_scale * float(profile.scale), hit, footprint, "back")


static func draw_status(canvas: CanvasItem, kind: String, at: Vector2, progress: float,
		visual_scale: float, footprint := Vector2.ZERO) -> bool:
	return SpriteFusionVfx.draw_status(canvas, kind, at, progress, visual_scale, footprint)


static func draw_cast(canvas: CanvasItem, profile: Dictionary, start: Vector2, target: Vector2, arrival: Vector2,
		progress: float, visual_scale: float, hit: bool, footprint := Vector2.ZERO) -> void:
	var official_contact := SpriteFusionVfx.draw_release(canvas, profile, start, target, arrival, progress,
		visual_scale * float(profile.scale), hit, footprint, "front")
	var signature_drawn := _draw_signature(canvas, profile, start, target, arrival, progress,
		visual_scale * float(profile.scale), hit, footprint, official_contact)
	if official_contact or signature_drawn:
		return
	var style: String = profile.style
	var variant: int = profile.variant
	var weight: float = profile.weight
	var size := visual_scale * float(profile.scale)
	var n := int(profile.get("trail_count", 2 + variant % 2))
	var lift := Vector2(0.0, -size * 0.88)
	var start_chest := start + lift
	var end_chest := target + lift
	var outline := Color(INK, (1.0 - progress) * 0.82)
	var ink := Color(profile.color, pow(1.0 - progress, 1.15) * 0.92)
	var light := Color(profile.get("accent", LIGHT), pow(1.0 - progress, 2.4) * 0.95)
	var direction := start.direction_to(target) if not start.is_equal_approx(target) else Vector2.RIGHT
	var normal := direction.orthogonal()
	var front := start_chest + direction * size * 0.40
	var close_end := front.move_toward(end_chest, size * (1.05 if hit else 0.62))
	var expansion := sin(progress * PI * 0.5)
	match style:
		"slash":
			var sweep := 1.25 + variant * 0.26
			for i in range(mini(n, 3)):
				var center := front.lerp(close_end, 0.55) + direction * size * i * 0.28
				var a := direction.angle() - sweep + (expansion - 0.4) * (1.1 if variant % 2 == 0 else -1.1)
				_arc(canvas, center, size * (0.63 - i * 0.11), a, a + sweep * 2.0, outline, ink, light, 3.0 * weight)
			if hit:
				_sparks(canvas, end_chest, direction.angle(), size * 0.42, n + 2, expansion, light)
		"thrust":
			for i in range(n):
				var across := normal * (i - (n - 1) * 0.5) * size * 0.15
				var tip := close_end + across
				var tail := front + across - direction * size * (0.35 + expansion * 0.36)
				_line(canvas, tail, tip, outline, ink, light, (1.15 + weight) * (1.0 if i == 0 else 0.75))
			if hit:
				_sparks(canvas, end_chest, direction.angle(), size * 0.66, n + 2, expansion, ink)
		"heavy", "burst", "spin":
			var center := target if hit or footprint.x > 0.0 else start.move_toward(target, size * 1.15)
			if style == "spin":
				center = start
			var radius := Vector2(size * 1.45, size * 0.58)
			if footprint.x > 0.0 and footprint.y > 0.0:
				radius = footprint
			var theta := direction.angle() + (variant * 0.57)
			var ring := radius * lerpf(0.42, 1.0, expansion)
			if style == "heavy":
				_line(canvas, close_end - Vector2(direction.x * size * 0.38, size * 1.05), close_end + Vector2(0.0, size * 0.25),
					outline, ink, light, 2.75 * weight)
			if style == "burst" and start.distance_squared_to(target) > pow(size * 3.0, 2.0):
				var tail := start_chest.lerp(center, progress * 0.65) - Vector2(0.0, size * 0.55 * expansion)
				var apex := tail.lerp(center, 0.4) - Vector2(0.0, size * (1.15 + variant * 0.12))
				var lob := PackedVector2Array()
				for i in range(9):
					var t := float(i) / 8.0
					lob.append(tail.lerp(apex, t).lerp(apex.lerp(center, t), t))
				canvas.draw_polyline(lob, Color(ink, ink.a * 0.72), 2.4, true)
			if style == "spin":
				_arc(canvas, start_chest, size * (0.75 + expansion * 0.52), theta + progress, theta + progress + TAU * 0.76,
					outline, ink, light, 2.4 * weight)
			var sections := 2 + variant if style == "burst" else 1 + variant % 2
			for i in range(sections):
				var angle := theta + TAU * i / sections
				_ellipse(canvas, center, ring, angle, angle + TAU / sections - 0.24, ink, 2.0 * weight)
			if hit or style == "spin":
				_sparks(canvas, center - Vector2(0, size * 0.28), theta, size, 3 + n, expansion, light)
		"shot", "bolt":
			var reach := end_chest if hit else front.lerp(end_chest, 0.82)
			for i in range(n):
				var across := normal * (i - (n - 1) * 0.5) * size * (0.07 + 0.035 * variant)
				var muzzle := front + across * 0.35
				var tracer := reach + across
				var tail := muzzle.lerp(tracer, progress * 0.66)
				if style == "bolt":
					var zig := normal * (size * (0.13 + variant * 0.06)) * (1.0 if i % 2 == 0 else -1.0)
					var path := PackedVector2Array([tail, tail.lerp(tracer, 0.30) + zig, tail.lerp(tracer, 0.54) - zig, tail.lerp(tracer, 0.76) + zig * 0.45, tracer])
					canvas.draw_polyline(path, outline, 4.0 * weight, true)
					canvas.draw_polyline(path, ink, 2.2 * weight, true)
					canvas.draw_polyline(path, light, 1.0, true)
				else:
					_line(canvas, tail, tracer, outline, ink, light, 1.5 * weight)
			_sparks(canvas, front, direction.angle(), size * 0.45, 3, expansion, light)
			if hit:
				_sparks(canvas, reach, direction.angle(), size * 0.65, n + 2, expansion, ink)
		"pull":
			var anchor := front
			var hook := end_chest.lerp(anchor, progress * (0.26 if hit else 0.44))
			canvas.draw_line(anchor, hook, outline, 4.4, true)
			canvas.draw_dashed_line(anchor, hook, ink, 2.2 * weight, 4.0 + variant * 1.6)
			canvas.draw_arc(hook, size * 0.22, direction.angle() - 1.0, direction.angle() + 2.3, 12, light, 2.0, true)
			for i in range(n):
				var joint := hook.lerp(anchor, (i + progress) / (n + 1.0))
				_diamond(canvas, joint, size * 0.11, ink, 1.5)
		"dash", "blink":
			if hit:
				_sparks(canvas, end_chest, arrival.direction_to(target).angle(), size * 0.66, n + 2, expansion, ink)
		"guard", "ward", "heal", "mark", "mine":
			_draw_glyph(canvas, style, start, target if hit else start, lift, size, variant, n, progress, ink, light)


static func _draw_signature(canvas: CanvasItem, profile: Dictionary, start: Vector2, target: Vector2,
		arrival: Vector2, progress: float, size: float, hit: bool, footprint: Vector2, official_contact: bool) -> bool:
	var signature: String = profile.get("signature_effect", "")
	if not SIGNATURE_SECONDS.has(signature):
		return false
	# Sheet clips can linger longer; weapon follow-through keeps its original real-time cadence.
	var phase: float = progress * lifetime(profile) / float(SIGNATURE_SECONDS[signature])
	if phase >= 1.0:
		return official_contact
	match signature:
		"meteor":
			if hit:
				_draw_meteor(canvas, target, footprint, size, phase, not official_contact)
				return true
		"skyline":
			_draw_skyline(canvas, start, target - Vector2(0.0, size * 0.88), size, phase, hit)
			return true
		"marshal_sweep":
			if footprint.x > 0.0:
				_draw_marshal_release(canvas, start, footprint, phase)
				return true
		"hammer":
			var strike_anchor := arrival if profile.style == "dash" else start
			_draw_hammer_swing(canvas, strike_anchor, target, size, phase, hit, not official_contact)
			return profile.style != "dash"
	return false


static func draw_blink_transition(canvas: CanvasItem, start: Vector2, arrival: Vector2, progress: float) -> void:
	if start.distance_squared_to(arrival) < 1.0:
		return
	SpriteFusionVfx.draw_blink(canvas, start, arrival, progress)


static func draw_motion_path(canvas: CanvasItem, points: PackedVector2Array, progress: float,
		tone: Color, size := 26.0) -> void:
	SpriteFusionVfx.draw_motion_path(canvas, points, progress, tone, size)


static func _draw_skyline(canvas: CanvasItem, start: Vector2, target_chest: Vector2, size: float, progress: float,
		hit: bool) -> void:
	var facing := 1.0 if target_chest.x >= start.x else -1.0
	var muzzle := start + Vector2(size * facing * 0.60, -size * 0.95)
	var target := target_chest if hit else muzzle.lerp(target_chest, 0.84)
	var direction := muzzle.direction_to(target)
	var across := direction.orthogonal()
	var opacity := 1.0 - progress
	var dark := Color("#192e42", opacity * 0.82)
	var trace := Color("#76def4", opacity)
	var white := Color("#f2ffff", opacity)
	var tail := muzzle.lerp(target, smoothstep(0.04, 0.96, progress) * 0.82)
	_line(canvas, tail, target, dark, trace, white, 2.8)
	var flash := 1.0 - smoothstep(0.0, 0.40, progress)
	if flash > 0.0:
		var flare := size * (0.23 + 0.39 * flash)
		var flare_tint := Color(white, flash)
		var edge := Color(dark, flash * 0.94)
		canvas.draw_colored_polygon(PackedVector2Array([muzzle - direction * flare * 0.45, muzzle + across * flare * 0.56,
			muzzle + direction * flare * 1.9, muzzle - across * flare * 0.56]), edge)
		canvas.draw_colored_polygon(PackedVector2Array([muzzle - direction * flare * 0.30, muzzle + across * flare * 0.36,
			muzzle + direction * flare * 1.54, muzzle - across * flare * 0.36]), flare_tint)
	if hit:
		_sparks(canvas, target, direction.angle(), size * 0.9, 7, progress, trace)


static func _draw_meteor(canvas: CanvasItem, hit: Vector2, footprint: Vector2, size: float, progress: float,
		draw_contact := true) -> void:
	var opacity := 1.0 - progress
	var travel := smoothstep(0.0, 0.34, progress)
	var upward := Vector2(0.44, -0.90)
	var across := upward.orthogonal()
	var center := hit - Vector2(0.0, size * 0.40)
	var rim := footprint if footprint.x > 0.0 else Vector2(size * 2.1, size)
	var dark := Color("#602922", opacity * 0.90)
	var orange := Color("#f97136", opacity)
	var gold := Color("#ffd489", opacity)
	if draw_contact:
		var ring := rim * lerpf(0.27, 1.0, smoothstep(0.0, 0.84, progress))
		_ellipse(canvas, hit, ring, 0.0, TAU, dark, 5.2)
		_ellipse(canvas, hit, ring, 0.0, TAU, gold, 2.8)
		if progress < 0.72:
			_ellipse(canvas, hit, ring * 0.79, 0.0, TAU, orange, 2.1)
	if progress < 0.40:
		var fade := 1.0 - smoothstep(0.24, 0.40, progress)
		var head := center + upward * size * lerpf(1.68, 0.0, travel)
		var tail := upward * size * lerpf(4.90, 2.15, travel)
		var flame_width := size * lerpf(0.69, 0.42, travel)
		var trail := PackedVector2Array([head - upward * size * 0.42, head + across * flame_width,
			head + tail * 0.70 + across * flame_width * 0.41, head + tail,
			head + tail * 0.81 - across * flame_width * 0.45, head - across * flame_width])
		canvas.draw_colored_polygon(trail, Color(dark, fade))
		var fire := PackedVector2Array([head - upward * size * 0.31, head + across * flame_width * 0.76,
			head + tail * 0.88, head - across * flame_width * 0.75])
		canvas.draw_colored_polygon(fire, Color(orange, fade))
		var meteor := PackedVector2Array()
		for index in range(8):
			var direction := Vector2.RIGHT.rotated(float(index) * TAU / 8.0 + 0.24)
			meteor.append(head + direction * size * (0.45 if index % 3 == 0 else 0.57))
		canvas.draw_colored_polygon(meteor, Color("#593640", fade))
		canvas.draw_circle(head - upward * size * 0.17 + across * size * 0.15, size * 0.25,
			Color(gold, fade * 0.87), true, -1.0, true)
	if draw_contact:
		_sparks(canvas, center, 0.9, size * 1.72, 10, progress, gold)


static func _draw_hammer_swing(canvas: CanvasItem, start: Vector2, target: Vector2, size: float, progress: float,
		hit: bool, draw_contact := true) -> void:
	var facing := 1.0 if target.x >= start.x else -1.0
	var shoulder := start + Vector2(facing * size * 0.32, -size * 0.70)
	var impact := target - Vector2(0.0, size * 0.55)
	var a := -2.0 if facing > 0.0 else -3.24
	var b := 0.15 if facing > 0.0 else -1.07
	var opacity := 1.0 - progress
	var shadow := Color("#653828", opacity * 0.9)
	var gold := Color("#eba750", opacity)
	var white := Color("#fff3c5", opacity)
	_arc(canvas, shoulder, size * lerpf(0.94, 1.40, progress), a + progress * 0.2, b,
		shadow, gold, white, 4.4)
	if hit and draw_contact:
		_diamond(canvas, impact, size * lerpf(0.32, 0.82, progress), white, 2.3)
		_sparks(canvas, impact, 0.4, size * 1.1, 7, progress, gold)


static func _draw_marshal_release(canvas: CanvasItem, center: Vector2, radius: Vector2, progress: float) -> void:
	var opacity := 1.0 - progress
	var ring := radius * lerpf(0.52, 1.0, smoothstep(0.0, 0.58, progress))
	var dark := Color("#542835", opacity * 0.9)
	var gold := Color("#ffd17f", opacity)
	var cream := Color("#fff0c7", opacity)
	_ellipse(canvas, center, radius, 0.0, TAU, Color("#712f30", opacity * 0.66), 3.4)
	_ellipse(canvas, center, ring, 0.0, TAU, dark, 7.0)
	_ellipse(canvas, center, ring, 0.0, TAU, gold, 3.6)
	_ellipse(canvas, center, ring * 0.91, 0.0, TAU, cream, 1.85)


static func draw_secondary_contact(canvas: CanvasItem, profile: Dictionary, start: Vector2, target: Vector2,
		progress: float, size: float) -> void:
	var ink := Color(profile.color, pow(1.0 - progress, 1.6) * 0.55)
	var lift := Vector2(0.0, -size * 0.45)
	if profile.style in ["heal", "ward"]:
		canvas.draw_arc(target + lift, size * lerpf(0.22, 0.55, progress), -2.8, 0.1, 14, ink, 1.8, true)
	else:
		canvas.draw_dashed_line(start + lift, target + lift, ink, 1.65, 4.5)
		_diamond(canvas, target + lift, size * lerpf(0.22, 0.42, progress), ink, 1.5)


static func _draw_glyph(canvas: CanvasItem, style: String, start: Vector2, target: Vector2, lift: Vector2, size: float,
		variant: int, count: int, progress: float, ink: Color, light: Color) -> void:
	var chest := target + lift
	var radius := size * lerpf(0.36, 0.82, progress)
	match style:
		"guard", "ward":
			if style == "guard":
				var side := 1.0 if target.x >= start.x else -1.0
				var edge := PackedVector2Array([Vector2(-0.50, -0.52), Vector2(0.48, -0.69), Vector2(0.62, -0.05),
					Vector2(0.39, 0.54), Vector2(-0.05, 0.85), Vector2(-0.46, 0.53), Vector2(-0.50, -0.52)])
				for i in range(edge.size()):
					edge[i] = chest + edge[i] * Vector2(side, 1.0) * radius
				canvas.draw_polyline(edge, ink, 2.7, true)
				for i in range(variant):
					var center := chest + Vector2(0.76 * side, 0.30 - i * 0.32) * radius
					canvas.draw_line(center - Vector2(1, 1) * radius * 0.14, center + Vector2(1, -1) * radius * 0.14, light, 1.7, true)
			else:
				var sides := 4 + variant
				for i in range(sides):
					var a := TAU * i / sides + progress * 0.7
					canvas.draw_arc(chest, radius, a, a + TAU / sides * 0.72, 6, ink, 2.4, true)
			_diamond(canvas, chest, radius * 0.27, light, 1.7)
		"heal":
			var center := chest + lift * progress * 0.52
			for i in range(count):
				var point := center + Vector2.RIGHT.rotated(i * TAU / count + progress * 0.85) * radius * 0.65
				var arm := maxf(1.1, size * (0.18 - progress * 0.09))
				canvas.draw_line(point - Vector2(arm, 0), point + Vector2(arm, 0), light, 2.0, true)
				canvas.draw_line(point - Vector2(0, arm), point + Vector2(0, arm), ink, 2.2, true)
		"mark":
			var inward := size * lerpf(0.96, 0.40, progress)
			_diamond(canvas, chest, inward, ink, 2.1)
			for i in range(4):
				var aim := Vector2.RIGHT.rotated(PI * i / 2.0 + (variant * 0.24 * progress))
				canvas.draw_line(chest + aim * inward * 0.65, chest + aim * inward * 1.16, light, 1.9, true)
		"mine":
			canvas.draw_dashed_line(start + lift, target, ink, 2.0, 4.0)
			_ellipse(canvas, target, Vector2(radius, radius * 0.46), 0.0, TAU, ink, 2.1)
			_diamond(canvas, target + lift * 0.24, size * 0.23, light, 2.0)


static func _line(canvas: CanvasItem, a: Vector2, b: Vector2, outline: Color, ink: Color, light: Color, weight: float) -> void:
	canvas.draw_line(a, b, outline, weight + 2.6, true)
	canvas.draw_line(a, b, ink, weight + 0.5, true)
	canvas.draw_line(a, b, light, maxf(0.7, weight * 0.38), true)


static func _arc(canvas: CanvasItem, at: Vector2, radius: float, a: float, b: float, outline: Color, ink: Color, light: Color, weight: float) -> void:
	canvas.draw_arc(at, radius, a, b, 18, outline, weight + 2.6, true)
	canvas.draw_arc(at, radius, a, b, 18, ink, weight, true)
	canvas.draw_arc(at, radius, a + (b - a) * 0.22, b - (b - a) * 0.12, 14, light, maxf(1.0, weight * 0.41), true)


static func _ellipse(canvas: CanvasItem, at: Vector2, radius: Vector2, a: float, b: float, color: Color, weight: float) -> void:
	var points := PackedVector2Array()
	for i in range(25):
		points.append(at + Vector2.RIGHT.rotated(lerpf(a, b, float(i) / 24.0)) * radius)
	canvas.draw_polyline(points, color, weight, true)


static func _diamond(canvas: CanvasItem, at: Vector2, radius: float, color: Color, weight: float) -> void:
	canvas.draw_polyline(PackedVector2Array([at + Vector2.UP * radius, at + Vector2.RIGHT * radius * 0.7,
		at + Vector2.DOWN * radius, at + Vector2.LEFT * radius * 0.7, at + Vector2.UP * radius]), color, weight, true)


static func _sparks(canvas: CanvasItem, at: Vector2, theta: float, size: float, count: int, progress: float, color: Color) -> void:
	for i in range(count):
		var ray := Vector2.RIGHT.rotated(theta + i * TAU / count)
		var start := at + ray * size * (0.24 + progress * (0.60 + 0.16 * (i % 3)))
		canvas.draw_line(start, start + ray * size * (0.36 - 0.16 * progress), color, 1.9, true)
