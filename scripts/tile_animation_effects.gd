extends RefCounted

# Local kinetic drawing complements the official release sheets. It never owns combat timing or positions.
const INK := Color("#252536")
const PALETTES := {
	"slash": Color("#f4dfb1"), "thrust": Color("#e6deb2"), "heavy": Color("#f3a765"),
	"shot": Color("#f6cb7b"), "bolt": Color("#8adcf4"), "pull": Color("#b6a0ed"),
	"guard": Color("#80dae8"), "ward": Color("#a6e3d1"), "heal": Color("#a5e5a5"),
	"blink": Color("#c1a5ee"), "dash": Color("#a6e0ed"), "burst": Color("#ffb36e"),
	"mine": Color("#eeb777"), "mark": Color("#dfaff1"), "spin": Color("#f3c692"),
}
const BACK_FEATURES := ["splash", "guard", "pull", "blink", "charge", "rune", "ally", "block", "intercept", "harmony", "travel", "tether"]
const FEATURE_PRIORITY := ["intercept", "harmony", "overflow", "return", "echo", "repeat", "chain", "blink", "travel", "rune",
	"pierce", "burn", "mark", "finish", "crit", "shatter", "collision", "ricochet", "splash", "pull", "push", "ally", "heal", "guard", "block", "charge", "windup", "tether"]


static func draw_release(canvas: CanvasItem, recipe: Dictionary, start: Vector2, target: Vector2,
		arrival: Vector2, progress: float, size: float, hit: bool, footprint: Vector2, layer: String) -> void:
	if recipe.is_empty() or progress >= 1.0:
		return
	var motif: Dictionary = recipe.get("motif", {})
	if motif.is_empty():
		return
	var p := clampf(progress, 0.0, 1.0)
	var unit := clampf(size, 13.0, 55.0)
	var color: Color = recipe.get("color", PALETTES.get(recipe.get("family", "slash"), Color("#eed7a6")))
	var accent: Color = recipe.get("accent", Color("#fff6dc"))
	var fade := pow(1.0 - p, 1.65)
	color.a = fade * 0.95
	accent.a = fade
	var direction := start.direction_to(target) if start.distance_squared_to(target) > 0.01 else Vector2.RIGHT
	var source := start + Vector2(0.0, -unit * 1.1)
	var contact := target + Vector2(0.0, -unit * 0.86) if hit else source + direction * unit * 1.2
	var at := contact
	var family: String = recipe.get("family", "")
	if family in ["guard", "ward", "heal"]:
		at = target - Vector2(0.0, unit * 0.5) if hit else source
	var turn := -1.0 if float(motif.get("turn", 1)) < 0.0 else 1.0
	var count := clampi(int(motif.get("count", 1)), 1, 5)
	var spread := clampf(float(motif.get("spread", 0.5)), 0.0, 1.0)
	var reach := clampf(float(motif.get("reach", 1.0)), 0.5, 1.8)
	var path: String = motif.get("path", "drive")
	var shape: String = motif.get("shape", "diamond")
	var angle := direction.angle()
	if layer == "back":
		if path in ["orbit", "converge", "spiral", "fold"]:
			_draw_path(canvas, path, source, at, arrival, p, unit * reach, count, spread, turn, Color(color, color.a * 0.5))
	else:
		_draw_rank(canvas, recipe, at, angle, p, unit, color, accent)
	var features := _features(recipe)
	for feature: Dictionary in features:
		if not hit and family not in ["guard", "ward", "heal"]:
			continue
		var kind: String = feature.kind
		if (kind in BACK_FEATURES) != (layer == "back"):
			continue
		_draw_feature(canvas, feature, source, at, start, arrival, direction, p, unit, hit, footprint, color, accent)
	if layer == "front":
		# Identity outlasts the initial sheet flash and stays above general upgrade/effect flourishes.
		var identity := pow(1.0 - p, 0.68)
		var body := Color(color, identity * 0.96)
		var highlight := Color(accent, identity)
		_draw_path(canvas, path, source, at, arrival, p, unit * reach, count, spread, turn, body, true)
		_draw_primary(canvas, shape, path, at, direction, p, unit, count, spread, turn, body, highlight,
			str(motif.get("family", "")))


