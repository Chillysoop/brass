extends RefCounted

const ROOT := "res://assets/sprite_fusion/vfx/"
const FRAME_SIZE := 192.0
const ANCHOR := Vector2(96, 132)
const CLIPS := {
	"slash": 32, "impact": 32, "muzzle": 32, "dash": 32, "blink": 32, "fire": 32,
	"energy_charge": 48, "gold_charge": 48, "energy": 32, "gold_ray": 8, "arc_ray": 8, "shield_charge": 24, "shield": 32,
	"black_hole": 40, "holy_charge": 24, "holy_light": 40, "heal": 48, "explosion": 40,
}
const STYLE_CLIPS := {
	"slash": "slash", "spin": "slash", "thrust": "impact", "heavy": "impact",
	"burst": "explosion", "mine": "explosion", "shot": "muzzle", "bolt": "energy",
	"pull": "black_hole", "blink": "blink", "dash": "impact", "guard": "shield",
	"ward": "holy_light", "heal": "heal", "mark": "energy",
}
const STATUS_CLIPS := {
	"ember_ignite": "fire", "ember_tick": "fire", "guard": "shield", "guard_break": "impact",
	"guard_spent": "shield", "bastion_release": "shield", "heal": "heal", "repair_heal": "heal",
	"rune_charge_ready": "energy", "rune_charge_spent": "energy", "mark": "energy", "mark_spent": "impact",
	"class_relic_wave": "impact", "hammer_collision": "impact",
}
const RELEASE_SECONDS := {
	"slash": 0.54, "impact": 0.50, "muzzle": 0.55, "dash": 0.65, "blink": 1.05,
	"fire": 0.80, "energy": 0.57, "shield": 0.60, "black_hole": 1.50,
	"holy_light": 0.77, "heal": 1.20, "explosion": 1.20,
}

static var _textures: Dictionary = {}
static var _clips: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json")).clips


static func release_key(profile: Dictionary) -> String:
	return profile.get("sprite_fusion", STYLE_CLIPS.get(profile.get("style", ""), ""))


static func release_seconds(profile: Dictionary) -> float:
	return RELEASE_SECONDS.get(release_key(profile), 0.45)


static func draw_release(canvas: CanvasItem, profile: Dictionary, start: Vector2, target: Vector2,
		arrival: Vector2, progress: float, size: float, hit: bool, footprint: Vector2, layer: String) -> bool:
	var key := release_key(profile)
	if key.is_empty():
		return false
	var direction := start.direction_to(target)
	var color := Color.WHITE.lerp(profile.get("color", Color.WHITE), 0.65 if key == "fire" else 0.25)
	var chest := Vector2(0, -size * 0.75)
	var scale := clampf(size / 43.0, 0.36, 1.05)
	match profile.get("style", ""):
		"shot":
			var muzzle := start + Vector2(0.0, -size * 1.25) + direction * size * 0.45
			var contact := target + Vector2(0.0, -size) if hit else muzzle + direction * size * 1.15
			_draw_release_ray(canvas, "gold_ray", muzzle, contact, progress * release_seconds(profile), size, layer, color)
			draw_clip(canvas, "muzzle" if key == "muzzle" else key, muzzle, progress, scale * 1.2, layer,
				direction.angle() if key == "muzzle" else 0.0, color)
			if hit:
				draw_clip(canvas, "impact" if key == "muzzle" else key, contact, progress, scale * (1.65 if key == "fire" else 1.0), layer,
				direction.angle() if key == "muzzle" else 0.0, color)
		"bolt":
			var muzzle := start + Vector2(0.0, -size * 1.65) + direction * size * 0.42
			var contact := target + Vector2(0.0, -size) if hit else muzzle + direction * size * 1.15
			_draw_release_ray(canvas, "gold_ray" if key == "fire" else "arc_ray", muzzle, contact,
				progress * release_seconds(profile), size, layer, color)
			draw_clip(canvas, key, muzzle, progress, scale * 0.80, layer, 0.0, color)
			if hit:
				draw_clip(canvas, key if key == "fire" else "impact", contact, progress, scale * (1.7 if key == "fire" else 1.1), layer, 0.0, color)
		"blink":
			if hit:
				draw_clip(canvas, "impact", target + chest, progress, scale * 0.8, layer, direction.angle(), color)
		"dash":
			if hit:
				draw_clip(canvas, key, target + chest, progress, scale, layer, arrival.direction_to(target).angle(), color)
		"slash", "spin":
			var anchor := (start.lerp(target, 0.48) if hit else start.move_toward(target, size * 0.6)) + chest
			draw_clip(canvas, key, anchor, progress, scale, layer, direction.angle(), color)
		"guard", "ward", "heal", "mark":
			draw_clip(canvas, key, target if hit else start, progress, scale, layer, 0.0, color)
		_:
			var at := target if hit else start.move_toward(target, size * 1.1)
			if footprint.x > 0.0 and footprint.y > 0.0:
				draw_clip(canvas, key, at, progress, Vector2(footprint.x / 58.0, footprint.y / 30.0).clamp(Vector2.ONE * 0.35, Vector2.ONE * 2.1), layer, 0.0, color)
			else:
				draw_clip(canvas, key, at + chest * 0.3, progress, scale * (1.6 if key == "fire" else 1.0), layer, direction.angle() if key == "impact" else 0.0, color)
	return true


