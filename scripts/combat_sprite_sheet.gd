extends RefCounted

const MANIFEST := "res://assets/sprite_fusion/manifest.json"
const STATES := ["idle", "run", "backpedal", "strafe", "sprint", "dash", "recover", "attack", "attack_quick",
	"attack_heavy", "attack_ranged", "attack_cast", "attack_guard", "attack_mobility", "block", "hit", "death"]
const SOCKETS := ["hand", "blade", "muzzle", "cast", "feet"]
const CLASS_ACTION_DEFAULTS := {
	"warden": "attack_guard", "bulwark": "attack_guard", "breaker": "attack_heavy",
	"hexwright": "attack_cast", "wayfarer": "attack_mobility", "lancer": "attack_quick",
	"cantor": "attack_cast", "apothecary": "attack_ranged", "rune_smith": "attack_heavy",
	"starshot": "attack_ranged", "cinder_mage": "attack_cast", "duelist": "attack_quick",
}

static var _catalog: Dictionary = {}
static var _catalog_loaded := false
static var _sheets: Dictionary = {}

var _record: Dictionary
var _clips: Dictionary = {}
var _idle_texture: Texture2D


static func for_identity(side: String, identity: String) -> RefCounted:
	if not _catalog_loaded:
		_catalog_loaded = true
		if FileAccess.file_exists(MANIFEST):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
			if parsed is Dictionary and int(parsed.get("version", 0)) == 1:
				_catalog = parsed
	var group := "heroes" if side == "hero" else "enemies"
	var key := group + "/" + identity
	if _sheets.has(key):
		return _sheets[key]
	var definition: Variant = _catalog.get(group, {}).get(identity)
	if not definition is Dictionary:
		return null
	var sheet := new(definition)
	if not sheet.has_animation("idle"):
		return null
	_sheets[key] = sheet
	return sheet


func _init(record: Dictionary) -> void:
	_record = record
	var animations: Dictionary = record.get("animations", {})
	for state: String in animations:
		var clip: Dictionary = animations.get(state, {})
		var path: String = clip.get("texture", "")
		if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
			continue
		var source := load(path) as Texture2D
		var pixel_texture := CanvasTexture.new()
		pixel_texture.diffuse_texture = source
		pixel_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var frames: Array[Dictionary] = []
		for frame: Dictionary in clip.get("frames", []):
			var rect: Array = frame.get("rect", [])
			var pivot: Array = frame.get("pivot", [])
			if rect.size() != 4 or pivot.size() != 2:
				continue
			var bounds := Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
			if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 \
					or not Rect2(Vector2.ZERO, source.get_size()).encloses(bounds):
				continue
			var anchors := {}
			for name: String in SOCKETS:
				var point: Variant = frame.get("sockets", {}).get(name)
				if point is Array and point.size() == 2 and is_finite(float(point[0])) and is_finite(float(point[1])):
					anchors[name] = Vector2(float(point[0]), float(point[1]))
			frames.append({"rect": bounds, "pivot": Vector2(float(pivot[0]), float(pivot[1])), "sockets": anchors})
		if frames.is_empty():
			continue
		_clips[state] = {"texture": pixel_texture, "source": source, "frames": frames,
			"fps": maxf(1.0, float(clip.get("fps", 8.0))), "loop": bool(clip.get("loop", state in ["idle", "run", "backpedal", "strafe", "sprint"])),
			"contact": clampi(int(clip.get("contact_frame", 0)), 0, frames.size() - 1),
			"stride_length": maxf(0.0, float(clip.get("stride_length", _record.get("stride_length", 0.0)))),
			"reference_height": maxf(1.0, float(clip.get("reference_height", _record.get("height", source.get_height()))))}


func has_animation(state: String) -> bool:
	return _clips.has(state)


func is_animated(state: String) -> bool:
	return frame_count(state) > 1


func frame_count(state: String) -> int:
	return _clips.get(state, {}).get("frames", []).size()


func duration(state: String) -> float:
	var clip: Dictionary = _clips.get(state, {})
	return float(clip.get("frames", []).size()) / float(clip.get("fps", 8.0))


func frame_at(state: String, age: float) -> int:
	var clip: Dictionary = _clips.get(state, {})
	var count := frame_count(state)
	if count == 0:
		return 0
	var frame := floori(maxf(0.0, age) * float(clip.fps))
	return posmod(frame, count) if clip.loop else mini(frame, count - 1)


func attack_frame(progress: float, released: bool, state := "attack") -> int:
	var clip: Dictionary = _clips.get(state, {})
	var count := frame_count(state)
	if count == 0:
		return 0
	var contact: int = clip.contact
	if not released:
		return clampi(floori(progress * contact), 0, maxi(0, contact - 1))
	return clampi(contact + floori(progress * (count - contact)), contact, count - 1)


func release_seconds(state: String) -> float:
	var clip: Dictionary = _clips.get(state, {})
	if clip.is_empty():
		return 0.24
	return clampf(float(clip.frames.size() - clip.contact) / float(clip.fps), 0.24, 0.62)