static func draw_anticipation(canvas: CanvasItem, recipe: Dictionary, at: Vector2, facing: float,
		size: float, progress: float, profile_color: Color, beats: float) -> void:
	if recipe.is_empty():
		return
	var motif: Dictionary = recipe.get("motif", {})
	if motif.is_empty():
		return
	var p := clampf(progress, 0.0, 0.999)
	var tempo: Array = motif.get("tempo", [0.24, 0.68, 0.9])
	var gather_end := clampf(float(tempo[0]), 0.08, 0.5)
	var focus_end := clampf(float(tempo[1]), gather_end + 0.1, 0.9)
	var ready_start := clampf(float(tempo[2]), focus_end, 0.98)
	var gather := smoothstep(0.0, gather_end, p)
	var focus := smoothstep(gather_end, focus_end, p)
	var ready := smoothstep(ready_start, 1.0, p)
	var unit := clampf(size * 0.24, 10.0, 27.0)
	var count := clampi(int(motif.get("count", 1)), 1, 5)
	var turn := -1.0 if float(motif.get("turn", 1)) < 0.0 else 1.0
	var path: String = motif.get("path", "drive")
	var shape: String = motif.get("shape", "diamond")
	var hand := at + Vector2(facing * size * 0.28, -size * 0.55)
	var color := profile_color.lerp(Color.WHITE, 0.22)
	color.a = 0.18 + gather * 0.22 + focus * 0.22 + ready * 0.22
	var accent := Color("#fff5dc", color.a * 0.75)
	var orientation := 0.0 if facing > 0.0 else PI
	var shape_size := unit * (0.36 + gather * 0.16 + focus * 0.35)
	_draw_shape(canvas, shape, hand, shape_size, orientation + turn * (1.0 - focus) * 0.45,
		color, accent, 0.8 + ready * 0.5, false)
	var long_cast := clampf((beats - 1.0) / 4.0, 0.0, 1.0)
	var opening := 1.3 - focus * 0.72
	for index in range(count):
		var angle := orientation + turn * (float(index) / count * TAU + p * 0.72)
		var offset := Vector2.RIGHT.rotated(angle) * unit * opening * (0.75 + long_cast * 0.6)
		var knot := hand + offset * Vector2(1.0, 0.7)
		var end := hand + offset * 0.45
		if path in ["sweep", "orbit", "spiral"]:
			_arc(canvas, hand, Vector2.ONE * unit * opening, angle, angle + turn * (0.32 + focus * 0.5), color, 1.3)
		elif path in ["split", "fan", "converge", "stitch"]:
			_stroke(canvas, PackedVector2Array([knot, knot.lerp(end, 0.5) + offset.orthogonal() * 0.24, end]), color, 1.4)
		elif path in ["fold", "relay"]:
			_draw_shape(canvas, "diamond", knot, unit * 0.14, orientation + p * turn, color, accent, 0.8, false)
		else:
			_stroke(canvas, PackedVector2Array([knot, end]), color, 1.3)
	if long_cast > 0.15 and focus > 0.0:
		var feet_color := Color(color, color.a * long_cast * focus * 0.7)
		_draw_rank(canvas, recipe, at, orientation, 0.05 + (1.0 - focus) * 0.35, unit * 1.15, feet_color, Color(accent, feet_color.a))


static func _draw_primary(canvas: CanvasItem, shape: String, path: String, at: Vector2, direction: Vector2,
		p: float, size: float, count: int, spread: float, turn: float, color: Color, accent: Color,
		weapon_family := "") -> void:
	var side := direction.orthogonal()
	var angle := direction.angle()
	var follow := smoothstep(0.0, 0.65, p)
	var center := at
	match path:
		"sweep": angle += turn * follow * 0.9
		"drive": center += direction * size * follow * 0.48
		"recoil":
			center -= direction * size * follow * 1.12
			center += side * size * sin(follow * PI) * (0.24 + spread * 0.35)
			angle -= turn * follow * 0.9
		"drop": center += Vector2(0.0, size * follow * 0.16)
		"orbit", "spiral": angle += turn * follow * 1.9
		"fold": angle += turn * follow * PI * 0.5
	var width := 2.0 + minf(size / 32.0, 1.35)
	if shape == "facet" and weapon_family in ["lance", "guard"]:
		_draw_weapon_facet(canvas, weapon_family, center, size, angle, color, accent, width)
	else:
		_draw_shape(canvas, shape, center, size * 1.02, angle, color, accent, width, true, 0.66)
	for index in range(1, count):
		var flip := -1.0 if index % 2 == 0 else 1.0
		var offset := side * flip * size * (0.18 + spread * 0.25) * ceili(float(index) / 2.0)
		var echo := center + offset - direction * size * (0.08 + index * 0.07) * (0.5 + follow)
		var tint := Color(color, color.a * (0.78 - index * 0.07))
		_draw_shape(canvas, shape, echo, size * (0.48 - index * 0.035), angle + flip * spread * 0.25,
			tint, Color(accent, tint.a * 0.85), width * 0.65, false)