static func _draw_release_ray(canvas: CanvasItem, key: String, origin: Vector2, target: Vector2,
		age: float, size: float, layer: String, tint: Color) -> void:
	if age >= 0.14 or origin.distance_squared_to(target) < 4.0:
		return
	var distance := origin.distance_to(target)
	var fade := 1.0 - smoothstep(0.035, 0.14, age)
	var scale := Vector2(distance / 100.0, clampf(size / 24.0, 0.65, 1.8))
	draw_clip(canvas, key, origin.lerp(target, 0.5), age / 0.14,
		scale, layer, origin.direction_to(target).angle(), Color(tint, tint.a * fade))


static func draw_anticipation(canvas: CanvasItem, at: Vector2, facing: float, size: float,
		progress: float, profile: Dictionary, beats: float) -> void:
	var phase := clampf(progress, 0.0, 0.999)
	var long_cast := clampf((beats - 1.0) / 4.0, 0.0, 1.0)
	var readiness := smoothstep(0.0, 0.28, phase)
	var gathering := smoothstep(0.22, 0.76, phase)
	var poised := smoothstep(0.72, 1.0, phase)
	var key := release_key(profile)
	var magical: bool = key in ["energy", "black_hole", "holy_light", "heal", "blink"]
	var charge_key := "energy_charge" if magical else "gold_charge"
	var anchor := at + Vector2(facing * size * 0.25, -size * 0.51)
	var scale := clampf(size / 100.0, 0.32, 1.0) * lerpf(0.55, 1.0, gathering) * (1.0 + long_cast * 0.20)
	var tint := Color.WHITE.lerp(profile.get("color", Color.WHITE), 0.36)
	tint.a = 0.15 + readiness * 0.16 + gathering * 0.28 + poised * 0.22
	for layer: String in ["back", "front"]:
		draw_clip(canvas, charge_key, anchor, lerpf(0.02, 0.965, phase), scale, layer, 0.0, tint)
		if long_cast > 0.20:
			var base := "holy_charge" if key in ["holy_light", "heal"] else "shield_charge"
			var base_tint := Color(tint, tint.a * long_cast * (0.26 + poised * 0.32))
			draw_clip(canvas, base, at, phase, scale * 0.82, layer, 0.0, base_tint)
		if long_cast > 0.60 and poised > 0.0:
			draw_clip(canvas, "energy", anchor, 0.12 + poised * 0.3, scale * 0.52, layer, 0.0, Color(tint, poised * 0.46))


static func draw_status(canvas: CanvasItem, kind: String, at: Vector2, progress: float,
		size: float, footprint := Vector2.ZERO) -> bool:
	var key: String = STATUS_CLIPS.get(kind, "")
	if key.is_empty():
		return false
	var scale := Vector2.ONE * clampf(size / 48.0, 0.30, 0.95)
	if footprint.x > 0.0 and footprint.y > 0.0:
		scale = Vector2(footprint.x / 58.0, footprint.y / 30.0).clamp(Vector2.ONE * 0.3, Vector2.ONE * 2.0)
	var phase := progress
	if kind == "ember_tick":
		phase = lerpf(0.14, 0.68, progress)
	for layer: String in ["back", "front"]:
		draw_clip(canvas, key, at, phase, scale, layer)
	return true


