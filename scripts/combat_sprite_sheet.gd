extends RefCounted

const MANIFEST := "res://assets/sprite_fusion/manifest.json"
const STATES := ["idle", "run", "attack", "hit", "death"]

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
	for state: String in STATES:
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
			frames.append({"rect": bounds, "pivot": Vector2(float(pivot[0]), float(pivot[1]))})
		if frames.is_empty():
			continue
		_clips[state] = {"texture": pixel_texture, "source": source, "frames": frames,
			"fps": maxf(1.0, float(clip.get("fps", 8.0))), "loop": bool(clip.get("loop", state in ["idle", "run"])),
			"contact": clampi(int(clip.get("contact_frame", 0)), 0, frames.size() - 1)}


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


func attack_frame(progress: float, released: bool) -> int:
	var clip: Dictionary = _clips.get("attack", {})
	var count := frame_count("attack")
	if count == 0:
		return 0
	var contact: int = clip.contact
	if not released:
		return clampi(floori(progress * contact), 0, maxi(0, contact - 1))
	return clampi(contact + floori(progress * (count - contact)), contact, count - 1)


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
	var native_height := maxf(1.0, float(_record.get("height", frame.rect.size.y)))
	var scale := height / native_height
	var mirrored: bool = (facing >= 0.0) != (float(_record.get("facing", 1.0)) >= 0.0)
	var position: Vector2 = -frame.pivot * scale
	var extent: Vector2 = frame.rect.size * scale
	if mirrored:
		position.x = (frame.pivot.x - frame.rect.size.x) * scale
		extent.x = -extent.x
	canvas.draw_texture_rect_region(clip.texture, Rect2(position, extent), frame.rect, tint, false, true)