static func _draw_weapon_facet(canvas: CanvasItem, family: String, at: Vector2, size: float,
		angle: float, color: Color, accent: Color, width: float) -> void:
	var axis := Vector2.RIGHT.rotated(angle)
	var side := axis.orthogonal()
	if family == "lance":
		var head := PackedVector2Array([at + axis * size * 1.25, at - axis * size * 0.42 + side * size * 0.28,
			at - axis * size * 0.72, at - axis * size * 0.42 - side * size * 0.28])
		_poly(canvas, head, color, true, width, 0.68)
		_stroke(canvas, PackedVector2Array([at - axis * size * 1.3, at + axis * size * 0.7]), accent, width * 0.65)
	else:
		var plate := PackedVector2Array([at - axis * size * 0.43 - side * size * 0.9,
			at + axis * size * 0.4 - side * size * 0.82, at + axis * size * 0.65,
			at + axis * size * 0.4 + side * size * 0.82, at - axis * size * 0.43 + side * size * 0.9])
		_poly(canvas, plate, color, true, width, 0.68)
		_stroke(canvas, PackedVector2Array([at - side * size * 0.62, at + side * size * 0.62]), accent, width * 0.7)


static func _draw_path(canvas: CanvasItem, path: String, start: Vector2, end: Vector2, arrival: Vector2,
		p: float, size: float, count: int, spread: float, turn: float, color: Color, identity := false) -> void:
	var direction := start.direction_to(end) if start.distance_squared_to(end) > 0.01 else Vector2.RIGHT
	var side := direction.orthogonal()
	var tint := Color(color, color.a * (0.78 if identity else 0.40))
	var width := clampf(size / 20.0, 1.2, 2.6) + (0.45 if identity else 0.0)
	var expansion := 0.65 + smoothstep(0.0, 0.7, p) * 0.5
	var distance := minf(start.distance_to(end), size * 3.8)
	var local_start := end - direction * distance
	match path:
		"sweep":
			for index in range(count):
				var radius := Vector2(size * (0.65 + index * 0.15), size * (0.32 + spread * 0.25)) * expansion
				_arc(canvas, end - direction * size * 0.45, radius, direction.angle() - turn * 1.7,
					direction.angle() + turn * (0.5 + p * 0.8), tint, width)
		"split", "fan":
			for index in range(count + 1):
				var across := (float(index) - float(count) * 0.5) * size * (0.18 + spread * 0.28)
				var tip := end + side * across
				var bend := local_start.lerp(end, 0.6) + side * across * (0.45 if path == "split" else 0.9)
				_stroke(canvas, PackedVector2Array([local_start, bend, tip]), tint, width)
		"orbit":
			for index in range(count):
				var angle := direction.angle() + TAU * index / count + p * turn
				_arc(canvas, end, Vector2(size, size * (0.38 + spread * 0.35)) * expansion,
					angle, angle + turn * 1.3, tint, width)
		"converge":
			for index in range(count + 1):
				var angle := direction.angle() + TAU * index / (count + 1)
				var outer := end + Vector2.RIGHT.rotated(angle) * size * (1.1 - p * 0.45)
				_stroke(canvas, PackedVector2Array([outer, outer.lerp(end, 0.45) + side * turn * size * 0.18, end]), tint, width)
		"drop":
			for index in range(count):
				var offset := side * (float(index) - (count - 1) * 0.5) * size * 0.18
				var tail := end + offset + Vector2(turn * size * (0.28 + spread), -size * (1.8 + spread)) * (1.0 - p)
				_stroke(canvas, PackedVector2Array([tail, end + offset]), tint, width * 1.35)
		"stitch":
			var points := PackedVector2Array([local_start])
			for index in range(1, count + 3):
				var t := float(index) / (count + 3)
				points.append(local_start.lerp(end, t) + side * (1.0 if index % 2 == 0 else -1.0) * size * (0.12 + spread * 0.2))
			points.append(end)
			_stroke(canvas, points, tint, width)
		"relay":
			var points := _curve(local_start, local_start.lerp(end, 0.5) - side * turn * size * (0.4 + spread), end, 9)
			_stroke(canvas, points, tint, width)
			for index in range(count):
				var node: Vector2 = points[mini(points.size() - 1, roundi(float(index + 1) * (points.size() - 1) / (count + 1)))]
				_poly(canvas, _regular(node, size * 0.12, 4, p * turn), tint, false, width)
		"spiral":
			var points := PackedVector2Array()
			for index in range(17):
				var t := float(index) / 16.0
				var angle := direction.angle() + turn * (t * TAU * (1.0 + count * 0.12) + p)
				points.append(end + Vector2.RIGHT.rotated(angle) * Vector2(1.0, 0.6) * size * t * expansion)
			_stroke(canvas, points, tint, width)
		"fold":
			for origin: Vector2 in [start, arrival - Vector2(0.0, size * 0.4)]:
				var points := _regular(origin, size * (0.5 + p * 0.2), 4, direction.angle() + turn * p)
				_poly(canvas, points, tint, false, width)
		"recoil":
			var withdrawal := smoothstep(0.0, 0.65, p)
			for index in range(count):
				var offset := side * (index - (count - 1) * 0.5) * size * 0.11
				var returning := end + offset - direction * size * (0.25 + withdrawal * 1.5)
				var bend := end + offset - direction * size * 0.55 + side * turn * size * (0.4 + spread * 0.7)
				_stroke(canvas, _curve(end + offset, bend, returning, 11), tint, width)
				_draw_shape(canvas, "chevron", returning, size * 0.2, direction.angle() + PI, tint, tint, width * 0.7, false)
		_:
			for index in range(count):
				var offset := side * (index - (count - 1) * 0.5) * size * (0.08 + spread * 0.09)
				_stroke(canvas, PackedVector2Array([local_start + offset, end + offset]), tint, width)