static func draw_blink(canvas: CanvasItem, start: Vector2, arrival: Vector2, progress: float) -> void:
	for layer: String in ["back", "front"]:
		draw_clip(canvas, "blink", start, progress, 0.42, layer, 0.0, Color(0.82, 0.76, 1.0, 0.80))
		draw_clip(canvas, "blink", arrival, minf(0.999, 0.22 + progress * 0.78), 0.50, layer)


static func draw_motion_path(canvas: CanvasItem, points: PackedVector2Array, progress: float,
		tone: Color, size := 26.0) -> void:
	if points.size() < 2:
		return
	var length := 0.0
	for index in range(1, points.size()):
		length += points[index - 1].distance_to(points[index])
	if length < 2.0:
		return
	# Keep dust and authored speed lines small; the caller retains the exact route outline.
	var stamps := clampi(ceili(length / 90.0), 1, 4)
	var scale := clampf(size / 65.0, 0.33, 0.72)
	var tint := Color.WHITE.lerp(tone, 0.36)
	tint.a = 0.68 * (1.0 - smoothstep(0.25, 1.0, progress))
	for index in range(stamps):
		var sample := _motion_sample(points, length * float(index + 1) / stamps)
		var direction: Vector2 = sample.direction
		var at: Vector2 = sample.point - direction * 37.5 * scale
		for layer: String in ["back", "front"]:
			draw_clip(canvas, "dash", at, 0.22 + progress * 0.78, scale, layer, direction.angle(), tint)


static func _motion_sample(points: PackedVector2Array, distance: float) -> Dictionary:
	var remaining := distance
	for index in range(1, points.size()):
		var segment := points[index - 1].distance_to(points[index])
		if segment <= 0.001:
			continue
		if remaining <= segment or index == points.size() - 1:
			return {"point": points[index - 1].lerp(points[index], clampf(remaining / segment, 0.0, 1.0)),
				"direction": points[index - 1].direction_to(points[index])}
		remaining -= segment
	return {"point": points[-1], "direction": Vector2.RIGHT}


static func draw_clip(canvas: CanvasItem, key: String, at: Vector2, progress: float,
		pixel_scale: Variant, layer := "front", angle := 0.0, tint := Color.WHITE) -> bool:
	if not CLIPS.has(key):
		return false
	var clip: Dictionary = _clips[key]
	if layer in clip.empty_layers:
		return true
	var texture_key := key + "_" + layer
	if not _textures.has(texture_key):
		var pixel_texture := CanvasTexture.new()
		pixel_texture.diffuse_texture = load(ROOT + texture_key + ".png")
		pixel_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_textures[texture_key] = pixel_texture
	var texture: Texture2D = _textures[texture_key]
	if texture == null:
		return false
	var scale: Vector2 = pixel_scale if pixel_scale is Vector2 else Vector2.ONE * float(pixel_scale)
	var index := mini(int(CLIPS[key]) - 1, floori(clampf(progress, 0.0, 0.9999) * int(CLIPS[key])))
	var frame_size := Vector2(clip.frame_size[0], clip.frame_size[1])
	var anchor := Vector2(clip.anchor[0], clip.anchor[1])
	var region := Rect2(Vector2(index % 8, index / 8) * frame_size, frame_size)
	# Transform the atlas quad around the authored effect origin without replacing the caller's canvas transform.
	var points := PackedVector2Array()
	for corner: Vector2 in [Vector2.ZERO, Vector2(frame_size.x, 0), frame_size, Vector2(0, frame_size.y)]:
		points.append(at + ((corner - anchor) * scale).rotated(angle))
	var uv_size := texture.get_size()
	var uvs := PackedVector2Array([region.position / uv_size,
		(region.position + Vector2(region.size.x, 0)) / uv_size, region.end / uv_size,
		(region.position + Vector2(0, region.size.y)) / uv_size])
	canvas.draw_polygon(points, PackedColorArray([tint]), uvs, texture)
	return true