static func action_family(profile: Dictionary, identity := "") -> String:
	var style: String = profile.get("style", "slash")
	var beats := int(profile.get("tile_animation", {}).get("beats", profile.get("beats", 0)))
	if style == "spin" or (beats >= 4 and style in ["shot", "bolt", "heavy", "burst", "mine", "thrust"]):
		return "attack_ranged" if identity == "apothecary" else "attack_heavy"
	match style:
		"guard": return "attack_guard"
		"blink", "dash": return "attack_mobility"
		"ward": return "attack_guard" if identity in ["warden", "bulwark", "hexwright", "cantor"] else "attack_cast"
		"pull", "heal", "mark": return "attack_cast"
		"shot", "bolt":
			return "attack_cast" if identity in ["hexwright", "cantor", "cinder_mage", "rune_smith"] else "attack_ranged"
		"heavy", "burst", "mine":
			return "attack_ranged" if identity == "apothecary" else ("attack_cast" if identity in ["hexwright", "cantor", "cinder_mage"] else "attack_heavy")
		_: return "attack_quick"


func action_for(profile: Dictionary, identity := "") -> String:
	var family := action_family(profile, identity)
	if is_animated(family):
		return family
	# Source-specific authored mappings can select a reviewed clip without renaming its art.
	var mappings: Dictionary = _record.get("action_families", {})
	var mapped: String = mappings.get(family, mappings.get(family.trim_prefix("attack_"), ""))
	if is_animated(mapped):
		return mapped
	if is_animated("attack"):
		return "attack"
	var preferred: String = CLASS_ACTION_DEFAULTS.get(identity, "")
	return preferred if is_animated(preferred) else ""


func stride_frame(state: String, distance: float, fallback_stride: float, reverse := false) -> int:
	var count := frame_count(state)
	if count <= 0:
		return 0
	var stride := maxf(1.0, float(_record.get("stride_length", fallback_stride)))
	var clip: Dictionary = _clips.get(state, {})
	if float(clip.get("stride_length", 0.0)) > 0.0:
		stride = float(clip.stride_length)
	var frame := floori(fposmod(distance / stride, 1.0) * count)
	return posmod(-frame, count) if reverse else frame


func socket_pixel(state: String, frame_index: int, name: String) -> Vector2:
	var clip: Dictionary = _clips.get(state, _clips.get("idle", {}))
	if clip.is_empty():
		return Vector2.ZERO
	var frame: Dictionary = clip.frames[clampi(frame_index, 0, clip.frames.size() - 1)]
	if frame.sockets.has(name):
		return frame.sockets[name]
	if name == "feet":
		return frame.pivot
	var forward := native_facing()
	var points := {"hand": Vector2(0.5 + forward * 0.18, 0.48), "blade": Vector2(0.5 + forward * 0.35, 0.42),
		"muzzle": Vector2(0.5 + forward * 0.36, 0.39), "cast": Vector2(0.5 + forward * 0.21, 0.35)}
	return points.get(name, Vector2(0.5, 0.5)) * frame.rect.size


func has_socket(state: String, frame_index: int, name: String) -> bool:
	var clip: Dictionary = _clips.get(state, _clips.get("idle", {}))
	return not clip.is_empty() and clip.frames[clampi(frame_index, 0, clip.frames.size() - 1)].sockets.has(name)


func frame_size(state: String, frame_index: int) -> Vector2:
	var clip: Dictionary = _clips.get(state, _clips.get("idle", {}))
	return Vector2.ZERO if clip.is_empty() else clip.frames[clampi(frame_index, 0, clip.frames.size() - 1)].rect.size


func socket_offset(state: String, frame_index: int, name: String, height: float, facing: float) -> Vector2:
	var clip: Dictionary = _clips.get(state, _clips.get("idle", {}))
	if clip.is_empty():
		return Vector2.ZERO
	var frame: Dictionary = clip.frames[clampi(frame_index, 0, clip.frames.size() - 1)]
	var offset: Vector2 = (socket_pixel(state, frame_index, name) - frame.pivot) * height / float(clip.reference_height)
	if (facing >= 0.0) != (native_facing() >= 0.0):
		offset.x = -offset.x
	return offset


func display_height(default_height: float) -> float:
	return float(_record.get("model_height", default_height))


func native_facing() -> float:
	return 1.0 if float(_record.get("facing", 1.0)) >= 0.0 else -1.0


func fallback_layout(height: float) -> Dictionary:
	var frame: Dictionary = _clips.idle.frames[0]
	var scale := height / maxf(1.0, float(_record.get("height", frame.rect.size.y)))
	return {"height": frame.rect.size.y * scale,
		"offset": (Vector2(frame.rect.size.x * 0.5, frame.rect.size.y) - frame.pivot) * scale}


func idle_texture() -> Texture2D:
	if _idle_texture != null:
		return _idle_texture
	var clip: Dictionary = _clips.get("idle", {})
	if clip.is_empty():
		return null
	var frame: Dictionary = clip.frames[0]
	var texture := AtlasTexture.new()
	texture.atlas = clip.texture
	texture.region = frame.rect
	texture.filter_clip = true
	_idle_texture = texture
	return _idle_texture


func draw_frame(canvas: CanvasItem, state: String, frame_index: int, height: float,
		facing: float, tint: Color = Color.WHITE) -> void:
	var clip: Dictionary = _clips.get(state, _clips.get("idle", {}))
	if clip.is_empty():
		return
	var frame: Dictionary = clip.frames[clampi(frame_index, 0, clip.frames.size() - 1)]
	var native_height: float = clip.reference_height
	var scale := height / native_height
	var mirrored: bool = (facing >= 0.0) != (float(_record.get("facing", 1.0)) >= 0.0)
	var position: Vector2 = -frame.pivot * scale
	var extent: Vector2 = frame.rect.size * scale
	if mirrored:
		position.x = (frame.pivot.x - frame.rect.size.x) * scale
		extent.x = -extent.x
	canvas.draw_texture_rect_region(clip.texture, Rect2(position, extent), frame.rect, tint, false, true)