static func _draw_shape(canvas: CanvasItem, kind: String, at: Vector2, radius: float, angle: float,
		color: Color, accent: Color, width: float, filled: bool, body_alpha := 0.32) -> void:
	var dir := Vector2.RIGHT.rotated(angle)
	var side := dir.orthogonal()
	match kind:
		"crescent":
			_arc(canvas, at - dir * radius * 0.5, Vector2(radius, radius * 0.8), angle - 1.1, angle + 1.1, color, width + 0.6)
			_arc(canvas, at - dir * radius * 0.48, Vector2(radius * 0.76, radius * 0.62), angle - 1.0, angle + 0.9, accent, width * 0.6)
		"chevron":
			_stroke(canvas, PackedVector2Array([at - dir * radius * 0.55 + side * radius * 0.55, at + dir * radius * 0.55,
				at - dir * radius * 0.55 - side * radius * 0.55]), color, width)
		"needle":
			var points := PackedVector2Array([at + dir * radius, at - dir * radius * 0.6 + side * radius * 0.16,
				at - dir * radius * 0.28, at - dir * radius * 0.6 - side * radius * 0.16])
			_poly(canvas, points, color, filled, width, body_alpha)
			_stroke(canvas, PackedVector2Array([at - dir * radius * 1.3, at + dir * radius * 0.65]), accent, width * 0.65)
		"facet":
			_poly(canvas, _regular(at, radius * 0.7, 6, angle), color, filled, width, body_alpha)
			_stroke(canvas, PackedVector2Array([at - dir * radius * 0.7, at + dir * radius * 0.7, at + side * radius * 0.6, at]), accent, width * 0.65)
		"ring":
			_arc(canvas, at, Vector2(radius, radius * 0.55), angle, angle + TAU * 0.86, color, width)
			_arc(canvas, at, Vector2(radius * 0.6, radius * 0.34), angle + PI, angle + TAU * 1.38, accent, width * 0.65)
		"shield":
			var points := PackedVector2Array()
			for point: Vector2 in [Vector2(-0.6, -0.6), Vector2(0.6, -0.6), Vector2(0.56, 0.12), Vector2(0, 0.9), Vector2(-0.56, 0.12)]:
				points.append(at + point.rotated(angle) * radius)
			_poly(canvas, points, color, filled, width, body_alpha)
			_stroke(canvas, PackedVector2Array([at - Vector2(0, radius * 0.4).rotated(angle), at + Vector2(0, radius * 0.5).rotated(angle)]), accent, width * 0.7)
		"diamond":
			_poly(canvas, _regular(at, radius * 0.76, 4, angle), color, filled, width, body_alpha)
			_poly(canvas, _regular(at, radius * 0.36, 4, angle), accent, false, width * 0.6)
		"petal":
			for index in range(4):
				var axis := Vector2.RIGHT.rotated(angle + TAU * index / 4.0)
				_poly(canvas, PackedVector2Array([at, at + axis * radius * 0.65 + axis.orthogonal() * radius * 0.25,
					at + axis * radius, at + axis * radius * 0.65 - axis.orthogonal() * radius * 0.25]), color, filled, width * 0.65, body_alpha)
		"flame":
			_poly(canvas, PackedVector2Array([at + side * radius * 0.48, at - dir * radius * 0.5,
				at + side * radius * 0.12 - dir * radius * 0.25, at - side * radius * 1.25,
				at + dir * radius * 0.36, at + dir * radius * 0.25 + side * radius * 0.46]), color, filled, width, body_alpha)
			_stroke(canvas, PackedVector2Array([at + side * radius * 0.38, at - side * radius * 0.45]), accent, width * 0.75)
		"rune":
			_poly(canvas, _regular(at, radius * 0.7, 4, angle + PI * 0.25), color, false, width)
			_stroke(canvas, PackedVector2Array([at - dir * radius, at + dir * radius, at + dir * radius * 0.4 + side * radius * 0.45]), accent, width * 0.7)
			_stroke(canvas, PackedVector2Array([at - side * radius * 0.85, at + side * radius * 0.85]), color, width * 0.75)
		"bell":
			var points := PackedVector2Array([at - dir * radius * 0.5 - side * radius * 0.6, at - dir * radius * 0.3 + side * radius * 0.3,
				at + side * radius * 0.65, at + dir * radius * 0.3 + side * radius * 0.3, at + dir * radius * 0.5 - side * radius * 0.6])
			_poly(canvas, points, color, filled, width, body_alpha)
			_arc(canvas, at - side * radius * 0.6, Vector2(radius * 0.6, radius * 0.18), angle, angle + TAU, accent, width * 0.7)
		"hook":
			_stroke(canvas, PackedVector2Array([at - dir * radius * 0.9, at + dir * radius * 0.35]), color, width)
			_arc(canvas, at + dir * radius * 0.3 + side * radius * 0.26, Vector2.ONE * radius * 0.42,
				angle - PI * 0.65, angle + PI * 0.58, accent, width)
		"hammer":
			_stroke(canvas, PackedVector2Array([at - dir * radius * 1.3, at + dir * radius * 0.3]), color, width * 1.2)
			var center := at + dir * radius * 0.3
			_poly(canvas, PackedVector2Array([center - dir * radius * 0.24 - side * radius * 0.66, center + dir * radius * 0.32 - side * radius * 0.66,
				center + dir * radius * 0.32 + side * radius * 0.66, center - dir * radius * 0.24 + side * radius * 0.66]), color, filled, width, body_alpha)
			_stroke(canvas, PackedVector2Array([center - side * radius * 0.44, center + side * radius * 0.44]), accent, width * 0.7)
		"cross":
			_stroke(canvas, PackedVector2Array([at - dir * radius * 0.7, at + dir * radius * 0.7]), color, width * 1.7)
			_stroke(canvas, PackedVector2Array([at - side * radius * 0.7, at + side * radius * 0.7]), accent, width * 1.5)
		"star":
			var points := PackedVector2Array()
			for index in range(8):
				points.append(at + Vector2.RIGHT.rotated(angle + TAU * index / 8.0) * radius * (1.0 if index % 2 == 0 else 0.28))
			_poly(canvas, points, color, filled, width, body_alpha)
		"flask":
			var points := PackedVector2Array()
			for point: Vector2 in [Vector2(-0.22, -0.9), Vector2(0.22, -0.9), Vector2(0.22, -0.25), Vector2(0.63, 0.55), Vector2(0.42, 0.78), Vector2(-0.42, 0.78), Vector2(-0.63, 0.55), Vector2(-0.22, -0.25)]:
				points.append(at + point.rotated(angle) * radius)
			_poly(canvas, points, color, filled, width, body_alpha)
			_stroke(canvas, PackedVector2Array([at + Vector2(-0.4, 0.32).rotated(angle) * radius,
				at + Vector2(0.4, 0.32).rotated(angle) * radius]), accent, width * 0.7)


