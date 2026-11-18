extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const GameIcons = preload("res://scripts/game_icons.gd")
const BrassVanguardCannon = preload("res://scripts/brass_vanguard_cannon.gd")
const MANIFEST := "res://assets/sprite_fusion/manifest.json"

var _failures: Array[String] = []
var _pixel_owners: Dictionary = {}


func _initialize() -> void:
	var heroes := {}
	for id: String in ArenaSim.HERO_CLASSES:
		heroes[id] = ArenaSim.HERO_CLASSES[id].label
	var enemies := _enemy_roster()
	_check(heroes.size() == 12 and enemies.size() == 92,
		"The Sprite Fusion package covers all 12 hero and 92 enemy identities.")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)) if FileAccess.file_exists(MANIFEST) else null
	if _check(parsed is Dictionary and int(parsed.get("version", 0)) == 1,
			"The versioned Sprite Fusion character manifest must be present and readable."):
		_check_group("heroes", heroes, parsed.get("heroes", {}))
		_check_group("enemies", enemies, parsed.get("enemies", {}))
	for failure: String in _failures:
		printerr(failure)
	if _failures.is_empty():
		print("Verified all 104 Sprite Fusion identities, runtime art, alpha, frame dimensions and distinct pixels.")
	quit(0 if _failures.is_empty() else 1)


func _enemy_roster() -> Dictionary:
	var roster := {}
	var sim := ArenaSim.new()
	var enemy_ids := ArenaSim.CAMPAIGN_ENEMIES.keys()
	enemy_ids.append_array(BrassVanguardCannon.ENEMIES.keys())
	for enemies in ArenaSim.PILOT_ENEMY_SCRIPTS.values():
		enemy_ids.append_array(enemies.ENEMIES.keys())
	for id: String in enemy_ids:
		sim._add_campaign_enemy(id, Vector2.ZERO)
		var enemy: Dictionary = sim.units.back()
		roster[enemy.sprite] = enemy.name
	sim.start(ArenaSim.default_lanes())
	for unit: Dictionary in sim.units:
		if unit.side == "enemy":
			roster[unit.sprite] = unit.name
	return roster


func _check_group(group: String, expected: Dictionary, records: Variant) -> void:
	if not _check(records is Dictionary, "The manifest needs a %s dictionary." % group):
		return
	_check(records.size() == expected.size() and records.keys().all(func(id: String): return expected.has(id)),
		"The %s manifest keys match the canonical runtime identities." % group)
	var prefix := "hero" if group == "heroes" else "enemy"
	for id: String in expected:
		var identity := "%s/%s" % [group, id]
		var record: Variant = records.get(id)
		if not _check(record is Dictionary, "%s has a manifest record." % identity):
			continue
		_check(record.get("label", "") == expected[id], "%s retains its canonical label." % identity)
		var animations: Variant = record.get("animations", {})
		if not _check(animations is Dictionary and animations.get("idle") is Dictionary,
				"%s has an idle animation definition." % identity):
			continue
		var path := "res://assets/sprite_fusion/characters/%s_%s.png" % [prefix, id]
		var idle: Dictionary = animations.idle
		_check(idle.get("texture", "") == path, "%s uses its own canonical Sprite Fusion PNG." % identity)
		var image := _source_image(path, identity)
		if image == null:
			continue
		var frames: Variant = idle.get("frames", [])
		if _check(frames is Array and frames.size() == 1 and frames[0] is Dictionary,
				"%s stores one base idle frame." % identity):
			var bounds := _frame_bounds(frames[0], identity)
			_check(bounds == Rect2i(Vector2i.ZERO, image.get_size()),
				"%s stores the PNG's actual dimensions in its idle frame." % identity)
		var fingerprint := _pixel_hash(image)
		var previous: String = _pixel_owners.get(fingerprint, "")
		_check(previous.is_empty(), "%s and %s have different artwork." % [identity, previous])
		_pixel_owners[fingerprint] = identity
		var texture := GameIcons.hero_art(id) if group == "heroes" else GameIcons.enemy_art(id)
		if not _check(texture != null and texture.resource_path == path,
				"%s resolves to the new artwork through the normal runtime loader." % identity):
			continue
		var runtime_image := texture.get_image()
		_check(runtime_image != null and runtime_image.get_size() == image.get_size()
			and runtime_image.get_used_rect().has_area(), "%s remains visible after texture import." % identity)


func _source_image(path: String, identity: String) -> Image:
	if not _check(FileAccess.file_exists(path), "%s has a source PNG at %s." % [identity, path]):
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if not _check(image != null and not image.is_empty(), "%s has a decodable source PNG." % identity):
		return null
	_check(image.get_used_rect().has_area(), "%s has visible source pixels." % identity)
	_check(image.detect_alpha() != Image.ALPHA_NONE, "%s has real transparency around its silhouette." % identity)
	return image


func _frame_bounds(frame: Dictionary, identity: String) -> Rect2i:
	var rect: Variant = frame.get("rect", [])
	if not _check(rect is Array and rect.size() == 4, "%s stores a four-coordinate idle frame." % identity):
		return Rect2i()
	for coordinate in rect:
		if not _check((coordinate is int or coordinate is float) and float(coordinate) == float(int(coordinate)),
				"%s stores whole-pixel frame bounds." % identity):
			return Rect2i()
	return Rect2i(int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3]))


func _pixel_hash(image: Image) -> String:
	var normalized := image.duplicate() as Image
	normalized.convert(Image.FORMAT_RGBA8)
	# Hidden RGB beneath zero alpha must not disguise identical visible artwork.
	normalized.premultiply_alpha()
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(str(normalized.get_size()).to_utf8_buffer())
	context.update(normalized.get_data())
	return context.finish().hex_encode()


func _check(condition: bool, description: String) -> bool:
	if not condition:
		_failures.append(description)
	return condition
