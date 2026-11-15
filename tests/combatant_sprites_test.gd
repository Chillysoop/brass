extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const GameIcons = preload("res://scripts/game_icons.gd")

var _failures: Array[String] = []
var _sprite_sources: Dictionary = {}


func _initialize() -> void:
	var sim := ArenaSim.new()
	var enemy_ids := ArenaSim.CAMPAIGN_ENEMIES.keys()
	for enemies in ArenaSim.PILOT_ENEMY_SCRIPTS.values():
		enemy_ids.append_array(enemies.ENEMIES.keys())
	for id: String in enemy_ids:
		sim._add_campaign_enemy(id, Vector2.ZERO)
		var enemy: Dictionary = sim.units.back()
		_check_sprite(enemy.name, GameIcons.enemy_art(enemy.get("sprite", "")))

	sim.start(ArenaSim.default_lanes())
	for unit: Dictionary in sim.units:
		if unit.side == "enemy":
			_check_sprite(unit.name, GameIcons.enemy_art(unit.get("sprite", "")))
	var enemy_count := _sprite_sources.size()
	for id: String in ArenaSim.HERO_CLASSES:
		_check_sprite(ArenaSim.HERO_CLASSES[id].label, GameIcons.hero_art(id))

	for failure: String in _failures:
		printerr(failure)
	if _failures.is_empty():
		print("Verified %d distinct hero sprites and %d distinct enemy sprites across the campaign and practice."
			% [ArenaSim.HERO_CLASSES.size(), enemy_count])
	quit(0 if _failures.is_empty() else 1)


func _check_sprite(name: String, texture: Texture2D) -> void:
	if texture == null:
		_failures.append("Missing sprite for %s." % name)
		return
	var image := texture.get_image()
	if image == null or not image.get_used_rect().has_area():
		_failures.append("Sprite for %s has no visible pixels." % name)
		return
	var source := texture.resource_path
	if texture is AtlasTexture:
		source = "%s %s" % [texture.atlas.resource_path, texture.region]
	var existing: String = _sprite_sources.get(source, "")
	if not existing.is_empty() and existing != name:
		_failures.append("%s and %s share the same sprite." % [existing, name])
	_sprite_sources[source] = name