static func _draw_rank(canvas: CanvasItem, recipe: Dictionary, at: Vector2, angle: float, p: float,
		size: float, color: Color, accent: Color) -> void:
	var rank := clampi(int(recipe.get("rank", 0)), 0, 4)
	if rank == 0:
		return
	var technique: bool = recipe.get("branch", "base") == "technique"
	var direction := Vector2.RIGHT.rotated(angle)
	var side := direction.orthogonal()
	var motif: Dictionary = recipe.get("motif", {})
	var count := clampi(int(motif.get("count", 1)), 1, 5)
	var spread := clampf(float(motif.get("spread", 0.5)), 0.0, 1.0)
	var radius := size * (0.90 + spread * 0.24 + p * 0.12)
	var tint := Color(color, color.a * 0.48)
	var light := Color(accent, accent.a * 0.50)
	var width := clampf(size / 13.0, 1.7, 3.2)
	var phase := smoothstep(0.0, 0.7, p)
	if technique:
		match rank:
			1:
				# Two offset, opposing orbital cuts replace the first tier's angular fork.
				for flip: float in [-1.0, 1.0]:
					var pivot := at + side * radius * 0.22 * flip
					var begin := angle + flip * phase * 1.2
					_arc(canvas, pivot, Vector2(radius * 0.86, radius * (0.48 + spread * 0.1)),
						begin, begin + flip * PI * 1.35, tint, width)
					_draw_shape(canvas, "diamond", pivot + direction.rotated(begin - angle) * radius * 0.86,
						size * 0.12, begin, tint, light, width * 0.6, true)
			2:
				# A triangular relay closes around the original motif; nodes are sigils, never victims.
				var nodes := _regular(at, radius, 3, angle + phase * 0.48)
				for index in range(3):
					var a: Vector2 = nodes[index]
					var b: Vector2 = nodes[(index + 1) % 3]
					_stroke(canvas, _curve(a, a.lerp(b, 0.5).lerp(at, -0.3), b, 9), tint, width)
					_draw_shape(canvas, "rune" if count >= 3 else "diamond", a, size * 0.16,
						angle + index * TAU / 3.0, tint, light, width * 0.6, false)
			3:
				# Three tilted loops counterrotate instead of sharing a growing circular outline.
				for index in range(3):
					var flip := -1.0 if index % 2 == 0 else 1.0
					var axis := angle + PI * index / 3.0 + flip * phase * 0.9
					var points := PackedVector2Array()
					for step in range(17):
						var t := float(step) / 16.0 * TAU
						points.append(at + (Vector2(cos(t), sin(t) * 0.35) * radius).rotated(axis))
					_stroke(canvas, points, tint, width)
			4:
				# The legendary path has two intertwined, open spiral arms and an inward cadence.
				for flip: float in [-1.0, 1.0]:
					var points := PackedVector2Array()
					for step in range(25):
						var t := float(step) / 24.0
						var theta := angle + flip * (t * TAU * (1.15 + count * 0.035) + phase * 0.9)
						points.append(at + Vector2.RIGHT.rotated(theta) * radius * (0.15 + t * 0.92))
					_stroke(canvas, points, tint, width)
	else:
		match rank:
			1:
				# A broad two-pronged fork is readable even over a bright contact sheet.
				for flip: float in [-1.0, 1.0]:
					var tail := at - direction * radius + side * flip * radius * (0.55 + phase * 0.15)
					var tip := at + direction * radius * 0.28
					_stroke(canvas, PackedVector2Array([tail, tail.lerp(tip, 0.58) + side * flip * size * 0.08, tip]), tint, width)
					_draw_shape(canvas, "chevron", tail, size * 0.18, angle, tint, light, width * 0.6, false)
			2:
				# A multi-panel fan opens sideways, making the second tier a different construction.
				var panels := 3 + int(count >= 3)
				for index in range(panels):
					var offset := (float(index) - (panels - 1) * 0.5) / maxf(1.0, panels - 1)
					var end := at + direction * radius * 0.26 + side * offset * radius * 1.8
					var tail := at - direction * radius * (0.8 + phase * 0.2)
					_poly(canvas, PackedVector2Array([tail, end - direction * size * 0.1,
						end + direction * size * 0.18]), tint, true, width * 0.75)
			3:
				# Crossed, opposite wedges lock into an X around the base weapon/effect.
				for flip: float in [-1.0, 1.0]:
					var axis := direction.rotated(flip * (0.65 + phase * 0.14))
					var normal := axis.orthogonal()
					_poly(canvas, PackedVector2Array([at - axis * radius - normal * size * 0.15,
						at + axis * radius * 0.8, at - axis * radius + normal * size * 0.15,
						at - axis * radius * 0.48]), tint, true, width)
			4:
				# A radial, faceted crown encloses the final stage without inferring extra hits.
				var rays := 4 + count
				for index in range(rays):
					var axis := Vector2.RIGHT.rotated(angle + TAU * index / rays + phase * 0.24)
					var normal := axis.orthogonal()
					_poly(canvas, PackedVector2Array([at + axis * radius * 0.55 - normal * size * 0.1,
						at + axis * radius * (1.15 + 0.1 * float(index % 2)),
						at + axis * radius * 0.55 + normal * size * 0.1]), tint, true, width * 0.7)
				_poly(canvas, _regular(at, radius * 0.53, rays, angle + phase * 0.24), light, false, width * 0.7)


static func _features(recipe: Dictionary) -> Array[Dictionary]:
	var grouped := {}
	for feature: Dictionary in recipe.get("features", []):
		if not str(feature.get("kind", "")).is_empty():
			grouped[feature.kind] = feature
	for kind: String in recipe.get("motif", {}).get("details", []):
		if not grouped.has(kind):
			grouped[kind] = {"kind": kind, "count": 1, "amount": 0.0}
	var result: Array[Dictionary] = []
	for kind: String in FEATURE_PRIORITY:
		if grouped.has(kind):
			result.append(grouped[kind])
		if result.size() >= 8:
			break
	return result


static func _draw_feature(canvas: CanvasItem, feature: Dictionary, source: Vector2, at: Vector2,
		start: Vector2, arrival: Vector2, direction: Vector2, p: float, size: float, hit: bool,
		footprint: Vector2, color: Color, accent: Color) -> void:
	var kind: String = feature.kind
	var count := clampi(int(feature.get("count", 1)), 1, 5)
	var amount := absf(float(feature.get("amount", 0.0)))
	var strength := clampf(amount / (amount + 18.0), 0.0, 1.0)
	var side := direction.orthogonal()
	var angle := direction.angle()
	var radius := size * (0.55 + strength * 0.26)
	var tint := Color(color, color.a * 0.45)
	var ink := Color(accent, accent.a * 0.52)
	var expansion := smoothstep(0.0, 0.8, p)
	match kind:
		"pierce":
			_stroke(canvas, PackedVector2Array([at - direction * radius, at + direction * radius * (0.9 + expansion * 0.35)]), ink, 1.6)
			for index in range(count):
				var mark := at + direction * size * (0.35 + index * 0.16)
				_draw_shape(canvas, "chevron", mark, size * 0.14, angle, tint, ink, 1.0, false)
		"chain", "ricochet", "tether":
			var end := at + side * radius * (1.0 if kind == "chain" else -1.0)
			var begin := source if kind == "tether" else at - direction * radius
			var points := PackedVector2Array([begin, at - direction * radius * 0.2 + side * radius * 0.35, at, end])
			_stroke(canvas, points, tint, 1.4)
			for index in range(count):
				_draw_shape(canvas, "diamond", at + side * radius * (index + 1) / (count + 1), size * 0.09, angle, tint, ink, 1.0, false)
		"splash":
			var extent := footprint if footprint.x > 0.0 else Vector2(radius * 1.4, radius * 0.65)
			_arc(canvas, at + Vector2(0.0, size * 0.6), extent * (0.7 + expansion * 0.35), 0.0, TAU, tint, 1.5)
		"crit", "finish":
			# Sharpened edge geometry describes potential; it is not a guaranteed-critical burst.
			for index in range(2 + int(kind == "finish")):
				var offset := side * (index - 0.5) * size * 0.22
				_stroke(canvas, PackedVector2Array([at + offset - direction * size * 0.2,
					at + offset + direction * size * 0.12, at + offset + direction * size * 0.03 + side * size * 0.12]), tint, 1.25)
		"mark":
			_draw_shape(canvas, "diamond", at, radius * (0.95 - expansion * 0.3), angle + PI * 0.25, tint, ink, 1.3, false)
		"guard", "block", "intercept":
			var center := at if kind != "intercept" else at - direction * size * 0.4
			_draw_shape(canvas, "shield", center, radius, 0.0, tint, ink, 1.4, false)
			if kind == "block":
				_stroke(canvas, PackedVector2Array([center - side * radius, center + side * radius]), ink, 1.1)
		"heal", "overflow":
			for index in range(count):
				var offset := Vector2((float(index) - (count - 1) * 0.5) * size * 0.24, -expansion * size * 0.4)
				_draw_shape(canvas, "cross" if kind == "heal" else "petal", at + offset,
					size * (0.12 + strength * 0.04), 0.0, tint, ink, 1.0, false)
			if kind == "overflow":
				_arc(canvas, at, Vector2(radius, radius * 0.6) * (1.0 + p * 0.3), -PI, PI, tint, 1.1)
		"burn":
			for index in range(count):
				var offset := side * (float(index) - (count - 1) * 0.5) * size * 0.18
				_draw_shape(canvas, "flame", at + offset - Vector2(0, p * size * 0.2), size * 0.18,
					0.08 * sin(p * 9.0 + index), tint, ink, 1.2, false)
		"echo", "repeat", "return":
			for index in range(count):
				var sign := -1.0 if kind == "return" else 1.0
				var center := at - direction * size * (0.3 + index * 0.15) * (0.7 + p * 0.6)
				_arc(canvas, center, Vector2(radius * 0.5, radius * 0.3), angle - sign * 1.2,
					angle + sign * (0.8 + index * 0.12), tint, 1.2)
		"pull":
			for index in range(3):
				var axis := Vector2.RIGHT.rotated(angle + TAU * index / 3.0)
				_draw_shape(canvas, "chevron", at + axis * radius * (1.0 - p * 0.5), size * 0.15,
					axis.angle() + PI, tint, ink, 1.1, false)
		"push", "charge", "travel":
			var center := arrival if kind in ["charge", "travel"] else at
			for index in range(mini(count + 1, 3)):
				_draw_shape(canvas, "chevron", center + direction * size * (0.18 + index * 0.2 + expansion * 0.2),
					size * 0.15, angle, tint, ink, 1.1, false)
		"blink":
			for center: Vector2 in [start, arrival]:
				_draw_shape(canvas, "diamond", center - Vector2(0.0, size * 0.35), radius * (0.7 + p * 0.25),
					PI * 0.25 + p * 0.4, tint, ink, 1.1, false)
		"rune", "harmony":
			var vertices := 4 if kind == "rune" else 6
			_poly(canvas, _regular(at, radius * (0.8 + p * 0.25), vertices, angle + p * 0.3), tint, false, 1.2)
			for index in range(mini(count, 4)):
				var axis := Vector2.RIGHT.rotated(angle + TAU * index / mini(count, 4))
				_stroke(canvas, PackedVector2Array([at + axis * radius * 0.6, at + axis * radius]), ink, 1.0)
		"ally":
			if source.distance_squared_to(at) > 16.0:
				_stroke(canvas, _curve(source, source.lerp(at, 0.5) - Vector2(0.0, size * 0.55), at, 9), tint, 1.0)
			_draw_shape(canvas, "petal", at, size * 0.18, PI * 0.25, tint, ink, 1.1, false)
		"shatter", "collision":
			for index in range(mini(count + 2, 5)):
				var axis := Vector2.RIGHT.rotated(angle + TAU * index / mini(count + 2, 5))
				var point := at + axis * size * (0.48 + expansion * 0.42)
				_poly(canvas, _regular(point, size * 0.08, 3, axis.angle()), tint, true, 1.0)
		"windup":
			_arc(canvas, at, Vector2(radius * 0.9, radius * 0.45), angle - 1.0 - p, angle + 1.0 + p, tint, 1.0)


static func _regular(at: Vector2, radius: float, count: int, angle: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(count):
		points.append(at + Vector2.RIGHT.rotated(angle + TAU * index / count) * radius)
	return points


static func _curve(start: Vector2, control: Vector2, end: Vector2, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(count):
		var p := float(index) / (count - 1)
		points.append(start.lerp(control, p).lerp(control.lerp(end, p), p))
	return points


static func _arc(canvas: CanvasItem, at: Vector2, radius: Vector2, first: float, last: float,
		color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in range(13):
		var angle := lerpf(first, last, float(index) / 12.0)
		points.append(at + Vector2.RIGHT.rotated(angle) * radius)
	_stroke(canvas, points, color, width)


static func _poly(canvas: CanvasItem, points: PackedVector2Array, color: Color, filled: bool, width: float,
		body_alpha := 0.32) -> void:
	if filled:
		canvas.draw_colored_polygon(points, Color(color, color.a * body_alpha))
	var closed := points.duplicate()
	closed.append(points[0])
	_stroke(canvas, closed, color, width)


static func _stroke(canvas: CanvasItem, points: PackedVector2Array, color: Color, width: float) -> void:
	if color.a <= 0.002:
		return
	canvas.draw_polyline(points, Color(INK, color.a * 0.65), width + 1.6, true)
	canvas.draw_polyline(points, color, width, true)
